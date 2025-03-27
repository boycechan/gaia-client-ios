//
//  © 2021 - 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation
import GaiaCore
import PluginBase

enum StreamingStatistics: StatisticsStatisticID, CaseIterable {
    enum Codecs: UInt8 {
        case sbc = 1
        case aac
        case aptx
        case aptxHD
        case aptxAdaptive

        func userVisibleName() -> String {
            switch self {
            case .sbc:
                return "SBC"
            case .aac:
                return "AAC"
            case .aptx:
				return "Qualcomm® aptX™"
            case .aptxHD:
                return "Qualcomm® aptX™ HD"
            case .aptxAdaptive:
                return "Qualcomm® aptX™ Adaptive"
            }
        }
    }
    // ID 0 is not permitted
    case codecType = 0x01
    case losslessEnabled = 0x02
    case bitrate = 0x03
    case primaryRSSI = 0x04
    case primaryLinkQuality = 0x05
    case transport = 0x06
}

extension StreamingStatistics: StatisticValueUITreatment {
    func userVisibleName() -> String {
        switch self {
        case .codecType:
            return String(localized: "Codec", comment: "Streaming Statistic Name")
        case .losslessEnabled:
            return String(localized: "Lossless Enabled", comment: "Streaming Statistic Name")
        case .bitrate:
            return String(localized: "Bitrate", comment: "Streaming Statistic Name")
        case .primaryRSSI:
            return String(localized: "RSSI (Primary)", comment: "Streaming Statistic Name")
        case .primaryLinkQuality:
            return String(localized: "Link Quality (Primary)", comment: "Streaming Statistic Name")
        case .transport:
            return String(localized: "Transport", comment: "Streaming Statistic Name")
        }
    }

    func id() -> StatisticsStatisticID {
        return self.rawValue
    }

    func userVisibleValue(plugin: GaiaDeviceStatisticsPluginProtocol) -> String? {
        switch self {
        case .codecType:
            let req = StatisticsStatisticValueRequest(category: StatisticCategories.streaming.rawValue,
                                                      statistic: self.rawValue)
            if let value = plugin.getStatisticValue(req, type: UInt8.self) {
                if let codec = Codecs(rawValue: value) {
                    return codec.userVisibleName()
                } else {
                    return String(localized: "Not Known", comment: "Streaming Statistic Name")
                }
            }
        case .losslessEnabled:
            let req = StatisticsStatisticValueRequest(category: StatisticCategories.streaming.rawValue,
                                                      statistic: self.rawValue)
            if let value = plugin.getStatisticValue(req, type: UInt8.self) {
                return value == 0 ? String(localized: "Yes", comment: "") : String(localized: "No", comment: "")
            }

            return nil
        case .bitrate:
            let req = StatisticsStatisticValueRequest(category: StatisticCategories.streaming.rawValue,
                                                      statistic: self.rawValue)
            if let value = plugin.getStatisticValue(req, type: UInt32.self) {
                return String(format: "%.1f kbps", Double(value)/1000.0)//"\(value)"
            }

            return nil
        case .primaryRSSI:
            let req = StatisticsStatisticValueRequest(category: StatisticCategories.streaming.rawValue,
                                                      statistic: self.rawValue)
            if let value = plugin.getStatisticValue(req, type: Int16.self) {
                return "\(value)"
            }

            return nil
        case .primaryLinkQuality:
            let req = StatisticsStatisticValueRequest(category: StatisticCategories.streaming.rawValue,
                                                      statistic: self.rawValue)
            if let value = plugin.getStatisticValue(req, type: UInt16.self) {
                let percentage = (Double(value) / 65535) * 100
                return String(format: "%.1f %%", percentage)
            }

            return nil
        case .transport:
            let req = StatisticsStatisticValueRequest(category: StatisticCategories.streaming.rawValue,
                                                      statistic: self.rawValue)
            if let value = plugin.getStatisticValue(req, type: UInt8.self) {
                switch value {
                case 1:
                    return String(localized: "WiFi", comment: "")
                case 2:
                    return String(localized: "LEA", comment: "")
                default:
                    return nil
                }
            }

            return nil
        }
        return nil
    }

    func shouldUpdate(plugin: GaiaDeviceStatisticsPluginProtocol) -> Bool {
        return true
    }
}
