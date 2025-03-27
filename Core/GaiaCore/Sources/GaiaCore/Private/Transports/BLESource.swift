//
//  © 2020 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation
import CoreBluetooth
import GaiaBase
import GaiaLogger

/// Represents a BLE transport and the manages the connection lifecycle of those devices on that transport.
class BLESource: NSObject, ConnectionFactorySource {
    let kind = ConnectionKind.ble
    struct DeviceContainer {
        let index: Int
        let cbPeripheral: CBPeripheral
        let gaiaDevice: GaiaDeviceProtocol
    }
    private var _devices = [String: DeviceContainer] ()
    var devices: [GaiaDeviceProtocol] {
        return _devices.values.sorted(by: { $0.index < $1.index }).map { $0.gaiaDevice }
    }

    private let notificationCenter: NotificationCenter // only used to set up devices.
    private var centralManager: CBCentralManager!
    weak var delegate: ConnectionFactorySourceDelegate?

    var isScanning: Bool {
        return centralManager.isScanning
    }

    var isAvailable: Bool {
        return centralManager.state == . poweredOn
    }

    init(notificationCenter: NotificationCenter) {
        self.notificationCenter = notificationCenter
        super.init()

        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    func clearDeviceList() {
        if !isScanning && isAvailable {
			_devices.removeAll()
        }
    }

    func startScanning() {
        if !isScanning && isAvailable {
            LOG(.low, "Starting BLE scan")

            let services = [CBUUID(string: Gaia.bleServiceUUID)]
            let currentConnected = centralManager.retrieveConnectedPeripherals(withServices: services)
            currentConnected.forEach { cbPeripheral in
                LOG(.low, "Current connected: \(cbPeripheral.name ?? "not known")")
                let id = GaiaBLEDeviceConnection.connectionID(peripheral: cbPeripheral)
                if _devices[id] == nil && supportsGaia(peripheral: cbPeripheral) {
                    registerAndPostAboutDiscovery(peripheral: cbPeripheral, rssi: 0, advertisements: [String : Any]())
                }
            }

            centralManager.scanForPeripherals(withServices: nil, options: nil)
        } else {
            LOG(.low, "BLE Source cannot rescan")
        }
    }

    func stopScanning() {
        if isScanning && isAvailable {
            LOG(.low, "Stopping scan")
            centralManager.stopScan()
        }
    }

    func connect(_ device: GaiaDeviceProtocol) {
        if let cbDevice = getCBPeripheral(gaiaDevice: device),
            centralManager.state != .poweredOff {
            if device.state == .disconnected {
            	centralManager.connect(cbDevice)/*,
                                       options: [CBConnectPeripheralOptionEnableTransportBridgingKey: true])*/
            } else if device.state == .awaitingTransportSetUp {
                device.startConnection()
            }
        } else {
            LOG(.medium, "Central Manager is powered off/device is not present so cannot connect .")
        }
    }

    func disconnect(_ device: GaiaDeviceProtocol) {
        if let cbDevice = getCBPeripheral(gaiaDevice: device),
            device.state != .disconnected {
            centralManager.cancelPeripheralConnection(cbDevice)
        }
    }

    func cancelConnect(_ device: GaiaDeviceProtocol) {
        if let cbDevice = getCBPeripheral(gaiaDevice: device) {
            centralManager.cancelPeripheralConnection(cbDevice)
        }
    }
}

private extension BLESource {
    func getCBPeripheral(gaiaDevice: GaiaDeviceProtocol) -> CBPeripheral? {
        guard let entry = _devices[gaiaDevice.connectionID] else {
            return nil
        }
        return entry.cbPeripheral
    }

    func supportsGaia(peripheral: CBPeripheral) -> Bool {
        return peripheral.name != nil
    }

    func registerAndPostAboutDiscovery(peripheral: CBPeripheral,
                                       rssi: Int,
                                       advertisements: [String : Any]) {
        let connection = GaiaBLEDeviceConnection(peripheral: peripheral,
                                                 notificationCenter: notificationCenter,
                                                 rssiOnDiscovery: rssi)
        let gaiaDevice = GaiaDevice(connection: connection, notificationCenter: notificationCenter, advertisements: advertisements)
        _devices[connection.connectionID] = DeviceContainer(index: _devices.count, cbPeripheral: peripheral, gaiaDevice: gaiaDevice)
        delegate?.didDiscoverDevice(gaiaDevice)
    }
}

extension BLESource: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if centralManager.state == .poweredOff {
            LOG(.medium, "BLE Central Powered off - notifying disconnection of all connected devices")
            // If the user "turns off" BT using Control Center we don't get automatic disconnection notifications.
            for device in devices {
                LOG(.low, "\(device.name) is \(device.state)")
                if device.state != .disconnected {
                    delegate?.didDisconnectDevice(device)
                }
                device.reset()
            }
        }
        delegate?.didChangeState()
    }

    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String : Any],
                        rssi RSSI: NSNumber) {
        if supportsGaia(peripheral: peripheral) {
            if _devices[GaiaBLEDeviceConnection.connectionID(peripheral: peripheral)] == nil {
                LOG(.medium, "Discovered: \(peripheral)\nAdverts: \(String(describing: advertisementData))")
            	registerAndPostAboutDiscovery(peripheral: peripheral, rssi: RSSI.intValue, advertisements: advertisementData)
            }
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        if supportsGaia(peripheral: peripheral) {
            let id = GaiaBLEDeviceConnection.connectionID(peripheral: peripheral)
            if _devices[id] == nil {
                registerAndPostAboutDiscovery(peripheral: peripheral, rssi: 0, advertisements: [String : Any]())
            }

            if let entry = _devices[id] {
                LOG(.medium, "Central Manager Connected Device: \(peripheral)")
                delegate?.didConnectDevice(entry.gaiaDevice)
            }
        }
    }

    func centralManager(_ central: CBCentralManager,
                        didFailToConnect peripheral: CBPeripheral,
                        error: Error?) {
        let id = GaiaBLEDeviceConnection.connectionID(peripheral: peripheral)
        if let entry = _devices[id] {
            delegate?.didFailToConnectDevice(entry.gaiaDevice)
        }
    }

    func centralManager(_ central: CBCentralManager,
                        didDisconnectPeripheral peripheral: CBPeripheral,
                        error: Error?) {
        LOG(.medium, "Central disconnected: \(peripheral)")
        let id = GaiaBLEDeviceConnection.connectionID(peripheral: peripheral)

        if let entry = _devices[id] {
            delegate?.didDisconnectDevice(entry.gaiaDevice)
            // Ordering here is important.
            entry.gaiaDevice.reset()
        }
    }
}
