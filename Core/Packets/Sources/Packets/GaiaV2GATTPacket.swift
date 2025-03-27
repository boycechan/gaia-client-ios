//
//  © 2020 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation
import GaiaBase
import ByteUtils

public struct GaiaV2GATTPacket: IncomingMessageProtocol {
    static let eventNotificationCommandID: UInt16 = 0x4003

    private let vendorID: UInt16
    private let commandID: UInt16
    private let payload: Data
    public let ack: Bool

    public var messageDescription: IncomingMessageDescription {
        let trimmedPayload = payload.count > 1 ? payload.advanced(by: 1) : Data()
        // We tried use dropFirst here but accessing by subscript subsequently failed.

        if commandID == Self.eventNotificationCommandID {
            return .notification(notificationID: payload.first ?? 0,
                                 data: trimmedPayload)
        }

        let status = payload.first ?? 0

        if status == 0 {
            return .response(command: commandID,
                             data: trimmedPayload)
        } else {
            return .error(command: commandID,
                          errorCode: status,
                          data: trimmedPayload)
        }
    }

    public init(commandID: UInt16,
         ack: Bool = false,
         payload: Data = Data()) {
        self.vendorID = QCVendorID.v2
        self.ack = ack
        self.commandID = commandID
        self.payload = payload
    }

    public init?(data: Data) {
        guard data.count >= 4 else {
            return nil
        }
        vendorID = UInt16(data: data, offset: 0, bigEndian: true)!
        let cBytes = UInt16(data: data, offset: 2, bigEndian: true)!
        commandID = cBytes & 0x7fff
        ack = cBytes & 0x8000 != 0
        payload = data.count > 4 ? data.advanced(by: 4) : Data()
    }

    public var data: Data {
       var byteArray = vendorID.data(bigEndian: true)
        byteArray.append(contentsOf: commandID.data(bigEndian: true))
        byteArray[2] |= ack ? 0x80 : 0
        byteArray.append(contentsOf: payload)
        return Data(byteArray)
    }
}
