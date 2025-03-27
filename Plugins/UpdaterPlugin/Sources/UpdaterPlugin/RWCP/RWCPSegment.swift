//
//  © 2021 - 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation

struct RWCPSegment {
    private let RWCP_HEADER_MASK_SEQ_NUMBER: UInt8 = 0b00111111
    private let RWCP_HEADER_MASK_OPCODE: UInt8 = 0b11000000

    let sequence: UInt8
    let opCode: UInt8
    let data: Data
    let payload: Data

    init?(data: Data) {
        guard data.count > 0 else {
            return nil
        }
        self.data = data
        self.payload = data.count > 1 ? data.advanced(by: 1) : Data()
        let first = data[0]
        self.sequence  = first & RWCP_HEADER_MASK_SEQ_NUMBER
        self.opCode  = first & RWCP_HEADER_MASK_OPCODE
    }

    init(opCode: UInt8,
         sequence: UInt8,
         payload: Data = Data()) {
        let header = (sequence & RWCP_HEADER_MASK_SEQ_NUMBER) |
            (opCode & RWCP_HEADER_MASK_OPCODE)
        var tempData = Data([header])
        tempData.append(payload)
        self.payload = payload
        self.data = tempData
        self.sequence = sequence
        self.opCode = opCode
    }
}
