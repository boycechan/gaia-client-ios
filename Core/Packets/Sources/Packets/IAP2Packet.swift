//
//  © 2020 - 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation
import GaiaBase
import ByteUtils

/**
* <p><blockquote><pre>
* 0 bytes   1         2         3          4                             len+8      len+9
* +---------+---------+---------+---------+ +---------+---------+ +----------+
* |   SOF   | VERSION |  FLAGS  | LENGTH  | |     PDU   ...     | | CHECKSUM |
* +---------+---------+---------+---------+ +---------+---------+ +----------+
* </pre></blockquote></p>
*/

public struct IAP2Packet {
    private(set) var wrapperAdditionalLength: Int = 4
    public private(set) var totalLength: Int = 0
    public private(set) var payload: Data = Data()
    public static let expectedSOF: UInt8 = 0xff
    public static let GAIAHeaderSize = 4
    public static let maxPacketSizeNoExtension = Int(UInt8.max - 1)
    public static let maxPayloadLengthNoExtension = Self.maxPacketSizeNoExtension - 4

    public static let maxPacketSizeWithExtension = Int(UInt16.max - 1)
    public static let maxPayloadLengthWithExtension = Self.maxPacketSizeWithExtension - 5

    public init?(streamData: Data) {
        guard
            streamData.count >= 4,
            streamData[0] == Self.expectedSOF // Check SOF
        else {
            return nil
        }

        let flags = streamData[2]
        let hasChecksum = (flags & 0x00000001) != 0
        let hasDatalengthExtension = (flags & 0x00000010) != 0

        if hasDatalengthExtension && streamData.count < 5 {
            // We're gonna need a bigger header.
            return nil
        }

        let payloadLength = hasDatalengthExtension ?
            Int(UInt16(data: streamData, offset: 3, bigEndian: true)!) :
            Int(streamData[3])

        wrapperAdditionalLength = 4 + (hasDatalengthExtension ? 1 : 0) + (hasChecksum ? 1 : 0)
        totalLength =  wrapperAdditionalLength + payloadLength + 4 // The payload length doesn't include the GAIA header's 4 bytes

        guard streamData.count >= totalLength else {
            return nil
        }

        let payloadOffset = hasDatalengthExtension ? 5 : 4

        payload = streamData.subdata(in: payloadOffset ..< (payloadOffset + payloadLength + 4)) // The payload length doesn't include the GAIA header's 4 bytes
    }

    public static func data(payload: Data, extensionSupported: Bool = false) -> Data? {
        let maxPayloadLength = extensionSupported ? Self.maxPayloadLengthWithExtension : Self.maxPayloadLengthNoExtension

        guard payload.count <= maxPayloadLength else {
            return nil
        }

        var data = Data([Self.expectedSOF, extensionSupported ? 0x04 : 0x03]) // Protocol version 4 if supported.
        if payload.count > Self.maxPayloadLengthNoExtension {
            data.append(Data([0b00000010])) // No checksum. Uses extension

            // The payload length doesn't include the GAIA header's 4 bytes so we take those 4 off the total
            let lengthData = UInt16(payload.count - 4).data(bigEndian: true)
            data.append(contentsOf: lengthData)
        } else {
            data.append(Data([0x0, UInt8(payload.count - 4)])) // No checksum. No extension
        }
        data.append(payload)
        return data
    }
}
