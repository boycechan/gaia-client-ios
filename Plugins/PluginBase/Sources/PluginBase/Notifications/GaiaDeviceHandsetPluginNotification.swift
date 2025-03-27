//
//  © 2021 - 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation
import GaiaBase

public extension Notification.Name {
    static let GaiaDeviceHandsetPluginNotification = Notification.Name("GaiaDeviceHandsetPluginNotification")
}

public struct GaiaDeviceHandsetPluginNotification: GaiaNotification {
    public enum Reason {
        case multipointEnabledChanged
    }

    public var sender: GaiaNotificationSender
    public var payload: GaiaDeviceIdentifierProtocol
    public var reason: Reason

    public static var name: Notification.Name = .GaiaDeviceHandsetPluginNotification

    public init(sender: GaiaNotificationSender,
                payload: GaiaDeviceIdentifierProtocol,
                reason: GaiaDeviceHandsetPluginNotification.Reason) {
        self.sender = sender
        self.payload = payload
        self.reason = reason
    }
}
