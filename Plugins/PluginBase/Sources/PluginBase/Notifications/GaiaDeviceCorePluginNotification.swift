//
//  © 2021 - 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation
import GaiaBase

public class CoreUpgradeRequiredPayload {
    public let majorVersion: Int
    public let minorVersion: Int
    public let psStoreVersion: Int
    
    public init(majorVersion: Int, minorVersion: Int, psStoreVersion: Int) {
        self.majorVersion = majorVersion
        self.minorVersion = minorVersion
        self.psStoreVersion = psStoreVersion
    }
}

public extension Notification.Name {
    static let GaiaDeviceCorePluginNotification = Notification.Name("GaiaDeviceCorePluginNotification")
}

public struct GaiaDeviceCorePluginNotification: GaiaNotification {

    public enum Reason {
        case handshakeComplete
        case userFeaturesComplete
        case chargerStatus
        case secondSerial
        case handoverAboutToHappen
        case upgradeRequired
    }
    
    public enum Payload {
        case device(GaiaDeviceIdentifierProtocol)
        case upgradeRequired(GaiaDeviceIdentifierProtocol, CoreUpgradeRequiredPayload)
    }

    public var sender: GaiaNotificationSender
    public var payload: Payload
    public var reason: Reason

    public static var name: Notification.Name = .GaiaDeviceCorePluginNotification

    public init(sender: GaiaNotificationSender,
                payload: Payload,
                reason: GaiaDeviceCorePluginNotification.Reason) {
        self.sender = sender
        self.payload = payload
        self.reason = reason
    }
}
