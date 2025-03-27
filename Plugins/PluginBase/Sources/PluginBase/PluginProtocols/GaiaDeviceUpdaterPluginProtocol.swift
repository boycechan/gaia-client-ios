//
//  © 2020 - 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation

public enum UpdateStateProgress {
    case awaitingConfirmation
    case awaitingConfirmForceUpgrade
    case awaitingConfirmTransferRequired
    case awaitingConfirmBatteryLow
    case awaitingEarbudsInCase
    case awaitingEarbudsInCaseConfirmed
    case awaitingEarbudsInCaseTimedOut
    case transferring
    case validating
    case restarting
    case paused
    case unpausing
    case connecting
}

public enum UpdateStateDone {
    case completed(status: UpdateCompletionStatus)
    case completedAwaitingReboot
    case userAbortPending
    case aborted(error: GaiaUpdateError)
}

public enum UpdateCompletionStatus {
	case success
    case updateSuccessButSecurityUpdateFailed
}

public enum UpdateState {
    case ready
    case busy(progress: UpdateStateProgress)
    case stopped(reason: UpdateStateDone)
}

public enum DFUState {
    case none
    case active(connectionID: String,
                settings: UpdateTransportOptions,
                data: Data)
}

public enum UpdateTransportOptions {
    public struct Constants {
        public static let rwcpInitialWindowSize: Int = 16
        public static let rwcpMaxWindow: Int = 31 // 32 fails on older handsets with BT4.2
        public static let maxSizeWithoutDLE: Int = 23
    }

    //case none
    case ble(useDLE: Bool, requestedMessageSize: Int)
    case bleRWCP(useDLE: Bool, requestedMessageSize: Int, initialWindowSize: Int, maxWindowSize: Int)
    case iap2(useDLE: Bool, requestedMessageSize: Int, expectACKs: Bool)
}

public enum UpdateTransportCapabilities {
    case none
    case ble(lengthExtensionAvailable: Bool, rwcpAvailable: Bool, maxMessageSize: Int, optimumMessageSize: Int)
    case iap2(lengthExtensionAvailable: Bool, maxMessageSize: Int, optimumMessageSize: Int)
}

public enum UpdateCommitOptions: UInt8 {
    case interactive = 0
    case cancel = 1
    case silent = 2
}

public protocol GaiaDeviceUpdaterPluginProtocol: GaiaDevicePluginProtocol {
    var updateState: UpdateState { get }
    var silentCommitSupported: Bool { get }
    var isUpdating: Bool { get }
    var restartUpdateAfterConnection: Bool { get }
    var percentProgress: Double { get }
    var timeRemaining: TimeInterval { get }
    var ongoingDFUState: DFUState { get }
    var transportCapabilities: UpdateTransportCapabilities { get }

	func dataReceived(_ data: Data)
    func startUpdate(fileData: Data,
                     requestedSettings: UpdateTransportOptions,
                     previousTransferCompleted: Bool)
    func abort()
    func commitConfirm(value: Bool)
    func confirmForceUpgradeResponse(value: Bool)
    func commitTransferRequired(value: UpdateCommitOptions)
    func batteryWarningConfirmed()
    
    func pause()
    func unpause()
}

public extension GaiaDeviceUpdaterPluginProtocol {
    func startUpdate(fileData: Data,
                     requestedSettings: UpdateTransportOptions) {
		startUpdate(fileData: fileData,
                    requestedSettings: requestedSettings,
                    previousTransferCompleted: false)
    }
}

public enum UpdateErrorCodes: UInt8 {
    case success                          = 0x00
    case errorUnknownId                   = 0x11
    case errorBadLength                   = 0x12
    case errorWrongVariant                = 0x13
    case errorWrongPartitionNumber        = 0x14
    case errorPartitionSizeMismatch       = 0x15
    case errorPartitionTypeNotFound       = 0x16
    case errorPartitionOpenFailed         = 0x17
    case errorPartitionWriteFailed        = 0x18
    case errorPartitionCloseFailed        = 0x19
    case errorSFSValidationFailed         = 0x1A
    case errorOEMValidationFailed         = 0x1B
    case errorUpdateFailed                = 0x1C
    case errorAppNotReady                 = 0x1D
    case errorLoaderError                 = 0x1E
    case errorUnexpectedLoaderMessage     = 0x1F
    case errorMissingLoaderMessage        = 0x20
    case errorBatteryLow                  = 0x21
    case errorInvalidSyncId               = 0x22
    case errorInErrorState                = 0x23
    case errorNoMemory                    = 0x24
    case errorHandoverDFUAbort              = 0x28
    case errorBadLengthPartitionParse     = 0x30
    case errorBadLengthTooShort           = 0x31
    case errorBadLengthUpgradeHeader      = 0x32
    case errorBadLengthPartitionHeader    = 0x33
    case errorBadLengthSignature          = 0x34
    case errorBadLengthDataHeaderResume   = 0x35
    case errorOEMValidationFailedHeader   = 0x38
    case errorOEMValidationFailedUpgradeHeader = 0x39
    case errorOEMValidationFailedPartitionHeader = 0x3A
    case errorOEMValidationFailedPartitionHeader2 = 0x3B
    case errorOEMValidationFailedPartitionData = 0x3C
    case errorOEMValidationFailedFooter   = 0x3D
    case errorOEMValidationFailedMemory   = 0x3E
    case errorPartitionCloseFailed2       = 0x40
    case errorPartitionCloseFailedHeader  = 0x41
    case errorPartitionCloseFailedPSSpace = 0x42
    case errorPartitionTypeNotMatching    = 0x48
    case errorPartitionTypeTwoDFU         = 0x49
    case errorPartitionWriteFailedHeader  = 0x50
    case errorPartitionWriteFailedData    = 0x51
    case errorFileTooSmall                = 0x58
    case errorFileTooBig                  = 0x59
    case errorInternalError1              = 0x65
    case errorInternalError2              = 0x66
    case errorInternalError3              = 0x67
    case errorInternalError4              = 0x68
    case errorInternalError5              = 0x69
    case errorInternalError6              = 0x6A
    case errorInternalError7              = 0x6B
    case errorSilentCommitNotSupported      = 0x70
    case errorTimeout                        = 0x71 // Used currently for in case notification
    case warnAppConfigVersionIncompatible = 0x80
    case warnSyncIdIsDifferent            = 0x81
    case warnSyncIdIsZero                  = 0x82
    case errorRequestedVersionMismatch    = 0x83
}
