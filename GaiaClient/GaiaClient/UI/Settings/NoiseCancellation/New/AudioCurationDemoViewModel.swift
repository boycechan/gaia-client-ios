//
//  © 2021 - 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation
import GaiaCore
import GaiaBase
import PluginBase

extension GaiaDeviceAudioCurationNoiseIDCategory {
    func userVisibleDescription() -> String {
        switch self {
        case .known(id: let id):
            switch id {
            case .categoryA:
                return String(localized: "Category A", comment: "Noise ID Category")
            case .categoryB:
                return String(localized: "Category B", comment: "Noise ID Category")
            case .categoryNotApplicable:
                return String(localized: "Category NA", comment: "Noise ID Category")
            }
        case .unknown(id: let id):
            return String(localized: "Unrecognized Category: \(id)", comment: "Noise ID Category")
        }
    }
}

class AudioCurationDemoViewModel: GaiaDeviceViewModelProtocol {
    typealias ModeInfo = GaiaDeviceAudioCurationModeInfo

    private weak var viewController: GaiaViewControllerProtocol?
    private let coordinator: AppCoordinator
    private let gaiaManager: GaiaManager
    private let notificationCenter: NotificationCenter

    private(set) weak var ancPlugin: GaiaDeviceAudioCurationPluginProtocol?

    private(set) var title: String

    private var device: GaiaDeviceProtocol? {
        didSet {
            ancPlugin = device?.plugin(featureID: .audioCuration) as? GaiaDeviceAudioCurationPluginProtocol
            if !(ancPlugin?.demoModeActive ?? false) {
                ancPlugin?.enterDemoMode()
            }
            refresh()
        }
    }

    var isEarbud: Bool {
        device?.deviceType == .earbud
    }

    var isEnabled: Bool {
        ancPlugin?.enabled ?? false
    }

    var availableDemoModes: [ModeInfo] {
        ancPlugin?.availableDemoModeModes() ?? [ModeInfo]()
    }

    var demoModeModeIndex: Int {
        guard let ancPlugin = ancPlugin else {
            return -1
        }

        if let index = availableDemoModes.firstIndex(where: { $0.mode == ancPlugin.demoModeMode() }) {
			return index
        } else {
            return -1
        }
    }

    var leakthroughGain: Int {
        if canSetLeakthroughGain {
            return Int(ancPlugin?.feedForwardGainsForCurrentMode.leftValues.first?.gain ?? 0)
        } else {
            return 0
        }
    }

    var adaptationIsActive: Bool {
        return ancPlugin?.adaptationIsActive ?? false
    }

    var feedForwardGains: GainContainer {
        ancPlugin?.feedForwardGainsForCurrentMode ?? GainContainer(instances: [])
    }

    private func infoForMode(_ mode: GaiaDeviceAudioCurationMode) -> GaiaDeviceAudioCurationModeInfo? {
        return availableDemoModes.first(where: { $0.mode == mode })
    }

    private func featuresForCurrentDemoMode() -> AudioCurationModeSupportedFeatures {
        guard
            let ancPlugin = ancPlugin,
            let modeInfo = infoForMode(ancPlugin.demoModeMode()),
            ancPlugin.enabled
        else {
            return []
        }
        return modeInfo.supportedFeatures
    }

    var canSelectDemoModeMode: Bool {
        guard let ancPlugin = ancPlugin else {
            return false
        }
        return ancPlugin.enabled && ancPlugin.numberOfFilterModes > 0
    }

    var canSetLeakthroughGain: Bool {
        return featuresForCurrentDemoMode().contains(.changeLeakthroughGain)
    }

    var showSteppedLeakthroughGainUI: Bool {
        guard let ancPlugin = ancPlugin else {
            return false
        }

        return canSetLeakthroughGain && ancPlugin.supportsAdaptiveTransparency
    }

    public var leakthroughSteppedGainLevel: Int {
        guard let ancPlugin = ancPlugin else {
            return 0
        }
        return ancPlugin.leakthroughSteppedGainLevel
    }

    public var leakthroughSteppedGainDB: Int {
        guard let ancPlugin = ancPlugin else {
            return 0
        }
        return ancPlugin.leakthroughSteppedGainDB
    }

    public var leakthroughSteppedGainNumberOfSteps: Int {
        guard let ancPlugin = ancPlugin else {
            return 0
        }
        return ancPlugin.leakthroughSteppedGainNumberOfSteps
    }

    var wndDetectionSupported: Bool {
        guard let ancPlugin = ancPlugin else {
            return false
        }

        return ancPlugin.windNoiseReductionSupported
    }

    var balanceAdjustmentSupported: Bool {
        guard let ancPlugin = ancPlugin else {
            return false
        }

        return canSetLeakthroughGain && ancPlugin.supportsAdaptiveTransparency
    }

    var wndDetectionEnabled: Bool {
        guard let ancPlugin = ancPlugin else {
            return false
        }

        return ancPlugin.windNoiseReductionSupported && ancPlugin.windNoiseReductionEnabled
    }

    func wndDetected() ->  (left: Bool, right: Bool) {
        guard
            let ancPlugin = ancPlugin,
            ancPlugin.windNoiseReductionSupported,
            ancPlugin.windNoiseReductionEnabled
        else {
            return (false, false)
        }

        return (ancPlugin.windNoiseReductionActiveLeft, ancPlugin.windNoiseReductionActiveRight)
    }

    var balance: Float {
        guard let ancPlugin = ancPlugin else {
            return 0.0
        }
        return Float(ancPlugin.balance)
    }

    var canChangeAdaptation: Bool {
        return featuresForCurrentDemoMode().contains(.changeAdaptiveState)
    }

    var feedForwardGainActive: Bool {
        return featuresForCurrentDemoMode().contains(.updatesFeedForwardGain)
    }

    var howlingDetectionSupported: Bool {
        return ancPlugin?.howlingDetectionSupported ?? false
    }

    var howlingDetectionAvailableForCurrentMode: Bool {
        return featuresForCurrentDemoMode().contains(.antiHowlingControl)
    }

    var howlingDetectionState: Bool {
        return ancPlugin?.howlingDetectionState ?? false
    }

    var howlingDetectionFeedbackGains: GainContainer {
        ancPlugin?.howlingDetectionFeedbackGains ?? GainContainer(instances: [])
    }

    var howlingControlGainReductionIndicationSupported: Bool {
        return ancPlugin?.HCGRIndicationSupported ?? false
    }

    func howlingControlGainReductionActive() ->  (left: Bool, right: Bool) {
        guard
            let ancPlugin = ancPlugin,
            ancPlugin.HCGRIndicationSupported
        else {
            return (false, false)
        }

        return (ancPlugin.HCGRGainReductionActiveLeft, ancPlugin.HCGRGainReductionActiveRight)
    }

    var noiseIDSupported: Bool {
        return ancPlugin?.noiseIDSupported ?? false
    }

    var noiseIDState: Bool {
        return ancPlugin?.noiseIDState ?? false
    }

    var noiseIDCategoryDescription: String {
        return ancPlugin?.noiseIDCategory?.userVisibleDescription() ?? ""
    }

    var AAHSupported: Bool {
        return ancPlugin?.AAHSupported ?? false
    }

    var AAHState: Bool {
        return ancPlugin?.AAHState ?? false
    }

    var AAHGainReductionIndicationSupported: Bool {
        return ancPlugin?.AAHGainReductionIndicationSupported ?? false
    }

    func AAHGainReductionActive() ->  (left: Bool, right: Bool) {
        guard
            let ancPlugin = ancPlugin,
            ancPlugin.AAHSupported,
            ancPlugin.AAHGainReductionIndicationSupported
        else {
            return (false, false)
        }

        return (ancPlugin.AAHGainReductionActiveLeft, ancPlugin.AAHGainReductionActiveRight)
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

        self.title = String(localized: "Audio Curation Demo", comment: "Settings Screen Title")

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
        ancPlugin?.enterDemoMode()
        refresh()
    }

    func deactivate() {
        ancPlugin?.exitDemoMode()
    }
}

extension AudioCurationDemoViewModel {
    func setEnabledState(isOn: Bool) {
        guard isOn != isEnabled else {
            return
        }

        ancPlugin?.setEnabledState(isOn)
    }

    func selectDemoModeMode(index: Int) {
        let modes = availableDemoModes

        guard index < modes.count else {
            return
        }

        let mode = modes[index].mode
        ancPlugin?.setDemoModeMode(mode)
    }

    func setNonSteppedLeakthroughGain(_ newValue: Int) {
        ancPlugin?.setGain(newValue)
    }

    func setSteppedLeakthroughGain(_ newValue: Int) {
        ancPlugin?.setLeakthroughSteppedGainLevel(newValue)
    }

    func setAdaptationState(isOn: Bool) {
        if isOn {
            ancPlugin?.startAdaptation()
        } else {
            ancPlugin?.stopAdaptation()
        }
    }

    func setNewBalance(_ newValue: Float) {
        ancPlugin?.setBalance(Double(newValue))
    }

    func setNewWNDEnabledState(isOn: Bool) {
        guard isOn != wndDetectionEnabled else {
            return
        }

        ancPlugin?.setWindNoiseReductionEnabled(isOn)
    }

    func setHowlingDetectionState(isOn: Bool) {
        ancPlugin?.setHowlingDetectionState(isOn)
    }

    func setNewAAHEnabledState(isOn: Bool) {
        guard isOn != AAHState else {
            return
        }

        ancPlugin?.setAAHState(isOn)
    }
}

private extension AudioCurationDemoViewModel {
    func refresh() {
        viewController?.update()
    }
}

private extension AudioCurationDemoViewModel {
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
            let vc = viewController as? AudioCurationDemoViewController,
            notification.payload.id == device?.id
        else {
            return
        }

        switch notification.reason {
        case .leakthoughSteppedGainConfigChanged:
            vc.updateOnSteppedGainConfigChanged()
        case .gainChanged:
            vc.updateOnGainState()
        case .adaptationStateChanged:
            vc.updateOnAdaptationState()
        case .wndStatusChanged:
            vc.updateOnWNDStateChanged()
        case .wndDetectionStateChanged:
            vc.updateOnWNDDetectionChanged()
        case .balanceChanged:
            vc.updateOnBalanceChanged()
        case .howlingDetectionStateChanged:
            vc.updateOnHowlingDetectionState()
        case .howlingDetectionGainChanged:
            vc.updateOnHowlingDetectionGainState()
        case .howlingDetectionGainReductionStateChanged:
            vc.updateOnHCGainReductionChanged()
        case .noiseIDStateChanged, .noiseIDCategoryChanged:
            vc.updateOnNoiseID()
        case .AAHStateChanged:
            vc.updateOnAAHStateChanged()
        case .AAHGainReductionStateChanged:
            vc.updateOnAAHGainReductionChanged()
        default:
            refresh()
        }
    }
}

