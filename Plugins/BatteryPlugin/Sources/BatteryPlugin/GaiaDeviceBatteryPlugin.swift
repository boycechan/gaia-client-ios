//
//  © 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation
import GaiaBase
import PluginBase
import Packets
import GaiaLogger

public class GaiaDeviceBatteryPlugin: GaiaDeviceBatteryPluginProtocol, GaiaNotificationSender {
    enum Commands: UInt16 {
        case getSupportedBatteries = 0
        case getBatteryLevel = 1
    }

    // MARK: Private ivars
    private weak var device: GaiaDeviceIdentifierProtocol?
    private let devicePluginVersion: UInt8
    private let connection: GaiaDeviceConnectionProtocol
    private let notificationCenter : NotificationCenter

    private let BatteryLevelUnavailable = 0xff
    private var batteries = Dictionary<BatteryTypes, Int> ()

    // MARK: Public ivars
    public static let featureID: GaiaDeviceQCPluginFeatureID = .battery

    public var supportedBatteries: Set<BatteryTypes> {
        return Set(batteries.keys)
    }

    // MARK: init/deinit
    public required init(version: UInt8,
                  device: GaiaDeviceIdentifierProtocol,
                  connection: GaiaDeviceConnectionProtocol,
                  notificationCenter: NotificationCenter) {
        self.devicePluginVersion = version
        self.device = device
        self.connection = connection
        self.notificationCenter = notificationCenter
    }

    // MARK: Public Methods
    public func startPlugin() {
        fetchSupported()
    }

    public func stopPlugin() {
    }

    public func handoverDidOccur() {
    }

    public func responseReceived(messageDescription: IncomingMessageDescription) {
        guard let _ = device else {
            return
        }

        switch messageDescription {
        case .response(let command, let data):
            if let id = Commands(rawValue: command) {
                switch id {
                case .getSupportedBatteries:
                    processGetSupportedBatteries(data: data)
                case .getBatteryLevel:
                    processGetBatteryLevel(data: data)
                }
            }
        case .error(let command, _, _):
            if let id = Commands(rawValue: command) {
                LOG(.high, "**** Battery command failed \(id) ****")
            }

        default:
            break
        }
    }

    public func didSendData(channel: GaiaDeviceConnectionChannel, error: GaiaError?) {
    }

    public func level(battery: BatteryTypes) -> Int? {
        if let value = batteries[battery],
           value != BatteryLevelUnavailable {
            return value
        }
        return nil
    }

    public func refreshLevels() {
        var payload = Data()
        for battery in batteries.keys {
            switch battery {
            case .known(_):
                payload.append(Data([battery.byteValue()]))
            case .unknown(_):
                break
            }
        }

        if !payload.isEmpty && payload.count <= 16 {
            let message = GaiaV3GATTPacket(featureID: .battery,
                                           commandID: Commands.getBatteryLevel.rawValue,
                                           payload: payload)
            connection.sendData(channel: .command, payload: message.data, acknowledgementExpected: true)
        }
    }
}

// MARK: - Private Methods

private extension GaiaDeviceBatteryPlugin {
    func fetchSupported() {
        let message = GaiaV3GATTPacket(featureID: .battery,
                                       commandID: Commands.getSupportedBatteries.rawValue)
        connection.sendData(channel: .command, payload: message.data, acknowledgementExpected: true)
    }

    func processGetSupportedBatteries(data: Data) {
        batteries.removeAll()
        for index in 0..<data.count {
            let byte = data[index]
            let battery = BatteryTypes(byteValue: byte)
            switch battery {
            case .known(_):
                batteries[battery] = 0
            case .unknown(_):
                break
            }
            batteries[battery] = BatteryLevelUnavailable
        }

        let notification = GaiaDeviceBatteryPluginNotification(sender: self,
                                                               payload: device!,
                                                               reason: .supported)
        notificationCenter.post(notification)

        refreshLevels()
    }

    func processGetBatteryLevel(data: Data) {
        guard data.count % 2 == 0 else {
            return
        }

        for batteryIndex in stride(from: 0, to: data.count, by: 2) {
            let battByte = data[batteryIndex]
            let battery = BatteryTypes(byteValue: battByte)
            let value = data[batteryIndex + 1]
            batteries[battery] = Int(value)
        }

        let notification = GaiaDeviceBatteryPluginNotification(sender: self,
                                                               payload: device!,
                                                               reason: .levelsChanged)
        notificationCenter.post(notification)
    }
}
