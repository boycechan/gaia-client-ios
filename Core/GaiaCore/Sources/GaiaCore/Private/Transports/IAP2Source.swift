//
//  © 2020 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation
import ExternalAccessory
import GaiaBase

/// Represents an iAP2 transport and the manages the connection lifecycle of those devices on that transport.
class IAP2Source: NSObject, ConnectionFactorySource {
    let kind = ConnectionKind.iap2

    private(set) var isScanning: Bool = false

    private(set) var isAvailable: Bool = true

    struct DeviceContainer {
        let index: Int
        let eaAccessory: EAAccessory
        let gaiaDevice: GaiaDeviceProtocol
    }
    private var _devices = [String : DeviceContainer] ()
    var devices: [GaiaDeviceProtocol] {
        return _devices.values.sorted(by: { $0.index < $1.index }).map { $0.gaiaDevice }
    }
    
    private let notificationCenter: NotificationCenter // only used to set up devices.
    weak var delegate: ConnectionFactorySourceDelegate?

    init(notificationCenter: NotificationCenter) {
        self.notificationCenter = notificationCenter
        super.init()

        EAAccessoryManager.shared().registerForLocalNotifications()
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(accessoryDidConnect),
                                               name: .EAAccessoryDidConnect,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(accessoryDidDisconnect),
                                               name: .EAAccessoryDidDisconnect,
                                               object: nil)

    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        EAAccessoryManager.shared().unregisterForLocalNotifications()
    }

    func clearDeviceList() {
        // Because of the way iAP works we can't really dispose of any devices we already know about.
        // This method therefore does nothing.
    }

    func scanConnected() {
        // Start afresh to get rid of stale devices.
        let oldDevices = _devices
        _devices.removeAll()

        // The streams really object to being torn down so we keep them alive
        let connected = EAAccessoryManager.shared().connectedAccessories
        connected.forEach { (accessory) in
            let id = GaiaIAP2DeviceConnection.connectionID(accessory: accessory)
            if let oldEntry = oldDevices[id] {
                _devices[id] = oldEntry
            } else {
                addAccessoryIfAppropriate(accessory: accessory)
            }
        }
    }

    func startScanning() {
        guard !isScanning else { return }

        isScanning = true

        scanConnected()
    }

    func stopScanning() {
        guard isScanning else { return }
        isScanning = false
    }

    private func addAccessoryIfAppropriate(accessory: EAAccessory) {
        let id = GaiaIAP2DeviceConnection.connectionID(accessory: accessory)

        guard _devices[id] == nil &&
            accessory.protocolStrings.contains(Gaia.iap2ProtocolName)
        else {
            return
        }

        let connection = GaiaIAP2DeviceConnection(accessory: accessory, notificationCenter: notificationCenter)
        let gaiaDevice = GaiaDevice(connection: connection, notificationCenter: notificationCenter, advertisements: [String : Any]())
        _devices[id] = DeviceContainer(index: _devices.count, eaAccessory: accessory, gaiaDevice: gaiaDevice)
        delegate?.didDiscoverDevice(gaiaDevice)
        if accessory.isConnected {
            delegate?.didConnectDevice(gaiaDevice)
        }
    }

    func connect(_ device: GaiaDeviceProtocol) {
        guard
            let accessory = getAccessory(gaiaDevice: device),
            accessory.isConnected else {
                return
        }
    }

    func disconnect(_ device: GaiaDeviceProtocol) {
        // We can't actually disconnect a IAP2 device but we can tear down the streams
        guard
            let accessory = getAccessory(gaiaDevice: device),
            accessory.isConnected else {
                return
        }

        if let d = device as? GaiaDevice,
           let c = d.connection as? GaiaIAP2DeviceConnection {
            d.reset()
            c.reset()
        }
    }

    func cancelConnect(_ device: GaiaDeviceProtocol) {
        // Nothing to do
    }

    private func getAccessory(gaiaDevice: GaiaDeviceProtocol) -> EAAccessory? {
        guard let entry = _devices[gaiaDevice.connectionID] else {
            return nil
        }
        return entry.eaAccessory
    }
}

extension IAP2Source {
    @objc func accessoryDidConnect(notification: Notification) {
        if let accessory = notification.userInfo?[EAAccessoryKey] as? EAAccessory {
            addAccessoryIfAppropriate(accessory: accessory)
        }
    }

    @objc func accessoryDidDisconnect(notification: Notification) {
        if let accessory = notification.userInfo?[EAAccessoryKey] as? EAAccessory {
            let id = GaiaIAP2DeviceConnection.connectionID(accessory: accessory)
            if let entry = _devices[id] {
                _devices[id] = nil
                delegate?.didDisconnectDevice(entry.gaiaDevice)
                // Ordering here is important.
                if let d = entry.gaiaDevice as? GaiaDevice,
                   let c = d.connection as? GaiaIAP2DeviceConnection {
                    d.reset()
                    c.reset()
                }
            }
        }
    }
}
