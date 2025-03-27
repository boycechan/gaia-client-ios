//
//  © 2020 - 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation
import CoreBluetooth
import GaiaBase
import GaiaLogger


/// This class encapsulates the behavior of a Gaia Device that is discovered/connected/etc using the BLE transport.
public class GaiaBLEDeviceConnection: NSObject, GaiaDeviceConnectionProtocol {

    // MARK: Private ivars
    private let peripheral: CBPeripheral
    private let notificationCenter: NotificationCenter
    private static let standardLength = 23
    private static let interestedServices = [CBUUID(string: Gaia.bleServiceUUID)]
    private var maxReadSize: Int = GaiaBLEDeviceConnection.standardLength
    private var commandCharacteristic: CBCharacteristic?
    private var responseCharacteristic: CBCharacteristic?
    private var dataCharacteristic: CBCharacteristic?
    private var gaiaManagerObserverToken: ObserverToken?
    private var awaitedServices = Set<CBUUID> ()
    private let commandQueue = CommandQueue()

    // MARK: Public ivars
    public weak var delegate: GaiaDeviceConnectionDelegate?
    public var connectionID: String { return Self.connectionID(peripheral: peripheral) }
    public var name: String { return peripheral.name ?? "Unnamed Device" }
    public private(set) var rssi: Int =  0
    public var maxReceivePayloadSizeForGaia: Int { return maxReadSize - 7 /* ATT Header + PDU */ }
    public var maxSendPayloadSizeForGaia: Int { return maximumWriteLength - 7 /* ATT Header + PDU */ }

    public private(set) var isDataLengthExtensionSupported = false
    public private(set) var maximumWriteLength: Int = GaiaBLEDeviceConnection.standardLength
    public private(set) var maximumWriteWithoutResponseLength: Int = GaiaBLEDeviceConnection.standardLength
    public private(set) var optimumWriteLength: Int = GaiaBLEDeviceConnection.standardLength
    public let connectionKind = ConnectionKind.ble

    public class func connectionID(peripheral: CBPeripheral) -> String {
        return "BLE-\(peripheral.identifier.uuidString)"
    }

    public var connected: Bool {
        return peripheral.state == .connected
    }

    public private(set) var state: GaiaDeviceConnectionState = .disconnected {
        didSet {
            delegate?.stateChanged(connection: self)
        }
    }

    // MARK: init/deinit
    public required init(peripheral: CBPeripheral,
                  notificationCenter: NotificationCenter,
                  rssiOnDiscovery: Int) {
        self.peripheral = peripheral
        self.rssi = rssiOnDiscovery
        self.notificationCenter = notificationCenter

        super.init()

        peripheral.delegate = self
        commandQueue.delegate = self
        state = connected ? .uninitialised : .disconnected

        gaiaManagerObserverToken = notificationCenter.addObserver(forType: GaiaManagerNotification.self,
                                                                          object: nil,
                                                                          queue: OperationQueue.main,
                                                                          using: { [weak self] notification in self?.gaiaManagerNotificationHandler(notification) })
    }

    deinit {
        notificationCenter.removeObserver(gaiaManagerObserverToken!)
    }

    // MARK: Public Methods
    public func start() {
        if state == .uninitialised {
            state = .initialising
            peripheral.readRSSI()
            peripheral.discoverServices(nil)
        }
    }

    public func sendData(channel: GaiaDeviceConnectionChannel, payload: Data, acknowledgementExpected: Bool) {
        if connected && state == .ready {
            switch channel {
            case .command:
                commandQueue.queueItem(CommandQueue.Command(data: payload, acknowledgementExpected: acknowledgementExpected))
                writeToCommandCharacteristicFromQueue()
            case .data:
                peripheral.writeValue(payload, for: dataCharacteristic!, type: .withoutResponse)
            default:
                break
            }
        }
    }

    public func acknowledgementReceived() {
        commandQueue.acknowledgementReceived()
        writeToCommandCharacteristicFromQueue()
     }

    public func transportParametersReceived(protocolVersion: Int, maxSendSize: Int, optimumSendSize: Int, maxReceiveSize: Int) {
        let max = isDataLengthExtensionSupported ? 255 : GaiaBLEDeviceConnection.standardLength
        LOG(.low, "Defaults BLE: maxSend: \(maximumWriteLength) optimumSend: \(optimumWriteLength) maxRead: \(maxReadSize)")
        LOG(.low, "Received BLE: protocol: \(protocolVersion) maxSend: \(maxSendSize) optimumSend: \(optimumSendSize) maxRead: \(maxReceiveSize)")
        maximumWriteLength = min(max, maxSendSize)
        maximumWriteWithoutResponseLength = min(max, maxSendSize)
        optimumWriteLength = min(max, optimumSendSize)
        maxReadSize = maxReceiveSize

        LOG(.medium, "Now BLE: maxSend: \(maximumWriteLength) optimumSend: \(optimumWriteLength) maxRead: \(maxReadSize)")
    }

    public func equivalentConnectionIDsForReconnection(btAddresses: [String], serialNumbers: [String]) -> [String] {
        return [connectionID] // Both devices in a pair should have the same BT connection ID.
    }
}

// MARK: - CommandQueueDelegate
extension GaiaBLEDeviceConnection: CommandQueueDelegate {
    func commandQueueTimedOut(_ queue: CommandQueue) {
        delegate?.didSendData(channel: .command, error: .writeToDeviceTimedOut)
        writeToCommandCharacteristicFromQueue()
    }
}

// MARK: - CBPeripheralDelegate
extension GaiaBLEDeviceConnection: CBPeripheralDelegate {
    public func peripheral(_ peripheral: CBPeripheral,
                    didReadRSSI RSSI: NSNumber,
                    error: Error?) {
        if let e = error {
            // Failed
            LOG(.low, "Failed to get RSSI: \(e)")
            rssi = 0
        } else {
            rssi = RSSI.intValue
            delegate?.rssiDidChange()
        }
    }

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        let characteristics = [CBUUID(string: Gaia.commandCharacteristicUUID),
                               CBUUID(string: Gaia.responseCharacteristicUUID),
                               CBUUID(string: Gaia.dataCharacteristicUUID)]
        guard state == .initialising else {
            return
        }
        LOG(.medium, "Discovered Services: \(String(describing: peripheral.services))")
        LOG(.low, "Interested Services: \(String(describing: GaiaBLEDeviceConnection.interestedServices))")
        peripheral.services?.forEach {
            if GaiaBLEDeviceConnection.interestedServices.contains($0.uuid) &&
                !awaitedServices.contains($0.uuid) {
                awaitedServices.insert($0.uuid)
                LOG(.low, "Found service for UUID: \($0.uuid) discovering characteristics")
                peripheral.discoverCharacteristics(characteristics, for: $0)
            }
        }
    }

    public func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
    }

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if awaitedServices.contains(service.uuid) {
            LOG(.low, "Found characteristics for service: \(service.uuid)")
            awaitedServices.remove(service.uuid)
            service.characteristics?.forEach {
                LOG(.low, "Requesting descriptor for : \($0.uuid)")
                peripheral.discoverDescriptors(for: $0)
            }

            if awaitedServices.count == 0 {
                LOG(.low, "Processed all awaiting services")
                // All done - find characteristics
                if peripheral.state == .connected {
                    LOG(.low, "Peripheral state is connected")
                    if !findGaiaCharacteristics() {
                        LOG(.high, "Connected but cannot find Gaia Characteristics")
                        state = .initialisationFailed
                    }
                } else {
                    LOG(.low, "Peripheral state is *not* connected = \(peripheral.state)")
                    state = .disconnected
                }
            }
        }
    }

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverDescriptorsFor characteristic: CBCharacteristic, error: Error?) {
        LOG(.low, "Found Descriptors")
    }

    private func notifyUpdate(characteristic: CBCharacteristic, error: Error?) {
        if let e = error {
            LOG(.medium, "Error: \(e.localizedDescription)")
            return
        }

        guard state == .ready,
            let data = characteristic.value else {
            return
        }

        switch characteristic.uuid {
        case commandCharacteristic?.uuid:
            delegate?.dataReceived(data, channel: .command)
        case responseCharacteristic?.uuid:
            delegate?.dataReceived(data, channel: .response)
        case dataCharacteristic?.uuid:
            delegate?.dataReceived(data, channel: .data)

        default:
            break
        }
    }

    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        notifyUpdate(characteristic: characteristic, error: error)
    }

    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor descriptor: CBDescriptor, error: Error?) {
    	#if swift(>=5.5) // iOS 15 / Xcode 13 changed CBDescriptor.characteristic to weak from assign
			if let characteristic = descriptor.characteristic {
    			notifyUpdate(characteristic: characteristic, error: error)
			}
		#else
    		notifyUpdate(characteristic: descriptor.characteristic, error: error)
    	#endif
    }

    public func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        LOG(.low, "Updated Notification State for \(characteristic) isNotifying: \(characteristic.isNotifying)")
        if characteristic.uuid == responseCharacteristic?.uuid && characteristic.isNotifying {
            LOG(.low, "Connection Available on response characteristic")
        }

        if characteristic.uuid == dataCharacteristic?.uuid && characteristic.isNotifying {
            state = .ready
            LOG(.low, "Connection Available on data characteristic")
        }
    }

    public func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        var gError: GaiaError? = nil
        if let error = error {
            let nsError = error as NSError
            if nsError.domain == "CBATTErrorDomain" && (nsError.code == 15 || nsError.code == 5) {
                // Encryption error. Some sort of pairing issue - maybe the user clicked cancel to the connection dialog or
                // the BLE bonding timeout has occured.
                gError = .bleBondingTimeout
            } else {
                gError = .systemError(error)
            }
        }

        switch characteristic.uuid {
        case commandCharacteristic?.uuid:
            delegate?.didSendData(channel: .command, error: gError)
        case responseCharacteristic?.uuid:
            delegate?.didSendData(channel: .response, error: gError)
        case dataCharacteristic?.uuid:
            delegate?.didSendData(channel: .data, error: gError)

        default:
            break
        }
    }
}

// MARK: - Notification Handlers
private extension GaiaBLEDeviceConnection {
    func gaiaManagerNotificationHandler(_ notification: GaiaManagerNotification) {
        switch notification.payload {
        case .device(let device):
            if device.connectionID == connectionID {
                switch notification.reason {
                case .connectSuccess:
                    // We do this after connection
                    // Maximum is 64 as that works reliably.
                    maximumWriteLength = min(64, peripheral.maximumWriteValueLength(for: .withResponse))
                    maximumWriteLength = maximumWriteLength > 0 ?
                        maximumWriteLength :
                        GaiaBLEDeviceConnection.standardLength

                    maximumWriteWithoutResponseLength = min(64, peripheral.maximumWriteValueLength(for: .withoutResponse))
                    maximumWriteWithoutResponseLength = maximumWriteWithoutResponseLength > 0 ?
                        maximumWriteWithoutResponseLength :
                        GaiaBLEDeviceConnection.standardLength

                    isDataLengthExtensionSupported = maximumWriteLength > GaiaBLEDeviceConnection.standardLength
                    optimumWriteLength = maximumWriteLength
                    state = .uninitialised
                case .connectFailed,
                     .disconnect:
                    commandQueue.reset()
                    awaitedServices.removeAll()
                    commandCharacteristic = nil
                    responseCharacteristic = nil
                    dataCharacteristic = nil
                    LOG(.high, "GaiaBLEDeviceConnection - disconnect or connectFailed")
                    state = .disconnected
                    break
                default:
                    break
                }
            }
        default:
            break
        }
    }
}

// MARK: - Private methods
private extension GaiaBLEDeviceConnection {
    func writeToCommandCharacteristicFromQueue() {
        if commandQueue.itemAvailable && connected && state == .ready {
            let item = commandQueue.removeItem()!
            peripheral.writeValue(item.data, for: commandCharacteristic!, type: .withResponse)
        }
    }

    func findGaiaCharacteristics() -> Bool {
        guard let gaiaService = findGaiaService() else {
            return false
        }
        commandCharacteristic = findCharacteristic(uuid: CBUUID(string: Gaia.commandCharacteristicUUID),
                                                   service: gaiaService)
        responseCharacteristic = findCharacteristic(uuid: CBUUID(string: Gaia.responseCharacteristicUUID),
                                                   service: gaiaService)
        dataCharacteristic = findCharacteristic(uuid: CBUUID(string: Gaia.dataCharacteristicUUID),
                                                   service: gaiaService)

        if responseCharacteristic != nil {
            LOG(.low, "Setting Notify on response")
            peripheral.setNotifyValue(true, for: responseCharacteristic!)
        }

        if dataCharacteristic != nil {
            LOG(.low, "Setting Notify on data")
            peripheral.setNotifyValue(true, for: dataCharacteristic!)
        }
        return commandCharacteristic != nil &&
            responseCharacteristic != nil &&
            dataCharacteristic != nil
    }

    func findGaiaService() -> CBService? {
        let uuid = CBUUID(string: Gaia.bleServiceUUID)
        return peripheral.services?.first {
            $0.uuid == uuid
        }
    }

    func findCharacteristic(uuid: CBUUID, service: CBService) -> CBCharacteristic? {
        return service.characteristics?.first {
            $0.uuid == uuid
        }
    }
}


