//
//  © 2023 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation
import PluginBase

extension GaiaDevicePluginProtocol {
    var title: String {
        switch self.featureID {
        case .core:
            return String(localized: "Core", comment: "Plugin title")
        case .earbud:
            return String(localized: "Earbud", comment: "Plugin title")
        case .legacyANC:
            return String(localized: "Legacy ANC", comment: "Plugin title")
        case .voiceAssistant:
            return String(localized: "Voice Assistant", comment: "Plugin title")
        case .debug:
            return "" // Not supported on this platform
        case .eq:
            return String(localized: "Equalizer", comment: "Plugin title")
        case .upgrade:
            return String(localized: "Software Updates", comment: "Plugin title")
        case .handset:
            return String(localized: "Handset", comment: "Plugin title")
        case .audioCuration:
            return String(localized: "Audio Curation", comment: "Plugin title")
        case .earbudFit:
            return String(localized: "Earbud Fit", comment: "Plugin title")
        case .voiceProcessing:
            return String(localized: "Voice Processing", comment: "Plugin title")
        case .earbudUI:
            return String(localized: "Gesture Configuration", comment: "Plugin title")
        case .statistics:
            return String(localized: "Statistics", comment: "Plugin title")
        case .battery:
            return String(localized: "Battery", comment: "Plugin title")
        case .unknown:
            return ""
        }
    }

    var subtitle: String? {
        switch self.featureID {
        case .core:
            return nil
        case .earbud:
            return nil
        case .legacyANC:
            if let plugin = self as? GaiaDeviceLegacyANCPluginProtocol {
                return plugin.enabled ? String(localized: "In Use", comment: "In Use") : String(localized: "Not in Use", comment: "EQ not in Use")
            } else {
                return nil
            }
        case .voiceAssistant:
            if let plugin = self as? GaiaDeviceVoiceAssistantPluginProtocol {
                return plugin.selectedAssistant.userVisibleDescription()
            } else {
                return nil
            }
        case .debug:
            return nil
        case .eq:
            if let plugin = self as? GaiaDeviceEQPluginProtocol {
                return plugin.eqEnabled ? String(localized: "In Use", comment: "EQ in Use") : String(localized: "Not in Use", comment: "EQ not in Use")
            } else {
                return nil
            }
        case .upgrade:
            if let plugin = self as? GaiaDeviceUpdaterPluginProtocol,
               plugin.isUpdating {
                return String(localized: "Currently Updating", comment: "Tableview subtitle")
            } else {
                return nil
            }
        case .handset:
            if let plugin = self as? GaiaDeviceHandsetPluginProtocol {
                return plugin.multipointEnabled ?
                    String(localized: "Multipoint Enabled", comment: "Multipoint Enabled") :
                    String(localized: "Multipoint Disabled", comment: "Multipoint Enabled")
            } else {
                return nil
            }
        case .audioCuration:
            if let plugin = self as? GaiaDeviceAudioCurationPluginProtocol {
                return plugin.enabled ?
                	String(localized: "In Use", comment: "ANC in Use") :
                	String(localized: "Not in Use", comment: "ANC not in Use")
            } else {
                return nil
            }
        case .earbudFit:
            return nil
        case .voiceProcessing:
            return nil
        case .earbudUI:
            return nil
        case .statistics:
            return nil
        case .battery:
            return nil
        case .unknown:
            return nil
        }
    }
}
