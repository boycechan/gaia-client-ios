//
//  © 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation

public enum GaiaError: Error {
    case writeToDeviceTimedOut
    case deviceVersionCouldNotBeDetermined
    case transportSetupFailed

    case systemError(Error)
    case bleBondingTimeout
}

