//
//  © 2021 - 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation

public typealias StatisticsCategoryID = UInt16
public typealias StatisticsStatisticID = UInt8

public struct StatisticsStatisticValueRequest {
    public let category: StatisticsCategoryID
    public let statistic: StatisticsStatisticID

    public init(category: StatisticsCategoryID, statistic: StatisticsStatisticID) {
        self.category = category
        self.statistic = statistic
    }
}

public protocol GaiaDeviceStatisticsPluginProtocol: GaiaDevicePluginProtocol {
    var supportedCategories: Set<StatisticsCategoryID> { get }

    func fetchCategoriesIfNotLoaded()
    func fetchAllStats(category: StatisticsCategoryID)
    func fetchStatisticsValues(_ requests: [StatisticsStatisticValueRequest])

    func getStatisticValue<T>(_ request: StatisticsStatisticValueRequest, type: T.Type) -> T? where T: FixedWidthInteger
}
