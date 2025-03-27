//
//  © 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation
import GaiaBase

public extension Notification.Name {
    static let GaiaDeviceBatteryPluginNotification = Notification.Name("GaiaDeviceBatteryPluginNotification")
}

public struct GaiaDeviceBatteryPluginNotification: GaiaNotification {
    public enum Reason {
        case supported
        case levelsChanged
    }

    public var sender: GaiaNotificationSender
    public var payload: GaiaDeviceIdentifierProtocol
    public var reason: Reason

    public static var name: Notification.Name = .GaiaDeviceBatteryPluginNotification

    public init(sender: GaiaNotificationSender,
                payload: GaiaDeviceIdentifierProtocol,
                reason: GaiaDeviceBatteryPluginNotification.Reason) {
        self.sender = sender
        self.payload = payload
        self.reason = reason
    }
}
