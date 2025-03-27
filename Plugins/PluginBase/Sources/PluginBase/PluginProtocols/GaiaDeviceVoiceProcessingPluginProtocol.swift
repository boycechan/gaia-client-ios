//
//  © 2021 - 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation

public enum VoiceProcessingCapabilities {
    case unknownOrUnavailable
    case none
    case cVc

    public init(byteValue: UInt8) {
        switch byteValue {
        case 0x00:
            self = .none
        case 0x01:
            self = .cVc
        default:
            self = .unknownOrUnavailable
        }
    }

    public func byteValue() -> UInt8? {
        switch self {
        case .none:
            return 0x00
        case .cVc:
            return 0x01
        case .unknownOrUnavailable:
            return nil
        }
    }
}

public enum VoiceProcessing3MicCVCOperationMode {
    case unknownOrUnavailable
    case twoMic
    case threeMic

    public init(byteValue: UInt8) {
        switch byteValue {
        case 0x00:
            self = .twoMic
        case 0x01:
            self = .threeMic
        default:
            self = .unknownOrUnavailable
        }
    }

    public func byteValue() -> UInt8? {
        switch self {
        case .twoMic:
            return 0x00
        case .threeMic:
            return 0x01
        case .unknownOrUnavailable:
            return nil
        }
    }
}

public enum VoiceProcessingCVCMicrophoneMode {
    case unknownOrUnavailable
    case bypass
    case oneMic
    case twoMic
    case threeMic

    public init(byteValue: UInt8) {
        switch byteValue {
        case 0x00:
            self = .bypass
        case 0x01:
            self = .oneMic
        case 0x02:
            self = .twoMic
        case 0x03:
            self = .threeMic
        default:
            self = .unknownOrUnavailable
        }
    }

    public func byteValue() -> UInt8? {
        switch self {
        case .bypass:
            return 0x00
        case .oneMic:
            return 0x01
        case .twoMic:
            return 0x02
        case .threeMic:
            return 0x03
        case .unknownOrUnavailable:
            return nil
        }
    }
}

public enum VoiceProcessingCVCBypassMode {
    case unknownOrUnavailable
    case voiceMic
    case externalMic
    case internalMic

    public init(byteValue: UInt8) {
        switch byteValue {
        case 0x00:
            self = .voiceMic
        case 0x01:
            self = .externalMic
        case 0x02:
            self = .internalMic
        default:
            self = .unknownOrUnavailable
        }
    }

    public func byteValue() -> UInt8? {
        switch self {
        case .voiceMic:
            return 0x00
        case .externalMic:
            return 0x01
        case .internalMic:
            return 0x02
        case .unknownOrUnavailable:
            return nil
        }
    }
}

public protocol GaiaDeviceVoiceProcessingPluginProtocol: GaiaDevicePluginProtocol {
    func isCapabilityPresent(_ capability: VoiceProcessingCapabilities) -> Bool

    // cVc
    var cVcOperationMode: VoiceProcessing3MicCVCOperationMode { get }
    
    var cVcMicrophonesMode: VoiceProcessingCVCMicrophoneMode { get }
    var cVcBypassMode: VoiceProcessingCVCBypassMode { get }

    func setCVCMicrophonesMode(_ mode: VoiceProcessingCVCMicrophoneMode)
    func setCVCBypassMode(_ mode: VoiceProcessingCVCBypassMode)
}
