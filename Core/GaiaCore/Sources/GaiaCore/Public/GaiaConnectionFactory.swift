//
//  © 2020 - 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation
import GaiaBase
import GaiaLogger

/// GaiaConnectionFactoryKind differs from ConnectionKind in that allows for a replay file connection that mocks a "ConnectionKind" connection.
public enum GaiaConnectionFactoryKind {
    case ble
    case iap2
    case replayFile(path: URL, mocking: ConnectionKind)
}

public class GaiaConnectionFactory {
    // MARK: Private ivars
    private var connectionSources: [ConnectionKind : ConnectionFactorySource]

    internal weak var delegate: GaiaConnectionFactoryDelegate?

    // MARK: init/deinit
    public required init(kinds: [GaiaConnectionFactoryKind], notificationCenter: NotificationCenter) {
        connectionSources =  [ConnectionKind : ConnectionFactorySource]()

        kinds.forEach { kind in
        	switch kind {
            case .ble:
                let source = BLESource(notificationCenter: notificationCenter)
                source.delegate = self
                connectionSources[.ble] = source
            case .iap2:
                let source = IAP2Source(notificationCenter: notificationCenter)
                source.delegate = self
                connectionSources[.iap2] = source
            case .replayFile(let path, let mocking):
                let source = ReplayFileSource(path: path, notificationCenter: notificationCenter, mockedKind: mocking)
                source.delegate = self
                connectionSources[mocking] = source
            }
        }
    }

    // MARK: Public Methods
    public var isScanning: Bool {
        // result is true is at least one source is scanning.
        var result = false
        connectionSources.values.forEach { source in
            result = result || (source.isScanning && source.isAvailable)
        }
        return result && isAvailable
    }

    public var isAvailable: Bool {
        // result is true is at least one source is available.
        var result = false
        connectionSources.values.forEach { source in
            if source.kind != .iap2 {
                // iAP2 has no way of telling if the BT is on and will always say yes.
            	result = result || source.isAvailable
            }
        }
        return result
    }

    public var devices: [GaiaDeviceProtocol] {
        // Enumerate the kinds in order. IAP2 first
        var devs = [GaiaDeviceProtocol]()

        ConnectionKind.allCases.forEach { kind in
            let kindDevices = connectionSources[kind]?.devices ?? []
            devs.append(contentsOf: kindDevices)
        }

        return devs
    }

    public func clearDeviceList() {
        connectionSources.values.forEach { source in
            source.clearDeviceList()
        }
    }

    public func startScanning() {
        connectionSources.values.forEach { source in
            if source.isAvailable {
            	source.startScanning()
            } else {
                LOG(.medium, "Cannot restart scan \(source.kind) - powered off!!!")
            }
        }
    }

    public func stopScanning() {
        connectionSources.values.forEach { source in
            source.stopScanning()
        }
    }

    public func connect(_ device: GaiaDeviceProtocol) {
        let kind = device.connectionKind
        if let source = connectionSources[kind] {
            source.connect(device)
        }
    }

    public func disconnect(_ device: GaiaDeviceProtocol) {
        let kind = device.connectionKind
        if let source = connectionSources[kind] {
            source.disconnect(device)
        }
    }

    public func cancelConnect(_ device: GaiaDeviceProtocol) {
        let kind = device.connectionKind
        if let source = connectionSources[kind] {
            source.cancelConnect(device)
        }
    }
}

// MARK: - ConnectionFactorySourceDelegate
extension GaiaConnectionFactory: ConnectionFactorySourceDelegate {
    func didDiscoverDevice(_ device: GaiaDeviceProtocol) {
        delegate?.didDiscoverDevice(device)
    }

    func didConnectDevice(_ device: GaiaDeviceProtocol) {
        delegate?.didConnectDevice(device)
    }

    func didFailToConnectDevice(_ device: GaiaDeviceProtocol) {
        delegate?.didFailToConnectDevice(device)
    }

    func didDisconnectDevice(_ device: GaiaDeviceProtocol) {
        delegate?.didDisconnectDevice(device)
    }

    func didChangeState() {
        delegate?.didChangeState()
    }
}
