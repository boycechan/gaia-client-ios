//
//  © 2020 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation
import GaiaBase

protocol ScriptConnectionDelegate: AnyObject {
    func scriptConnected()
    func scriptDisconnected()
}

/// Represents a "replay file" transport to enable offline testing and debug.
class ReplayFileSource: ConnectionFactorySource {
    var kind: ConnectionKind { testConnection.connectionKind }
    private let testDevice: GaiaDevice
    private let testConnection: GaiaReplayScriptDeviceConnection

    var devices: [GaiaDeviceProtocol] {
        return [testDevice]
    }

    private (set) var isScanning: Bool = false
    private (set) var isAvailable: Bool = true
    weak var delegate: ConnectionFactorySourceDelegate?

    init(path: URL,
         notificationCenter: NotificationCenter,
         mockedKind: ConnectionKind) {
        testConnection = GaiaReplayScriptDeviceConnection(path: path, mockedKind: mockedKind)
        testDevice = GaiaDevice(connection: testConnection, notificationCenter: notificationCenter, advertisements: [String : Any]())
        testConnection.delegate = testDevice
        testConnection.scriptDelegate = self
    }

    func clearDeviceList() {
    }

    func startScanning() {
        isScanning = true
        delegate?.didDiscoverDevice(testDevice)
    }

    func stopScanning() {
        isScanning = false
    }

    func connect(_ device: GaiaDeviceProtocol) {
        testConnection.connect()
    }

    func disconnect(_ device: GaiaDeviceProtocol) {
        testConnection.disconnect()
    }

    func cancelConnect(_ device: GaiaDeviceProtocol) {
        // Nothing to do
    }
}

extension ReplayFileSource: ScriptConnectionDelegate {
    func scriptConnected() {
        delegate?.didConnectDevice(testDevice)
    }

    func scriptDisconnected() {
        testDevice.reset()
        delegate?.didDisconnectDevice(testDevice)
    }
}
