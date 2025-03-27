//
//  © 2021 - 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation
import GaiaBase
import PluginBase
import Packets
import GaiaLogger

public class GaiaDeviceCorePlugin: GaiaDeviceCorePluginProtocol, GaiaNotificationSender {
    enum Commands: UInt16 {
        case getAPIVersion = 0

        // Used to create plugins.
        // case getSupportedFeatures = 1
        // case getSupportedFeaturesNext = 2
        case getSerialNumber = 3
        case getVariantName = 4
        case getApplicationVersion = 5
        case deviceReset = 6
        //case registerForNotification = 7 See DeviceNotificationRegistration
        //case unregisterForNotification = 8

        case getTransportInfo = 12
        case setTransportParam = 13

        // Used to create human readable list of supported "marketing" features.
        case getUserFeatures = 14
        case getUserFeaturesNext = 15

        case getBluetoothAddress = 16

        case getSystemInformation = 17
    }

    enum Notifications: UInt8 {
        case chargerStatus = 0
        case upgradeRequired = 1
    }

    enum UserFeatureTypes: UInt8 {
        case applicationFeatureList = 0x01
        // More expected to be added.
    }

    enum SystemInformationTypes: UInt8 {
        case applicationBuildID = 0x00
        // More expected to be added.
    }

    enum TransportCommandKeys: UInt8 {
        case MAX_TX_PACKET_SIZE = 1          // Maximum packet size in bytes device can send
        case OPTIMUM_TX_PACKET_SIZE = 2     // Optimum packet size in bytes device should send, where optimum is generally taken to mean fastest transfer
        case MAX_RX_PACKET_SIZE = 3          // Maximum packet size in bytes device can receive
        case OPTIMUM_RX_PACKET_SIZE = 4      // Optimum packet size in bytes device can receive, where optimum is generally taken to mean fastest transfer
        case TX_FLOW_CONTROL = 5         // 1 - transport has flow control from device to handset, 0 - no flow control
        case RX_FLOW_CONTROL = 6         // 1 - transport has flow control from handset to device, 0 - no flow control
        case PROTOCOL_VERSION = 7
    }

    // MARK: Private ivars
    private weak var device: GaiaDeviceIdentifierProtocol?
    private let devicePluginVersion: UInt8
    private let connection: GaiaDeviceConnectionProtocol
    private let notificationCenter : NotificationCenter

    private var userFeatureData = Data()
    private var systemInformationData = Data()
	private var systemInformation = Dictionary<SystemInformationTypes, Data>()

    private var coreVersion: UInt8 = 0
    private var protocolVersion: Int = 3
    private var optimumSendPacketSize: Int = 0
    private var maxReceivePacketSize: Int = 0

    private var startedHandshakes: Bool = false


    // MARK: Public ivars
    public static let featureID: GaiaDeviceQCPluginFeatureID = .core

    public private(set) var serialNumber: String = ""
    public private(set) var deviceVariant: String = ""
    public private(set) var applicationVersion: String = ""
    public private(set) var isCharging: Bool = false
    public private(set) var userFeatures: [String] = [String]()
    public private(set) var bluetoothAddress: String? = nil

    public var applicationBuildID: String {
        guard
            let value = systemInformation[.applicationBuildID],
            let str = String(bytes: value, encoding: .utf8)
        else {
             return ""
        }
        return str
    }

    // MARK: init/deinit
    public required init(version: UInt8,
                  device: GaiaDeviceIdentifierProtocol,
                  connection: GaiaDeviceConnectionProtocol,
                  notificationCenter: NotificationCenter) {
        self.devicePluginVersion = version
        self.device = device
        self.connection = connection
        self.notificationCenter = notificationCenter
    }

    // MARK: Public Methods
    public func startPlugin() {
        LOG(.medium, "Starting Core...")
        startedHandshakes = false
        if devicePluginVersion >= 2 {
            let message = GaiaV3GATTPacket(featureID: .core,
                                           commandID: Commands.setTransportParam.rawValue,
                                           payload: Data([TransportCommandKeys.PROTOCOL_VERSION.rawValue, 0x0, 0x0, 0x0, 0x4]))
            connection.sendData(channel: .command, payload: message.data, acknowledgementExpected: true)
        } else {
			doHandshakeRequests()
        }
    }

    public func stopPlugin() {
    }

    public func handoverDidOccur() {
        getPrimarySerialNumber()
    }

    public func responseReceived(messageDescription: IncomingMessageDescription) {
        guard let device = device else {
            return
        }
        
        switch messageDescription {
        case .notification(let notificationID, let payload):
            if let notification = Notifications(rawValue: notificationID) {
                switch notification {
                case .chargerStatus:
                    isCharging = (payload.first ?? 0) == 1
                    notificationCenter.post(GaiaDeviceCorePluginNotification(sender: self,
                                                                             payload: .device(device),
                                                                             reason: .chargerStatus))
                case .upgradeRequired:
                    let upgradePayload = CoreUpgradeRequiredPayload(majorVersion: Int(UInt16(data: payload, offset: 0) ?? 0),
                                                             minorVersion: Int(UInt16(data: payload, offset: 2) ?? 0),
                                                             psStoreVersion: Int(UInt16(data: payload, offset: 4) ?? 0))
                    
                    notificationCenter.post(GaiaDeviceCorePluginNotification(sender: self,
                                                                             payload: .upgradeRequired(device, upgradePayload),
                                                                             reason: .upgradeRequired))
                }
            }

        case .response(let command, let data):
            if let basicCommand = Commands(rawValue: command) {
                switch basicCommand {
                case .getAPIVersion,
                     .deviceReset:
                    break
                case .getBluetoothAddress:
                    processBluetoothAddress(data: data)
                case .getSerialNumber:
                    serialNumber = String(data: data, encoding: .utf8) ?? ""
                case .getVariantName:
                    deviceVariant = String(data: data, encoding: .utf8) ?? ""
                case .getApplicationVersion:
                    LOG(.low, "Sending core handshake done")
                    applicationVersion = String(data: data, encoding: .utf8) ?? ""
                    notificationCenter.post(GaiaDeviceCorePluginNotification(sender: self,
                                                                             payload: .device(device),
                                                                             reason: .handshakeComplete))
                case .getTransportInfo:
					handleTransportParamCommandResponse(data: data)
                case .setTransportParam:
                    guard
                        data.count == 5,
                        let transportCommand = TransportCommandKeys(rawValue: data[0])
                    else {
                        return
                    }

                    switch transportCommand {
                    case .PROTOCOL_VERSION:
                        protocolVersion = Int(data[4]) // 32 Bit Big Endian - Bytes 1...4

                        let maxTX: UInt32 = 65535
                        var payload = Data([TransportCommandKeys.MAX_TX_PACKET_SIZE.rawValue])
                        payload.append(maxTX.data(bigEndian: true))
                        let message = GaiaV3GATTPacket(featureID: featureID,
                                                       commandID: Commands.setTransportParam.rawValue,
                                                       payload: payload)
                        connection.sendData(channel: .command, payload: message.data, acknowledgementExpected: true)
                    case .MAX_TX_PACKET_SIZE:
                        if let size = UInt32(data: data, offset: 1, bigEndian: true) {
                            maxReceivePacketSize = Int(size)
							
                            let message = GaiaV3GATTPacket(featureID: featureID,
                                                           commandID: Commands.getTransportInfo.rawValue,
                                                           payload: Data([TransportCommandKeys.OPTIMUM_RX_PACKET_SIZE.rawValue]))
                            connection.sendData(channel: .command, payload: message.data, acknowledgementExpected: true)
                        }

                    default:
                        break
                    }
                case .getUserFeatures,
                     .getUserFeaturesNext:
                    if basicCommand == .getUserFeatures &&
                        userFeatureData.count > 0 {
                        return // Shouldn't happen but ignore
                    }

                    if let bitfield = data.first {
                        let isMoreComing = (bitfield & 0b00000001) > 0
                        let readingStatus = (data.count >= 4) ? data.subdata(in: 1..<4) : Data()
                        let featureData = (data.count > 4) ? data.advanced(by: 4) : Data()
                        userFeatureData.append(featureData)
                        if isMoreComing {
                            // There's more so we make another request
                            let message = GaiaV3GATTPacket(featureID: featureID,
                                                           commandID: Commands.getUserFeaturesNext.rawValue,
                                                           payload: readingStatus)
                            connection.sendData(channel: .command, payload: message.data, acknowledgementExpected: true)
                        } else {
                            processUserFeatureData()
                            notificationCenter.post(GaiaDeviceCorePluginNotification(sender: self,
                                                                                     payload: .device(device),
                                                                                     reason: .userFeaturesComplete))
                        }
                    }
                case .getSystemInformation:
                    if let bitfield = data.first {
                        let isMoreComing = (bitfield & 0b00000001) > 0
                        let readingStatus = (data.count >= 5) ? data.subdata(in: 1..<5) : Data()
                        let featureData = (data.count > 5) ? data.advanced(by: 5) : Data()
                        systemInformationData.append(featureData)
                        if isMoreComing {
                            // There's more so we make another request
                            let message = GaiaV3GATTPacket(featureID: featureID,
                                                           commandID: Commands.getSystemInformation.rawValue,
                                                           payload: readingStatus)
                            connection.sendData(channel: .command, payload: message.data, acknowledgementExpected: true)
                        } else {
                            processSytemInformationData()
                        }
                    }
                }
            }
        default:
            break
        }
    }

    public func didSendData(channel: GaiaDeviceConnectionChannel, error: GaiaError?) {
    }
}

// MARK: - Private Methods

private extension GaiaDeviceCorePlugin {
    private func doHandshakeRequests() {
        guard !startedHandshakes else {
            LOG(.high, "*** DUPLICATE HANDSHAKE AVOIDED ***")
			return
        }

        startedHandshakes = true
        if devicePluginVersion >= 4 {
            getBluetoothAddress()
        }
        getPrimarySerialNumber()
        getVariantName()
        getApplicationVersion()
        if devicePluginVersion >= 5 {
            getSystemInformation()
        }
        getUserFeatures()
    }

    func handleTransportParamCommandResponse(data: Data) {
        guard
            data.count == 5,
            let transportCommand = TransportCommandKeys(rawValue: data[0])
        else {
            return
        }

        switch transportCommand {
        case .OPTIMUM_RX_PACKET_SIZE:
            if let size = UInt32(data: data, offset: 1, bigEndian: true) {
                optimumSendPacketSize = Int(size)
                let message = GaiaV3GATTPacket(featureID: featureID,
                                               commandID: Commands.getTransportInfo.rawValue,
                                               payload: Data([TransportCommandKeys.MAX_RX_PACKET_SIZE.rawValue]))
                connection.sendData(channel: .command, payload: message.data, acknowledgementExpected: true)
            }
        case .MAX_RX_PACKET_SIZE:
            if let size = UInt32(data: data, offset: 1, bigEndian: true) {
                connection.transportParametersReceived(protocolVersion: protocolVersion, maxSendSize: Int(size), optimumSendSize: optimumSendPacketSize, maxReceiveSize: maxReceivePacketSize)
            }
            doHandshakeRequests()
        case .PROTOCOL_VERSION:
			// This shouldn't happen but handle it anyway as it has been seen in some versions of the ADK code
            protocolVersion = Int(data[4]) // 32 Bit Big Endian - Bytes 1...4

            let message = GaiaV3GATTPacket(featureID: featureID,
                                           commandID: Commands.getTransportInfo.rawValue,
                                           payload: Data([TransportCommandKeys.OPTIMUM_RX_PACKET_SIZE.rawValue]))
            connection.sendData(channel: .command, payload: message.data, acknowledgementExpected: true)
        default:
            break
        }
    }

    func processUserFeatureData() {
        guard userFeatureData.count > 2 else {
            // Needs at least a type (byte one) and a size (bytes 1-2)
            return
        }

        var offset = 0
        while offset < userFeatureData.count - 3 {
            let featureTypeByte = userFeatureData[offset]
            let size = UInt16(data: userFeatureData, offset: offset + 1, bigEndian: true) ?? 0

            offset = offset + 3
            let stopOffset = min(offset + Int(size), userFeatureData.count)
            if featureTypeByte == UserFeatureTypes.applicationFeatureList.rawValue {

                while offset < stopOffset - 2 {
                    // First byte is index - we ignore it.
                    let strByteLength = Int(userFeatureData[offset + 1])
                    let strOffset = offset + 2
                    let nextOffset = strOffset + strByteLength
                    if nextOffset <= stopOffset {
                        if strByteLength > 0 {
                            let strData = userFeatureData.subdata(in: strOffset..<nextOffset)
                            if let str = String(bytes: strData, encoding: .utf8) {
                                userFeatures.append(str)
                            }
                        }
                        offset = nextOffset
                    } else {
                        offset = stopOffset
                        LOG(.medium, "User feature - string too long")
                    }
                }
            } else {
                // Skip as unrecognised
                LOG(.low, "Skipping unrecognized user feature list type")
				offset = stopOffset
            }
        }
    }

    func processSytemInformationData() {
        guard systemInformationData.count > 1 else {
            // Needs at least a type (byte zero) and a size (byte 1)
            return
        }

        var offset = 0
        while offset < systemInformationData.count - 2 {
            let infoTypeByte = systemInformationData[offset]
            let size = systemInformationData[offset + 1]
            if offset + 2 + Int(size) <= systemInformationData.count {
                let value = systemInformationData.subdata(in: offset + 2..<offset + 2 + Int(size))
                offset += 2 + Int(size)

                if let type = SystemInformationTypes(rawValue: infoTypeByte) {
					systemInformation[type] = value
                }
            } else {
                offset = systemInformationData.count
            }
        }
    }

    func processBluetoothAddress(data: Data) {
        guard data.count >= 6 else {
            return
        }
        let address = data.prefix(6)
        bluetoothAddress = address.map { String(format: "%02x", $0) }.joined(separator: ":")
    }
}

private extension GaiaDeviceCorePlugin {
    func getBluetoothAddress() {
        let message = GaiaV3GATTPacket(featureID: featureID,
                                       commandID: Commands.getBluetoothAddress.rawValue,
                                       payload: Data())
        connection.sendData(channel: .command, payload: message.data, acknowledgementExpected: true)
    }

    func getPrimarySerialNumber() {
        let message = GaiaV3GATTPacket(featureID: featureID,
                                       commandID: Commands.getSerialNumber.rawValue,
                                       payload: Data())
        connection.sendData(channel: .command, payload: message.data, acknowledgementExpected: true)
    }

    func getVariantName() {
        let message = GaiaV3GATTPacket(featureID: featureID,
                                       commandID: Commands.getVariantName.rawValue,
                                       payload: Data())
        connection.sendData(channel: .command, payload: message.data, acknowledgementExpected: true)
    }

    func getApplicationVersion() {
        let message = GaiaV3GATTPacket(featureID: featureID,
                                   commandID: Commands.getApplicationVersion.rawValue,
                                   payload: Data())
        connection.sendData(channel: .command, payload: message.data, acknowledgementExpected: true)
    }

    func getUserFeatures() {
        userFeatureData = Data()
        let message = GaiaV3GATTPacket(featureID: featureID,
                                       commandID: Commands.getUserFeatures.rawValue,
                                       payload: Data())
        connection.sendData(channel: .command, payload: message.data, acknowledgementExpected: true)
    }

    func getSystemInformation() {
        systemInformationData = Data()
        systemInformation.removeAll()
        let message = GaiaV3GATTPacket(featureID: featureID,
                                       commandID: Commands.getSystemInformation.rawValue,
                                       payload: Data([0x00, 0x00, 0x00, 0x00]))
        connection.sendData(channel: .command, payload: message.data, acknowledgementExpected: true)
    }
}

