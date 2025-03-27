//
//  © 2020 - 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation

public enum VoiceAssistant: UInt8 {
    case none
    case audioTuning
    case googleAssistant
    case amazonAlexa
}

public protocol GaiaDeviceVoiceAssistantPluginProtocol: GaiaDevicePluginProtocol {
    var availableAssistantOptions: [VoiceAssistant] { get }
    var selectedAssistant: VoiceAssistant { get }

    func selectOption(_ option: VoiceAssistant)
}
