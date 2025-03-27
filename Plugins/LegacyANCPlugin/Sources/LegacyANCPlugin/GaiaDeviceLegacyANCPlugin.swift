//
//  © 2020 - 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation
import GaiaBase
import PluginBase
import Packets
import GaiaLogger

public class GaiaDeviceLegacyANCPlugin: GaiaDeviceLegacyANCPluginProtocol, GaiaNotificationSender {
    enum Commands: UInt16 {
        case getANCState = 1
        case setANCState = 2
        case getNumANCModes = 3
        case getANCMode = 4
        case setANCMode = 5
        case getConfiguredLeakthroughGain = 6
        case setConfiguredLeakthroughGain = 7
    }

    enum Notifications:  UInt8 {
        case ANCStateChanged = 0
        case ANCModeChanged = 1
        case ANCGainChanged = 2
        case adaptiveANCStateChanged = 3
        case adaptiveANCGainChanged = 4
    }

    // MARK: Private ivars
    private weak var device: GaiaDeviceIdentifierProtocol?
    private let devicePluginVersion: UInt8
    private let connection: GaiaDeviceConnectionProtocol
    private let notificationCenter : NotificationCenter

    // MARK: Public ivars
    public static let featureID: GaiaDeviceQCPluginFeatureID = .legacyANC

    public private(set) var enabled: Bool = false
    public private(set) var isLeftAdaptive: Bool = false
    public private(set) var isRightAdaptive: Bool = false
    public private(set) var leftAdaptiveGain: Int = 0
    public private(set) var rightAdaptiveGain: Int = 0
    public private(set) var currentMode: Int = 0
    public private(set) var maxMode: Int = 0
    public private(set) var staticGain: Int = 0

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
        getCurrentState()
        getNumberOfModes()
        getCurrentMode()
        getStaticGain()
    }

    public func stopPlugin() {
    }

    public func handoverDidOccur() {
    }

    public func responseReceived(messageDescription: IncomingMessageDescription) {
        guard let device = device else {
            return
        }
        
        switch messageDescription {
        case .notification(let notificationID, let data):
            guard let notification = Notifications(rawValue: notificationID) else {
                LOG(.medium, "ANC Non valid notification id")
                return
            }
            switch notification {
            case .ANCStateChanged:
                processNewANCState(data: data)
            case .ANCModeChanged:
                processNewANCMode(data: data)
            case .ANCGainChanged:
                processNewANCStaticGain(data: data)
            case .adaptiveANCStateChanged:
                guard data.count == 2 else {
                    LOG(.medium, "ANC Wrong data length for \(notification)")
                    return
                }
                let isLeftEarbud = data[0] == 0
                let isEnabled = data[1] == 1
                if isLeftEarbud {
					isLeftAdaptive = isEnabled
                } else {
                    isRightAdaptive = isEnabled
                }
                let notification = GaiaDeviceLegacyANCPluginNotification(sender: self,
                                                                           payload: device,
                                                                           reason: .adaptiveStateChanged)
                notificationCenter.post(notification)

            case .adaptiveANCGainChanged:
                guard data.count == 2 else {
                    LOG(.medium, "ANC Wrong data length for \(notification)")
                    return
                }
                let isLeftEarbud = data[0] == 0
                let gain = Int(data[1])
                if isLeftEarbud {
                    leftAdaptiveGain = gain
                } else {
                    rightAdaptiveGain = gain
                }
                let notification = GaiaDeviceLegacyANCPluginNotification(sender: self,
                                                                           payload: device,
                                                                           reason: .gainChanged)
                notificationCenter.post(notification)
            }
        case .response(let commandID, let data):
            guard let command = Commands(rawValue: commandID) else {
                LOG(.medium, "ANC Non valid command id")
                return
            }

            switch command {
            case .getANCState:
                processNewANCState(data: data)
            case .getNumANCModes:
                guard data.count > 0 else {
                    LOG(.medium, "ANC Wrong data length for \(command)")
                    return
                }
                maxMode = max(0, (min(Int(data[0]) - 1, 9)))
            case .getANCMode:
                processNewANCMode(data: data)
            case .getConfiguredLeakthroughGain:
                processNewANCStaticGain(data: data)
            case .setANCState,
                 .setANCMode,
                 .setConfiguredLeakthroughGain:
                break
            }
        case .error(_, _, _):
            break
        default:
            break
        }
    }

    public func didSendData(channel: GaiaDeviceConnectionChannel, error: GaiaError?) {

    }
}

// MARK: - Public "Setter" Methods
public extension GaiaDeviceLegacyANCPlugin {
    func setEnabledState(_ enabled: Bool) {
        let message = GaiaV3GATTPacket(featureID: featureID,
                                       commandID: Commands.setANCState.rawValue,
                                       payload: Data([enabled ? 0x01 : 0x00]))
        connection.sendData(channel: .command, payload: message.data, acknowledgementExpected: true)
    }

    func setCurrentMode(_ value: Int) {
        let mode = UInt8(max(min(value, maxMode), 0))
        let message = GaiaV3GATTPacket(featureID: featureID,
                                       commandID: Commands.setANCMode.rawValue,
                                       payload: Data([mode]))
        connection.sendData(channel: .command, payload: message.data, acknowledgementExpected: true)
    }

    func setStaticGain(_ value: Int) {
        let valueToSet = UInt8(min(255, max(0, value)))

        let message = GaiaV3GATTPacket(featureID: featureID,
                                       commandID: Commands.setConfiguredLeakthroughGain.rawValue,
                                       payload: Data([valueToSet]))
        connection.sendData(channel: .command, payload: message.data, acknowledgementExpected: true)
    }
}

// MARK: - Private Methods
private extension GaiaDeviceLegacyANCPlugin {
    func processNewANCState(data: Data) {
        guard
            let device = device,
            data.count > 0
        else {
            return
        }
        enabled = data[0] == 1
        let notification = GaiaDeviceLegacyANCPluginNotification(sender: self,
                                                                   payload: device,
                                                                   reason: .enabledChanged)
        notificationCenter.post(notification)
    }

    func processNewANCMode(data: Data) {
        guard
            let device = device,
            data.count > 0
        else {
            return
        }
        currentMode = max(0, min(Int(data[0]), maxMode))
        let notification = GaiaDeviceLegacyANCPluginNotification(sender: self,
                                                                   payload: device,
                                                                   reason: .modeChanged)
        notificationCenter.post(notification)
    }

    func processNewANCStaticGain(data: Data) {
        guard
            let device = device,
            data.count > 0
        else {
            return
        }
        staticGain = Int(data[0])
        if !isLeftAdaptive {
            leftAdaptiveGain = staticGain
        }
        if !isRightAdaptive {
            rightAdaptiveGain = staticGain
        }
        let notification = GaiaDeviceLegacyANCPluginNotification(sender: self,
                                                                   payload: device,
                                                                   reason: .gainChanged)
        notificationCenter.post(notification)
    }
    
    func getCurrentState() {
        let message = GaiaV3GATTPacket(featureID: featureID,
                                       commandID: Commands.getANCState.rawValue,
                                       payload: Data())
        connection.sendData(channel: .command, payload: message.data, acknowledgementExpected: true)
    }

    func getNumberOfModes() {
        let message = GaiaV3GATTPacket(featureID: featureID,
                                       commandID: Commands.getNumANCModes.rawValue,
                                       payload: Data())
        connection.sendData(channel: .command, payload: message.data, acknowledgementExpected: true)
    }

    func getCurrentMode() {
        let message = GaiaV3GATTPacket(featureID: featureID,
                                       commandID: Commands.getANCMode.rawValue,
                                       payload: Data())
        connection.sendData(channel: .command, payload: message.data, acknowledgementExpected: true)
    }

    func getStaticGain() {
        let message = GaiaV3GATTPacket(featureID: featureID,
                                       commandID: Commands.getConfiguredLeakthroughGain.rawValue,
                                       payload: Data())
        connection.sendData(channel: .command, payload: message.data, acknowledgementExpected: true)
    }
}
