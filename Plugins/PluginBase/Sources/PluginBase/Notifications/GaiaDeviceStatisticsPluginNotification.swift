//
//  © 2021 - 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation
import GaiaBase

extension Notification.Name {
    static let GaiaDeviceStatisticsPluginNotification = Notification.Name("GaiaDeviceStatisticsPluginNotification")
}

public struct GaiaDeviceStatisticsPluginNotification: GaiaNotification {
    public enum Reason {
        case categoriesUpdated
        case statisticUpdated(request: StatisticsStatisticValueRequest, moreComing: Bool)
    }

    public var sender: GaiaNotificationSender
    public var payload: GaiaDeviceIdentifierProtocol?
    public var reason: Reason

    public static var name: Notification.Name = .GaiaDeviceStatisticsPluginNotification

    public init(sender: GaiaNotificationSender, payload:
                GaiaDeviceIdentifierProtocol? = nil,
                reason: GaiaDeviceStatisticsPluginNotification.Reason) {
        self.sender = sender
        self.payload = payload
        self.reason = reason
    }
}
