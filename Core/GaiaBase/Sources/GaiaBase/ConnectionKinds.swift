//
//  © 2020 - 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation

/// ConnectionKind describes the real physical bluetooth transports.
public enum ConnectionKind: Int, CaseIterable {
    case iap2
    case ble
}
