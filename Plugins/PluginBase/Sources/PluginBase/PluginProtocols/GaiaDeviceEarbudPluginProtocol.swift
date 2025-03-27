//
//  © 2020 - 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation

public protocol GaiaDeviceEarbudPluginProtocol: GaiaDevicePluginProtocol {
    var secondEarbudSerialNumber: String? { get }
    var leftEarbudIsPrimary: Bool { get }
}
