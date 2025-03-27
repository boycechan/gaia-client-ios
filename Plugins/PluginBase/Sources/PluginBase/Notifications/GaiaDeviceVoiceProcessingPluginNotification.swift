//
//  © 2021 - 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation
import GaiaBase

extension Notification.Name {
    static let GaiaDeviceVoiceProcessingPluginNotification = Notification.Name("GaiaDeviceVoiceProcessingPluginNotification")
}

public struct GaiaDeviceVoiceProcessingPluginNotification: GaiaNotification {
    public enum Reason {
		case capabilityAvailabilityChanged

        case cVcMicOperationModeChanged
        case cVcMicrophonesModeChanged
        case cVcBypassModeChanged
    }

    public var sender: GaiaNotificationSender
    public var payload: GaiaDeviceIdentifierProtocol
    public var reason: Reason

    public static var name: Notification.Name = .GaiaDeviceVoiceProcessingPluginNotification

    public init(sender: GaiaNotificationSender,
                payload: GaiaDeviceIdentifierProtocol,
                reason: GaiaDeviceVoiceProcessingPluginNotification.Reason) {
        self.sender = sender
        self.payload = payload
        self.reason = reason
    }
}
