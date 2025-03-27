//
//  © 2020 - 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation

public enum IncomingMessageDescription {
    case notification(notificationID: UInt8, data: Data)
    case response(command: UInt16, data: Data)
    case error(command: UInt16, errorCode: UInt8, data: Data)
    case unknown
}

public protocol IncomingMessageProtocol {
    var messageDescription: IncomingMessageDescription { get }
    init?(data: Data)
}
