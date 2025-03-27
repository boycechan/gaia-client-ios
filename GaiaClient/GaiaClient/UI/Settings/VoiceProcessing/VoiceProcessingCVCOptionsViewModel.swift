//
//  © 2021 - 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation
import GaiaCore
import GaiaBase
import PluginBase

class VoiceProcessingCVCOptionsViewModel: GaiaTableViewModelProtocol {
    private weak var viewController: GaiaViewControllerProtocol?
    private let coordinator: AppCoordinator
    private let gaiaManager: GaiaManager
    private let notificationCenter: NotificationCenter

    private(set) weak var vePlugin: GaiaDeviceVoiceProcessingPluginProtocol?

    private(set) var title: String

    private(set) var sections = [SettingSection] ()
    private(set) var checkmarkIndexPath: IndexPath?

    // Closures

    private var availableModesGetter: ((GaiaDeviceVoiceProcessingPluginProtocol) -> ([String]))?
    private var currentModeGetter: ((GaiaDeviceVoiceProcessingPluginProtocol) -> (Int))?
    private var currentModeSetter: ((GaiaDeviceVoiceProcessingPluginProtocol, Int) -> ())?

    private var device: GaiaDeviceProtocol? {
        didSet {
            vePlugin = device?.plugin(featureID: .voiceProcessing) as? GaiaDeviceVoiceProcessingPluginProtocol
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

        observerTokens.append(notificationCenter.addObserver(forType: GaiaDeviceVoiceProcessingPluginNotification.self,
                                                             object: nil,
                                                             queue: OperationQueue.main,
                                                             using: { [weak self] notification in self?.voiceProcessingNotificationHandler(notification) }))

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

    func injectClosures(title: String,
                        availableModesGetter: @escaping (GaiaDeviceVoiceProcessingPluginProtocol) -> ([String]),
                        currentModeGetter: @escaping (GaiaDeviceVoiceProcessingPluginProtocol) -> (Int),
                        currentModeSetter: @escaping (GaiaDeviceVoiceProcessingPluginProtocol, Int) -> ()) {
        self.title = title
        self.availableModesGetter = availableModesGetter
        self.currentModeGetter = currentModeGetter
        self.currentModeSetter = currentModeSetter
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
}

extension VoiceProcessingCVCOptionsViewModel {
    func toggledSwitch(indexPath: IndexPath) {
    }

    func selectedItem(indexPath: IndexPath) {
        guard
            let vePlugin = vePlugin,
            indexPath.section < sections.count,
            indexPath.row < sections[indexPath.section].rows.count
        else {
            return
        }

        let currentSelected = currentModeGetter?(vePlugin) ?? -1
        let newMode = indexPath.row

        if newMode != currentSelected {
            currentModeSetter?(vePlugin, newMode)
        }
    }

    func valueChanged(indexPath: IndexPath, newValue: Int) {
        abort()
    }
}

private extension VoiceProcessingCVCOptionsViewModel {
    func refresh() {
        guard
            let vePlugin = vePlugin,
            let options = availableModesGetter?(vePlugin)
        else {
            sections = [SettingSection]()
            viewController?.update()
            return
        }

        let currentMode = currentModeGetter?(vePlugin) ?? -1
        if currentMode >= 0 {
            checkmarkIndexPath = IndexPath(row: currentMode, section: 0)
        } else {
            checkmarkIndexPath = nil
        }

        var newSections = [SettingSection]()
        var newRows = [SettingRow]()

        for options in options {
            let newRow = SettingRow.title(title: options, tapable: true)
            newRows.append(newRow)
        }

        newSections.append(SettingSection(title: nil, rows: newRows))

        sections = newSections

        viewController?.update()
    }
}

private extension VoiceProcessingCVCOptionsViewModel {
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

    func voiceProcessingNotificationHandler(_ notification: GaiaDeviceVoiceProcessingPluginNotification) {
        guard notification.payload.id == device?.id else {
            return
        }

        if notification.reason == .cVcBypassModeChanged || notification.reason == .cVcMicrophonesModeChanged {
            refresh()
        }
    }
}

