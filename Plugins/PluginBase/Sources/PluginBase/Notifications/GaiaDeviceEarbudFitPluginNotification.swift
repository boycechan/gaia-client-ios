//
//  © 2021 - 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation
import GaiaBase

public extension Notification.Name {
    static let GaiaDeviceEarbudFitPluginNotification = Notification.Name("GaiaDeviceEarbudFitPluginNotification")
}

public struct GaiaDeviceEarbudFitPluginNotification: GaiaNotification {
    public enum Reason {
        case resultChanged
    }

    public var sender: GaiaNotificationSender
    public var payload: GaiaDeviceIdentifierProtocol
    public var reason: Reason

    public static var name: Notification.Name = .GaiaDeviceEarbudFitPluginNotification

    public init(sender: GaiaNotificationSender,
                payload: GaiaDeviceIdentifierProtocol,
                reason: GaiaDeviceEarbudFitPluginNotification.Reason) {
        self.sender = sender
        self.payload = payload
        self.reason = reason
    }
}
