//
//  © 2020 - 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation
import GaiaBase

internal protocol GaiaConnectionFactoryDelegate: AnyObject {
    func didChangeState()
    func didDiscoverDevice(_ device: GaiaDeviceProtocol)
    func didConnectDevice(_ device: GaiaDeviceProtocol)
    func didFailToConnectDevice(_ device: GaiaDeviceProtocol)
    func didDisconnectDevice(_ device: GaiaDeviceProtocol)
}

internal protocol ConnectionFactorySourceDelegate: AnyObject {
    func didChangeState()
    func didDiscoverDevice(_ device: GaiaDeviceProtocol)
    func didConnectDevice(_ device: GaiaDeviceProtocol)
    func didFailToConnectDevice(_ device: GaiaDeviceProtocol)
    func didDisconnectDevice(_ device: GaiaDeviceProtocol)
}

/// A ConnectionFactorySource represents an individual transport (for example BLE or iAP2).
/// All devices available via that method are represented by the same source instance.
internal protocol ConnectionFactorySource {
/// The underlying transport type - for example BLE.
    var kind: ConnectionKind { get }
/// Is the underlying transport scaning for new devices. For some transports this may not be applicable.
    var isScanning: Bool { get }
/// Is the underlying transport available i.e not turned off or otherwise disabled.
    var isAvailable: Bool { get }
/// A list of the devices available using the underlying transport.
    var devices: [GaiaDeviceProtocol] { get }
/// A delegate to receive messages about the transport state and the connection status of devices on that transport.
    var delegate: ConnectionFactorySourceDelegate? { get set }
/// Clear the list of known devices so that the list may be refreshed. For some transports (notably iAP2), this command will only remove the devices that are not currently connected.
    func clearDeviceList()
/// Turns on scanning for devices on the underlying transport where supported.
    func startScanning()
/// Turns off scanning for devices on the underlying transport where supported.
    func stopScanning()
/// Connect to the given device using the underlying transport. This will give rise to a number of delegate method callbacks.
    func connect(_ device: GaiaDeviceProtocol)
/// Disconnect to the given device using the underlying transport. Where supported this will give rise to a number of delegate method callbacks.
    func disconnect(_ device: GaiaDeviceProtocol)
/// Cancel an outstanding request to connect to the given device using the underlying transport. This will give rise to a number of delegate method callbacks.
    func cancelConnect(_ device: GaiaDeviceProtocol)
}

