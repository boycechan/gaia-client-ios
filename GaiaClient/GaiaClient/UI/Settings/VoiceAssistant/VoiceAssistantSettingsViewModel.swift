//
//  © 2020 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation
import GaiaCore
import GaiaBase
import PluginBase

class VoiceAssistantSettingsViewModel: GaiaTableViewModelProtocol {
    private weak var viewController: GaiaViewControllerProtocol?
    private let coordinator: AppCoordinator
    private let gaiaManager: GaiaManager
    private let notificationCenter: NotificationCenter

    private(set) weak var vaPlugin: GaiaDeviceVoiceAssistantPluginProtocol?

    private(set) var title: String

    private(set) var sections = [SettingSection] ()
    private(set) var checkmarkIndexPath: IndexPath?

    private var device: GaiaDeviceProtocol? {
        didSet {
            vaPlugin = device?.plugin(featureID: .voiceAssistant) as? GaiaDeviceVoiceAssistantPluginProtocol
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

        self.title = String(localized: "Voice Assistant", comment: "Settings Screen Title")

        observerTokens.append(notificationCenter.addObserver(forType: GaiaDeviceNotification.self,
                                                             object: nil,
                                                             queue: OperationQueue.main,
                                                             using: { [weak self] notification in self?.deviceNotificationHandler(notification) }))

        observerTokens.append(notificationCenter.addObserver(forType: GaiaManagerNotification.self,
                                                             object: nil,
                                                             queue: OperationQueue.main,
                                                             using: { [weak self] notification in self?.deviceDiscoveryAndConnectionHandler(notification) }))

        observerTokens.append(notificationCenter.addObserver(forType: GaiaDeviceVoiceAssistantPluginNotification.self,
                                                             object: nil,
                                                             queue: OperationQueue.main,
                                                             using: { [weak self] notification in self?.voiceAssistantNotificationHandler(notification) }))
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
        guard let vaPlugin = vaPlugin else {
            return
        }

        let optionsSectionRows = vaPlugin.availableAssistantOptions.map({ SettingRow.title(title: $0.userVisibleDescription(),
                                                                                       tapable: true) })
        let optionsSection = SettingSection(title: nil, rows: optionsSectionRows)
        sections = [optionsSection]
        let selectedOption = vaPlugin.selectedAssistant
        let row = vaPlugin.availableAssistantOptions.firstIndex(where: { option in
            option == selectedOption
        }) ?? 0

        checkmarkIndexPath = IndexPath(row: row, section: sections.count - 1)
        viewController?.update()
    }
}

extension VoiceAssistantSettingsViewModel {
    func selectedItem(indexPath: IndexPath) {
        guard let vaPlugin = vaPlugin,
            indexPath.section == sections.count - 1,
            indexPath.row < sections[indexPath.section].rows.count else {
            return
        }

        vaPlugin.selectOption(vaPlugin.availableAssistantOptions[indexPath.row])
    }

    func toggledSwitch(indexPath: IndexPath) {
        abort()
    }

    func valueChanged(indexPath: IndexPath, newValue: Int) {
        abort()
    }
}

private extension VoiceAssistantSettingsViewModel {
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

    func voiceAssistantNotificationHandler(_ notification: GaiaDeviceVoiceAssistantPluginNotification) {
        guard notification.payload.id == device?.id else {
            return
        }
        
		refresh()
    }
}
