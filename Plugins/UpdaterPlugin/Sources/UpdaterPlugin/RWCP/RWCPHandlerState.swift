//
//  © 2021 - 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation

class RWCPHandlerState {
    enum ConnectionState{
        /// Client and Server. Client is waiting to send the first SYN to initiate the session. Server is waiting for the SYN.
        case listen
        /// Client only. The client has sent the SYN and is waiting for the server to reply with the SYN+ACK.
        case synSent
        /// Client and Server. The client sends DATA segments to the server. The server received DATA segments from the client. The server sends ACK+sequence segments to the client.
        case established
        /// Client only. The client has sent a RST packet to the server. The server is waiting for a RST+ACK from the server.
        case closing
        
        func userVisibleName() -> String {
            switch self {
            case .listen:
                return "LISTEN"
            case .synSent:
                return "SYNSENT"
            case .established:
                return "ESTABLISHED"
            case .closing:
                return "CLOSING"
            }
        }
    }

    var connectionState = ConnectionState.listen

    var initialCongestionWindowSize = RWCPConstants.RWCP_CWIN_MAX
    var maximumCongestionWindowSize = RWCPConstants.RWCP_CWIN_MAX
    var window = RWCPConstants.RWCP_CWIN_MAX
    var credits = RWCPConstants.RWCP_CWIN_MAX

    // The sequence numbers are stored as Ints as -1 is possible value
    var lastAckSequence: Int = -1
    var nextSequence: Int = 0
    var acknowledgedSegments: Int = 0

	var isResendingSegments = false

    var dataTimeout = RWCPConstants.RWCP_DATA_TIMEOUT_MS_NORMAL

    var pendingData = [Data]()
    var isMoreToSend = true
    var unacknowledgedSegments = [RWCPSegment]()
}

