//
//  © 2021 - 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation
import GaiaCore
import GaiaBase
import PluginBase

class AudioCurationModesViewModel: GaiaTableViewModelProtocol {
    private weak var viewController: GaiaViewControllerProtocol?
    private let coordinator: AppCoordinator
    private let gaiaManager: GaiaManager
    private let notificationCenter: NotificationCenter

    private(set) weak var ncPlugin: GaiaDeviceAudioCurationPluginProtocol?

    private(set) var title: String

    private(set) var sections = [SettingSection] ()
    private var modesInSections = [[GaiaDeviceAudioCurationModeInfo]]()
    private(set) var checkmarkIndexPath: IndexPath?

    // Closures

    private var availableModesGetter: ((GaiaDeviceAudioCurationPluginProtocol) -> ([GaiaDeviceAudioCurationModeInfo]))?
    private var currentModeGetter: ((GaiaDeviceAudioCurationPluginProtocol) -> (GaiaDeviceAudioCurationMode))?
    private var currentModeSetter: ((GaiaDeviceAudioCurationPluginProtocol, GaiaDeviceAudioCurationMode) -> ())?

    private var device: GaiaDeviceProtocol? {
        didSet {
            ncPlugin = device?.plugin(featureID: .audioCuration) as? GaiaDeviceAudioCurationPluginProtocol
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

        observerTokens.append(notificationCenter.addObserver(forType: GaiaDeviceAudioCurationPluginNotification.self,
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

    func injectClosures(title: String,
                        availableModesGetter: @escaping (GaiaDeviceAudioCurationPluginProtocol) -> ([GaiaDeviceAudioCurationModeInfo]),
                        currentModeGetter: @escaping (GaiaDeviceAudioCurationPluginProtocol) -> (GaiaDeviceAudioCurationMode),
                        currentModeSetter: @escaping (GaiaDeviceAudioCurationPluginProtocol, GaiaDeviceAudioCurationMode) -> ()) {
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

extension AudioCurationModesViewModel {
    func toggledSwitch(indexPath: IndexPath) {
    }

    func selectedItem(indexPath: IndexPath) {
        guard let ncPlugin = ncPlugin,
            indexPath.section < modesInSections.count,
            indexPath.row < modesInSections[indexPath.section].count
        else {
            return
        }

        let currentMode = currentModeGetter?(ncPlugin) ?? .off
        let newMode = modesInSections[indexPath.section][indexPath.row].mode

        if newMode != currentMode {
			currentModeSetter?(ncPlugin, newMode)
        }
    }

    func valueChanged(indexPath: IndexPath, newValue: Int) {
        abort()
    }
}

private extension AudioCurationModesViewModel {
    func refresh() {
		guard
            let plugin = ncPlugin,
            let availableModes = availableModesGetter?(plugin)
        else {
            sections = [SettingSection]()
            viewController?.update()
            return
        }

        let currentMode = currentModeGetter?(plugin) ?? .off
        checkmarkIndexPath = nil

        var newSections = [SettingSection]()
        var newModesInSections = [[GaiaDeviceAudioCurationModeInfo]]()
        var modesSectionTitle: String? = nil

        if let playbackMode = availableModes.first(where: { info in info.mode == .voidOrUnchanged }) {
            // Add Honor playback as an option
            let row = SettingRow.title(title: playbackMode.action.userVisibleDescription(), tapable: true)
            newSections.append(SettingSection(title: nil, rows: [row]))
            newModesInSections.append([playbackMode])
            modesSectionTitle = String(localized: "Automatically change mode to", comment: "ANC Modes section header")

            if currentMode == .voidOrUnchanged {
                checkmarkIndexPath = IndexPath(row: 0, section: 0)
            }
        }

        var rows = [SettingRow]()
        var modeRows = [GaiaDeviceAudioCurationModeInfo]()
        for modeInfo in availableModes {
            switch modeInfo.mode {
            case .numberedMode(let modeNumber):
                let row = SettingRow.title(title: "\(modeNumber): " + modeInfo.action.userVisibleDescription(), tapable: true)
                rows.append(row)
                modeRows.append(modeInfo)

                if currentMode == modeInfo.mode {
                    checkmarkIndexPath = IndexPath(row: modeRows.count - 1, section: newModesInSections.count)
                }
            default:
                break
            }
        }

        if let offMode = availableModes.first(where: { info in info.mode == .off }) {
            // Add Off as an option
            let row = SettingRow.title(title: offMode.action.userVisibleDescription(), tapable: true)
            rows.append(row)
            modeRows.append(offMode)

            if currentMode == .off {
                checkmarkIndexPath = IndexPath(row: modeRows.count - 1, section: newModesInSections.count)
            }
        }

        newSections.append(SettingSection(title: modesSectionTitle, rows: rows))
        newModesInSections.append(modeRows)

        modesInSections = newModesInSections
        sections = newSections

        if checkmarkIndexPath == nil {
            checkmarkIndexPath = IndexPath(row: 0, section: 0)
        }

        viewController?.update()
    }
}

private extension AudioCurationModesViewModel {
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

    func noiseCancellationNotificationHandler(_ notification: GaiaDeviceAudioCurationPluginNotification) {
        guard notification.payload.id == device?.id else {
            return
        }

        if notification.reason == .toggleConfigChanged || notification.reason == .scenarioConfigChanged {
        	refresh()
        }
    }
}
