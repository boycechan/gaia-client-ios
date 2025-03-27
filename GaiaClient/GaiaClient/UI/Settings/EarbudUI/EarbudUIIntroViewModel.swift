//
//  © 2021 - 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import UIKit
import GaiaCore
import GaiaBase
import PluginBase

class EarbudUIIntroViewModel: GaiaDeviceViewModelProtocol {
    struct GestureInfo {
        fileprivate let gestureID: EarbudUIGesture
        let name: String
        let subtitle: String?
        let image: UIImage?
    }

    private weak var viewController: GaiaViewControllerProtocol?
    private let coordinator: AppCoordinator
    private let gaiaManager: GaiaManager
    private let notificationCenter: NotificationCenter

    private(set) weak var uiPlugin: GaiaDeviceEarbudUIPluginProtocol?

    private(set) var title: String

    private(set) var gestures = [GestureInfo] ()
    private(set) var checkmarkIndexPath: IndexPath?

    private var device: GaiaDeviceProtocol? {
        didSet {
            uiPlugin = device?.plugin(featureID: .earbudUI) as? GaiaDeviceEarbudUIPluginProtocol
            if let vc = viewController,
               vc.isViewLoaded,
               vc.view.window != nil {
                // We're on screen so we should load if not already present.
                uiPlugin?.fetchIfNotLoaded()
            }
            refresh()
        }
    }

    private(set) var observerTokens = [ObserverToken]()

    required init(viewController: GaiaViewControllerProtocol,
                  coordinator: AppCoordinator,
                  gaiaManager: GaiaManager,
                  notificationCenter: NotificationCenter) {
        self.viewController = viewController
        self.coordinator = coordinator
        self.gaiaManager = gaiaManager
        self.notificationCenter = notificationCenter

        self.title = String(localized: "Gesture Configuration", comment: "Settings Screen Title")

        observerTokens.append(notificationCenter.addObserver(forType: GaiaDeviceNotification.self,
                                                             object: nil,
                                                             queue: OperationQueue.main,
                                                             using: { [weak self] notification in self?.deviceNotificationHandler(notification) }))

        observerTokens.append(notificationCenter.addObserver(forType: GaiaManagerNotification.self,
                                                             object: nil,
                                                             queue: OperationQueue.main,
                                                             using: { [weak self] notification in self?.deviceDiscoveryAndConnectionHandler(notification) }))

        observerTokens.append(notificationCenter.addObserver(forType: GaiaDeviceEarbudUIPluginNotification.self,
                                                             object: nil,
                                                             queue: OperationQueue.main,
                                                             using: { [weak self] notification in self?.earbudUINotificationHandler(notification) }))
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
        uiPlugin?.fetchIfNotLoaded()
        refresh()
    }

    func deactivate() {
    }

    func refresh() {
        if let uiPlugin = uiPlugin,
           uiPlugin.isValid {
            let supportedGestures = uiPlugin.supportedGestures
            let supportedContexts = uiPlugin.supportedContexts
            let nestedContexts = EarbudUIContext.nestedContextsForUI(contexts: supportedContexts)

			var newGestures = [GestureInfo]()
            for gesture in supportedGestures {
                var actionStrings = [String] ()
                var actionSet = Set<EarbudUIAction> ()
                for heading in nestedContexts {
                    let subContexts = heading.subContexts
                    for context in subContexts {
                        let touchpadActionsForCombo = uiPlugin.currentTouchpadActions(gesture: gesture, context: context)
                        for touchpadAction in touchpadActionsForCombo {
                            if !actionSet.contains(touchpadAction.action) {
                                actionStrings.append(touchpadAction.action.userVisibleName())
                                actionSet.insert(touchpadAction.action)
                            }
                        }
                    }
                }
                let subtitle = actionStrings.joined(separator: ", ")
				let gestureEntry = GestureInfo(gestureID: gesture,
                                               name: gesture.userVisibleName(),
                                               subtitle: subtitle,
                                               image: gesture.userVisibleImage())
                newGestures.append(gestureEntry)
            }
            gestures = newGestures.sorted(by: { $0.gestureID < $1.gestureID } )
        } else {
            gestures.removeAll()
        }

        viewController?.update()
    }
}

extension EarbudUIIntroViewModel {
    func selectedItem(indexPath: IndexPath) {
        guard let device = device else {
            return
        }

        let gesture = gestures[indexPath.row].gestureID
        coordinator.showContextsForGesture(device: device, gesture: gesture)
    }

    func resetToDefaults() {
        uiPlugin?.performFactoryReset()
    }
}

private extension EarbudUIIntroViewModel {
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

    func earbudUINotificationHandler(_ notification: GaiaDeviceEarbudUIPluginNotification) {
        guard
            notification.payload?.id == device?.id
        else {
            return
        }

        switch notification.reason {
        case .resetFailed:
            if let vc = viewController as? EarbudUIIntroViewController,
               device?.deviceType == .earbud {
                vc.showDenialAlert(title: String(localized: "Cannot reset to defaults", comment: "EarbudUI reset failure"),
                                   message: String(localized: "Please ensure both earbuds are out of the case and try again.", comment: "EarbudUI reset failure"),
                                   completion: {})
            }
        default:
            refresh()
        }
    }
}

