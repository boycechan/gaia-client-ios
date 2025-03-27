//
//  © 2020 - 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation

public enum GaiaDeviceConnectionState {
    case disconnected
    case uninitialised
    case initialising
    case initialisationFailed
    case ready
}

/// Protocol defining the interface for a device connection. Each device transport would have a different concrete implementation of this protocol. A connection may be responsible for
/// the discovery of Gaia specific transport characteristics and descriptors, or the creation of the necessary streams, but is not responsible for any other Gaia specific set up.
public protocol GaiaDeviceConnectionProtocol: AnyObject {
    /// The connection delegate - usually the Gaia Device instance. This notifies about the connection set up status and also about data sent or received across the connection.
    var delegate: GaiaDeviceConnectionDelegate? { get set }

    /// The kind describes the transport used for the connection - for example BLE or iAP2.
    var connectionKind: ConnectionKind { get }

    /// An identifier the app can use to identify the device/connection. Derivation depends upon the connection method.
    var connectionID: String { get }

    /// The user readable name of the device.
    var name: String { get }

    /// returns true if the device is connected at a transport level.
    var connected: Bool { get }

    /// returns state depending on if the device is connected and the transport setup has completed (for example discovery of characteristics).
    var state: GaiaDeviceConnectionState { get }

    /// The rssi for the device. This is only available for some transports and updates may be infrequent or never. Not to be relied upon.
    var rssi: Int { get }

    /// true if a data length extension is available for this connection.
    var isDataLengthExtensionSupported: Bool { get }

    /// the maximum packet size for the connection if a response is expected (for BLE when RWCP is not used).
    var maximumWriteLength: Int { get }

    /// the maximum packet size for the connection if a response is not expected (for BLE when RWCP is used).
    var maximumWriteWithoutResponseLength: Int { get }

    /// the optimum write packet size as notified by the Gaia device. Due to constraints on the Gaia device, this packet size may be smaller than the maximum possible.
    var optimumWriteLength: Int { get }

    /// Returns max size remaining in a read packet after Gaia PDU bytes including overhead for IAP2, ATT headers etc.
    var maxReceivePayloadSizeForGaia: Int { get }

    /// Returns max size remaining in a write packet after Gaia PDU bytes including overhead for IAP2, ATT headers etc.
    var maxSendPayloadSizeForGaia: Int { get }

    /// Performs any initialisation the connection needs. Typically called after setting the delegate
    func start()

    /// This method is used to send data to the Gaia device
    /// - Parameter channel: The channel to be used for the data. This is only applicable for BLE/RWCP transfers.
    /// - Parameter payload: The data to be sent. For Gaia messages the data is expected to be formatted as a BLE Gaia message (with PDU etc) *regardless of the actual transport*.
    ///						 For iAP2 connections an additional iAP2 header is added to the BLE packet before it is sent.
    ///	- Parameter acknowledgementExpected: Notes if an acknowledgement of a sent packet should be expected from Gaia device after each packet is sent. This is used to throttle the sending of
    ///										 packets so as to not overwhelm the Gaia device.
    func sendData(channel: GaiaDeviceConnectionChannel, payload:Data, acknowledgementExpected: Bool)

    /// This method is used to notify the connection that an acknowledgement to a previous sent message has been received. As message decoding is done elsewhere, it is necessary to notify the connection
    /// that a message has been acknowledged in order to allow communication to progress as quickly as possible.
    func acknowledgementReceived()

    /// During the initial Gaia handshake, some devices may support the reporting of optimum packet sizes. This method is used to modify the packet size parameters depending upon any packet headers etc.
    func transportParametersReceived(protocolVersion: Int, maxSendSize: Int, optimumSendSize: Int, maxReceiveSize: Int)

    /// Some information is only available after a Gaia connection is established (BT Mac address, primary/secondary serial numbers).
    /// This method is used to generate the connection IDs that should be accepted as equivalent to this connection. This allows for handover and for
    /// earbuds with different serial numbers. The values passed into this method may or may not be used to generate the connection IDs. For example, BLE
    /// connections use only the CBPeripheral provided unique ID. This method however provides a common interface.
    /// - Parameter btAddresses: MAC Address. These can be determined through a GAIA API on some devices. Currently, both earbuds in a pair use the same MAC address.
    /// - Parameter serialNumbers: The serial numbers for the devices. Some devices support fetching both the primary and secondary serial numbers through GAIA.

    func equivalentConnectionIDsForReconnection(btAddresses: [String], serialNumbers: [String]) -> [String]
}

public protocol GaiaDeviceConnectionDelegate: AnyObject {
    func rssiDidChange()
    func stateChanged(connection: GaiaDeviceConnectionProtocol)

    func dataReceived(_ data: Data, channel: GaiaDeviceConnectionChannel)
    func didSendData(channel: GaiaDeviceConnectionChannel, error: GaiaError?)
}
