//
//  © 2021 - 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation
import GaiaBase

extension Notification.Name {
    static let GaiaDeviceEQPluginNotification = Notification.Name("GaiaDeviceEQPluginNotification")
}

public struct GaiaDeviceEQPluginNotification: GaiaNotification {
    public enum Reason {
        case enabledChanged
        case presetChanged
        case bandChanged
    }

    public var sender: GaiaNotificationSender
    public var payload: GaiaDeviceIdentifierProtocol
    public var reason: Reason

    public static var name: Notification.Name = .GaiaDeviceEQPluginNotification

    public init(sender: GaiaNotificationSender,
                payload: GaiaDeviceIdentifierProtocol,
                reason: GaiaDeviceEQPluginNotification.Reason) {
        self.sender = sender
        self.payload = payload
        self.reason = reason
    }

}

