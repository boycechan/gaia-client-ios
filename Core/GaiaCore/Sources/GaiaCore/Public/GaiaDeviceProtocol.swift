//
//  © 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation
import GaiaBase
import PluginBase

/// A Gaia Device represents a single device regardless of transport.

public protocol GaiaDeviceProtocol: GaiaDeviceIdentifierProtocol {
    /// The current state of set up of the device during selection by the user and eventual Gaia handshake.
    var state: GaiaDeviceState { get }

    /// The connection transport. Currently ble and iAP2 are supported.
    var connectionKind: ConnectionKind { get }

    /// User readable device name
    var name: String { get }

    /// The device rssi. Not to be relied upon and may be removed in future update.
    var rssi: Int { get }

    /// The serial number reported by the device. For earbuds this is the serial of the primary earbud.
    var serialNumber: String { get }

    /// For earbuds this is the serial number of the secondary earbud. Otherwise this is nil.
    var secondEarbudSerialNumber: String? { get }

    /// The device variant as reported by the device.
    var deviceVariant: String { get }

    /// The application version as reported by the device.
    var applicationVersion: String { get }

    /// The API version as reported by the device.
    var apiVersion: String { get }

    /// True if the device is currently charging.
    var isCharging: Bool { get }

    /// The bluetooth address reported by the device. This is not supported on all devices.
    var bluetoothAddress: String? { get }

    /// An array of the features supported by the device as reported by getSupportedFeatures that have had plugins created as handlers.
    var supportedFeatures: [GaiaDeviceQCPluginFeatureID] { get }

    /// Returns the plugin that has been created to handle the specified feature. Note not all feature IDs have plugins created as some are handled internally in the Gaia Device instance without external plugins.
    func plugin(featureID: GaiaDeviceQCPluginFeatureID) -> GaiaDevicePluginProtocol?

    /// Returns the vendor extension that has been created to handle the specified vendorID.
    func vendorExtension(vendorID: UInt16) -> GaiaDeviceVendorExtensionProtocol?

    /// Used to tear down the device
    func reset()

    /// Used to start the setting up streams/discovering characteristics etc
    func startConnection()

    /// Used to start the process of creating a Gaia connection.
    func connectGaia()

    /// Some information is only available after a Gaia connection is established (BT Mac address, primary/secondary serial numbers).
    /// This method is used to generate the connection IDs that should be accepted as equivalent. This allows for handover and for
    /// earbuds with different serial numbers. The array is empty if the information required to determine the equivalent IDs has not yet been determined.
    var equivalentConnectionIDsForReconnection: [String] { get }
}
