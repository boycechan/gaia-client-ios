//
//  © 2021 - 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation
import GaiaCore
import PluginBase

enum StatisticCategories: StatisticsCategoryID {
    // ID 0 is not permitted
	case streaming = 1
    case spatialAudio = 2
}

extension StatisticCategories {
    func userVisibleName() -> String {
        switch self {
        case .streaming:
            return String(localized: "Streaming", comment: "Statistic Category Name")
        case .spatialAudio:
            return String(localized: "Spatial Audio", comment: "Statistic Category Name")
        }
    }

    func allStatistics() -> [StatisticValueUITreatment] {
        switch self {
        case .streaming:
            return StreamingStatistics.allCases
        case .spatialAudio:
            return SpatialAudioStatistics.allCases
        }
    }

    func statistic(id: StatisticsStatisticID) -> StatisticValueUITreatment? {
        switch self {
        case .streaming:
            return StreamingStatistics(rawValue: id)
        case .spatialAudio:
            return SpatialAudioStatistics(rawValue: id)
        }
    }

    func defaultRefreshRate() -> TimeInterval {
        switch self {
        case .spatialAudio:
            return 1.0
        default:
            return 5.0
        }
    }
}

protocol StatisticValueUITreatment {
    func id() -> StatisticsStatisticID
    func userVisibleName() -> String
    func userVisibleValue(plugin: GaiaDeviceStatisticsPluginProtocol) -> String?
    func shouldUpdate(plugin: GaiaDeviceStatisticsPluginProtocol) -> Bool
}
