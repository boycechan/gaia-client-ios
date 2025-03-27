//
//  © 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation
import GaiaBase
import PluginBase
import GaiaLogger

class GaiaManagerUpdateRestartTransitionManager: GaiaManagerTransitionManagerProtocol, GaiaNotificationSender {
    private let connectionFactory: GaiaConnectionFactory
    private let notificationCenter: NotificationCenter
    private let updatingDevice: GaiaDeviceProtocol

    private var ongoingDFUState = DFUState.none
    private var transferCompleted: Bool

    private var dfuReconnectionTimeoutTimer: DispatchSourceTimer?
    private let DFUReconnectionTimeoutIntervalSecs = 30 // Seconds

    private var equivalentConnectionIDs = [String]()

    required init(device: GaiaDeviceProtocol, connectionFactory: GaiaConnectionFactory, notificationCenter: NotificationCenter) {
        self.connectionFactory = connectionFactory
        self.notificationCenter = notificationCenter
        self.updatingDevice = device
        equivalentConnectionIDs = device.equivalentConnectionIDsForReconnection
        if let plugin = device.plugin(featureID: .upgrade) as? GaiaDeviceUpdaterPluginProtocol {
            ongoingDFUState = plugin.ongoingDFUState
        } else {
            ongoingDFUState = .none
        }
        transferCompleted = false
    }

    deinit {
        if let _ = dfuReconnectionTimeoutTimer {
            dfuReconnectionTimeoutTimer?.cancel()
            dfuReconnectionTimeoutTimer = nil
        }
    }

    func deviceDisconnected(_ device: GaiaDeviceProtocol) {
        guard device.id == self.updatingDevice.id else {
            return
        }

        if let plugin = device.plugin(featureID: .upgrade) as? GaiaDeviceUpdaterPluginProtocol {
            switch plugin.updateState {
            case .busy(progress: let progress):
                if progress == .restarting {
                    setUpDFUReconnectionTimeoutTimer()
                    transferCompleted = true
                }
            default:
                break
            }
        }
    }

    func deviceConnected(_ device: GaiaDeviceProtocol) { }

    func deviceStateChanged(_ device: GaiaDeviceProtocol) {
        if device.state == .gaiaReady && equivalentConnectionIDs.contains(device.connectionID) {
            LOG(.medium, "MATCHED IDS")

            var dfuConnectionID: String? = nil
            var fileData: Data? = nil
            var settings: UpdateTransportOptions? = nil
            switch ongoingDFUState {
            case .active(let id, let s, let d):
                dfuConnectionID = id
                fileData = d
                settings = s
            default:
                break
            }

            if let plugin = device.plugin(featureID: .upgrade) as? GaiaDeviceUpdaterPluginProtocol,
               let dfuConnectionID = dfuConnectionID,
               let fileData = fileData,
               let settings = settings,
               equivalentConnectionIDs.contains(dfuConnectionID) {

                if !plugin.isUpdating {
                    LOG(.high, "Sending restart of update after reconnection...")
                    if let _ = dfuReconnectionTimeoutTimer {
                        dfuReconnectionTimeoutTimer?.cancel()
                        dfuReconnectionTimeoutTimer = nil
                    }

                    LOG(.low, "Data: \(fileData.count) bytes Settings: \(settings)")
                    plugin.startUpdate(fileData: fileData, requestedSettings: settings, previousTransferCompleted: transferCompleted)
                } else {
                    // We may have paused due to error. Upon re-establishment of response state moves again to GaiaReady.
                    // DFU therefore will need to be unpaused.
                    plugin.unpause()
                }
            }
        }
    }

    func updateIndentificationInfo(_ device: GaiaDeviceProtocol?) {
        if let device = device {
            equivalentConnectionIDs = device.equivalentConnectionIDsForReconnection
        }
    }
}

private extension GaiaManagerUpdateRestartTransitionManager {
    private func setUpDFUReconnectionTimeoutTimer() {
        LOG(.medium, "Starting timeout timer...")
        if let _ = dfuReconnectionTimeoutTimer {
            dfuReconnectionTimeoutTimer?.cancel()
            dfuReconnectionTimeoutTimer = nil
        }

        dfuReconnectionTimeoutTimer = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
        dfuReconnectionTimeoutTimer?.setEventHandler(handler: { [weak self] () -> () in
            guard let self = self else {
                return
            }

            self.dfuReconnectionTimeoutTimer = nil

            LOG(.high, "DFU Reconnection timer timed out")
            self.ongoingDFUState = .none

            let notification = GaiaManagerNotification(sender: self,
                                                       payload: .system,
                                                       reason: .dfuReconnectTimeout)
            self.notificationCenter.post(notification)
            self.connectionFactory.startScanning()
        })

        let timeoutInMS = DFUReconnectionTimeoutIntervalSecs * 1000

        dfuReconnectionTimeoutTimer?.schedule(deadline: DispatchTime.now() + .milliseconds(timeoutInMS))
        dfuReconnectionTimeoutTimer?.resume()
    }
}
