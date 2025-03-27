//
//  © 2020 - 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation
import GaiaBase
import PluginBase
import GaiaLogger
import Packets

internal struct GaiaDeviceAudioCurationModeByteCodes {
    static let off: UInt8 = 0x00
    static let modeRange: ClosedRange<UInt8> = 0x01...0x64
    static let voidOrUnchanged: UInt8 = 0xff
}

internal extension GaiaDeviceAudioCurationMode {
    init(byteValue: UInt8) {
        switch byteValue {
        case GaiaDeviceAudioCurationModeByteCodes.off:
            self = .off
        case GaiaDeviceAudioCurationModeByteCodes.modeRange:
            self = .numberedMode(mode: byteValue)
        case GaiaDeviceAudioCurationModeByteCodes.voidOrUnchanged:
            self = .voidOrUnchanged
        default:
            self = .unknown
        }
    }

    func byteValue() -> UInt8? {
        switch self {
        case .off:
            return GaiaDeviceAudioCurationModeByteCodes.off
        case .numberedMode(let mode):
            return mode
        case .voidOrUnchanged:
            return GaiaDeviceAudioCurationModeByteCodes.voidOrUnchanged
        case .unknown:
            return nil
        }
    }
}

internal extension AudioCurationModeType {
    init(byteValue: UInt8) {
        switch byteValue {
        case 0x01:
            self = .staticANC
        case 0x02:
            self = .leakthroughANC
        case 0x03:
            self = .adaptiveANC
        case 0x04:
            self = .adaptiveLeakthroughANC
        default:
            self = .unknown
        }
    }
}

public class GaiaDeviceAudioCurationPlugin: GaiaDeviceAudioCurationPluginProtocol, GaiaNotificationSender {
    internal enum Commands: UInt16 {
        case getACState = 0
        case setACState = 1
        case getModesCount = 2
        case getCurrentMode = 3
        case setCurrentMode = 4
        case getGain = 5
        case setGain = 6
        case getToggleConfigCount = 7
        case getToggleConfig = 8
        case setToggleConfig = 9
        case getScenarioConfig = 10
        case setScenarioConfig = 11
        case getDemoModeSupport = 12
        case getDemoModeState = 13
        case setDemoModeState = 14
        case getAdaptationControlState = 15
        case setAdaptationControlState = 16

        // V2/Adaptive Transparency
        case getLeakthroughSteppedGaiaInfo = 17
        case getLeakthroughSteppedGaiaStep = 18
        case setLeakthroughSteppedGaiaStep = 19
        case getBalance = 20
        case setBalance = 21
        case getWNDSupport = 22
        case getWNDState = 23
        case setWNDState = 24

        // Auto transparency
        case getAutoTransparencySupport = 25
        case getAutoTransparencyState = 26
        case setAutoTransparencyState = 27
        case getAutoTransparencyReleaseTime = 28
        case setAutoTransparencyReleaseTime = 29

        // Howling Detection
        case getHowlingDetectionSupport = 30
        case getHowlingDetectionState = 31
        case setHowlingDetectionState = 32
        case getHowlingDetectionFBGain = 33

        // Noise ID
        case getNoiseIDSupport = 34
        case getNoiseIDState = 35
        case setNoiseIDState = 36
        case getNoiseIDCategory = 37

    	// Adverse Acoustic Handler
        case getAdverseAcousticHandlerSupport = 38
        case getAdverseAcousticHandlerState = 39
        case setAdverseAcousticHandlerState = 40
        
        
        case getANCFilterTopology = 41
    }

    internal enum Notifications: UInt8 {
        case stateChanged = 0
        case currentModeChanged = 1
        case gainChanged = 2
        case toggleConfigChanged = 3
        case scenarioConfigChanged = 4
        case demoModeStateChanged = 5
        case adaptationStateChanged = 6

        // V2/Adaptive Transparency
        case leakthroughSteppedGainInfoChanged = 7
        case leakthroughSteppedGainStepChanged = 8
        case balanceChanged = 9
        case wndStateChanged = 10
        case wndDetectionStateChanged = 11

        // Auto transparency
        case autoTransparencyStateChanged = 12
        case autoTransparencyReleaseTimeChanged = 13

        // Howling Detection
        case howlingDetectionStateChanged = 14
        case howlingDetectionFBGainChanged = 15

        // NoiseID
        case noiseIDStateChanged = 16
        case noiseIDCategoryChanged = 17

        // Adverse Acoustic Handler
        case adverseAcousticHandlerStateChanged = 18

        case adverseAcousticHandlerGainReductionStateChanged = 19
        case howlingControlGainReductionStateChanged = 20
    }

    internal struct StateTypeByteCodes {
        static let anc: UInt8 = 0x01
    }

    internal enum StateTypes{
        case anc
        case unknown

        init(byteValue: UInt8) {
            switch byteValue {
            case StateTypeByteCodes.anc:
                self = .anc
            default:
                self = .unknown
            }
        }

        func byteValue() -> UInt8? {
            switch self {
            case .anc:
                return StateTypeByteCodes.anc
            default:
                return nil
            }
        }
    }
    
    internal struct FilterTopologyByteCodes {
        static let single: UInt8 = 0x00
        static let parallel: UInt8 = 0x01
        static let dual: UInt8 = 0x02
    }
    
    internal enum FilterTopology {
        case single
        case parallel
        case dual
        
        init(byteValue: UInt8) {
            switch byteValue {
            case FilterTopologyByteCodes.single:
                self = .single
            case FilterTopologyByteCodes.parallel:
                self = .parallel
            case FilterTopologyByteCodes.dual:
                self = .dual
            default:
                self = .single
            }
        }
    }

    internal class ModeContainer {
        var toggleOptions = [GaiaDeviceAudioCurationMode]()
        var scenarioModes = [GaiaDeviceAudioCurationScenario : GaiaDeviceAudioCurationMode]()
        var filterModes = [GaiaDeviceAudioCurationModeInfo]()
    }

    internal class OtherState {
        var inDemoMode: Bool = false
        var adaptationIsEnabled: Bool = false
        var demoModeAvailable: Bool = false
    }

    internal class AdaptiveTransparencyState {
        var isSupported: Bool = false
        var leakthroughGainSteps: Int = 7
        var leakthroughGainMinStepDb: Int = -6
        var leakthroughGainStepSize: Int = 2
        var leakthroughGainLevel: Int = 4
        var balance: Double = 0.5
        var windNoiseReductionSupported: Bool = false
        var windNoiseReductionEnabled: Bool = false
        var windNoiseReductionActiveLeft: Bool = false
        var windNoiseReductionActiveRight: Bool = false
    }

    internal class AutoTransparencyState {
        var isSupported: Bool = false
        var isEnabled: Bool = false
        var releaseTime: GaiaDeviceAudioCurationAutoTransparencyReleaseTime? = nil
    }

    internal class HowlingDetectionState {
        var isSupported = false
        var isEnabled = false
        var gains = GainContainer(instances: [])

        var gainReductionIndicationSupported: Bool = false
        var gainReductionActiveLeft: Bool = false
        var gainReductionActiveRight: Bool = false
    }

    internal class NoiseIDState {
        var isSupported = false
        var isEnabled = false
        var category: GaiaDeviceAudioCurationNoiseIDCategory? = nil
    }

    internal class AAHState {
        var isSupported = false
        var isEnabled = false

        var gainReductionIndicationSupported: Bool = false
        var gainReductionActiveLeft: Bool = false
        var gainReductionActiveRight: Bool = false
    }

    internal class InternalState {
        var modes = ModeContainer()
        var feedForwardGains = GainContainer(instances: [])
        var state = OtherState()
        var adState = AdaptiveTransparencyState()
        var autoTransparencyState = AutoTransparencyState()
        var howlingDetectionState = HowlingDetectionState()
        var noiseIDState = NoiseIDState()
        var aahState = AAHState()
        var filterTopology = FilterTopology.single
    }

    // MARK: Private ivars

    internal let devicePluginVersion: UInt8
    internal private(set) weak var device: GaiaDeviceIdentifierProtocol?
    internal let connection: GaiaDeviceConnectionProtocol
    internal let notificationCenter : NotificationCenter

    // V2
    internal let state = InternalState()

    // MARK: Public ivars
    public static let featureID: GaiaDeviceQCPluginFeatureID = .audioCuration

    public var adaptationIsActive: Bool {
        state.state.adaptationIsEnabled
    }

    public var demoModeAvailable: Bool {
        state.state.demoModeAvailable
    }

    public var demoModeActive: Bool {
        state.state.inDemoMode
    }

    public var supportsAdaptiveTransparency: Bool {
        state.adState.isSupported
    }

    public var leakthroughSteppedGainNumberOfSteps: Int  {
        state.adState.leakthroughGainSteps
    }

    public var leakthroughSteppedGainLevel: Int {
        state.adState.leakthroughGainLevel
    }

    public var leakthroughSteppedGainDB: Int {
        state.adState.leakthroughGainMinStepDb + ((state.adState.leakthroughGainLevel - 1) * state.adState.leakthroughGainStepSize)
    }

    public var balance: Double  {
        state.adState.balance
    }

    public var windNoiseReductionSupported: Bool  {
        state.adState.windNoiseReductionSupported
    }

    public var windNoiseReductionEnabled: Bool  {
        state.adState.windNoiseReductionEnabled
    }

    public var windNoiseReductionActiveLeft: Bool  {
        state.adState.windNoiseReductionActiveLeft
    }

    public var windNoiseReductionActiveRight: Bool  {
        state.adState.windNoiseReductionActiveRight
    }

    public var autoTransparencySupported: Bool {
        state.autoTransparencyState.isSupported
    }

    public var autoTransparencyEnabled: Bool {
        state.autoTransparencyState.isEnabled
    }

    public var autoTransparencyReleaseTime: GaiaDeviceAudioCurationAutoTransparencyReleaseTime? {
        state.autoTransparencyState.releaseTime
    }

    public var howlingDetectionSupported: Bool {
        state.howlingDetectionState.isSupported
    }

    public var howlingDetectionState: Bool {
        state.howlingDetectionState.isEnabled
    }

    public var howlingDetectionFeedbackGains: GainContainer {
        state.howlingDetectionState.gains
    }

    public var HCGRIndicationSupported: Bool {
        state.howlingDetectionState.gainReductionIndicationSupported
    }

    public var HCGRGainReductionActiveLeft: Bool {
        state.howlingDetectionState.gainReductionActiveLeft
    }

    public var HCGRGainReductionActiveRight: Bool {
        state.howlingDetectionState.gainReductionActiveRight
    }

    public var noiseIDSupported: Bool {
        state.noiseIDState.isSupported
    }

    public var noiseIDState: Bool {
        state.noiseIDState.isEnabled
    }

    public var noiseIDCategory: GaiaDeviceAudioCurationNoiseIDCategory? {
        state.noiseIDState.category
    }

    public var AAHSupported: Bool {
        state.aahState.isSupported
    }

    public var AAHState: Bool {
        state.aahState.isEnabled
    }

    public var AAHGainReductionIndicationSupported: Bool {
        state.aahState.gainReductionIndicationSupported
    }

    public var AAHGainReductionActiveLeft: Bool {
        state.aahState.gainReductionActiveLeft
    }

    public var AAHGainReductionActiveRight: Bool {
        state.aahState.gainReductionActiveRight
    }

    private func useLeakthroughModeGain() -> Bool {
        guard currentFilterMode > 0 else {
            return false
        }
        let currentModeFeatures = state.modes.filterModes[currentFilterMode - 1].supportedFeatures
        return currentModeFeatures.contains(.changeLeakthroughGain)
    }

    public var feedForwardGainsForCurrentMode: GainContainer {
        guard currentFilterMode > 0 else {
            return GainContainer(instances: [])
        }

        return state.feedForwardGains
    }

    public var leakthroughGain: Int {
        if let instance0 = state.feedForwardGains.instances.first {
            return instance0.left.gain > 0 ? Int(instance0.left.gain) : Int(instance0.right.gain)
        } else {
            return 0
        }
    }

    public internal(set) var enabled: Bool = false

    public internal(set) var currentFilterMode: Int = 0 // Always 1 to numberOfFilterModes previously was 0 to 9.
    public internal(set) var numberOfFilterModes: Int = 0
    public internal(set) var numberOfToggles: Int = 0

    // MARK: init/deinit
    public required init(version: UInt8,
                         device: GaiaDeviceIdentifierProtocol,
                         connection: GaiaDeviceConnectionProtocol,
                         notificationCenter: NotificationCenter) {
        self.devicePluginVersion = version
        self.device = device
        self.connection = connection
        self.notificationCenter = notificationCenter
    }

    // MARK: Public Methods
    public func startPlugin() {
        self.state.adState.isSupported = devicePluginVersion >= 2
        
        
        if devicePluginVersion >= 8 {
            getANCFilterTopology()
        } else {
            state.filterTopology = .single
        }

        getCurrentState()
        getNumberOfModes()
        getNumberOfToggles()
        getCurrentMode()
        if self.state.adState.isSupported {
            getSteppedGainState()
            getBalance()
            getWNDSupport()
        } else {
            getGain()
        }

        if devicePluginVersion >= 4 {
            getAutoTransparencySupported()
        } else {
            state.autoTransparencyState.isSupported = false
        }

        if devicePluginVersion >= 5 {
            getHowlingDetectionSupported()
        } else {
            state.howlingDetectionState.isSupported = false
        }

        if devicePluginVersion >= 6 {
            getNoiseIDSupported()
        } else {
            state.noiseIDState.isSupported = false
        }

        if devicePluginVersion >= 7 {
            getAAHSupported()
        } else {
            state.aahState.isSupported = false
        }
        
        

        getDemoModeSupport()

        getScenarioConfig(scenario: .idle)
        getScenarioConfig(scenario: .leStereoRecording)
        getScenarioConfig(scenario: .digitalAssistant)
        getScenarioConfig(scenario: .playback)

        if devicePluginVersion >= 3 {
            getScenarioConfig(scenario: .voiceCall)
        }
    }

    public func stopPlugin() {
    }

    public func handoverDidOccur() {
    }

    public func responseReceived(messageDescription: IncomingMessageDescription) {
        switch messageDescription {
        case .error(let commandCode, let errorCode, _):
            if featureID == .audioCuration {
                if let reason = Gaia.CommandErrorCodes(rawValue: errorCode),
                   let cmd = Commands(rawValue: commandCode) {
                    if reason != .success {
                        LOG(.high, "Received Error: \(reason) for command \(cmd) feature ID: \(featureID)")
                    }
                } else {
                    LOG(.high, "Received Error with unknown reason/command")
                }
            }
        case .notification(let notificationID, let data):
            guard let notification = Notifications(rawValue: notificationID) else {
                LOG(.medium, "ANC Non valid notification id")
                return
            }
            switch notification {
            case .stateChanged:
                processNewANCState(data: data)
            case .currentModeChanged:
                processNewANCModeAndTypeInfo(data: data)
            case .gainChanged:
                processNewGain(data: data)
            case .toggleConfigChanged:
                processNewToggleConfig(data: data)
            case .scenarioConfigChanged:
                processNewScenarioConfig(data: data)
            case .demoModeStateChanged:
                processNewDemoModeState(data: data)
            case .adaptationStateChanged:
                processNewAdaptationState(data: data)
            case .leakthroughSteppedGainInfoChanged:
                processNewLeakthroughSteppedGainInfo(data: data)
            case .leakthroughSteppedGainStepChanged:
                processNewLeakthroughSteppedGainStep(data: data)
            case .balanceChanged:
                processNewBalance(data: data)
            case .wndStateChanged:
                processNewWNDState(data: data)
            case .wndDetectionStateChanged:
                processNewWNDDetectionState(data: data)
            case .autoTransparencyStateChanged:
                processNewAutoTransparencyState(data: data)
            case .autoTransparencyReleaseTimeChanged:
                processNewAutoTransparencyReleaseTime(data: data)
            case .howlingDetectionStateChanged:
                processNewHowlingDetectionState(data: data)
            case .howlingDetectionFBGainChanged:
                processNewHowlingDetectionFBGain(data: data)
            case .howlingControlGainReductionStateChanged:
                processNewHowlingDetectionGainReduction(data: data)
            case .noiseIDStateChanged:
                processNewNoiseIDState(data: data)
            case .noiseIDCategoryChanged:
                processNewNoiseIDCategory(data: data)
            case .adverseAcousticHandlerStateChanged:
                processNewAAHState(data: data)
            case .adverseAcousticHandlerGainReductionStateChanged:
                processNewAAHGainReduction(data: data)
            }
            
        case .response(let commandID, let data):
            guard let command = Commands(rawValue: commandID) else {
                LOG(.medium, "ANC Non valid command id")
                return
            }

            switch command {
            case .getACState:
                processNewANCState(data: data)
            case .getModesCount:
                guard data.count > 0 else {
                    LOG(.medium, "ANC Wrong data length for \(command)")
                    return
                }
                numberOfFilterModes = max(0, Int(data[0]))
                prepareFilterModes()
            case .getCurrentMode:
                processNewANCModeAndTypeInfo(data: data)
            case .getToggleConfigCount:
                guard data.count > 0 else {
                    LOG(.medium, "ANC Wrong data length for \(command)")
                    return
                }
                numberOfToggles = max(0, Int(data[0]))
                prepareToggles()
            case .getGain:
                processNewGain(data: data)
            case .getToggleConfig:
                processNewToggleConfig(data: data)
            case .getScenarioConfig:
                processNewScenarioConfig(data: data)
            case .getDemoModeSupport:
                processNewANCDemoModeSupport(data: data)
            case .getDemoModeState:
                processNewDemoModeState(data: data)
            case .getAdaptationControlState:
                processNewAdaptationState(data: data)
            case .getLeakthroughSteppedGaiaInfo:
                processNewLeakthroughSteppedGainInfo(data: data)
            case .getLeakthroughSteppedGaiaStep:
                processNewLeakthroughSteppedGainStep(data: data)
            case .getBalance:
                processNewBalance(data: data)
            case .getWNDSupport:
                processNewWNDSupport(data: data)
            case .getWNDState:
                processNewWNDState(data: data)
            case .getAutoTransparencySupport:
                processNewAutoTransparencySupported(data: data)
            case .getAutoTransparencyState:
                processNewAutoTransparencyState(data: data)
            case .getAutoTransparencyReleaseTime:
                processNewAutoTransparencyReleaseTime(data: data)
            case .getHowlingDetectionSupport:
                processNewHowlingDetectionSupport(data: data)
            case .getHowlingDetectionState:
                processNewHowlingDetectionState(data: data)
            case .getHowlingDetectionFBGain:
                processNewHowlingDetectionFBGain(data: data)
            case .getNoiseIDSupport:
                processNewNoiseIDSupport(data: data)
            case .getNoiseIDState:
                processNewNoiseIDState(data: data)
            case .getNoiseIDCategory:
                processNewNoiseIDCategory(data: data)
            case .getAdverseAcousticHandlerSupport:
                processNewAAHSupport(data: data)
            case .getAdverseAcousticHandlerState:
                processNewAAHState(data: data)
            case .getANCFilterTopology:
                processNewANCFilterTopology(data: data)
            case .setACState,
                    .setCurrentMode,
                    .setGain,
                    .setAdaptationControlState,
                    .setDemoModeState,
                    .setScenarioConfig,
                    .setToggleConfig,
                    .setLeakthroughSteppedGaiaStep,
                    .setBalance,
                    .setWNDState,
                    .setAutoTransparencyState,
                    .setAutoTransparencyReleaseTime,
                    .setHowlingDetectionState,
                    .setNoiseIDState,
                    .setAdverseAcousticHandlerState:
                break
            }
        default:
            break
        }
    }

    public func didSendData(channel: GaiaDeviceConnectionChannel, error: GaiaError?) {
    }
}

public extension GaiaDeviceAudioCurationPlugin {
    func modeForToggle(_ toggle: Int) -> GaiaDeviceAudioCurationMode {
        assert(toggle > 0 && toggle <= numberOfToggles)

        return state.modes.toggleOptions[toggle - 1]
    }

    func setModeForToggle(_ toggle: Int, mode: GaiaDeviceAudioCurationMode) {
        assert(toggle > 0 && toggle <= numberOfToggles)

        let current = modeForToggle(toggle)
        guard current != mode else {
            return
        }

        if let modeByteValue = mode.byteValue() {
            let message = GaiaV3GATTPacket(featureID: .audioCuration,
                                           commandID: Commands.setToggleConfig.rawValue,
                                           payload: Data([UInt8(toggle), modeByteValue]))
            connection.sendData(channel: .command, payload: message.data, acknowledgementExpected: true)
        }
    }

    func availableModesForToggle(_ toggle: Int) -> [GaiaDeviceAudioCurationModeInfo] {
        var retVal = [GaiaDeviceAudioCurationModeInfo(mode: .off,
                                                      action: actionForMode(.off),
                                                      type: .none,
                                                      supportedFeatures: [])]
        if toggle > 2 {
            retVal.append(GaiaDeviceAudioCurationModeInfo(mode: .voidOrUnchanged,
                                                          action: actionForMode(.voidOrUnchanged, isToggle: true),
                                                          type: .none,
                                                          supportedFeatures: []))
        }

        retVal.append(contentsOf: availableDemoModeModes())
        return retVal
    }

    func scenarioSupported(_ scenario: GaiaDeviceAudioCurationScenario) -> Bool {
        return state.modes.scenarioModes[scenario] != nil
    }

    func currentModeForScenario(_ scenario: GaiaDeviceAudioCurationScenario) -> GaiaDeviceAudioCurationMode {
        guard let result = state.modes.scenarioModes[scenario] else {
            return .unknown
        }
        return result
    }

    func setCurrentModeForScenario(_ scenario: GaiaDeviceAudioCurationScenario, mode: GaiaDeviceAudioCurationMode) {
        guard
            let current = state.modes.scenarioModes[scenario],
            current != mode
        else {
            return
        }

        if let modeByteValue = mode.byteValue(), let scenarioByteValue = scenario.byteValue() {
            let message = GaiaV3GATTPacket(featureID: .audioCuration,
                                           commandID: Commands.setScenarioConfig.rawValue,
                                           payload: Data([scenarioByteValue, modeByteValue]))
            connection.sendData(channel: .command, payload: message.data, acknowledgementExpected: true)
        }
    }

    func availableModesForScenario(_ scenario: GaiaDeviceAudioCurationScenario) -> [GaiaDeviceAudioCurationModeInfo] {
        var retVal = [GaiaDeviceAudioCurationModeInfo(mode: .off, action: actionForMode(.off), type: .none, supportedFeatures: []),
                      GaiaDeviceAudioCurationModeInfo(mode: .voidOrUnchanged,
                                                      action: actionForMode(.voidOrUnchanged, isToggle: false),
                                                      type: .none,
                                                      supportedFeatures: [])]

        retVal.append(contentsOf: availableDemoModeModes())
        return retVal
    }

    private func setDemoModeState(enabled: Bool) {
        let message = GaiaV3GATTPacket(featureID: .audioCuration,
                                       commandID: Commands.setDemoModeState.rawValue,
                                       payload: Data([enabled ? 0x01 : 0x00]))
        connection.sendData(channel: .command, payload: message.data, acknowledgementExpected: true)
    }

    func enterDemoMode() {
        guard !state.state.inDemoMode && demoModeAvailable else {
            return
        }
        setDemoModeState(enabled: true)
    }

    func exitDemoMode() {
        guard state.state.inDemoMode else {
            return
        }
        setDemoModeState(enabled: false)
    }

    private func actionForMode(_ mode: GaiaDeviceAudioCurationMode, isToggle: Bool = false) -> GaiaDeviceAudioCurationModeAction {
        switch mode {
        case .off:
            return .off
        case .numberedMode(mode: let mode):
            return .selectMode(mode: mode)
        case .voidOrUnchanged:
            if isToggle {
                return .disableToggle
            } else {
                return .doNotChangeMode
            }
        case .unknown:
            return .unknown
        }
    }

    func availableDemoModeModes() -> [GaiaDeviceAudioCurationModeInfo] {
        return state.modes.filterModes
    }

    func setDemoModeMode(_ mode: GaiaDeviceAudioCurationMode) {
        guard let modeNumber = mode.byteValue() else {
            return
        }
        setCurrentFilterMode(Int(modeNumber))
    }

    func demoModeMode() -> GaiaDeviceAudioCurationMode {
        return .numberedMode(mode: UInt8(currentFilterMode))
    }

    private func setAdaptationControlState(enabled: Bool) {
        let message = GaiaV3GATTPacket(featureID: .audioCuration,
                                       commandID: Commands.setAdaptationControlState.rawValue,
                                       payload: Data([enabled ? 0x01 : 0x00]))
        connection.sendData(channel: .command, payload: message.data, acknowledgementExpected: true)
    }

    func startAdaptation() {
        let currentModeFeatures = state.modes.filterModes[currentFilterMode - 1].supportedFeatures
        guard !state.state.adaptationIsEnabled && currentModeFeatures.contains(.changeAdaptiveState) else {
            return
        }
        setAdaptationControlState(enabled: true)
    }

    func stopAdaptation() {
        let currentModeFeatures = state.modes.filterModes[currentFilterMode - 1].supportedFeatures
        guard state.state.adaptationIsEnabled && currentModeFeatures.contains(.changeAdaptiveState) else {
            return
        }
        setAdaptationControlState(enabled: false)
    }
}

private extension GaiaDeviceAudioCurationPlugin {
    func prepareToggles() {
        guard numberOfToggles != state.modes.toggleOptions.count else {
            return
        }

        var toggles = [GaiaDeviceAudioCurationMode]()
        let mode = GaiaDeviceAudioCurationMode.unknown
        for _ in 1...numberOfToggles {
            toggles.append(mode)
        }
        state.modes.toggleOptions = toggles

        for toggle in 1...numberOfToggles {
            getToggleConfig(toggle: toggle)
        }
    }

    func prepareFilterModes() {
        // Prepare placeholders for the filter modes that gets filled in as info arrives.
        guard numberOfFilterModes != state.modes.filterModes.count else {
            return
        }

        var filterModes = [GaiaDeviceAudioCurationModeInfo]()
        for index in 1...numberOfFilterModes {
            let mode = GaiaDeviceAudioCurationMode.numberedMode(mode: UInt8(index))
            let info = GaiaDeviceAudioCurationModeInfo(mode: mode,
                                                       action: actionForMode(mode),
                                                       type: .unknown,
                                                       supportedFeatures: [])
            filterModes.append(info)
        }
        state.modes.filterModes = filterModes
    }
}
