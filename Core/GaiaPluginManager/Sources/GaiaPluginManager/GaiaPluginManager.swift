//
//  © 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation
import GaiaBase
import PluginBase

public typealias GaiaPluginCreatorFeatureDescription = (featureID: GaiaDeviceQCPluginFeatureID, version: UInt8)

public typealias GaiaDevicePluginCreator = (_ version: UInt8,
                                            _ device: GaiaDeviceIdentifierProtocol,
                                            _ connection: GaiaDeviceConnectionProtocol,
                                            _ notificationCenter: NotificationCenter) -> GaiaDevicePluginProtocol

public class GaiaPluginManager {
    public static let shared = GaiaPluginManager()

    private var creators = [GaiaDeviceQCPluginFeatureID : GaiaDevicePluginCreator] ()

    public func register(featureID: GaiaDeviceQCPluginFeatureID,
                         creator: @escaping GaiaDevicePluginCreator) {
        creators[featureID] = creator
    }

    public func pluginsForNewDevice(_ device: GaiaDeviceIdentifierProtocol,
                                    featureDescriptions: [GaiaPluginCreatorFeatureDescription],
                                    connection: GaiaDeviceConnectionProtocol,
                                    notificationCenter: NotificationCenter) -> [GaiaDevicePluginProtocol] {
        var plugins = [GaiaDevicePluginProtocol] ()
        featureDescriptions.forEach { (featureID, version) in
            if let creator = creators[featureID] {
                let plugin = creator(version, device, connection, notificationCenter)
                plugins.append(plugin)
            }
        }
        return plugins
    }
}

