//
//  © 2020 - 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation
import GaiaBase

public enum GaiaDeviceAudioCurationMode {
    case off
    case numberedMode(mode: UInt8)
    case voidOrUnchanged
    case unknown
}

public enum GaiaDeviceAudioCurationModeAction {
	case off
	case selectMode(mode: UInt8)
    case disableToggle
    case doNotChangeMode
	case unknown
}

extension GaiaDeviceAudioCurationMode: Equatable {
    public static func ==(lhs: GaiaDeviceAudioCurationMode, rhs: GaiaDeviceAudioCurationMode) -> Bool {
        switch lhs {
        case .off:
            switch rhs {
            case .off:
                return true
            default:
                return false
            }
        case .numberedMode(let lhsMode):
            switch rhs {
            case .numberedMode(let rhsMode):
                return lhsMode == rhsMode
            default:
                return false
            }
        case .voidOrUnchanged:
            switch rhs {
            case .voidOrUnchanged:
                return true
            default:
                return false
            }
        case .unknown:
            switch rhs {
            case .unknown:
                return true
            default:
                return false
            }
        }
    }
}

public struct AudioCurationModeSupportedFeatures: OptionSet {
    public static let changeAdaptiveState = AudioCurationModeSupportedFeatures(rawValue: 1)
    public static let changeLeakthroughGain = AudioCurationModeSupportedFeatures(rawValue: 1 << 1)
    public static let updatesFeedForwardGain = AudioCurationModeSupportedFeatures(rawValue: 1 << 2)
    public static let antiHowlingControl = AudioCurationModeSupportedFeatures(rawValue: 1 << 3)

    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
}

public enum AudioCurationModeType {
    case staticANC
    case leakthroughANC
    case adaptiveANC
    case adaptiveLeakthroughANC // Added in V2
    case unknown
    case none
}

public struct GaiaDeviceAudioCurationModeInfo {
    public init(mode: GaiaDeviceAudioCurationMode,
                action: GaiaDeviceAudioCurationModeAction,
                type: AudioCurationModeType,
                supportedFeatures: AudioCurationModeSupportedFeatures) {
        self.mode = mode
        self.action = action
        self.type = type
        self.supportedFeatures = supportedFeatures
    }

    public let mode: GaiaDeviceAudioCurationMode
    public let action: GaiaDeviceAudioCurationModeAction
    public let type: AudioCurationModeType
    public let supportedFeatures: AudioCurationModeSupportedFeatures
}

public enum GaiaDeviceAudioCurationScenario {
    case unknown
    case idle
    case playback
    case voiceCall
    case digitalAssistant
    case leStereoRecording
}

extension GaiaDeviceAudioCurationScenario {
    public init(byteValue: UInt8) {
        switch byteValue {
        case 0x01:
            self = .idle
        case 0x02:
            self = .playback
        case 0x03:
            self = .voiceCall
        case 0x04:
            self = .digitalAssistant
        case 0x05:
            self = .leStereoRecording
        default:
            self = .unknown
        }
    }

    public func byteValue() -> UInt8? {
        switch self {
        case .idle:
            return 0x01
        case .playback:
            return 0x02
        case .voiceCall:
            return 0x03
        case .digitalAssistant:
            return 0x04
        case .leStereoRecording:
            return 0x05
        case .unknown:
            return nil
        }
    }
}

public enum GaiaDeviceAudioCurationNoiseIDCategory: ByteValueProtocol {
    public enum NoiseIDCategory: UInt8 {
        case categoryA = 0x00
        case categoryB = 0x01
        case categoryNotApplicable = 0xff
    }
    case known(id: NoiseIDCategory)
    case unknown(id: UInt8)

    public init(byteValue: UInt8) {
        if let knownID = NoiseIDCategory(rawValue: byteValue) {
            self = .known(id: knownID)
            return
        }
        self = .unknown(id: byteValue)
    }

    public func byteValue() -> UInt8 {
        switch self {
        case .known(let category):
            return category.rawValue
        case .unknown(let id):
            return id
        }
    }

    public static func ==(lhs: GaiaDeviceAudioCurationNoiseIDCategory, rhs: GaiaDeviceAudioCurationNoiseIDCategory) -> Bool {
        return lhs.byteValue() == rhs.byteValue()
    }

    public static func < (lhs: GaiaDeviceAudioCurationNoiseIDCategory, rhs: GaiaDeviceAudioCurationNoiseIDCategory) -> Bool {
        return lhs.byteValue() < rhs.byteValue()
    }
}

public enum GaiaDeviceAudioCurationAutoTransparencyReleaseTime: ByteValueProtocol, Comparable, Hashable {
    public enum ReleaseTimeIDs: UInt8, CaseIterable {
        case noActionOnRelease = 0
        case shortRelease = 1
        case normalRelease = 2
        case longRelease = 3
    }
    case known(id: ReleaseTimeIDs)
    case unknown(id: UInt8)

    public init(byteValue: UInt8) {
        if let knownID = ReleaseTimeIDs(rawValue: byteValue) {
            self = .known(id: knownID)
            return
        }
        self = .unknown(id: byteValue)
    }

    public func byteValue() -> UInt8 {
        switch self {
        case .known(let timeID):
            return timeID.rawValue
        case .unknown(let id):
            return id
        }
    }

    public static func allKnown() -> [GaiaDeviceAudioCurationAutoTransparencyReleaseTime] {
        return ReleaseTimeIDs.allCases.map { GaiaDeviceAudioCurationAutoTransparencyReleaseTime.known(id: $0) }
    }

    public static func ==(lhs: GaiaDeviceAudioCurationAutoTransparencyReleaseTime, rhs: GaiaDeviceAudioCurationAutoTransparencyReleaseTime) -> Bool {
        return lhs.byteValue() == rhs.byteValue()
    }

    public static func < (lhs: GaiaDeviceAudioCurationAutoTransparencyReleaseTime, rhs: GaiaDeviceAudioCurationAutoTransparencyReleaseTime) -> Bool {
        return lhs.byteValue() < rhs.byteValue()
    }
}

public protocol GaiaDeviceAudioCurationPluginProtocol: GaiaDevicePluginProtocol {
    var enabled: Bool { get }
	func setEnabledState(_ enabled: Bool)
    
    var currentFilterMode: Int { get } // 1...numberOfFilterModes
    var numberOfFilterModes: Int { get }
    func setCurrentFilterMode(_ value: Int) // 1...numberOfFilterModes

    var feedForwardGainsForCurrentMode: GainContainer { get }
    
    func setGain(_ value: Int)

    var numberOfToggles: Int { get }
    // The value of toggle starts at 0x01 ... numberOfToggleOptions
    func modeForToggle(_ toggle: Int) -> GaiaDeviceAudioCurationMode // The value of toggle starts at 0x01 ... numberOfToggleOptions
    func setModeForToggle(_ toggle: Int, mode: GaiaDeviceAudioCurationMode) // The value of toggle starts at 0x01 ... numberOfToggleOptions
    func availableModesForToggle(_ toggle: Int) -> [GaiaDeviceAudioCurationModeInfo] // The value of toggle starts at 0x01 ... numberOfToggleOptions

    func scenarioSupported(_ scenario: GaiaDeviceAudioCurationScenario) -> Bool
    func currentModeForScenario(_ scenario: GaiaDeviceAudioCurationScenario) -> GaiaDeviceAudioCurationMode
	func setCurrentModeForScenario(_ scenario: GaiaDeviceAudioCurationScenario, mode: GaiaDeviceAudioCurationMode)
    func availableModesForScenario(_ scenario: GaiaDeviceAudioCurationScenario) -> [GaiaDeviceAudioCurationModeInfo]

    var demoModeAvailable: Bool { get }
    var demoModeActive: Bool { get }
    func enterDemoMode()
    func exitDemoMode()

    func setDemoModeMode(_ mode: GaiaDeviceAudioCurationMode)
    func demoModeMode() -> GaiaDeviceAudioCurationMode
    func availableDemoModeModes() -> [GaiaDeviceAudioCurationModeInfo]

    var adaptationIsActive: Bool { get }
	func startAdaptation()
    func stopAdaptation()

    // Version 2 - Adaptive Transparency

    var supportsAdaptiveTransparency: Bool { get }

    // There are different representations/APIs for the leakthough gain between v1 and v2 of the plugin.
    // v2 has a discrete small number of levels. v1 had 0-255.
    var leakthroughSteppedGainNumberOfSteps: Int { get }
    var leakthroughSteppedGainLevel: Int { get } // Starts at 1 not zero
    var leakthroughSteppedGainDB: Int { get }
    var balance: Double { get } // 0.0 = 100% left, 1.0 = 100% right, 0.5 = even

    var windNoiseReductionSupported: Bool { get }
    var windNoiseReductionEnabled: Bool { get }
    var windNoiseReductionActiveLeft: Bool { get }
    var windNoiseReductionActiveRight: Bool { get }

    func setLeakthroughSteppedGainLevel(_ step: Int)
    func setBalance(_ balance: Double)
    func setWindNoiseReductionEnabled(_ state: Bool)

    var autoTransparencySupported: Bool { get }
    var autoTransparencyEnabled: Bool { get }
    var autoTransparencyReleaseTime: GaiaDeviceAudioCurationAutoTransparencyReleaseTime? { get }
    func setAutoTransparencyEnabled(_ state: Bool)
    func setAutoTransparencyReleaseTime(_ time: GaiaDeviceAudioCurationAutoTransparencyReleaseTime)

    var howlingDetectionSupported: Bool { get }
    var howlingDetectionState: Bool { get }
    var howlingDetectionFeedbackGains: GainContainer { get }
    func setHowlingDetectionState(_ state: Bool)

    var HCGRIndicationSupported: Bool { get }
    var HCGRGainReductionActiveLeft: Bool { get }
    var HCGRGainReductionActiveRight: Bool { get }

    var noiseIDSupported: Bool { get }
    var noiseIDState: Bool { get }
    var noiseIDCategory: GaiaDeviceAudioCurationNoiseIDCategory? { get }
    func setNoiseIDState(_ state: Bool)

    var AAHSupported: Bool { get }
    var AAHState: Bool { get }
    func setAAHState(_ state: Bool)
    
    var AAHGainReductionIndicationSupported: Bool { get }
    var AAHGainReductionActiveLeft: Bool { get }
    var AAHGainReductionActiveRight: Bool { get }
}
