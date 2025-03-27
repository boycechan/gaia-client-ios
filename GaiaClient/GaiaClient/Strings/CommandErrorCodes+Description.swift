//
//  © 2023 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation
import GaiaBase

extension Gaia.CommandErrorCodes {
    public func userVisibleDescription() -> String {
        switch self {
        case .success:
            return String(localized: "Everything is fine", comment: "Error Code")
        case .failedNotSupported:
            return String(localized: "An invalid Command ID was specified", comment: "Error Code")
        case .failedNotAuthenticated:
            return String(localized: "The host is not authenticated to use a Command ID or control a Feature Type", comment: "Error Code")
        case .failedInsufficientResources:
            return String(localized: "The command was valid, but the device could not successfully carry out the command", comment: "Error Code")
        case .authenticating:
            return String(localized: "The device is in the process of authenticating the host", comment: "Error Code")
        case .invalidParameter:
            return String(localized: "An invalid parameter was used in the command", comment: "Error Code")
        case .incorrectState:
            return String(localized: "The device is not in the correct state to process the command", comment: "Error Code")
        case .inProgress:
            return String(localized: "The command is already in progress", comment: "Error Code")
        case .noStatusAvailable:
            return String(localized: "No status available", comment: "Error Code")
        }
    }
}
