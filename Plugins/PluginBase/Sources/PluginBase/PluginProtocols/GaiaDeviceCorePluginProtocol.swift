//
//  © 2021 - 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation

public protocol GaiaDeviceCorePluginProtocol: GaiaDevicePluginProtocol {
    /// The bluetooth reported by the device. 
    var bluetoothAddress: String? { get }

    /// The serial number reported by the device. For earbuds this is the serial of the primary earbud.
    var serialNumber: String { get }

    /// The device variant as reported by the device.
    var deviceVariant: String { get }

    /// The application version as reported by the device.
    var applicationVersion: String { get }

    /// True if the device is currently charging.
    var isCharging: Bool { get }

    var userFeatures: [String] { get }

    var applicationBuildID: String { get }
}
