//
//  © 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation
import GaiaBase
import GaiaLogger

class GaiaManagerReconnectionManager {
    private let connectionFactory: GaiaConnectionFactory

    private var reconnectionTimer: DispatchSourceTimer?
    private var reconnectingDevice: GaiaDeviceProtocol?

    private(set) var connectedDeviceConnectionID: String?
    private(set) var equivalentConnectionIDs = [String]()

    required init(connectionFactory: GaiaConnectionFactory) {
        self.connectionFactory = connectionFactory
    }

    func startReconnection(for device: GaiaDeviceProtocol, after ms: Int = 0) {
        LOG(.high, "startReconnection: \(device.name)")
        if let reconnectingDevice = reconnectingDevice {
            if reconnectingDevice.connectionID != device.connectionID {
                LOG(.medium, "startReconnection - cancel connect: \(device.name)")
                connectionFactory.cancelConnect(reconnectingDevice)
            } else {
                LOG(.medium, "startReconnection - not restarting as already started?: \(device.name)")
                return // Already started connection.
            }
        }

		reconnectingDevice = device
        attemptReconnection(after: ms)
    }

    func didConnect(_ device: GaiaDeviceProtocol,
                             connectionFactory: GaiaConnectionFactory) {

        LOG(.high, "didConnect: \(device.name)")
        if let reconnectingDevice = reconnectingDevice,
           reconnectingDevice.connectionID != device.connectionID {
            connectionFactory.cancelConnect(reconnectingDevice)
        }

        if let _ = reconnectionTimer {
            reconnectionTimer?.cancel()
            reconnectionTimer = nil
        }

        LOG(.low, "didConnect nulling reconnecting device: \(device.name)")
		reconnectingDevice = nil
        updateIndentificationInfo(device)
    }

    func deviceStateChanged(_ device: GaiaDeviceProtocol) {
        if device.state == .gaiaReady && !equivalentConnectionIDs.contains(device.connectionID) {
            updateIndentificationInfo(device)
        }
    }

    func updateIndentificationInfo(_ device: GaiaDeviceProtocol?) {
        if let device = device {
            connectedDeviceConnectionID = device.connectionID
            equivalentConnectionIDs = device.equivalentConnectionIDsForReconnection
            LOG(.medium, "Updated equivalents to \(equivalentConnectionIDs)")
        } else {
            LOG(.low, "connectedDeviceConnectionID is now nil")
            connectedDeviceConnectionID = nil
            equivalentConnectionIDs = []
        }
    }
}

extension GaiaManagerReconnectionManager {
    private func attemptReconnection(after ms: Int = 0) {
        guard
            let reconnectingDevice = reconnectingDevice
        else {
            reconnectionTimer = nil
            return
        }

        if reconnectingDevice.state == .disconnected && connectionFactory.isAvailable && ms == 0 {
            LOG(.high, "Will try to reconnect \(reconnectingDevice.name).")
            connectionFactory.connect(reconnectingDevice)
        } else {

            let newDelay = ms > 0 ? ms : 5000
            LOG(.high, "Reconnection will be attempted to \(reconnectingDevice.name) in \(newDelay) ms.")
            setUpReconnectionTimer(ms: newDelay)
        }
    }

    private func setUpReconnectionTimer(ms: Int) {
        if let _ = reconnectionTimer {
            reconnectionTimer?.cancel()
            reconnectionTimer = nil
        }

        reconnectionTimer = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
        reconnectionTimer?.setEventHandler(handler: { [weak self] () -> () in
            guard let self = self else {
                return
            }
            self.attemptReconnection(after: 0)
        })

        reconnectionTimer?.schedule(deadline: DispatchTime.now() + .milliseconds(ms))
        reconnectionTimer?.resume()

        LOG(.low, "Timer started")
    }
}
