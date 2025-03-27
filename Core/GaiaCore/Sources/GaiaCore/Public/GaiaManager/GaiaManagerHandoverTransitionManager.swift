//
//  © 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation
import GaiaBase
import PluginBase
import GaiaLogger

class GaiaManagerHandoverTransitionManager: GaiaManagerTransitionManagerProtocol {
    private let handoverDevice: GaiaDeviceProtocol

    private var handoverTimeoutTimer: DispatchSourceTimer?

    required init(device: GaiaDeviceProtocol, connectionFactory: GaiaConnectionFactory, notificationCenter: NotificationCenter) {
        self.handoverDevice = device
    }

    deinit {
        cancelTimer()
    }

    func deviceDisconnected(_ device: GaiaDeviceProtocol) {
        guard device.id == self.handoverDevice.id else {
			return
        }
        cancelTimer()
    }

    func deviceConnected(_ device: GaiaDeviceProtocol) { }

    func deviceStateChanged(_ device: GaiaDeviceProtocol) { }

    func waitForHandover(timeout: Int, isStatic: Bool) {
        // There is the possibility of a static handover being
        // cancelled after the notification **with no further notification that this has happened**.
        // We must therefore unpause the DFU after a timeout if the expected disconnect has not happened.
        guard isStatic, // Dynamic handovers are handled differently via pause / unpause
              let plugin = handoverDevice.plugin(featureID: .upgrade) as? GaiaDeviceUpdaterPluginProtocol else {
            return
        }

        LOG(.high, "HANDOVER EXPECTED - PAUSING DFU!!!!")
        plugin.pause() // Tell the plugin to stop sending and wait.

        cancelTimer()

        handoverTimeoutTimer = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
        handoverTimeoutTimer?.setEventHandler(handler: { [weak self, weak plugin] () -> () in
            guard
                let self = self,
                let plugin = plugin else {
                    return
                }

            self.handoverTimeoutTimer = nil

            LOG(.high, "DFU Handover timer timed out - restarting anyway")
            plugin.unpause()
        })

        let timeoutInMS = max(timeout * 1000, 5000)

        handoverTimeoutTimer?.schedule(deadline: DispatchTime.now() + .milliseconds(timeoutInMS))
        handoverTimeoutTimer?.resume()
    }

    func handoverDidHappen(device: GaiaDeviceProtocol) {
        cancelTimer()

        if let d = device as? GaiaDevice {
            d.handoverDidOccur()
        }
    }

    private func cancelTimer() {
        if let _ = handoverTimeoutTimer {
            handoverTimeoutTimer?.cancel()
            handoverTimeoutTimer = nil
        }
    }
}
