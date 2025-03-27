//
//  © 2023 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation
import PluginBase

extension GaiaDeviceAudioCurationModeAction {
    func userVisibleDescription() -> String {
        switch self {
        case .off:
            return String(localized: "Audio curation off", comment: "Mode name")
        case .selectMode(mode: let mode):
            return String(localized: "Mode \(mode)", comment: "Audio Curation Mode Action")
        case .disableToggle:
            return String(localized: "Disable this toggle", comment: "Void name")
        case .doNotChangeMode:
            return String(localized: "Do not change current mode", comment: "Unchanged name")
        case .unknown:
            return String(localized:"Unknown", comment: "Unknown")
        }
    }
}
