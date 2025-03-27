//
//  © 2020 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation
import GaiaBase
import PluginBase
import ByteUtils

private enum V3MessageReason: UInt8 {
    case command = 0b00
    case notification = 0b01
    case response = 0b10
    case error = 0b11
}

public enum GaiaV3PacketFeatureID {
    case qualcomm(GaiaDeviceQCPluginFeatureID)
    case vendor(UInt8)
}

public extension GaiaV3PacketFeatureID {
    var byteValue: UInt8 {
        switch self {
        case .qualcomm(let featureID):
            return featureID.rawValue
        case .vendor(let vendorFeatureID):
            return vendorFeatureID
        }
    }
}

/*
 * PDU = Protocol Data Unit
 *
 * PDU is as follows:
 *
 * 0 bytes     1           2           3            4                      len+4
 * +-----------+-----------+-----------+-----------+ +-----------+-----------+
 * |       VENDOR ID       |  COMMAND DESCRIPTION  | | Optional PAYLOAD  ... |
 * +-----------+-----------+-----------+-----------+ +-----------+-----------+
 *
 */



public struct GaiaV3GATTPacket: IncomingMessageProtocol {
    public let vendorID: UInt16
    public let featureID: GaiaV3PacketFeatureID

    private let commandID: UInt16
    private let payload: Data
    private let reason: V3MessageReason

    public var messageDescription: IncomingMessageDescription {
        switch reason {
        case .command:
            return .unknown
        case .notification:
            return .notification(notificationID: UInt8(commandID),
                                 data: payload)
        case .response:
            return .response(command: commandID,
                             data: payload)
        case .error:
            let trimmedPayload = payload.count > 1 ? payload.advanced(by: 1) : Data()
            // We tried use dropFirst here but accessing by subscript subsequently failed.
            return .error(command: commandID,
                          errorCode: payload.first ?? 0,
                          data: trimmedPayload)
        }
    }

    public init(featureID: GaiaDeviceQCPluginFeatureID,
         commandID: UInt16,
         payload: Data = Data()) {
        self.vendorID = QCVendorID.v3
        self.featureID = .qualcomm(featureID)
        self.commandID = commandID
        self.reason = .command
        self.payload = payload
    }

    public init(vendorID: UInt16,
         featureID: UInt8,
         commandID: UInt16,
         payload: Data = Data()) {
        self.vendorID = vendorID
        self.featureID = .vendor(featureID)
        self.commandID = commandID
        self.reason = .command
        self.payload = payload
    }

    public init?(data: Data) {
        guard data.count >= 4 else {
            return nil
        }
        vendorID = UInt16(data: data, offset: 0, bigEndian: true)!

        let featureIDByte = data[2]
        var workingReason = (featureIDByte & 0b00000001) << 1
        let feature: UInt8 = (featureIDByte & 0b11111110) >> 1
        if vendorID == QCVendorID.v3 {
            if let id = GaiaDeviceQCPluginFeatureID(rawValue: (featureIDByte & 0b11111110) >> 1) {
                featureID = .qualcomm(id)
            } else {
                featureID = .qualcomm(.unknown)
            }
        } else {
            featureID = .vendor(feature)
        }

        let commandIDByte = data[3]
		workingReason = workingReason + ((commandIDByte & 0b10000000) >> 7)
        if let workingReason = V3MessageReason(rawValue: workingReason) {
            reason = workingReason
        } else {
            reason = .error
        }

        commandID = UInt16(commandIDByte & 0b01111111)
        payload = data.count > 4 ? data.advanced(by: 4) : Data()
    }

    public var data: Data {
        var byteArray = vendorID.data(bigEndian: true)
        var featureIDInt: UInt8 = 0
        switch featureID {
        case .qualcomm(let id):
            featureIDInt = id.rawValue
        case .vendor(let id):
            featureIDInt = id
        }
        var workingFeatureByte = (featureIDInt << 1) & 0b11111110
        let typeRaw = reason.rawValue
        workingFeatureByte |= ((typeRaw >> 1) & 0b00000001)
        byteArray.append(workingFeatureByte)

        var workingCommandByte = UInt8(commandID & 0b0000000001111111)
        workingCommandByte |= ((typeRaw & 0b00000001) << 7)
        byteArray.append(workingCommandByte)
		return Data(byteArray) + payload
    }
}
