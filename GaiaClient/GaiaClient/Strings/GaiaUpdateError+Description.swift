//
//  © 2023 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation
import PluginBase

public extension GaiaUpdateError {
    func userVisibleDescription() -> String {
        switch self {
        case .invalidParameters:
            return String(localized: "Invalid parameters", comment: "General error reason")
        case .unexpectedCommand:
            return String(localized: "Unexpected command received", comment: "General error reason")
        case .invalidDataRequest:
            return String(localized: "Invalid data request exceeds update file bounds", comment: "General error reason")
        case .updateCancelledByUser:
            return String(localized: "User cancelled update", comment: "General error reason")
        case .connectFailed:
            return String(localized: "Cannot connect for Update", comment: "General error reason")
        case .startFailed:
            return String(localized: "Cannot start update", comment: "General error reason")
        case .unexpectedStart:
            return String(localized: "Update failed and device reset", comment: "General error reason")
        case .deviceError(let errorCode):
            return errorCode.userVisibleDescription()
        case .unknownDeviceError(let code):
            return String(localized: "Unknown error code \(code)")
        }
    }
}
