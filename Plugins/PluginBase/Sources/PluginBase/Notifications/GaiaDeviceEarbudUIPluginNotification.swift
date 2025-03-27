//
//  © 2021 - 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation
import GaiaBase

extension Notification.Name {
    static let GaiaDeviceEarbudUIPluginNotification = Notification.Name("GaiaDeviceEarbudUIPluginNotification")
}

public struct GaiaDeviceEarbudUIPluginNotification: GaiaNotification {
    public enum Reason {
        case updated
        case resetFailed
    }

    public var sender: GaiaNotificationSender
    public var payload: GaiaDeviceIdentifierProtocol?
    public var reason: Reason

    public static var name: Notification.Name = .GaiaDeviceEarbudUIPluginNotification

    public init(sender: GaiaNotificationSender,
                payload: GaiaDeviceIdentifierProtocol? = nil,
                reason: GaiaDeviceEarbudUIPluginNotification.Reason) {
        self.sender = sender
        self.payload = payload
        self.reason = reason
    }
}
