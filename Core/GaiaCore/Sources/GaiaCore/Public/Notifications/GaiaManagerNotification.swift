//
//  © 2021 - 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation
import GaiaBase

extension Notification.Name {
    static let GaiaManagerNotification = Notification.Name("GaiaManagerNotification")
}

public struct GaiaManagerNotification: GaiaNotification {
    public enum Reason {
        case poweredOn
        case poweredOff
        case discover
        case connectSuccess
        case connectFailed
        case disconnect
        case dfuReconnectTimeout
    }

    public enum Payload {
        case system
        case device(_ : GaiaDeviceIdentifierProtocol)
    }

    public var sender: GaiaNotificationSender
    public var payload: Payload
    public var reason: GaiaManagerNotification.Reason

    public static var name: Notification.Name = .GaiaManagerNotification
}
