//
//  © 2021 - 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation
import GaiaBase

let unknownString = String(localized: "Unknown", comment: "Unknown")

extension GaiaError {
    func userVisibleDescription() -> String {
        switch self {
        case .writeToDeviceTimedOut:
            return String(localized: "Timed out waiting for acknowledgement.", comment: "General error reason")
        case .deviceVersionCouldNotBeDetermined:
            return String(localized: "Device API version could not be determined.", comment: "General error reason")
        case .transportSetupFailed:
            return String(localized: "Couldn't set up transport.", comment: "Error")
        case .bleBondingTimeout:
            return String(localized: "Bluetooth pairing reset required.", comment: "Error")
        case .systemError(let err):
            return err.localizedDescription
        }
    }
}



