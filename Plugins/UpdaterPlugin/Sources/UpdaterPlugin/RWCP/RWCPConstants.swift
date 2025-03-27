//
//  © 2021 - 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation

enum RWCPConstants {
    // Timeout periods
    static let RWCP_SYN_TIMEOUT_MS = 1500
    static let RWCP_RST_TIMEOUT_MS = 1500
    static let RWCP_DATA_TIMEOUT_MS_NORMAL = 500
    static let RWCP_DATA_TIMEOUT_MS_MAX = 5000

    // RWCP protocol definitions
    static let RWCP_MAX_SEQUENCE = 63
    static let RWCP_SEQUENCE_SPACE_SIZE = RWCP_MAX_SEQUENCE + 1
    static let RWCP_HEADER_SIZE = 1

    // Opcodes
    static let RWCP_HEADER_OPCODE_DATA: UInt8 = (0 << 6)
    static let RWCP_HEADER_OPCODE_DATA_ACK: UInt8 = (0 << 6)
    static let RWCP_HEADER_OPCODE_SYN: UInt8 = (1 << 6)
    static let RWCP_HEADER_OPCODE_SYN_ACK: UInt8 = (1 << 6)
    static let RWCP_HEADER_OPCODE_RST: UInt8 = (2 << 6)
    static let RWCP_HEADER_OPCODE_RST_ACK: UInt8 = (2 << 6)
    static let RWCP_HEADER_OPCODE_GAP: UInt8 = (3 << 6)
    static let RWCP_CWIN_MAX = (15)            // Maximum size of congestion window. i.e. maximum number of outstanding segments
}
