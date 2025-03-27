//
//  © 2021 - 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation
import GaiaBase

extension Notification.Name {
    static let GaiaDeviceEarbudPluginNotification = Notification.Name("GaiaDeviceEarbudPluginNotification")
}

public struct GaiaDeviceEarbudPluginNotification: GaiaNotification {
    public struct Payload {
        public let device: GaiaDeviceIdentifierProtocol
        public var handoverDelay: Int = 0
        public var handoverIsStatic: Bool = true

        public init(device: GaiaDeviceIdentifierProtocol,
                    handoverDelay: Int = 0,
                    handoverIsStatic: Bool = true) {
            self.device = device
            self.handoverDelay = handoverDelay
            self.handoverIsStatic = handoverIsStatic
        }
    }
    public enum Reason {
        case secondSerial
        case handoverAboutToHappen
        case primaryChanged
    }

    public var sender: GaiaNotificationSender
    public var payload: Payload?
    public var reason: Reason

    public static var name: Notification.Name = .GaiaDeviceEarbudPluginNotification

    public init(sender: GaiaNotificationSender,
                payload: GaiaDeviceEarbudPluginNotification.Payload? = nil,
                reason: GaiaDeviceEarbudPluginNotification.Reason) {
        self.sender = sender
        self.payload = payload
        self.reason = reason
    }
}
