//
//  © 2020 - 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation
import GaiaBase

public typealias VendorExtensionCreator = (_ device: GaiaDeviceProtocol,
    _ connection: GaiaDeviceConnectionProtocol,
    _ notificationCenter: NotificationCenter) -> GaiaDeviceVendorExtensionProtocol

public class VendorExtensionManager {
    public static let shared = VendorExtensionManager()

    private var creators = [VendorExtensionCreator] ()

    public func register(creator: @escaping VendorExtensionCreator) {
        creators.append(creator)
    }

    func vendorExtensionsForNewDevice(_ device: GaiaDeviceProtocol,
                                      connection: GaiaDeviceConnectionProtocol,
                                      notificationCenter: NotificationCenter) -> [GaiaDeviceVendorExtensionProtocol] {
        return creators.map { creator in
            return creator(device, connection, notificationCenter)
        }
    }
}
