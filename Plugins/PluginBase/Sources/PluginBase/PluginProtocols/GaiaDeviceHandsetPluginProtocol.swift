//
//  © 2021 - 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation

public protocol GaiaDeviceHandsetPluginProtocol: GaiaDevicePluginProtocol {
    var multipointEnabled: Bool { get }
    func setEnableMultipoint(_ state: Bool)
}
