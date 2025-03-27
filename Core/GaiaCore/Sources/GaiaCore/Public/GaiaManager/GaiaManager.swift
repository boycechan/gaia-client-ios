//
//  © 2020 - 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation
import GaiaSupportedPlugins
import GaiaBase
import PluginBase
import GaiaLogger

/// Gaia Manager gathers the individual Gaia Device instances regardless of transport. It provides a complete, transport-agnostic overview of all
/// Gaia Devices on all supported transports.
public class GaiaManager: NSObject, GaiaNotificationSender {
    // MARK: Private ivars
    static private let standardTimeDelay: Int = 5

    private let connectionFactory: GaiaConnectionFactory
    private let notificationCenter: NotificationCenter

    private let reconnectionManager: GaiaManagerReconnectionManager
    private var handoverManager: GaiaManagerHandoverTransitionManager?
    private var updateRestartManager: GaiaManagerUpdateRestartTransitionManager?

    private var observers = [ObserverToken] ()
    private var reconnectDelaySecs: Int = standardTimeDelay

    // MARK: Public ivars
    public var connectedDeviceConnectionID: String? {
        reconnectionManager.connectedDeviceConnectionID
    }

    public var devices: [GaiaDeviceProtocol] {
        return connectionFactory.devices
    }

    public var isAvailable: Bool {
        return connectionFactory.isAvailable
    }

    public var isScanning: Bool {
        return connectionFactory.isScanning
    }

    // MARK: init/deinit
    public required init(connectionFactory: GaiaConnectionFactory,
                         notificationCenter: NotificationCenter) {
        self.connectionFactory = connectionFactory
        self.notificationCenter = notificationCenter
        self.reconnectionManager = GaiaManagerReconnectionManager(connectionFactory: connectionFactory)

        super.init()
        connectionFactory.delegate = self

        GaiaSupportedPlugins.register()

        observers.append(notificationCenter.addObserver(forType: GaiaDeviceUpdaterPluginNotification.self,
                                                        object: nil,
                                                        queue: OperationQueue.main,
                                                        using: { [weak self] notification in self?.updaterNotificationHandler(notification) }))

        observers.append(notificationCenter.addObserver(forType: GaiaDeviceNotification.self,
                                                        object: nil,
                                                        queue: OperationQueue.main,
                                                        using: { [weak self] notification in self?.deviceNotificationHandler(notification) }))

        observers.append(notificationCenter.addObserver(forType: GaiaDeviceEarbudPluginNotification.self,
                                                        object: nil,
                                                        queue: OperationQueue.main,
                                                        using: { [weak self] notification in self?.earbudNotificationHandler(notification) }))
    }

    deinit {
        observers.forEach { token in
            notificationCenter.removeObserver(token)
        }
        observers.removeAll()
    }

    // MARK: Public Methods
    public func clearDeviceList() {
        connectionFactory.clearDeviceList()
    }

    public func stopScanning() {
        connectionFactory.stopScanning()
    }

    public func startScanning() {
        connectionFactory.startScanning()
    }

    public func device(connectionID: String) -> GaiaDeviceProtocol? {
        return devices.first(where: { $0.connectionID == connectionID })
    }

    public func start(device: GaiaDeviceProtocol) {
        reconnectionManager.updateIndentificationInfo(device)

        switch device.state {

        case .disconnected:
            LOG(.medium, "Connect Requested")
            connectionFactory.connect(device)
        case .awaitingTransportSetUp:
            LOG(.medium, "Device already connected - setting up transport")
            device.startConnection()
        case .settingUpTransport:
            break
        case .transportReady:
            LOG(.medium, "Transport already up - start gaia")
            device.connectGaia()
        case .settingUpGaia:
            break
        case .gaiaReady:
            break
        case .failed(reason: _):
            break
        }
    }
    
    public func disconnect(device: GaiaDeviceProtocol) {
        // Explicit disconnection request
        if device.state != .disconnected {
			updateRestartManager = nil
            handoverManager = nil
            reconnectionManager.updateIndentificationInfo(nil)

            connectionFactory.disconnect(device)
        }
    }
}

// MARK: - Notification Handlers
private extension GaiaManager {
    func updaterNotificationHandler(_ notification: GaiaDeviceUpdaterPluginNotification) {
        guard
            let device = device(connectionID: notification.payload.connectionID),
            devices.contains(where: { $0 === device }),
            let plugin = device.plugin(featureID: .upgrade) as? GaiaDeviceUpdaterPluginProtocol
        else {
            return
        }

        switch notification.reason {
        case .statusChanged:
            switch plugin.updateState {
            case .ready:
                break
            case .busy(progress: let progress):
                switch progress {
                case .transferring:
                    updateRestartManager = GaiaManagerUpdateRestartTransitionManager(device: device,
                                                                              connectionFactory: connectionFactory,
                                                                              notificationCenter: notificationCenter)
                case .unpausing:
                    handoverManager = nil
                default:
                    break
                }
            case .stopped(reason: _):
                updateRestartManager = nil
            }
        case .ready:
            break
        }
    }

    func deviceNotificationHandler(_ notification: GaiaDeviceNotification) {
        guard let device = device(connectionID: notification.payload.connectionID),
              devices.contains(where: { $0 === device }) else {
            return
        }

        if notification.reason == .stateChanged {
            handoverManager?.deviceStateChanged(device)
            updateRestartManager?.deviceStateChanged(device)
            reconnectionManager.deviceStateChanged(device)

            LOG(.medium, "State Change to \(device.state) for \(device.name)")
            if device.state == .gaiaReady {
                LOG(.medium, "Device ID: \(device.connectionID)\nEquivalents: \(reconnectionManager.equivalentConnectionIDs)")

                if !reconnectionManager.equivalentConnectionIDs.contains(device.connectionID) {
                    LOG(.medium, "NOT MATCHED!!!")
                    updateRestartManager = nil
                }
            } else if device.state == .transportReady {
                // Are we trying to connect to this device or has it connected automatically (eg iAP)
                if reconnectionManager.equivalentConnectionIDs.contains(device.connectionID) {
                    reconnectionManager.updateIndentificationInfo(device)
                    LOG(.medium, "Transport up as requested - start gaia")
                    device.connectGaia()
                }
            }
        } else if notification.reason == .identificationComplete {
            if device.connectionID == connectedDeviceConnectionID {
                reconnectionManager.updateIndentificationInfo(device)
            }
        }
    }
    
    func earbudNotificationHandler(_ notification: GaiaDeviceEarbudPluginNotification) {
        guard
            let payload = notification.payload,
            payload.device.connectionID == connectedDeviceConnectionID,
            let device = device(connectionID: payload.device.connectionID),
            devices.contains(where: { $0 === device })
        else {
            return
        }

        switch notification.reason {
        case .handoverAboutToHappen:
            reconnectDelaySecs = payload.handoverDelay
            handoverManager = GaiaManagerHandoverTransitionManager(device: device,
                                                            connectionFactory: connectionFactory,
                                                            notificationCenter: notificationCenter)
            handoverManager?.waitForHandover(timeout: payload.handoverDelay, isStatic: payload.handoverIsStatic)
        case .primaryChanged:
            handoverManager?.handoverDidHappen(device: device)
            handoverManager = nil
            reconnectDelaySecs = Self.standardTimeDelay
        default:
            break
        }
    }
}

//MARK: - GaiaConnectionFactoryDelegate - Device Discovery etc.
extension GaiaManager: GaiaConnectionFactoryDelegate {
    func didChangeState() {
        if connectionFactory.isAvailable {
            LOG(.low, "Powered on")
            let notification = GaiaManagerNotification(sender: self,
                                                       payload: .system,
                                                       reason: .poweredOn)
            notificationCenter.post(notification)
			connectionFactory.startScanning()

        } else {
            LOG(.low, "Powered off")
            let notification = GaiaManagerNotification(sender: self,
                                                       payload: .system,
                                                       reason: .poweredOff)
            notificationCenter.post(notification)
        }
    }

    func didDiscoverDevice(_ device: GaiaDeviceProtocol) {
        let notification = GaiaManagerNotification(sender: self,
                                                   payload: .device(device),
                                                   reason: .discover)
        notificationCenter.post(notification)

        let discoveredDeviceNeedsReconnection = reconnectionManager.equivalentConnectionIDs.contains(device.connectionID)

        if discoveredDeviceNeedsReconnection {
            if device.state == .disconnected || device.state == .awaitingTransportSetUp {
                LOG(.high, "Discover: Will try to reconnect \(device.name).")
                start(device: device)
                stopScanning()
            }
        }
    }

    func didConnectDevice(_ device: GaiaDeviceProtocol) {
        reconnectDelaySecs = Self.standardTimeDelay
        LOG(.medium, "DID CONNECT DEVICE - GAIAMANAGER")

        if let connectedDeviceID = connectedDeviceConnectionID,
           connectedDeviceID == device.connectionID {
            handoverManager?.deviceConnected(device)
            updateRestartManager?.deviceConnected(device)
            reconnectionManager.didConnect(device, connectionFactory: connectionFactory)
        }

        let notification = GaiaManagerNotification(sender: self,
                                                   payload: .device(device),
                                                   reason: .connectSuccess)
        notificationCenter.post(notification)
        device.startConnection()
    }

    func didFailToConnectDevice(_ device: GaiaDeviceProtocol) {
        let notification = GaiaManagerNotification(sender: self,
                                                   payload: .device(device),
                                                   reason: .connectFailed)
        notificationCenter.post(notification)

        LOG(.high, "Connection failed: \(device)")

        if let connectedDeviceID = connectedDeviceConnectionID,
           connectedDeviceID == device.connectionID {
            reconnectionManager.startReconnection(for: device, after: reconnectDelaySecs * 1000)
        }
    }

    func didDisconnectDevice(_ device: GaiaDeviceProtocol) {
        let notification = GaiaManagerNotification(sender: self,
                                                   payload: .device(device),
                                                   reason: .disconnect)
        notificationCenter.post(notification)

        LOG(.high, "Disconnection: \(device)")

        if let connectedDeviceID = connectedDeviceConnectionID,
           connectedDeviceID == device.connectionID {
            handoverManager?.deviceDisconnected(device)
            updateRestartManager?.deviceDisconnected(device)
            reconnectionManager.startReconnection(for: device, after: reconnectDelaySecs * 1000)
        }
    }
}
