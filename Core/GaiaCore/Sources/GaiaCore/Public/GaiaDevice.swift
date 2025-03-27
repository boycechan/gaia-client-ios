//
//  © 2020 - 2024 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation
import GaiaBase
import PluginBase
import Packets
import GaiaLogger
import GaiaPluginManager

// MARK: -

public class GaiaDevice: NSObject, GaiaDeviceProtocol, GaiaNotificationSender {
	enum V2Commands: UInt16 {
        case getAPIVersion                   = 0x0300
    }

    enum SupportedFeaturesCommands: UInt16 {
        case first = 1
        case next = 2
    }

    enum DeviceNotificationRegistration: UInt16 {
        case register = 7
        case unregister = 8
    }

    // MARK: Private ivars
    private let notificationCenter : NotificationCenter
    private let advertisements: [String : Any]
    internal private(set) var connection: GaiaDeviceConnectionProtocol
    private var vendorExtensions = [GaiaDeviceVendorExtensionProtocol] ()
    private var pluginsInUse = [GaiaDevicePluginProtocol] ()
    private var supportedFeaturesData = Data()
    private var observerTokens = [ObserverToken]()
    private var awaitingRegistrationConfirmation: Int = 0

    private var connected: Bool {
        connection.connected
    }

    // MARK: Public ivars
    public private(set) var version: GaiaDeviceVersion
    public private(set) var apiVersion: String = ""

    public var serialNumber: String {
        if let corePlugin = plugin(featureID: .core) as? GaiaDeviceCorePluginProtocol {
            return corePlugin.serialNumber
        } else {
            return ""
        }
    }
    public var secondEarbudSerialNumber: String? {
        if let earbudPlugin = plugin(featureID: .earbud) as? GaiaDeviceEarbudPluginProtocol {
            return earbudPlugin.secondEarbudSerialNumber
        } else {
            return nil
        }
    }
    public var applicationVersion: String {
        if let corePlugin = plugin(featureID: .core) as? GaiaDeviceCorePluginProtocol {
            return corePlugin.applicationVersion
        } else {
            return ""
        }
    }
    public var deviceVariant: String {
        if let corePlugin = plugin(featureID: .core) as? GaiaDeviceCorePluginProtocol {
            return corePlugin.deviceVariant
        } else {
            return ""
        }
    }
    public var isCharging: Bool {
        if let corePlugin = plugin(featureID: .core) as? GaiaDeviceCorePluginProtocol {
            return corePlugin.isCharging
        } else {
            return false
        }
    }
    public private(set) var state: GaiaDeviceState = .disconnected {
        didSet {
            if oldValue != state {
                notificationCenter.post(GaiaDeviceNotification(sender: self,
                                                               payload: self,
                                                               reason: .stateChanged))
            }
        }
    }
    public var connectionKind: ConnectionKind {
        connection.connectionKind
    }
    public var bluetoothAddress: String? {
        if let corePlugin = plugin(featureID: .core) as? GaiaDeviceCorePluginProtocol {
            return corePlugin.bluetoothAddress
        } else {
            return nil
        }
    }
    public var connectionID: String {
        connection.connectionID
    }
    public var name: String {
        connection.name
    }
    public private(set) var equivalentConnectionIDsForReconnection = [String]()

    public var deviceType: GaiaDeviceType {
        if plugin(featureID: .earbud) != nil {
            return .earbud
        }

        if connection.state != .ready {
            return .unknown
        }

        if connectionKind == .ble {
            if let _ = advertisements[Gaia.chargingCaseAdvertisementKey]  {
                return .chargingCase
            }
        }

        return .headset
    }
    public var rssi: Int {
        connection.rssi
    }
    public var supportedFeatures: [GaiaDeviceQCPluginFeatureID] {
        return pluginsInUse.map { $0.featureID }
    }

    // MARK: init/deinit
    required init(connection: GaiaDeviceConnectionProtocol,
                  notificationCenter: NotificationCenter,
                  advertisements: [String : Any]) {
        self.connection = connection
        self.notificationCenter = notificationCenter
        self.advertisements = advertisements
        self.version = .unknown
        super.init()

        equivalentConnectionIDsForReconnection = [connectionID]
        self.connection.delegate = self
		stateChanged(connection: connection)

        observerTokens.append(notificationCenter.addObserver(forType: GaiaDeviceCorePluginNotification.self,
                                                             object: nil,
                                                             queue: OperationQueue.main,
                                                             using: { [weak self] notification in self?.corePluginHandler(notification) }))

        observerTokens.append(notificationCenter.addObserver(forType: GaiaDeviceEarbudPluginNotification.self,
                                                             object: nil,
                                                             queue: OperationQueue.main,
                                                             using: { [weak self] notification in self?.earbudPluginHandler(notification) }))

        observerTokens.append(notificationCenter.addObserver(forType: GaiaDeviceUpdaterPluginNotification.self,
                                                             object: nil,
                                                             queue: OperationQueue.main,
                                                             using: { [weak self] notification in self?.updaterPluginHandler(notification) }))
    }

    deinit {
        observerTokens.forEach { token in
            notificationCenter.removeObserver(token)
        }
        observerTokens.removeAll()
    }

    // MARK: Public Methods
    public func plugin(featureID: GaiaDeviceQCPluginFeatureID) -> GaiaDevicePluginProtocol? {
        return pluginsInUse.first {
            $0.featureID == featureID
        }
    }

    public func vendorExtension(vendorID: UInt16) -> GaiaDeviceVendorExtensionProtocol? {
        return vendorExtensions.first {
            $0.vendorID == vendorID
        }
    }

    public func startConnection() {
        if connection.state == .uninitialised {
            connection.start()
        }
    }

    public func connectGaia() {
        if state == .transportReady {
            state = .settingUpGaia
            fetchDeviceVersion()
        }
    }

    public func reset() {
        version = .unknown
        pluginsInUse.forEach { plugin in
            let message = GaiaV3GATTPacket(featureID: .core,
                                           commandID: DeviceNotificationRegistration.unregister.rawValue,
                                           payload: Data([plugin.featureID.rawValue]))
            connection.sendData(channel: .command, payload: message.data, acknowledgementExpected: true)
            plugin.stopPlugin()
        }
        pluginsInUse.removeAll()

        vendorExtensions.forEach {
            $0.stop()
        }
        vendorExtensions.removeAll()
    }

    internal func handoverDidOccur() {
        pluginsInUse.forEach {
            $0.handoverDidOccur()
        }
    }
}

// MARK: GaiaDeviceConnectionDelegate
extension GaiaDevice: GaiaDeviceConnectionDelegate {
    public func dataReceived(_ data: Data, channel: GaiaDeviceConnectionChannel) {
        if channel == .response {
            switch version {
            case .unknown:
                if let message = GaiaV2GATTPacket(data: data) {
                    notifyConnectionOfResponseIfNecessary(message: message)
                    handleV2VersionReply(message, channel: channel)
                }
            case .v2:
                if let message = GaiaV2GATTPacket(data: data) {
                    LOG(.medium, "v2: Message: \(message)")
                    notifyConnectionOfResponseIfNecessary(message: message)
                    if !handleV2CoreReplies(message, channel: channel) {
                        pluginsInUse.forEach {
                            $0.responseReceived(messageDescription: message.messageDescription)
                        }
                    }
                }
            case .v3:
                // Check vendorID to see if QC
                if let vendorID = UInt16(data: data, offset: 0, bigEndian: true) {
                    if vendorID == QCVendorID.v3 {
                        if let message = GaiaV3GATTPacket(data: data),
                           let featureID = getV3FeatureID(packetFeatureID: message.featureID) {
                            if !handleV3CoreReplies(message, channel: channel) {
                                pluginsInUse.forEach {
                                    if featureID == $0.featureID {
                                        $0.responseReceived(messageDescription: message.messageDescription)
                                    }
                                }
                            }
                        }
                    } else {
                        // Third Party Vendor ID?
                        if let vendorExtension = vendorExtension(vendorID: vendorID) {
                            // As vendor could use any data format we unlock the send queue
                            if vendorExtension.dataReceived(data) {
                                connection.acknowledgementReceived()
                            }
                        }
                    }
                }
            }
        } else if channel == .data {
            // RWCP use data channel
            switch version {
            case .v2, .v3:
                pluginsInUse.forEach {
                    if let updaterPlugin = $0 as? GaiaDeviceUpdaterPluginProtocol {
                        updaterPlugin.dataReceived(data) // Sent as is
                    }
                }
            default:
                break
            }
        }
    }

    public func didSendData(channel: GaiaDeviceConnectionChannel, error: GaiaError?) {
        if version == .v2 || version == .v3 {
            pluginsInUse.forEach {
                $0.didSendData(channel: channel, error: error)
            }
            if let error = error {
                vendorExtensions.forEach {
                    $0.didError(error)
                }
            }
        }
        if let error = error {
            LOG(.high, "Error writing - moving to failed state Reason: \(error)")
            state = .failed(reason: error)
        }
    }

    public func rssiDidChange() {
        notificationCenter.post(GaiaDeviceNotification(sender: self,
                                                       payload: self,
                                                       reason: .rssi))
    }

    public func stateChanged(connection: GaiaDeviceConnectionProtocol) {
        switch connection.state {
        case .disconnected:
            state = .disconnected
        case .uninitialised:
            state = .awaitingTransportSetUp
        case .initialising:
            state = .settingUpTransport
        case .initialisationFailed:
            state = .failed(reason: .transportSetupFailed)
        case .ready:
            state = .transportReady
        }
    }
}

// MARK: - Private Methods
private extension GaiaDevice {
    func notifyConnectionOfResponseIfNecessary(message: IncomingMessageProtocol) {
        switch message.messageDescription {
        case .response(_, _):
            connection.acknowledgementReceived()
        case .error(_, _, _):
            connection.acknowledgementReceived()
        case .notification(_, _):
            break
        default:
            break
        }

        let shouldRestoreState = state == .failed(reason: .writeToDeviceTimedOut)

        if shouldRestoreState {
            LOG(.high, "Response/Error received in failed state due to timeout. Moving to GaiaReady to resume")
            state = .gaiaReady
        }
    }

    func corePluginHandler(_ notification: GaiaDeviceCorePluginNotification) {
        guard
            let myPlugin = plugin(featureID: .core) as? GaiaDeviceCorePluginProtocol,
            let senderPlugin = notification.sender as? GaiaDeviceCorePluginProtocol,
            senderPlugin === myPlugin // note pointer comparison
        else {
            return
        }
        
        switch notification.reason {
        case .handshakeComplete:
			updateIdentification()
            if deviceType != .earbud {
                notifyIndentificationComplete()
            }
            startNonCorePlugins()
            if plugin(featureID: .upgrade) == nil {
            	state = .gaiaReady
            }
        default:
            break
        }
    }

    func earbudPluginHandler(_ notification: GaiaDeviceEarbudPluginNotification) {
        guard
            let myPlugin = plugin(featureID: .earbud) as? GaiaDeviceEarbudPluginProtocol,
            let senderPlugin = notification.sender as? GaiaDeviceEarbudPluginProtocol,
            senderPlugin === myPlugin // note pointer comparison
        else {
            return
        }

        switch notification.reason {
        case .secondSerial:
            LOG(.medium, "Second Serial Done")
            updateIdentification()
            notifyIndentificationComplete()
        default:
            break
        }
    }

    private func updateIdentification() {
        var btAddresses = [String]()
        if let bluetoothAddress = bluetoothAddress {
            btAddresses.append(bluetoothAddress)
        }
        var serials = [serialNumber]
        if let secondEarbudSerialNumber = secondEarbudSerialNumber {
            serials.append(secondEarbudSerialNumber)
        }
        equivalentConnectionIDsForReconnection = connection.equivalentConnectionIDsForReconnection(btAddresses: btAddresses,
                                                                                                   serialNumbers: serials)
    }

    private func notifyIndentificationComplete() {
        notificationCenter.post(GaiaDeviceNotification(sender: self,
                                                       payload: self,
                                                       reason: .identificationComplete))
    }

    func updaterPluginHandler(_ notification: GaiaDeviceUpdaterPluginNotification) {
        guard
            let myPlugin = plugin(featureID: .upgrade) as? GaiaDeviceUpdaterPluginProtocol,
            let senderPlugin = notification.sender as? GaiaDeviceUpdaterPluginProtocol,
            senderPlugin === myPlugin // note pointer comparison
        else {
            return
        }

        switch notification.reason {
        case .ready:
            LOG(.medium, "Updater Ready")
            state = .gaiaReady
        default:
            break
        }
    }

    func fetchDeviceVersion() {
        LOG(.medium, "Sending Version Request")
        version = .unknown
    	let message = GaiaV2GATTPacket(commandID: V2Commands.getAPIVersion.rawValue,
                                       payload: Data())
        connection.sendData(channel: .command, payload: message.data, acknowledgementExpected: connectionKind != .ble)
    }

    func handleV2VersionReply(_ packet: GaiaV2GATTPacket, channel: GaiaDeviceConnectionChannel) {
        guard channel == .response else {
			return
        }

        switch packet.messageDescription {
        case .response(let commandID, let data):
            if commandID == V2Commands.getAPIVersion.rawValue {
                LOG(.low, "Get API Version replied....")
                if data.count >= 3 {
                    let protocolVersion = data[0]
                    let apiVersionMajor = data[1]
                    let apiVersionMinor = data[2]
                    apiVersion = "\(apiVersionMajor).\(apiVersionMinor)"
                    LOG(.medium, "Success: protocol version: \(protocolVersion) API version: \(apiVersion)")
                    version = apiVersionMajor > 2 ? .v3 : .v2
                    LOG(.medium, "Device is \(version)")
                } else {
                    version = .v2
                }
                fetchPlugins()
            }
        case .error(let commandID, _, _):
            if commandID == V2Commands.getAPIVersion.rawValue {
                version = .unknown
                state = .failed(reason: .deviceVersionCouldNotBeDetermined)
            }
        default:
            break
        }
    }

    func handleV2CoreReplies(_ packet: GaiaV2GATTPacket, channel: GaiaDeviceConnectionChannel) -> Bool {
		return false
    }

    func getV3FeatureID(packetFeatureID: GaiaV3PacketFeatureID) -> GaiaDeviceQCPluginFeatureID? {
        switch packetFeatureID {
        case .qualcomm(let id):
            return id
        case .vendor(_):
            return nil
        }
    }

    func handleV3CoreReplies(_ message: GaiaV3GATTPacket, channel: GaiaDeviceConnectionChannel) -> Bool {
        if let featureID = getV3FeatureID(packetFeatureID: message.featureID) {
            notifyConnectionOfResponseIfNecessary(message: message)
            switch message.messageDescription {
            case .notification(_, _):
                return false
            case .error(let commandCode , let errorCode, _):
                if featureID == .core {
                    if let reason = Gaia.CommandErrorCodes(rawValue: errorCode) {
                        if reason != .success {
                            if let cmd = SupportedFeaturesCommands(rawValue: commandCode) {
                                LOG(.high, "Received Error: \(reason) for command \(cmd) feature ID: \(featureID)")
                            } else {
                                LOG(.high, "Received Error with unknown command: \(commandCode) feature ID: \(featureID)")
                            }
                        }
                    } else {
                        LOG(.high, "Received Error with unknown reason: \(errorCode) feature ID: \(featureID)")
                    }
                    return true
                } else {
                    return false
                }
            case .response(let command, let data):
                var handled = false
                if featureID == .core {
                    if let coreCommand = SupportedFeaturesCommands(rawValue: command) {
                        handled = true

                        if coreCommand == .first &&
                            supportedFeaturesData.count > 0 {
                            return true // Shouldn't happen but ignore
                        }

                        if let more = data.first {
                            let featureData = (data.count > 1) ? data.advanced(by: 1) : Data()
                            supportedFeaturesData.append(featureData)
                            if more == 1 {
                                // There's more so we make another request
                                let message = GaiaV3GATTPacket(featureID: .core,
                                                               commandID: SupportedFeaturesCommands.next.rawValue,
                                                               payload: Data())
                                connection.sendData(channel: .command, payload: message.data, acknowledgementExpected: true)
                            } else {
                                // There's no more so we process
                                processSupportedFeatureResponse()
                                registerAllPluginsForNotifications()
                            }
                        }
                    } else if let notificationCommand = DeviceNotificationRegistration(rawValue: command) {
                        handled = true
                        if notificationCommand == .register && awaitingRegistrationConfirmation > 0 {
                            awaitingRegistrationConfirmation -= 1
                            if awaitingRegistrationConfirmation == 0 {
                                pluginsInUse.forEach({ plugin in
                                    plugin.notificationStateDidChange(true)
                                })
                                startV3Plugins()
                            }
                        }
                    }
                }
                return handled

            default:
                return false

            }
        }
        return false
    }

    func fetchPlugins() {
        pluginsInUse.removeAll()
        
        switch version {
        case .v2:
            let descriptions = [GaiaPluginCreatorFeatureDescription(GaiaDeviceQCPluginFeatureID.upgrade, 0)]
            pluginsInUse = GaiaPluginManager.shared.pluginsForNewDevice(self,
                                                                        featureDescriptions: descriptions,
                                                                        connection: connection,
                                                                        notificationCenter: notificationCenter)
            if let updater = plugin(featureID: .upgrade) {
                LOG(.medium, "Starting Updater Initialisation")
                updater.startPlugin()
            }
        case .v3:
            LOG(.medium, "Requesting supported features - v3")
            // make API request for features
            supportedFeaturesData = Data()
            let message = GaiaV3GATTPacket(featureID: .core,
                                           commandID: SupportedFeaturesCommands.first.rawValue,
                                           payload: Data())

            connection.sendData(channel: .command, payload: message.data, acknowledgementExpected: true)
        default:
            break
        }
    }

    func processSupportedFeatureResponse() {
        guard supportedFeaturesData.count % 2 == 0 else {
            LOG(.medium, "Supported features data has odd number of bytes")
            return
        }

        var descriptions = [GaiaPluginCreatorFeatureDescription] ()
        for index in stride(from: 0, to: supportedFeaturesData.count, by: 2) {
            if let featureID = GaiaDeviceQCPluginFeatureID(rawValue: supportedFeaturesData[index]) {
                let version = supportedFeaturesData[index + 1]

                let desc = GaiaPluginCreatorFeatureDescription(featureID, version)
                descriptions.append(desc)
            }
        }

        pluginsInUse = GaiaPluginManager.shared.pluginsForNewDevice(self,
                                                                    featureDescriptions: descriptions,
                                                                    connection: connection,
                                                                    notificationCenter: notificationCenter)

    }

    func registerAllPluginsForNotifications() {
        awaitingRegistrationConfirmation = pluginsInUse.count
        pluginsInUse.forEach({ plugin in
            let message = GaiaV3GATTPacket(featureID: .core,
                                           commandID: DeviceNotificationRegistration.register.rawValue,
                                           payload: Data([plugin.featureID.rawValue]))
            connection.sendData(channel: .command, payload: message.data, acknowledgementExpected: true)
        })
    }

    func startV3Plugins() {
        // If there's a core plugin we start it then wait for it to finish handshake so the connection is set up
        // to maximum packet sizes.
        if let core = plugin(featureID: .core) {
            LOG(.medium, "Starting Core Initialisation")
            core.startPlugin()
        } else {
            startNonCorePlugins()
            if plugin(featureID: .upgrade) == nil {
                // If there's no upgrade plugin we declare ready now. If not we wait for it to get state.
                state = .gaiaReady
            }
        }
    }

    func startNonCorePlugins() {
        if let earbud = plugin(featureID: .earbud) {
            LOG(.medium, "Starting Earbud Initialisation")
            earbud.startPlugin()
        }

        if let updater = plugin(featureID: .upgrade) {
            LOG(.medium, "Starting Updater Initialisation")
            updater.startPlugin()
        }

        pluginsInUse.forEach {
            if $0.featureID != .upgrade &&
                $0.featureID != .core  &&
                $0.featureID != .earbud {
                // We started the updater/earbud plugin early.
            	$0.startPlugin()
            }
        }

        vendorExtensions = VendorExtensionManager.shared.vendorExtensionsForNewDevice(self,
                                                                                      connection: connection,
                                                                                      notificationCenter: notificationCenter)

        vendorExtensions.forEach {
            $0.start()
        }
    }
}
