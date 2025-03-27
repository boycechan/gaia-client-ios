//
//  © 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation

public enum GaiaUpdateError: Error {
    case invalidParameters
    case unexpectedCommand
    case invalidDataRequest
    case updateCancelledByUser
    case connectFailed
    case startFailed
    case unexpectedStart
    case deviceError(error: UpdateErrorCodes)
    case unknownDeviceError(error: UInt8)
}
