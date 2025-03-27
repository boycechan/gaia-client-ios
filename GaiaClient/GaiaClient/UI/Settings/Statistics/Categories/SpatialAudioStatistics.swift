//
//  © 2021 - 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation
import GaiaCore
import PluginBase

enum SpatialAudioStatistics: StatisticsStatisticID, CaseIterable {
    // ID 0 is not permitted
    case quaternionW = 0x01
    case quaternionX = 0x02
    case quaternionY = 0x03
    case quaternionZ = 0x04
}

extension SpatialAudioStatistics: StatisticValueUITreatment {
    func userVisibleName() -> String {
        switch self {
        case .quaternionW:
            return String(localized: "Quaternion W", comment: "Streaming Statistic Name")
        case .quaternionX:
            return String(localized: "Quaternion X", comment: "Streaming Statistic Name")
        case .quaternionY:
            return String(localized: "Quaternion Y", comment: "Streaming Statistic Name")
        case .quaternionZ:
            return String(localized: "Quaternion Z", comment: "Streaming Statistic Name")
        }
    }

    func id() -> StatisticsStatisticID {
        return self.rawValue
    }
    
    func userVisibleValue(plugin: GaiaDeviceStatisticsPluginProtocol) -> String? {
        let req = StatisticsStatisticValueRequest(category: StatisticCategories.spatialAudio.rawValue,
                                                  statistic: self.rawValue)
        if let value = plugin.getStatisticValue(req, type: Int16.self) {
            return "\(value)"
        }
        
        return nil
    }

    func shouldUpdate(plugin: GaiaDeviceStatisticsPluginProtocol) -> Bool {
        return true
    }
}
