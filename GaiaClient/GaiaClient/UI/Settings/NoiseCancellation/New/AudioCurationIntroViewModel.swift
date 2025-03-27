//
//  © 2021 - 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation
import GaiaCore
import GaiaBase
import PluginBase

extension GaiaDeviceAudioCurationAutoTransparencyReleaseTime {
    func userVisibleDescription() -> String {
        switch self {
        case .known(id: let id):
            switch id {
            case .noActionOnRelease:
                return String(localized: "No Action", comment: "Release time description")
            case .shortRelease:
                return String(localized: "Short", comment: "Release time description")
            case .normalRelease:
                return String(localized: "Normal", comment: "Release time description")
            case .longRelease:
                return String(localized: "Long", comment: "Release time description")
            }
        case .unknown(id: let id):
            return String(localized: "\(id) seconds", comment: "Release time description")
        }
    }
}

class AudioCurationIntroViewModel: GaiaTableViewModelProtocol {
    private enum ACSectionID: SectionIdentifier {
		case enabled
        case toggles
        case otherBehaviours
        case autoTransparency
        case noiseID
    }

    private weak var viewController: GaiaViewControllerProtocol?
    private let coordinator: AppCoordinator
    private let gaiaManager: GaiaManager
    private let notificationCenter: NotificationCenter

    private(set) weak var ncPlugin: GaiaDeviceAudioCurationPluginProtocol?

    private(set) var title: String

    private(set) var sections = [SettingSection] ()
    private var scenariosAvailable = [GaiaDeviceAudioCurationScenario]()

    private(set) var checkmarkIndexPath: IndexPath?

    private var device: GaiaDeviceProtocol? {
        didSet {
            ncPlugin = device?.plugin(featureID: .audioCuration) as? GaiaDeviceAudioCurationPluginProtocol
            refresh()
        }
    }

    private var observerTokens = [ObserverToken]()

    public var isDemoModePermitted: Bool { return ncPlugin?.demoModeAvailable ?? false }

    required init(viewController: GaiaViewControllerProtocol, coordinator: AppCoordinator, gaiaManager: GaiaManager, notificationCenter: NotificationCenter) {
        self.viewController = viewController
        self.coordinator = coordinator
        self.gaiaManager = gaiaManager
        self.notificationCenter = notificationCenter

        self.title = String(localized: "Audio Curation", comment: "Settings Screen Title")

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

extension AudioCurationIntroViewModel {
    func enterDemoMode() {
        if let device {
            coordinator.showANCDemoModeRequested(device: device)
        }
    }

    func toggledSwitch(indexPath: IndexPath) {
        guard
            let ncPlugin = ncPlugin,
            indexPath.section < sections.count,
            let sectionID = sections[indexPath.section].identifier as? ACSectionID
        else {
            return
        }

        switch sectionID {
        case .enabled:
            ncPlugin.setEnabledState(!ncPlugin.enabled)
        case .autoTransparency:
            ncPlugin.setAutoTransparencyEnabled(!ncPlugin.autoTransparencyEnabled)
        case .noiseID:
            ncPlugin.setNoiseIDState(!ncPlugin.noiseIDState)
        default:
            break
        }
    }


    func valueChanged(indexPath: IndexPath, newValue: Int) {
    }

    func selectedItem(indexPath: IndexPath) {
        guard
            indexPath.section < sections.count,
            let sectionID = sections[indexPath.section].identifier as? ACSectionID
        else {
            return
        }

        switch sectionID {
        case .toggles:
            let toggleNumber = indexPath.row + 1
            let title = String(localized: "Toggle \(toggleNumber)", comment: "Audio Curation Toggle")
            coordinator.showV2ANCModes(device: device!,
                                       title: title,
                                       availableModesGetter: { (plugin: GaiaDeviceAudioCurationPluginProtocol) in
                                        return plugin.availableModesForToggle(toggleNumber)
                                       },
                                       currentModeGetter: { (plugin: GaiaDeviceAudioCurationPluginProtocol) in
                                        return plugin.modeForToggle(toggleNumber)
                                       },
                                       currentModeSetter: { (plugin: GaiaDeviceAudioCurationPluginProtocol, mode: GaiaDeviceAudioCurationMode) in
                                        plugin.setModeForToggle(toggleNumber, mode: mode)
                                       })
            
            
        case .otherBehaviours:
            let scenario = scenariosAvailable[indexPath.row]
            
            var title = ""
            switch scenario {
            case .playback:
                title = String(localized: "Playback Behaviour ", comment: "Mode screen title")
            case .idle:
                title = String(localized: "Idle Behaviour ", comment: "Mode screen title")
            case .voiceCall:
                title = String(localized: "Call Behaviour ", comment: "Mode screen title")
            case .digitalAssistant:
                title = String(localized: "Assistant Behaviour ", comment: "Mode screen title")
            case .leStereoRecording:
                title = String(localized: "Voice Recording Behaviour ", comment: "Mode screen title")
            default:
                break
            }
            
            coordinator.showV2ANCModes(device: device!,
                                       title: title,
                                       availableModesGetter: { (plugin: GaiaDeviceAudioCurationPluginProtocol) in
                return plugin.availableModesForScenario(scenario)
            },
                                       currentModeGetter: { (plugin: GaiaDeviceAudioCurationPluginProtocol) in
                return plugin.currentModeForScenario(scenario)
            },
                                       currentModeSetter: { (plugin: GaiaDeviceAudioCurationPluginProtocol, mode: GaiaDeviceAudioCurationMode) in
                plugin.setCurrentModeForScenario(scenario, mode: mode)
            })
        case .autoTransparency:
            coordinator.showANCGeneralOptions(device: device!,
                                              title: String(localized: "Release Time", comment: "VC Title"),
                                              availableOptionsGetter: { plugin in
                return self.autoTransparencyReleaseTimeOptions().map({ $0.userVisibleDescription() })
            },
                                              currentOptionGetter: { plugin in
                let options = self.autoTransparencyReleaseTimeOptions()
                if
                    let current = plugin.autoTransparencyReleaseTime,
                    let index = options.firstIndex(of: current)  {
                    return index
                }

                return 0
            },
                                              currentOptionSetter: { plugin, newOption in
                let options = self.autoTransparencyReleaseTimeOptions()
                plugin.setAutoTransparencyReleaseTime(options[newOption])
            })


        default:
            break
        }
    }
}

private extension AudioCurationIntroViewModel {
    func autoTransparencyReleaseTimeOptions() -> [GaiaDeviceAudioCurationAutoTransparencyReleaseTime] {
        guard
            let ncPlugin = ncPlugin,
            let current = ncPlugin.autoTransparencyReleaseTime
        else {
            return []
        }

        var options = GaiaDeviceAudioCurationAutoTransparencyReleaseTime.allKnown()

        if !options.contains(current) {
            options.append(current)
        }
        return options
    }

    func subtitleForScenario(_ scenario: GaiaDeviceAudioCurationScenario) -> String {
        guard let ncPlugin = ncPlugin else {
            return ""
        }

        let mode = ncPlugin.currentModeForScenario(scenario)
        let description = modeDescription(mode: mode,
                                          modeInfoList: ncPlugin.availableModesForScenario(scenario)) ?? "Unknown"
        let subtitle = mode == .voidOrUnchanged ?
            description : // Already Localized
            String(localized: "Change to:", comment: "ANC Mode description") + " " + description
        return subtitle
    }

    func refresh() {
        guard let ncPlugin = ncPlugin else {
            return
        }
        
        sections.removeAll()
        
        let enabledRow = SettingRow.titleAndSwitch(title: String(localized: "Active Noise Cancellation", comment: "Enabled Option"),
                                                   switchOn: ncPlugin.enabled)
        let firstSection = SettingSection(identifier: ACSectionID.enabled,
                                          title: nil,
                                          rows: [enabledRow])
        sections.append(firstSection)
        
        var toggleRows = [SettingRow]()

        if ncPlugin.numberOfToggles > 0 {

            for toggle in 1...ncPlugin.numberOfToggles {
                let toggleDescription = modeDescription(mode: ncPlugin.modeForToggle(toggle),
                                                        modeInfoList: ncPlugin.availableModesForToggle(toggle)) ?? String(localized:"Unknown", comment: "Unknown")
                let title = String(localized: "Toggle \(toggle)", comment: "Section Title")
                let toggleRow = SettingRow.titleAndSubtitle(title: title,
                                                            subtitle: toggleDescription,
                                                            tapable: true)
                toggleRows.append(toggleRow)
            }

        }

        sections.append(SettingSection(identifier: ACSectionID.toggles,
                                       title: String(localized: "Toggle Behaviour", comment: "ANC Section Title"),
                                       rows: toggleRows))

        var otherRows = [SettingRow]()
        scenariosAvailable.removeAll()

        // Playback behaviour
        if ncPlugin.scenarioSupported(.playback) {
            let row = SettingRow.titleAndSubtitle(title: String(localized: "During playback", comment: "ANC mode row title"),
                                                  subtitle: subtitleForScenario(.playback),
                                                  tapable: true)
            otherRows.append(row)
            scenariosAvailable.append(.playback)
        }

        // Idle behaviour
        if ncPlugin.scenarioSupported(.idle) {
            let row = SettingRow.titleAndSubtitle(title: String(localized: "During idle", comment: "ANC mode row title"),
                                                  subtitle: subtitleForScenario(.idle),
                                                  tapable: true)
            otherRows.append(row)
            scenariosAvailable.append(.idle)
        }

        // Calls
        if ncPlugin.scenarioSupported(.voiceCall) {
            let row = SettingRow.titleAndSubtitle(title: String(localized: "During calls", comment: "ANC mode row title"),
                                                      subtitle: subtitleForScenario(.voiceCall),
                                                      tapable: true)
            otherRows.append(row)
            scenariosAvailable.append(.voiceCall)
        }

        // Assistant
        if ncPlugin.scenarioSupported(.digitalAssistant) {
            let row = SettingRow.titleAndSubtitle(title: String(localized: "During assistant", comment: "ANC mode row title"),
                                                      subtitle: subtitleForScenario(.digitalAssistant),
                                                      tapable: true)
            otherRows.append(row)
            scenariosAvailable.append(.digitalAssistant)
        }

        // LE Stereo
        if ncPlugin.scenarioSupported(.leStereoRecording) {
            let row = SettingRow.titleAndSubtitle(title: String(localized: "During Voice Recording", comment: "ANC mode row title"),
                                                      subtitle: subtitleForScenario(.leStereoRecording),
                                                      tapable: true)
            otherRows.append(row)
            scenariosAvailable.append(.leStereoRecording)
        }

        sections.append(SettingSection(identifier: ACSectionID.otherBehaviours,
                                       title: String(localized: "Other Behaviours", comment: "ANC Section Title"),
                                       rows: otherRows))

        // Auto Transparency
        
        if ncPlugin.autoTransparencySupported {
            let atEnabledRow = SettingRow.titleAndSwitch(title: String(localized: "Auto Transparency", comment: "Enabled Option"),
                                                         switchOn: ncPlugin.autoTransparencyEnabled)
            let timeRow = SettingRow.titleAndSubtitle(title: String(localized: "Release Time", comment: "ANC mode row title"),
                                                      subtitle: ncPlugin.autoTransparencyReleaseTime?.userVisibleDescription() ?? "Unknown",
                                                      tapable: true)
            let atSection = SettingSection(identifier: ACSectionID.autoTransparency,
                                           title: String(localized: "Auto Transparency", comment: "ANC Section Title"),
                                           rows: [atEnabledRow, timeRow])
            sections.append(atSection)
        }

        // Noise ID

        if ncPlugin.noiseIDSupported {
            let row = SettingRow.titleAndSwitch(title: String(localized: "Noise ID", comment: "Enabled Option"),
                                                switchOn: ncPlugin.noiseIDState)
            let section = SettingSection(identifier: ACSectionID.noiseID,
                                         title: String(localized: "Noise ID", comment: "ANC Section Title"),
                                         rows: [row])
            sections.append(section)
        }
        viewController?.update()
    }

    func modeDescription(mode: GaiaDeviceAudioCurationMode, modeInfoList: [GaiaDeviceAudioCurationModeInfo]) -> String? {
        return modeInfoList.first(where: { modeInfo in modeInfo.mode == mode })?.action.userVisibleDescription()
    }
}

private extension AudioCurationIntroViewModel {
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
        guard
            notification.payload.id == device?.id,
            notification.reason != .gainChanged
        else {
            return
        }

        if notification.reason == .enabledChanged ||
            notification.reason == .scenarioConfigChanged ||
            notification.reason == .toggleConfigChanged ||
            notification.reason == .autoTransparencyReleaseTimeChanged ||
            notification.reason == .autoTransparencyStateChanged ||
            notification.reason == .noiseIDStateChanged {

            refresh()
        }
    }
}
