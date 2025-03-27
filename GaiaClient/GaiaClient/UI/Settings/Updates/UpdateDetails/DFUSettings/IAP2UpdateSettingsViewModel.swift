//
//  © 2020 - 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation
import GaiaCore
import GaiaBase
import PluginBase


class IAP2UpdateSettingsViewModel: GaiaDeviceViewModelProtocol {
    struct IAP2Limits {
        let maxMessageSize: Int
        let optimumMessageSize: Int
        let dleAvailable: Bool
    }

    private weak var viewController: GaiaViewControllerProtocol?
    private let coordinator: AppCoordinator
    private let gaiaManager: GaiaManager
    private let notificationCenter: NotificationCenter

    private(set) weak var updatesPlugin: GaiaDeviceUpdaterPluginProtocol?
    private(set) var title: String
    private(set) var limits: IAP2Limits?

    private var device: GaiaDeviceProtocol? {
        didSet {
            updatesPlugin = device?.plugin(featureID: .upgrade) as? GaiaDeviceUpdaterPluginProtocol
            if let transportCaps = updatesPlugin?.transportCapabilities {
                switch transportCaps {
                case .iap2(let lengthExtensionAvailable, let maxMessageSize, let optimumMessageSize):
                    let max = lengthExtensionAvailable ? maxMessageSize : min(0xfe, maxMessageSize)
                    let opt = lengthExtensionAvailable ? optimumMessageSize : min(0xfe, optimumMessageSize)
                    limits = IAP2Limits(maxMessageSize: max,
                                        optimumMessageSize: opt,
                                        dleAvailable: lengthExtensionAvailable)
                    refresh()
                default:
                    assertionFailure("IAP UI but connection is BLE")
                }

            }
        }
    }

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

extension IAP2UpdateSettingsViewModel {
    func updateSettings(newMessageSize: Int) {
        guard let limits else {
            return
        }
        
        let newSize = min(newMessageSize, limits.maxMessageSize)
        let newSettings = UpdateTransportOptions.iap2(useDLE: limits.dleAvailable,
                                                      requestedMessageSize: newSize,
                                                      expectACKs: true)
        UpdateSettingsContainer.shared.settings = newSettings
        
        refresh()
    }
}

private extension IAP2UpdateSettingsViewModel {
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


