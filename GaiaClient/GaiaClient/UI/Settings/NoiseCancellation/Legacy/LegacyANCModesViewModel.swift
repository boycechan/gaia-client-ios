//
//  © 2020 - 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation
import GaiaCore
import GaiaBase
import PluginBase

class LegacyANCModesViewModel: GaiaTableViewModelProtocol {
    private weak var viewController: GaiaViewControllerProtocol?
    private let coordinator: AppCoordinator
    private let gaiaManager: GaiaManager
    private let notificationCenter: NotificationCenter

    private(set) weak var ncPlugin: GaiaDeviceLegacyANCPluginProtocol?

    private(set) var title: String

    private(set) var sections = [SettingSection] ()
    private(set) var checkmarkIndexPath: IndexPath?

    private var device: GaiaDeviceProtocol? {
        didSet {
            ncPlugin = device?.plugin(featureID: .legacyANC) as? GaiaDeviceLegacyANCPluginProtocol
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

        self.title = String(localized: "Mode", comment: "Settings Screen Title")

        observerTokens.append(notificationCenter.addObserver(forType: GaiaDeviceNotification.self,
                                                             object: nil,
                                                             queue: OperationQueue.main,
                                                             using: { [weak self] notification in self?.deviceNotificationHandler(notification) }))

        observerTokens.append(notificationCenter.addObserver(forType: GaiaManagerNotification.self,
                                                             object: nil,
                                                             queue: OperationQueue.main,
                                                             using: { [weak self] notification in self?.deviceDiscoveryAndConnectionHandler(notification) }))

        observerTokens.append(notificationCenter.addObserver(forType: GaiaDeviceLegacyANCPluginNotification.self,
                                                             object: nil,
                                                             queue: OperationQueue.main,
                                                             using: { [weak self] notification in self?.noiseCancellationNotificationHandler(notification) }))

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
        guard let ncPlugin = ncPlugin else {
            return
        }

        let maxMode = min(9, max(0, ncPlugin.maxMode)) // constrain 0..9
        let modeCurrent = min(maxMode, max(0, ncPlugin.currentMode))

        sections.removeAll()

        var sectionRows = [SettingRow] ()

        for index in 0...maxMode {
            let row = SettingRow.title(title: LegacyANCShared.modeOptions[index], tapable: true)
            sectionRows.append(row)
        }
        sections.append(SettingSection(title: nil, rows: sectionRows))

        checkmarkIndexPath = IndexPath(row: modeCurrent, section: sections.count - 1)
        viewController?.update()
    }
}

extension LegacyANCModesViewModel {
    func toggledSwitch(indexPath: IndexPath) {
    }

    func selectedItem(indexPath: IndexPath) {
        guard let ncPlugin = ncPlugin,
            indexPath.section == sections.count - 1,
            indexPath.row < sections[indexPath.section].rows.count,
            indexPath.row != ncPlugin.currentMode else {
            return
        }

        ncPlugin.setCurrentMode(indexPath.row)
    }

    func valueChanged(indexPath: IndexPath, newValue: Int) {
        abort()
    }
}

private extension LegacyANCModesViewModel {
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

    func noiseCancellationNotificationHandler(_ notification: GaiaDeviceLegacyANCPluginNotification) {
        guard notification.payload.id == device?.id else {
            return
        }
        
        refresh()
    }
}

