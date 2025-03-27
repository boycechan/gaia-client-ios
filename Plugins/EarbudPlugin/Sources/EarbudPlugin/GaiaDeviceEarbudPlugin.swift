//
//  © 2020 - 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation
import GaiaBase
import PluginBase
import Packets

public class GaiaDeviceEarbudPlugin: GaiaDeviceEarbudPluginProtocol, GaiaNotificationSender {
    enum Commands: UInt16 {
        case getWhichEarbudIsPrimary = 0
        case getSecondarySerialNumber = 1
    }

    enum Notifications: UInt8 {
        case primaryEarbudWillChange = 0
        case primaryEarbudDidChange = 1
        case secondaryEarbudConnectionState = 2
    }
    // MARK: Private ivars
    private weak var device: GaiaDeviceIdentifierProtocol?
    private let devicePluginVersion: UInt8
    private let connection: GaiaDeviceConnectionProtocol
    private let notificationCenter : NotificationCenter

    // MARK: Public ivars
    public static let featureID: GaiaDeviceQCPluginFeatureID = .earbud

    public private(set) var secondEarbudSerialNumber: String?
    public private(set) var secondEarbudConnected: Bool = false
    public private(set) var leftEarbudIsPrimary: Bool = true

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
        getWhichEarbudIsPrimary()
        getSecondarySerialNumber()
    }

    public func stopPlugin() {
    }

    public func handoverDidOccur() {
        getWhichEarbudIsPrimary()
        getSecondarySerialNumber()
    }

    public func responseReceived(messageDescription: IncomingMessageDescription) {
        guard let device else {
            return
        }
        
        switch messageDescription {
        case .notification(let notificationID, let data):
            if let id = Notifications(rawValue: notificationID) {
                switch id {
                case .primaryEarbudWillChange:
                    if let type = data.first {
                        let delay = data.count > 1 ? data[1] : 5
                        let handoverPayload = GaiaDeviceEarbudPluginNotification.Payload(device: device,
                                                                                         handoverDelay: Int(delay),
                                                                                         handoverIsStatic: type == 0)
                        let notification = GaiaDeviceEarbudPluginNotification(sender: self,
                                                                              payload: handoverPayload,
                                                                              reason: .handoverAboutToHappen)
                        notificationCenter.post(notification)
                    }
                case .primaryEarbudDidChange:
                    if let value = data.first {
                        let oldValue = leftEarbudIsPrimary
                        leftEarbudIsPrimary = value == 0
                        if oldValue != leftEarbudIsPrimary {
                            let payload = GaiaDeviceEarbudPluginNotification.Payload(device: device)
                            let notification = GaiaDeviceEarbudPluginNotification(sender: self,
                                                                                  payload: payload,
                                                                                  reason: .primaryChanged)
                            notificationCenter.post(notification)
                        }
                    }
                case .secondaryEarbudConnectionState:
                    if let reason = data.first {
						secondEarbudConnected = reason == 1
                        if secondEarbudConnected && (secondEarbudSerialNumber?.isEmpty ?? true) {
							getSecondarySerialNumber()
                        }
                    }
                }
            }
        case .response(let command, let data):
            if let id = Commands(rawValue: command) {
                switch id {
                case .getSecondarySerialNumber:
                    if let newValue = String(data: data, encoding: .utf8) {
                        secondEarbudSerialNumber = newValue
                        let payload = GaiaDeviceEarbudPluginNotification.Payload(device: device)
                        let notification = GaiaDeviceEarbudPluginNotification(sender: self,
                                                                              payload: payload,
                                                                              reason: .secondSerial)
                        notificationCenter.post(notification)
                    }
                case .getWhichEarbudIsPrimary:
                    if let value = data.first {
						leftEarbudIsPrimary = value == 0
                    }
                }
           }
        case .error(let command, _, _):
            if let id = Commands(rawValue: command),
                id == .getSecondarySerialNumber {
				secondEarbudSerialNumber = nil
                let payload = GaiaDeviceEarbudPluginNotification.Payload(device: device)
                let notification = GaiaDeviceEarbudPluginNotification(sender: self,
                                                                      payload: payload,
                                                                      reason: .secondSerial)
                notificationCenter.post(notification)
            }

        default:
            break
        }
    }

    public func didSendData(channel: GaiaDeviceConnectionChannel, error: GaiaError?) {
    }
}

// MARK: - Private Methods
private extension GaiaDeviceEarbudPlugin {
    func getWhichEarbudIsPrimary() {
        let message = GaiaV3GATTPacket(featureID: .earbud,
                                       commandID: Commands.getWhichEarbudIsPrimary.rawValue,
                                       payload: Data())
        connection.sendData(channel: .command, payload: message.data, acknowledgementExpected: true)
    }

    func getSecondarySerialNumber() {
        let message = GaiaV3GATTPacket(featureID: .earbud,
                                       commandID: Commands.getSecondarySerialNumber.rawValue,
                                       payload: Data())
        connection.sendData(channel: .command, payload: message.data, acknowledgementExpected: true)
    }
}


