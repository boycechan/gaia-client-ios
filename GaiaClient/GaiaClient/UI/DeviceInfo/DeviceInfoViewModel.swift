//
//  © 2020 - 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation
import GaiaCore
import GaiaBase
import PluginBase

class DeviceInfoViewModel: GaiaDeviceViewModelProtocol {
    struct DeviceWrapper {
        fileprivate let device: GaiaDeviceProtocol
        var name: String { device.name }
        var version: GaiaDeviceVersion { device.version }
        var deviceType: GaiaDeviceType { device.deviceType }
        var connectionKind: ConnectionKind { device.connectionKind }
        var state: GaiaDeviceState { device.state }
        var serialNumber: String { device.serialNumber }
        var secondEarbudSerialNumber: String? { device.secondEarbudSerialNumber }
        var deviceVariant: String { device.deviceVariant }
        var applicationVersion: String {
            let base = device.applicationVersion
            let comps = base.components(separatedBy: ".")
            if let last = comps.last,
               last.isValidHex(),
               last.count > 8 {
                // Truncate last hex
                let newLast = String(last.prefix(8) + "…")
                var newComps = comps
                newComps.removeLast()
                newComps.append(newLast)
                return newComps.joined(separator: ".")
            } else {
                return base
            }
       }
        var apiVersion: String { device.apiVersion }
        var isCharging: Bool { device.isCharging }
        var batteryState: String? {
            if let batteryPlugin = device.plugin(featureID: .battery) as? GaiaDeviceBatteryPluginProtocol {
                var str = ""
                if let level = batteryPlugin.level(battery: .known(id: .single)) {
                    if deviceType == .headset {
                        str = str + String(format: "Headset: %d%% ", level)
                    } else {
                        str = str + String(format: "Battery: %d%% ", level)
                    }
                }

                if let level = batteryPlugin.level(battery: .known(id: .left)) {
                    str = str + String(format: "Left: %d%% ", level)
                }
                
                if let level = batteryPlugin.level(battery: .known(id: .right)) {
                    str = str + String(format: "Right: %d%% ", level)
                }

                if let level = batteryPlugin.level(battery: .known(id: .chargercase)) {
                    str = str + String(format: "Case: %d%% ", level)
                }

                str = str.trimmingCharacters(in: .whitespaces)
                return str.isEmpty ? nil : str
            }
            return nil
        }
        var isEarbud: Bool {
            device.deviceType == .earbud
        }
        var isLeftEarbudPrimary: Bool {
            if let earbudPlugin = device.plugin(featureID: .earbud) as? GaiaDeviceEarbudPluginProtocol {
                return earbudPlugin.leftEarbudIsPrimary
            }
            return true
        }
        var isUpdating: Bool {
            if let updaterPlugin = device.plugin(featureID: .upgrade) as? GaiaDeviceUpdaterPluginProtocol {
                return updaterPlugin.isUpdating
            }
            return false
        }
    }
    private weak var viewController: GaiaViewControllerProtocol?
    private let coordinator: AppCoordinator
    private let gaiaManager: GaiaManager
    private let notificationCenter: NotificationCenter

    private(set) var title: String

    private var device: GaiaDeviceProtocol? {
        didSet {
            if let device = device {
                deviceInfo = DeviceWrapper(device: device)
            } else {
                deviceInfo = nil
            }
            refresh()
        }
    }

    private(set) var deviceInfo: DeviceWrapper?
    var devicesAreAvailable: Bool {
        return gaiaManager.isAvailable
    }

    var observerTokens = [ObserverToken]()

    required init(viewController: GaiaViewControllerProtocol,
                  coordinator: AppCoordinator,
                  gaiaManager: GaiaManager,
                  notificationCenter: NotificationCenter) {
        self.viewController = viewController
        self.coordinator = coordinator
        self.gaiaManager = gaiaManager
        self.notificationCenter = notificationCenter

        self.title = ""

        observerTokens.append(notificationCenter.addObserver(forType: GaiaDeviceNotification.self,
                                                             object: nil,
                                                             queue: OperationQueue.main,
                                                             using: { [weak self] notification in self?.deviceNotificationHandler(notification) }))

        observerTokens.append(notificationCenter.addObserver(forType: GaiaManagerNotification.self,
                                                             object: nil,
                                                             queue: OperationQueue.main,
                                                             using: { [weak self] notification in self?.deviceDiscoveryAndConnectionHandler(notification) }))

        observerTokens.append(notificationCenter.addObserver(forType: GaiaDeviceEarbudPluginNotification.self,
                                                             object: nil,
                                                             queue: OperationQueue.main,
                                                             using: { [weak self] notification in self?.earbudHandler(notification) }))

        observerTokens.append(notificationCenter.addObserver(forType: GaiaDeviceCorePluginNotification.self,
                                                             object: nil,
                                                             queue: OperationQueue.main,
                                                             using: { [weak self] notification in self?.coreHandler(notification) }))

        observerTokens.append(notificationCenter.addObserver(forType: GaiaDeviceBatteryPluginNotification.self,
                                                             object: nil,
                                                             queue: OperationQueue.main,
                                                             using: { [weak self] notification in self?.batteryHandler(notification) }))
        
        observerTokens.append(notificationCenter.addObserver(forType: GaiaDeviceUpdaterPluginNotification.self,
                                                             object: nil,
                                                             queue: OperationQueue.main,
                                                             using: { [weak self] notification in self?.deviceUpdateHandler(notification) }))
    }

    deinit {
        observerTokens.forEach { token in
            notificationCenter.removeObserver(token)
        }
        observerTokens.removeAll()
    }

    func injectDevice(device: GaiaDeviceProtocol?) {
        self.device = device
    }

    func isDeviceConnected() -> Bool {
        if let device = device {
            return device.state != .disconnected
        } else {
            return false
        }
    }

    func activate() {
        refresh()
    }

    func deactivate() {
    }

    func refresh() {
        if let batteryPlugin = device?.plugin(featureID: .battery) as? GaiaDeviceBatteryPluginProtocol {
            batteryPlugin.refreshLevels()
        }
        viewController?.update()
    }

    func connectDisconnect() {
        if let d = device {
            if d.state != .disconnected || d.version == .unknown || d.connectionKind == .iap2 {
                coordinator.userRequestedDisconnect(d)
            } else {
                coordinator.userRequestedConnect(d)
            }
        } else {
            coordinator.userRequestedConnect(nil)
        }
    }
}

extension DeviceInfoViewModel {
    func deviceNotificationHandler(_ notification: GaiaDeviceNotification) {
        switch notification.reason {
        case .rssi,
             .stateChanged:
            refresh()
        case .identificationComplete:
            break
        }
    }

    func deviceDiscoveryAndConnectionHandler(_ notification: GaiaManagerNotification) {
        switch notification.reason {
        case .discover,
             .connectFailed,
             .connectSuccess,
             .disconnect,
             .poweredOff:
            refresh()
            break
        case .poweredOn:
            refresh()
        case .dfuReconnectTimeout:
            break
        }
    }

    func earbudHandler(_ notification: GaiaDeviceEarbudPluginNotification) {
        if notification.payload?.device.id == device?.id &&
            notification.reason == .secondSerial {
            refresh()
        }
    }

    func coreHandler(_ notification: GaiaDeviceCorePluginNotification) {
        guard case let .device(deviceIdentification) = notification.payload,
              deviceIdentification.id == device?.id else {
            return
        }
        
        switch notification.reason {
        case .chargerStatus,
             .handshakeComplete:
            refresh()
        default:
            break
        }
    }

    func batteryHandler(_ notification: GaiaDeviceBatteryPluginNotification) {
        guard notification.payload.id == device?.id else {
            return
        }

        switch notification.reason {
        case .levelsChanged:
            viewController?.update() // not refresh as that triggers another fetch
        default:
            break
        }
    }

    func deviceUpdateHandler(_ notification: GaiaDeviceUpdaterPluginNotification) {
        guard notification.payload.id == device?.id else {
            return
        }
        refresh()
    }
}
