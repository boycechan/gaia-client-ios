//
//  © 2020 - 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation
import GaiaBase
import PluginBase
import Packets
import GaiaLogger

// MARK: -

private extension UpdateCompletionStatus {
    init(status: UpdateCompleteIndStatusCode) {
        switch status {
        case .UNDEFINED, .COMMIT_AND_SECURITY_UPDATE_SUCCESS:
            self = .success
        case .COMMIT_SUCCESS_SECURITY_UPDATE_FAILED:
            self = .updateSuccessButSecurityUpdateFailed
        }
    }
}

class UpdateProgressInfo {
    enum GaiaUpdateResumePoint: UInt8 {
        case start
        case validate
        case reboot
        case postReboot
        case commit
    }

    var fileMD5: Data?
    var dataBuffer = [Data]()
    var startTime: TimeInterval = 0
    var resumePoint: GaiaUpdateResumePoint = .start
    var startResumePointPermitted = true
    var userState = UpdateState.ready
	var updateInProgress = false
    var needToValidate = false
    var transferCompleteAcknowledged = false
    var didAbort = false
    var syncAfterAbort = false
    var completionStatus = UpdateCompleteIndStatusCode.UNDEFINED

    var dataPacketMaxBytes: UInt = 0

    var skipped: UInt32 = 0
    var progress: UInt32 = 0
    var transferSize: UInt32 = 0
    var startOffset: UInt32 = 0
    var bytesToSend: UInt32 = 0
}

// MARK: -

public class GaiaDeviceUpdaterPlugin: NSObject,
                               GaiaDeviceUpdaterPluginProtocol,
                             GaiaNotificationSender {

    // MARK: Private ivars
    private static let GATTHeaderSize: Int = 8 // PDU length (4 bytes) + upgrade command (1 byte), data length (2 bytes), more comming flag (1 byte) = 8
    private static let ATTHeaderSize: Int = 3
    private static let GAIADataHeaderSize: Int = GATTHeaderSize + ATTHeaderSize
    private static let RWCPDataHeaderSize: Int = GATTHeaderSize + 1 + ATTHeaderSize
    private static let IAP2DataHeaderSize: Int = GATTHeaderSize + 4
    private static let IAP2DataHeaderExtendedSize: Int = GATTHeaderSize + 5

    internal private(set) var rwcpAvailable = false
    internal private(set) var silentCommitConfirmed: Bool = false
    internal private(set) var updateUrl: URL?
    private weak var device: GaiaDeviceIdentifierProtocol?
    private let devicePluginVersion: UInt8
    private let connection: GaiaDeviceConnectionProtocol
    private let notificationCenter : NotificationCenter
    private let protocolVersionForSilentCommit: UInt8 = 4

    private var updater: GaiaDeviceUpdaterProtocol?
    private var rwcpHandler: GaiaRWCPHandlerProtocol?
    private var registeredForNotifications = false
    private var protocolVersion: UInt8 = 0
    private var updateProgress: UpdateProgressInfo

    private var startTime: TimeInterval {
        return updateProgress.startTime
    }

    private var useRWCP: Bool {
        switch ongoingDFUState {
        case .active(_, let settings, _):
            switch settings {
            case .bleRWCP(_, _, _, _):
                return true
            default:
                return false
            }
        default:
            return false
        }
    }

    private var fileData: Data? {
        switch ongoingDFUState {
        case .active(_, _, let data):
            return data
        default:
            return nil
        }
    }

    private var isPaused: Bool {
        switch updateProgress.userState {
        case .busy(progress: let progress):
            return progress == .paused
        default:
            return false
        }
    }

    private var isUnpausing: Bool {
        switch updateProgress.userState {
        case .busy(progress: let progress):
            return progress == .unpausing
        default:
            return false
        }
    }

    private var dataLengthExtensionAvailable: Bool {
        return connection.isDataLengthExtensionSupported
    }

    private var maximumWriteLength: Int {
        return connection.maximumWriteLength
    }

    private var maximumWriteLengthNoResponse: Int {
        return connection.maximumWriteWithoutResponseLength
    }

    // MARK: Public ivars
    public static let featureID: GaiaDeviceQCPluginFeatureID = .upgrade

    public private(set) var silentCommitSupported: Bool = false

    public var updateState: UpdateState {
        return updateProgress.userState
    }

    public var percentProgress: Double {
        if updateProgress.transferSize == 0 {
            return 0
        }
        return (Double(updateProgress.progress) / Double(updateProgress.transferSize)) * 100.0
    }

    public var timeRemaining: TimeInterval {
        let unskippedTransferSize = updateProgress.transferSize - updateProgress.skipped
        let transferredNotSkipped = updateProgress.progress - updateProgress.skipped

        if unskippedTransferSize == 0 {
            return 0
        }

        if transferredNotSkipped == 0 {
            return 0
        }

        let timeTaken = Date.timeIntervalSinceReferenceDate - startTime
        let done = Double(transferredNotSkipped) / Double(unskippedTransferSize)
        let fullTime = timeTaken / done
        let remaining = fullTime - timeTaken
        return max(0, remaining)
    }

    public private(set)var ongoingDFUState = DFUState.none

    public var isUpdating: Bool {
        return updateProgress.updateInProgress
    }

    public var restartUpdateAfterConnection: Bool {
        if updateProgress.didAbort {
            // We may get disconnection after we aborted for an error but we expect a restart after the abort.
            return updateProgress.updateInProgress && updateProgress.syncAfterAbort
        } else {
            return updateProgress.updateInProgress
        }
    }

    public var transportCapabilities: UpdateTransportCapabilities {
        switch connection.connectionKind {
        case .iap2:
            return .iap2(lengthExtensionAvailable: connection.isDataLengthExtensionSupported,
                         maxMessageSize: connection.maximumWriteLength,
                         optimumMessageSize: connection.optimumWriteLength)
        case .ble:
            return .ble(lengthExtensionAvailable: connection.isDataLengthExtensionSupported,
                        rwcpAvailable: rwcpAvailable,
                        maxMessageSize: connection.maximumWriteLength,
                        optimumMessageSize: connection.optimumWriteLength)
        }
    }

    // MARK: init/deinit
    public required init(version: UInt8,
                  device: GaiaDeviceIdentifierProtocol,
                  connection: GaiaDeviceConnectionProtocol,
                  notificationCenter: NotificationCenter) {
        
        self.devicePluginVersion = version
        self.device = device
        self.connection = connection
        self.notificationCenter = notificationCenter
        self.updateProgress = UpdateProgressInfo()

        switch device.version {
        case .v2:
            updater = GaiaV2Updater(connection: connection)
        case .v3:
            updater = GaiaV3Updater(connection: connection)
        default:
            updater = GaiaV3Updater(connection: connection)
        }

        super.init()

        rwcpHandler = GaiaRWCPHandler(connection: connection, delegate: self)
    }

    deinit {
        if useRWCP {
            rwcpHandler?.teardown()
        }
    }

    // MARK: Public GaiaDevicePluginProtocol Methods
    public func startPlugin() {
        guard let device else {
            return
        }

        if device.version == .v3 {
            // V3 registers plugins in device class so don't do it here.
            if connection.connectionKind == .ble {
                // RWCP status check for BLE
                updater?.setDataEndpointMode(true)
            } else {
                let notification = GaiaDeviceUpdaterPluginNotification(sender: self,
                                                                       payload: device,
                                                                       reason: .ready)
                notificationCenter.post(notification)
            }
        } else {
            if connection.connectionKind == .ble {
                // RWCP status check for BLE
                updater?.setDataEndpointMode(true)
            }
            updater?.registerForUpgradeNotifications() // Ready on receipt
        }
    }
    
    public func stopPlugin() {
		updater?.cancelUpgradeNotificationRegistration()
    }

    public func handoverDidOccur() {
    }

    public func responseReceived(messageDescription: IncomingMessageDescription) {
        guard
            let _ = updater
        else {
            return
        }

        handleResponseReceived(messageDescription: messageDescription)
    }

    public func dataReceived(_ data: Data) {
        rwcpHandler?.didReceive(data: data)
    }

    public func didSendData(channel: GaiaDeviceConnectionChannel, error: GaiaError?) {
        if channel == .command && updateProgress.updateInProgress {
            handleDataSent(error: error)
        }
    }

    public func notificationStateDidChange(_ registered: Bool) {
        LOG(.high, "Updater is registered for notifications - v3 only")
        registeredForNotifications = true
    }
}

// MARK: - Public GaiaDeviceUpdaterPluginProtocol Methods
public extension GaiaDeviceUpdaterPlugin {
    func startUpdate(fileData: Data,
                     requestedSettings: UpdateTransportOptions,
                     previousTransferCompleted: Bool) {
        assert(registeredForNotifications)
        
        guard let device = device else {
            return
        }

        if !isPaused && updateProgress.updateInProgress {
            return
        }

        ongoingDFUState = .active(connectionID: device.connectionID,
                                  settings: requestedSettings,
                                  data: fileData)


        updateProgress = UpdateProgressInfo()
        setUserStateAndNotify(.busy(progress: .connecting))
        
        updateProgress.startResumePointPermitted = !previousTransferCompleted
        LOG(.high, "UPDATE: startResumePointPermitted: \(updateProgress.startResumePointPermitted)")

        updateProgress.fileMD5 = fileData.md5()
        updateProgress.transferSize = UInt32(fileData.count)

        switch requestedSettings {
        case .ble(useDLE: let useDLE, requestedMessageSize: let requestedMessageSize):
            if connection.connectionKind != .ble {
                setUserStateAndNotify(.stopped(reason: .aborted(error: .invalidParameters)))
                return
            }

            updater?.dataPacketsRequireACKs = true

            // As user can choose smaller packets we need to calculate available space here
            let packetSize = (useDLE && dataLengthExtensionAvailable) ? requestedMessageSize : min(requestedMessageSize, UpdateTransportOptions.Constants.maxSizeWithoutDLE)

			updateProgress.dataPacketMaxBytes = UInt((packetSize - Self.GAIADataHeaderSize) / 2) * 2 // Round down to even number
            LOG(.medium, "******** request total packet length: \(packetSize) databytes: \(updateProgress.dataPacketMaxBytes)")
        case .bleRWCP(let useDLE, let requestedMessageSize, let initialWindowSize, let maxWindowSize):
            if connection.connectionKind != .ble || !rwcpAvailable {
                setUserStateAndNotify(.stopped(reason: .aborted(error: .invalidParameters)))
                return
            }

            rwcpHandler?.prepareForUpdate(initialCongestionWindowSize: initialWindowSize, maximumCongestionWindowSize: maxWindowSize)

            updater?.dataPacketsRequireACKs = false

            let packetSize = (useDLE && dataLengthExtensionAvailable) ? requestedMessageSize : min(requestedMessageSize, UpdateTransportOptions.Constants.maxSizeWithoutDLE)

            updateProgress.dataPacketMaxBytes = UInt((packetSize - Self.RWCPDataHeaderSize) / 2) * 2 // Round down to even number
            LOG(.medium, "******** request total packet length: \(packetSize) databytes: \(updateProgress.dataPacketMaxBytes)")

        case .iap2(let useDLE, let requestedMessageSize, let expectACKs):
            if connection.connectionKind != .iap2 || device.version != .v3 {
                setUserStateAndNotify(.stopped(reason: .aborted(error: .invalidParameters)))
                return
            }

            updater?.dataPacketsRequireACKs = expectACKs

            let packetSize = useDLE ? min(requestedMessageSize, 0xfffe) : min(requestedMessageSize, 0xfe)

            if packetSize > 0xfe {
				updateProgress.dataPacketMaxBytes = UInt(packetSize - Self.IAP2DataHeaderExtendedSize)
            } else {
            	updateProgress.dataPacketMaxBytes = UInt(packetSize - Self.IAP2DataHeaderSize)
            }

            LOG(.medium, "******** request total packet length: \(requestedMessageSize) databytes: \(updateProgress.dataPacketMaxBytes)")
        }

        updateProgress.updateInProgress = true

        updateProgress.startTime = Date.timeIntervalSinceReferenceDate
        LOG(.medium, "GaiaCommand_RegisterNotification > vmUpgradeConnect")
        updater?.vmUpgradeConnect()
    }

    func pause() {
        guard updateProgress.updateInProgress && !isPaused else {
            return
        }

        LOG(.high, "PAUSING")

        if useRWCP {
            rwcpHandler?.abort()
        }
        updateProgress.dataBuffer.removeAll()
        setUserStateAndNotify(.busy(progress: .paused))
        updater?.vmUpgradeDisconnect()
    }

    func unpause() {
        guard updateProgress.updateInProgress && isPaused else {
            return
        }

        LOG(.high, "RESUMING")

        updateProgress.updateInProgress = true
        setUserStateAndNotify(.busy(progress: .unpausing))

        updateProgress.startTime = Date.timeIntervalSinceReferenceDate
        updateProgress.progress = 0
        updateProgress.skipped = 0
        updateProgress.startOffset = 0
        updateProgress.bytesToSend = 0

        LOG(.medium, "GaiaCommand_RegisterNotification > vmUpgradeConnect")
        updater?.vmUpgradeConnect()
    }

    func abort() {
        updateProgress.didAbort = true
        setUserStateAndNotify(.stopped(reason: .userAbortPending))
        
        if useRWCP {
            rwcpHandler?.abort()
        }
        
        abortUpdateInProgress()
    }

    func commitConfirm(value: Bool) {
        updater?.vmUpgradeCommitConfirmRequest(reply: value)
        if !value {
            abort()
        }
    }

    func confirmForceUpgradeResponse(value: Bool) {
        if value {
            updateProgress.syncAfterAbort = true
            abort()
        } else {
            // Here we do not actually send the abort message. We send just disconnect.
            updateProgress.didAbort = true
            if useRWCP {
                rwcpHandler?.abort()
            }
            updateProgress.dataBuffer.removeAll()
            updater?.vmUpgradeDisconnect()
            setUserStateAndNotify(.stopped(reason: .aborted(error: .updateCancelledByUser)))
        }
    }

    func commitTransferRequired(value: UpdateCommitOptions) {
        updater?.vmUpgradeTransferConfirmRequest(reply: value)
        switch value {
        case .cancel:
            abort()
        case .interactive,
             .silent:
            willDisconnectDevice(aborted: false)
        }
    }

    func batteryWarningConfirmed() {
        updateProgress.startTime = Date.timeIntervalSinceReferenceDate
        updateProgress.progress = 0
        updateProgress.skipped = 0
        updateProgress.startOffset = 0
        updateProgress.bytesToSend = 0

        updater?.vmUpgradeSyncRequest(md5: updateProgress.fileMD5!)
    }
}

// MARK: - Private Methods
private extension GaiaDeviceUpdaterPlugin {
    func abortUpdateInProgress() {
        if updateProgress.updateInProgress {
            updateProgress.didAbort = true
            LOG(.high, "GaiaUpdate_AbortRequest > vmUpgradeControl")
            updateProgress.dataBuffer.removeAll()
            updater?.vmUpgradeAbort()
        }
    }

    func handleDataSent(error: Error?) {
        guard !useRWCP && !updateProgress.didAbort && !isPaused else {
            return
        }

        guard updateProgress.dataBuffer.count > 0 else {
            if updateProgress.needToValidate &&
                (updateProgress.bytesToSend + updateProgress.startOffset) >= updateProgress.transferSize {
                updateProgress.needToValidate = false
                setUserStateAndNotify(.busy(progress: .validating))
                logDFUCompletion()
                updater?.vmUpgradeIsValidationDoneRequest(md5: updateProgress.fileMD5!)
            }
            return
        }

        if let _ = error {
            pause()
        } else {
            let dataToSend = updateProgress.dataBuffer.removeFirst()
            updateProgress.progress = updateProgress.progress + UInt32(dataToSend.count - 8)
            LOG(.low, "Sending packet. \(updateProgress.dataBuffer.count) remaining.")
            updater?.vmUpgradeSendPreformedDataPacketViaGaia(dataToSend)
        }
    }

    func willDisconnectDevice(aborted: Bool) {
        if updateProgress.updateInProgress {
            setUserStateAndNotify(.busy(progress: .restarting))
            updateProgress.progress = 0
            updateProgress.skipped = 0
            updateProgress.startOffset = 0
            updateProgress.bytesToSend = 0

            if useRWCP {
                rwcpHandler?.powerOff()
            }
        } else {
            updateProgress = UpdateProgressInfo()
            if aborted {
                setUserStateAndNotify(.stopped(reason: .aborted(error: .updateCancelledByUser)))
            } else {
                if silentCommitConfirmed {
                    setUserStateAndNotify(.stopped(reason: .completedAwaitingReboot))
                } else {
                    let status = UpdateCompletionStatus(status: updateProgress.completionStatus)
                	setUserStateAndNotify(.stopped(reason: .completed(status: status)))
                }
            }
        }
    }

    func setUserStateAndNotify(_ newState: UpdateState) {
        updateProgress.userState = newState
        if let device = device {
            let notification = GaiaDeviceUpdaterPluginNotification(sender: self,
                                                                   payload: device,
                                                                   reason: .statusChanged)
            notificationCenter.post(notification)
        }
    }

    func handleResponseReceived(messageDescription: IncomingMessageDescription) {
        guard
            let updater = updater,
			let device = device
            else {
                return
        }

        switch messageDescription {
        case .response(let command, _):
            if updater.isRegisterNotificationCommand(command) {
                LOG(.high, "Updater is registered for notifications - v2 only")
                registeredForNotifications = true
                let notification = GaiaDeviceUpdaterPluginNotification(sender: self,
                                                                       payload: device,
                                                                       reason: .ready)
                notificationCenter.post(notification)
            } else if updater.isSetDataEndpointModeCommand(command) {
                LOG(.medium, "RWCP Available")
                rwcpAvailable = true
                if device.version == .v3 {
                    let notification = GaiaDeviceUpdaterPluginNotification(sender: self,
                                                                           payload: device,
                                                                           reason: .ready)
                    notificationCenter.post(notification)
                }
            }  else if isUpdating {
                if updater.isUpgradeDisconnectCommand(command) {
                    LOG(.high, "VMUpgradeDisconnect acknowledged.")
                    if updateProgress.didAbort {
                        // Persist abort error across clean up
                        var abortError: GaiaUpdateError = .updateCancelledByUser
                        switch updateProgress.userState {
                        case .stopped(let reason):
                            switch reason {
                            case .aborted(let error):
                                abortError = error
                            default:
                                break
                            }
                        default:
                            break
                        }
                        updateProgress = UpdateProgressInfo()
                        setUserStateAndNotify(.stopped(reason: .aborted(error: abortError)))
                    } else if isPaused || isUnpausing {
                        // Just sit. We ignore disconnect during unpause to avoid a potential race: VMCSA-10217
                    } else {
                        updateProgress = UpdateProgressInfo()
                        if silentCommitConfirmed {
                            setUserStateAndNotify(.stopped(reason: .completedAwaitingReboot))
                        } else {
                            let status = UpdateCompletionStatus(status: updateProgress.completionStatus)
                            setUserStateAndNotify(.stopped(reason: .completed(status: status)))
                        }
                    }
                } else if updater.isUpgradeConnectCommand(command) {
                    if isUnpausing {
                    	setUserStateAndNotify(.busy(progress: .transferring))
                    }
                    updater.vmUpgradeSyncRequest(md5: updateProgress.fileMD5!)
                }
            }
        case .error(let command, _, _):
            if updater.isSetDataEndpointModeCommand(command) {
                LOG(.medium, "RWCP is not Available")
                rwcpAvailable = false
                if device.version == .v3 {
                    let notification = GaiaDeviceUpdaterPluginNotification(sender: self,
                                                                           payload: device,
                                                                           reason: .ready)
                    notificationCenter.post(notification)
                }
            } else if isUpdating {
                if updater.isUpgradeConnectCommand(command) {
                    updateProgress = UpdateProgressInfo()
                    updateProgress.dataBuffer.removeAll()
                    setUserStateAndNotify(.stopped(reason: .aborted(error: .connectFailed)))
                } else if updater.isUpgradeControlCommand(command) && isUpdating {
                    LOG(.high, "Error Received - Connect or Control")
                    abortUpdateInProgress()
                    setUserStateAndNotify(.stopped(reason: .aborted(error: .unexpectedCommand)))
                }
            }
        case .notification(let notificationID, let data):
            guard isUpdating else {
                return
            }

            if let v3Notification = GaiaV3Updater.Events(rawValue: notificationID),
                device.version == .v3 {
                // Handle pause/resume behaviour
                switch v3Notification {
                case .vmUpgradeStopRequest:
                    pause()
                    return
                case .vmUpgradeStartRequest:
                    unpause()
                    return
                default:
                    // Others fall through
                    break
                }
            }

            guard
                !isPaused,
                updater.isVMUpgradeProtocolPacket(notificationID),
            	data.count >= 3 else {
                return
            }
            if let updateEventCode = data.first,
                let controlOperation = UpdateControlOperations(rawValue: updateEventCode),
                let _ = UInt16(data: data, offset: 1, bigEndian: true) {
                let upgradePayload = data.count > 3 ? data.advanced(by: 3) : Data()
                // UpgradePayload now points to the bytes after the length.
                LOG(.medium, "Notification Received: \(controlOperation)")
                switch controlOperation {
                case .UPGRADE_SYNC_REQ,
                     .UPGRADE_START_REQ,
                     .UPGRADE_ABORT_REQ,
                     .UPGRADE_START_DATA_REQ,
                     .UPGRADE_DATA,
                     .UPGRADE_IS_VALIDATION_DONE_REQ,
                     .UPGRADE_COMMIT_CFM,
                     .UPGRADE_TRANSFER_COMPLETE_RES,
                     .UPGRADE_PROCEED_TO_COMMIT,
                     .UPGRADE_ERROR_RES,
                     .UPGRADE_SILENT_COMMIT_SUPPORTED_REQ:
                    // These are all outgoing messages
                    break
                case .UPGRADE_START_CFM:
                    if upgradePayload.first ?? 1 != 0 {
                        // abort
                        updateProgress = UpdateProgressInfo()
                        setUserStateAndNotify(.stopped(reason: .aborted(error: .startFailed)))
                        return
                    }
                    switch updateProgress.resumePoint {
                    case .start:
                        LOG(.medium, "UPGRADE_START_CFM - Resume Point Start")
                        updateProgress.startTime = Date.timeIntervalSinceReferenceDate
                        updater.vmUpgradeStartDataRequest()
                    case .validate:
                        LOG(.medium, "UPGRADE_START_CFM - Resume Point Validate")
                        setUserStateAndNotify(.busy(progress: .validating))
                        updater.vmUpgradeIsValidationDoneRequest(md5: upgradePayload.md5())
                    case .reboot:
                        LOG(.medium, "UPGRADE_START_CFM - Resume Point Reboot")
                        if protocolVersion >= protocolVersionForSilentCommit {
                            updater.vmUpgradeRequestIsSilentCommitAvailable()
                        } else {
                            silentCommitConfirmed = false
                            silentCommitSupported = false
                        	setUserStateAndNotify(.busy(progress: .awaitingConfirmTransferRequired))
                        }
                    case .postReboot:
                        LOG(.medium, "UPGRADE_START_CFM - Resume Point Post Reboot")
                        updater.vmUpgradeUpdateComplete()
                    case .commit:
                        LOG(.medium, "UPGRADE_START_CFM - Resume Point Commit")
                        updater.vmUpgradeCommitConfirmRequest(reply: true)
                    }
                case .UPGRADE_DATA_BYTES_REQ:
                    if updateProgress.progress == 0 {
                        LOG(.low, "First request")
						updateProgress.startTime = Date.timeIntervalSinceReferenceDate
                    }
                    dataRequest(upgradePayload: upgradePayload)
                case .UPGRADE_ABORT_CFM:
                    if updateProgress.syncAfterAbort {
                        updateProgress.syncAfterAbort = false
                        updateProgress.didAbort = false
                        updateProgress.progress = 0
                        updateProgress.skipped = 0
                        updateProgress.transferSize = UInt32(fileData?.count ?? 0)
                        updateProgress.startOffset = 0
                        updateProgress.bytesToSend = 0
                        updateProgress.updateInProgress = true
                        updateProgress.resumePoint = .start
                        updater.vmUpgradeSyncRequest(md5: updateProgress.fileMD5!)
                    } else {
                        LOG(.high, "Abort successful")
                        updateProgress.didAbort = true
                    	updater.vmUpgradeDisconnect()
                    }
                case .UPGRADE_TRANSFER_COMPLETE_IND:
                    guard !updateProgress.transferCompleteAcknowledged else {
                        LOG(.medium, "***** UPGRADE_TRANSFER_COMPLETE_IND received more than once. Ignoring *****")
                        return
                    }
                    updateProgress.transferCompleteAcknowledged = true
                    if protocolVersion >= protocolVersionForSilentCommit {
                        updater.vmUpgradeRequestIsSilentCommitAvailable()
                    } else {
                        silentCommitSupported = false
                    	setUserStateAndNotify(.busy(progress: .awaitingConfirmTransferRequired))
                    }
                case .UPGRADE_COMMIT_REQ:
                    setUserStateAndNotify(.busy(progress: .awaitingConfirmation))
                case .UPGRADE_ERROR_IND:
                    if upgradePayload.count > 1 {
                        let updateErrorByte = upgradePayload[1]
                        updater.vmUpgradeConfirmError(errorCode: UInt16(updateErrorByte))

                        var userError: GaiaUpdateError = .unknownDeviceError(error: updateErrorByte)
                        var shouldAbort = true

                        if let updateError = UpdateErrorCodes(rawValue: updateErrorByte) {
                            if updateError == .success {
                                shouldAbort = false
                            } else {
                                userError = .deviceError(error: updateError)
                                if updateError == .warnSyncIdIsDifferent {
                                    shouldAbort = false
                                    setUserStateAndNotify(.busy(progress: .awaitingConfirmForceUpgrade))
                                } else if updateError == .errorBatteryLow {
                                    shouldAbort = false
                                    setUserStateAndNotify(.busy(progress: .awaitingConfirmBatteryLow))
                                } else if updateError == .errorHandoverDFUAbort {
                                    // Handover will happen. Just ack, stop.
                                    shouldAbort = false
                                    pause()
                                } else if updateError == .errorTimeout {
                                    shouldAbort = false
                                    setUserStateAndNotify(.busy(progress: .awaitingEarbudsInCaseTimedOut))
                                }
                            }
                        }
                        if shouldAbort {
                            // Abort
                            if useRWCP {
                                rwcpHandler?.abort()
                            }
                            abortUpdateInProgress()
                            setUserStateAndNotify(.stopped(reason: .aborted(error: userError)))
                        }
                    }
                case .UPGRADE_COMPLETE_IND:
                    updater.vmUpgradeDisconnect()
                case .UPGRADE_COMPLETE_IND_WITH_STATUS:
                    let byte = upgradePayload.first ?? 0
                    if let status = UpdateCompleteIndStatusCode(rawValue: byte) {
                        updateProgress.completionStatus = status
                    }
                    updater.vmUpgradeDisconnect()
                case .UPGRADE_SYNC_CFM:
                    let state = upgradePayload.first ?? 0
                    if upgradePayload.count >= 6 {
                        protocolVersion = upgradePayload[5]
                    } else {
                        protocolVersion = 3
                    }
                    LOG(.high, "UPDATE: startResumePointPermitted: \(updateProgress.startResumePointPermitted)")
                    updateProgress.resumePoint = UpdateProgressInfo.GaiaUpdateResumePoint(rawValue: state) ?? .start
                    if updateProgress.resumePoint == .start && !updateProgress.startResumePointPermitted {
                        // We shouldn't get a start resume point now. Maybe the earbud has crashed post reboot?
                        abortUpdateInProgress()
                        setUserStateAndNotify(.stopped(reason: .aborted(error: .unexpectedStart)))
                    } else {
                        updater.vmUpgradeStartRequest()
                    }
                case .UPGRADE_IS_VALIDATION_DONE_CFM:
                    // We get a reply to wait a bit
                    let delay = UInt16(data: upgradePayload, offset: 0, bigEndian: true) ?? 1000
                    let gatedDelay = max(1000.0, Double(delay)) // Leave at least a second.
                    DispatchQueue.main.asyncAfter(deadline: .now() + gatedDelay/1000.0) { [weak self] in
                        guard
                            let self = self,
                            self.updateProgress.updateInProgress,
                            !self.isPaused,
                            !self.updateProgress.didAbort
                        else {
                            return
                        }
                        self.setUserStateAndNotify(.busy(progress: .validating))
                        self.updater?.vmUpgradeIsValidationDoneRequest(md5: self.updateProgress.fileMD5!)
                    }
                case .UPGRADE_SILENT_COMMIT_SUPPORTED_CFM:
                    silentCommitConfirmed = false
                    silentCommitSupported = (upgradePayload.first ?? 0) == 1
                    setUserStateAndNotify(.busy(progress: .awaitingConfirmTransferRequired))
                case .UPGRADE_SILENT_COMMIT_COMPLETE_CFM:
                    silentCommitConfirmed = true
                    updater.vmUpgradeDisconnect()
                case .UPGRADE_PUT_EARBUDS_IN_CASE_REQ:
                    setUserStateAndNotify(.busy(progress: .awaitingEarbudsInCase))
                case .UPGRADE_PUT_EARBUDS_IN_CASE_CFM:
                    setUserStateAndNotify(.busy(progress: .awaitingEarbudsInCaseConfirmed))
                }
            }
        default:
            break
        }
    }

    func dataRequest(upgradePayload: Data) {
        guard
            let numberOfBytesReq = UInt32(data:upgradePayload, offset: 0, bigEndian: true),
            let fileOffsetReq = UInt32(data:upgradePayload, offset: 4, bigEndian: true),
            numberOfBytesReq + fileOffsetReq <= UInt32(fileData?.count ?? 0),
            let updater = updater
        else {
            abortUpdateInProgress()
            setUserStateAndNotify(.stopped(reason: .aborted(error: .invalidDataRequest)))
            return
        }

        setUserStateAndNotify(.busy(progress: .transferring))
        LOG(.medium, "Requested: \(numberOfBytesReq) from offset \(fileOffsetReq)")

        let fileLength = UInt32(fileData?.count ?? 0)
        updateProgress.bytesToSend = numberOfBytesReq // Start with what we were asked for
        if fileOffsetReq > 0 {
            updateProgress.skipped = updateProgress.skipped + fileOffsetReq
            updateProgress.progress = updateProgress.progress + fileOffsetReq
            if fileOffsetReq + updateProgress.startOffset < fileLength {
                updateProgress.startOffset += fileOffsetReq
            }
        }

        let remainingLength = fileLength - updateProgress.startOffset
        updateProgress.bytesToSend = min(updateProgress.bytesToSend, remainingLength)
        let maxLength = UInt32(updateProgress.dataPacketMaxBytes)
        var newPackets = [Data]()

        LOG(.medium, "Starting bytes at \(updateProgress.startOffset)")

        while updateProgress.bytesToSend > 0 && !updateProgress.didAbort {

            let bytesInPacket = min(updateProgress.bytesToSend, maxLength)

            let lastPacket = fileLength - updateProgress.startOffset <= bytesInPacket
            let fileDataToSend = fileData!.subdata(in: Int(updateProgress.startOffset)..<Int(updateProgress.startOffset + bytesInPacket))

            let bytes = updater.vmUpgradeDataPacket(bytes: fileDataToSend, moreComing: !lastPacket)

            if useRWCP {
                rwcpHandler?.setPayload(data: bytes, lastPacket: lastPacket)
            } else {
				newPackets.append(bytes)
            }

            if lastPacket {
                updateProgress.needToValidate = true
            }

            updateProgress.bytesToSend -= bytesInPacket
            updateProgress.startOffset += bytesInPacket
        }

        if useRWCP {
            rwcpHandler?.startTransfer()
        } else {
            updateProgress.dataBuffer += newPackets
            handleDataSent(error: nil) // Sends the first item or requests validation
        }
        LOG(.medium, "Done adding bytes")
    }

    func logDFUCompletion() {
        let transferredNotSkipped = Int(updateProgress.progress - updateProgress.skipped)
        let duration = Int(Date().timeIntervalSinceReferenceDate - startTime)

        guard transferredNotSkipped > 0 && duration > 0 else {
            return
        }

        let rate = ((transferredNotSkipped * 8) / duration) / 1000
        var dfuType = ""
        switch ongoingDFUState {
        case .active(_ , let settings, _):
            switch settings {
            case .ble(_, _):
                dfuType = "BLE"
            case .bleRWCP(_, _, _, _):
                dfuType = "RWCP"
            case .iap2(_, _, _):
                dfuType = "iAP2"
            }
        default:
            break
        }
        LOG(.high, "\(dfuType) handset->primary finished - transferred \(transferredNotSkipped) bytes in \(Int(duration))s - \(rate)kbps")
    }
}

// MARK: - GaiaRWCPHandlerDelegate
extension GaiaDeviceUpdaterPlugin: GaiaRWCPHandlerDelegate {
    func didCompleteDataSend() {
        LOG(.medium, "did complete data send")
        if updateProgress.updateInProgress && !updateProgress.didAbort && updateProgress.needToValidate {
            updateProgress.needToValidate = false
            setUserStateAndNotify(.busy(progress: .validating))
            logDFUCompletion()
            updater?.vmUpgradeIsValidationDoneRequest(md5: updateProgress.fileMD5!)
        }
    }

    func didSend(bytes: Double) {
        updateProgress.progress += UInt32(bytes) - UInt32(Self.GATTHeaderSize)
    }
}
