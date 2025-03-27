//
//  © 2021 - 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation
import GaiaBase

extension Notification.Name {
    static let GaiaDeviceAudioCurationPluginNotification = Notification.Name("GaiaDeviceAudioCurationPluginNotification")
}

public struct GaiaDeviceAudioCurationPluginNotification: GaiaNotification {
    public enum Reason {
        case enabledChanged
        case modeChanged
        case gainChanged

        case toggleConfigChanged
        case scenarioConfigChanged
        case demoModeStateChanged
        case adaptationStateChanged

        // Adaptive Transparency
        case leakthoughSteppedGainConfigChanged
        case balanceChanged
        case wndStatusChanged
        case wndDetectionStateChanged

        // Auto Transparency
        case autoTransparencyStateChanged
        case autoTransparencyReleaseTimeChanged

        // Howling Detection
        case howlingDetectionStateChanged
        case howlingDetectionGainChanged
        case howlingDetectionGainReductionStateChanged

        // Noise ID
        case noiseIDStateChanged
        case noiseIDCategoryChanged

        // AAH
        case AAHStateChanged
        case AAHGainReductionStateChanged
    }

    public let sender: GaiaNotificationSender
    public let payload: GaiaDeviceIdentifierProtocol
    public let reason: Reason

    public static var name: Notification.Name = .GaiaDeviceAudioCurationPluginNotification

    public init(sender: GaiaNotificationSender,
                payload: GaiaDeviceIdentifierProtocol,
                reason: GaiaDeviceAudioCurationPluginNotification.Reason) {
        self.sender = sender
        self.payload = payload
        self.reason = reason
    }
}
