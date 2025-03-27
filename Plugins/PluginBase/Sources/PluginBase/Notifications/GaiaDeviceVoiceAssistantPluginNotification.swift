//
//  © 2021 - 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation
import GaiaBase

extension Notification.Name {
    static let GaiaDeviceVoiceAssistantPluginNotification = Notification.Name("GaiaDeviceVoiceAssistantPluginNotification")
}

public struct GaiaDeviceVoiceAssistantPluginNotification: GaiaNotification {
    public enum Reason {
        case optionChanged
    }

    public var sender: GaiaNotificationSender
    public var payload: GaiaDeviceIdentifierProtocol
    public var reason: Reason

    public static var name: Notification.Name = .GaiaDeviceVoiceAssistantPluginNotification

    public init(sender: GaiaNotificationSender,
                  payload: GaiaDeviceIdentifierProtocol,
                  reason: GaiaDeviceVoiceAssistantPluginNotification.Reason) {
        self.sender = sender
        self.payload = payload
        self.reason = reason
    }
}
