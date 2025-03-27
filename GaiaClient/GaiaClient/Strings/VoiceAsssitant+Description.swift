//
//  © 2023 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation
import PluginBase

extension VoiceAssistant {
    public func userVisibleDescription() -> String {
        switch self {
        case .none:
            return String(localized: "None", comment: "Voice Option")
        case .audioTuning:
            return String(localized: "Audio Tuning", comment: "Voice Option")
        case .googleAssistant:
            return String(localized: "Google Assistant", comment: "Voice Option")
        case .amazonAlexa:
            return String(localized: "Amazon Alexa", comment: "Voice Option")
        }
    }
}
