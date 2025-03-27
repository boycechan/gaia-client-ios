//
//  © 2021 - 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation
import GaiaBase

extension Notification.Name {
    static let GaiaDeviceUpdaterPluginNotification = Notification.Name("GaiaDeviceUpdaterPluginNotification")
}

public struct GaiaDeviceUpdaterPluginNotification: GaiaNotification {
    public enum Reason {
        case ready
        case statusChanged
    }

    public var sender: GaiaNotificationSender
    public var payload: GaiaDeviceIdentifierProtocol
    public var reason: Reason

    public static var name: Notification.Name = .GaiaDeviceUpdaterPluginNotification

    public init(sender: GaiaNotificationSender,
                payload: GaiaDeviceIdentifierProtocol,
                reason: GaiaDeviceUpdaterPluginNotification.Reason) {
        self.sender = sender
        self.payload = payload
        self.reason = reason
    }
}
