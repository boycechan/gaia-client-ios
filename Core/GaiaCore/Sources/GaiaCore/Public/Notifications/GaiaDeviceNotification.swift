//
//  © 2021 - 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation
import GaiaBase

extension Notification.Name {
    static let GaiaDeviceNotification = Notification.Name("GaiaDeviceNotification")
}

public struct GaiaDeviceNotification: GaiaNotification {
    public enum Reason {
        case rssi
        case stateChanged
        case identificationComplete
    }

    public var sender: GaiaNotificationSender
    public var payload: GaiaDeviceIdentifierProtocol
    public var reason: Reason

    public static var name: Notification.Name = .GaiaDeviceNotification
}
