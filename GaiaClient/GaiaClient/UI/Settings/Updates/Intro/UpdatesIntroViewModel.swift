//
//  © 2020 - 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation
import GaiaCore
import GaiaBase

class UpdatesIntroViewModel: GaiaTableViewModelProtocol {
    private weak var viewController: GaiaViewControllerProtocol?
    private let coordinator: AppCoordinator
    private let gaiaManager: GaiaManager
    private let notificationCenter: NotificationCenter

    private(set) var title: String

    private(set) var sections = [SettingSection] ()
    private(set) var checkmarkIndexPath: IndexPath?

    private var device: GaiaDeviceProtocol? {
        didSet {
            refresh()
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

        self.title = String(localized: "Software Updates", comment: "Settings Screen Title")

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
        sections.removeAll()

        guard let device = device else {
			viewController?.update()
            return
        }

        var firstSectionRows = [SettingRow] ()
        if device.version == .v3 {
            let appRow = SettingRow.titleAndSubtitle(title: String(localized: "Application Version", comment: "App Version"),
                                                     subtitle: device.applicationVersion,
                                                     tapable: false)
            firstSectionRows.append(appRow)
        }

        let apiRow = SettingRow.titleAndSubtitle(title: String(localized: "API Version", comment: "API Version"),
                                                 subtitle: device.apiVersion,
                                                 tapable: false)
        firstSectionRows.append(apiRow)

        let section = SettingSection(title: nil, rows: firstSectionRows)
        sections = [section]
        viewController?.update()
    }
}

extension UpdatesIntroViewModel {
    func showFiles() {
        guard let device = device else {
            return
        }

        coordinator.updateIntroProceedRequested(device, showRemote: false)
    }

    func showRemoteUpdates() {
        guard let device = device else {
            return
        }

        coordinator.updateIntroProceedRequested(device, showRemote: true)
    }

    func toggledSwitch(indexPath: IndexPath) {
        abort()
    }
    func selectedItem(indexPath: IndexPath) {
        abort()
    }
    func valueChanged(indexPath: IndexPath, newValue: Int) {
        abort()
    }
}

private extension UpdatesIntroViewModel {
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
}


