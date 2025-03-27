//
//  © 2020 - 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation
import GaiaCore
import GaiaBase
import PluginBase

class BLEUpdateSettingsViewModel: GaiaDeviceViewModelProtocol {
    struct BLELimits {
        let maxMessageSize: Int
        let optimumMessageSize: Int
        let dleAvailable: Bool
        let rwcpAvailable: Bool
    }

    private weak var viewController: GaiaViewControllerProtocol?
    private let coordinator: AppCoordinator
    private let gaiaManager: GaiaManager
    private let notificationCenter: NotificationCenter

    private(set) weak var updatesPlugin: GaiaDeviceUpdaterPluginProtocol?

    private(set) var title: String

    private var device: GaiaDeviceProtocol? {
        didSet {
            updatesPlugin = device?.plugin(featureID: .upgrade) as? GaiaDeviceUpdaterPluginProtocol
            if let transportCaps = updatesPlugin?.transportCapabilities {
                switch transportCaps {
                case .ble(lengthExtensionAvailable: let lengthExtensionAvailable,
                          rwcpAvailable: let rwcpAvailable,
                          maxMessageSize: let maxMessageSize,
                          optimumMessageSize: let optimumMessageSize):
                    let max = lengthExtensionAvailable ? maxMessageSize : min(UpdateTransportOptions.Constants.maxSizeWithoutDLE, maxMessageSize)
                    let opt = lengthExtensionAvailable ? optimumMessageSize : min(UpdateTransportOptions.Constants.maxSizeWithoutDLE, optimumMessageSize)
                    limits = BLELimits(maxMessageSize: max,
                                       optimumMessageSize: opt,
                                       dleAvailable: lengthExtensionAvailable,
                                       rwcpAvailable: rwcpAvailable)
                    refresh()
                default:
                    assertionFailure("IAP UI but connection is BLE")
                }

            }
        }
    }

    private(set) var limits: BLELimits?

    private var observerTokens = [ObserverToken]()

    required init(viewController: GaiaViewControllerProtocol,
                  coordinator: AppCoordinator,
                  gaiaManager: GaiaManager,
                  notificationCenter: NotificationCenter) {
        self.viewController = viewController
        self.coordinator = coordinator
        self.gaiaManager = gaiaManager
        self.notificationCenter = notificationCenter

        self.title = String(localized: "Update Settings", comment: "Settings Screen Title")

        observerTokens.append(notificationCenter.addObserver(forType: GaiaDeviceNotification.self,
                                                             object: nil,
                                                             queue: OperationQueue.main,
                                                             using: { [weak self] notification in self?.deviceNotificationHandler(notification) }))

        observerTokens.append(notificationCenter.addObserver(forType: GaiaManagerNotification.self,
                                                             object: nil,
                                                             queue: OperationQueue.main,
                                                             using: { [weak self] notification in self?.deviceDiscoveryAndConnectionHandler(notification) }))

        observerTokens.append(notificationCenter.addObserver(forType: GaiaDeviceUpdaterPluginNotification.self,
                                                             object: nil,
                                                             queue: OperationQueue.main,
                                                             using: { [weak self] notification in self?.deviceUpdaterNotificationHandler(notification) }))
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
        viewController?.update()
    }
}

extension BLEUpdateSettingsViewModel {
    func updateSettings(newMessageSize: Int,
                        initialWindowSize: Int = UpdateTransportOptions.Constants.rwcpInitialWindowSize,
                        maxWindowSize: Int = UpdateTransportOptions.Constants.rwcpMaxWindow) {
        guard let limits else {
            return
        }

        let sizeToSet = min(newMessageSize, limits.maxMessageSize)
        let initialToSet = min(initialWindowSize, UpdateTransportOptions.Constants.rwcpMaxWindow)
        let maxToSet = min(maxWindowSize, UpdateTransportOptions.Constants.rwcpMaxWindow)
        if limits.rwcpAvailable {
            let newSettings = UpdateTransportOptions.bleRWCP(useDLE: limits.dleAvailable,
                                                             requestedMessageSize: sizeToSet,
                                                             initialWindowSize: initialToSet,
                                                             maxWindowSize: maxToSet)
            UpdateSettingsContainer.shared.settings = newSettings
        } else {
            let newSettings = UpdateTransportOptions.ble(useDLE: limits.dleAvailable,
                                                         requestedMessageSize: sizeToSet)
            UpdateSettingsContainer.shared.settings = newSettings
        }

        refresh()
    }
}

private extension BLEUpdateSettingsViewModel {
    func deviceNotificationHandler(_ notification: GaiaDeviceNotification) {
        guard notification.payload.id == device?.id else {
            return
        }

        switch notification.reason {
        case .stateChanged:
            refresh()
        default:
            break
        }
    }

    func deviceDiscoveryAndConnectionHandler(_ notification: GaiaManagerNotification) {
        switch notification.reason {
        case .discover,
             .connectFailed,
             .connectSuccess,
             .disconnect:
            refresh()
        case .poweredOff:
            break
        case .poweredOn:
			break
        case .dfuReconnectTimeout:
            break
        }
    }

    func deviceUpdaterNotificationHandler(_ notification: GaiaDeviceUpdaterPluginNotification) {
        guard notification.payload.id == device?.id else {
            return
        }
        
        switch notification.reason {
        case .ready,
             .statusChanged:
            refresh()
        }
    }
}

