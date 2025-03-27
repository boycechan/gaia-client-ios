//
//  © 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation
import GaiaBase
import PluginBase
import GaiaPluginManager
import CorePlugin
import UpdaterPlugin
import EarbudFitPlugin
import AudioCurationPlugin
import LegacyANCPlugin
import BatteryPlugin
import EarbudPlugin
import EarbudUIPlugin
import EQPlugin
import HandsetPlugin
import StatisticsPlugin
import VoiceAssistantPlugin
import VoiceProcessingPlugin

public enum GaiaSupportedPlugins {
    public static func register() {
        GaiaPluginManager.shared.register(featureID: GaiaDeviceCorePlugin.featureID,
                                          creator: { (version, device, connection, notificationCenter) -> GaiaDevicePluginProtocol in
            return GaiaDeviceCorePlugin(version: version,
                                        device: device,
                                        connection: connection,
                                        notificationCenter: notificationCenter)
        })
        
        GaiaPluginManager.shared.register(featureID: GaiaDeviceUpdaterPlugin.featureID,
                                          creator: { (version, device, connection, notificationCenter) -> GaiaDevicePluginProtocol in
            return GaiaDeviceUpdaterPlugin(version: version,
                                           device: device,
                                           connection: connection,
                                           notificationCenter: notificationCenter)
        })
        
        GaiaPluginManager.shared.register(featureID: GaiaDeviceEarbudFitPlugin.featureID,
                                          creator: { (version, device, connection, notificationCenter) -> GaiaDevicePluginProtocol in
            return GaiaDeviceEarbudFitPlugin(version: version,
                                             device: device,
                                             connection: connection,
                                             notificationCenter: notificationCenter)
        })
        
        GaiaPluginManager.shared.register(featureID: GaiaDeviceAudioCurationPlugin.featureID,
                                          creator: { (version, device, connection, notificationCenter) -> GaiaDevicePluginProtocol in
            return GaiaDeviceAudioCurationPlugin(version: version,
                                                 device: device,
                                                 connection: connection,
                                                 notificationCenter: notificationCenter)
        })
        
        GaiaPluginManager.shared.register(featureID: GaiaDeviceLegacyANCPlugin.featureID,
                                          creator: { (version, device, connection, notificationCenter) -> GaiaDevicePluginProtocol in
            return GaiaDeviceLegacyANCPlugin(version: version,
                                             device: device,
                                             connection: connection,
                                             notificationCenter: notificationCenter)
        })
        
        GaiaPluginManager.shared.register(featureID: GaiaDeviceBatteryPlugin.featureID,
                                          creator: { (version, device, connection, notificationCenter) -> GaiaDevicePluginProtocol in
            return GaiaDeviceBatteryPlugin(version: version,
                                           device: device,
                                           connection: connection,
                                           notificationCenter: notificationCenter)
        })
        
        GaiaPluginManager.shared.register(featureID: GaiaDeviceEarbudPlugin.featureID,
                                          creator: { (version, device, connection, notificationCenter) -> GaiaDevicePluginProtocol in
            return GaiaDeviceEarbudPlugin(version: version,
                                          device: device,
                                          connection: connection,
                                          notificationCenter: notificationCenter)
        })

        GaiaPluginManager.shared.register(featureID: GaiaDeviceEarbudUIPlugin.featureID,
                                          creator: { (version, device, connection, notificationCenter) -> GaiaDevicePluginProtocol in
            return GaiaDeviceEarbudUIPlugin(version: version,
                                            device: device,
                                            connection: connection,
                                            notificationCenter: notificationCenter)
        })
        
        GaiaPluginManager.shared.register(featureID: GaiaDeviceEQPlugin.featureID,
                                          creator: { (version, device, connection, notificationCenter) -> GaiaDevicePluginProtocol in
            return GaiaDeviceEQPlugin(version: version,
                                      device: device,
                                      connection: connection,
                                      notificationCenter: notificationCenter)
        })
        
        GaiaPluginManager.shared.register(featureID: GaiaDeviceHandsetPlugin.featureID,
                                          creator: { (version, device, connection, notificationCenter) -> GaiaDevicePluginProtocol in
            return GaiaDeviceHandsetPlugin(version: version,
                                           device: device,
                                           connection: connection,
                                           notificationCenter: notificationCenter)
        })
        
        GaiaPluginManager.shared.register(featureID: GaiaDeviceStatisticsPlugin.featureID,
                                          creator: { (version, device, connection, notificationCenter) -> GaiaDevicePluginProtocol in
            return GaiaDeviceStatisticsPlugin(version: version,
                                              device: device,
                                              connection: connection,
                                              notificationCenter: notificationCenter)
        })
        
        GaiaPluginManager.shared.register(featureID: GaiaDeviceVoiceAssistantPlugin.featureID,
                                          creator: { (version, device, connection, notificationCenter) -> GaiaDevicePluginProtocol in
            return GaiaDeviceVoiceAssistantPlugin(version: version,
                                                  device: device,
                                                  connection: connection,
                                                  notificationCenter: notificationCenter)
        })

        GaiaPluginManager.shared.register(featureID: GaiaDeviceVoiceProcessingPlugin.featureID,
                                          creator: { (version, device, connection, notificationCenter) -> GaiaDevicePluginProtocol in
            return GaiaDeviceVoiceProcessingPlugin(version: version,
                                                   device: device,
                                                   connection: connection,
                                                   notificationCenter: notificationCenter)
        })
    }
}
