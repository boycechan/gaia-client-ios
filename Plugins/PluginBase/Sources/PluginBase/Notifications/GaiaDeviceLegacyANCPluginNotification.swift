//
//  © 2021 - 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation
import GaiaBase

extension Notification.Name {
    static let GaiaDeviceLegacyANCPluginNotification = Notification.Name("GaiaDeviceLegacyANCPluginNotification")
}

public struct GaiaDeviceLegacyANCPluginNotification: GaiaNotification {
    public enum Reason {
        case enabledChanged
        case modeChanged
        case gainChanged
        case adaptiveStateChanged
    }

    public var sender: GaiaNotificationSender
    public var payload: GaiaDeviceIdentifierProtocol
    public var reason: Reason

    public static var name: Notification.Name = .GaiaDeviceLegacyANCPluginNotification

    public init(sender: GaiaNotificationSender,
                payload: GaiaDeviceIdentifierProtocol,
                reason: GaiaDeviceLegacyANCPluginNotification.Reason) {
        self.sender = sender
        self.payload = payload
        self.reason = reason
    }
}
