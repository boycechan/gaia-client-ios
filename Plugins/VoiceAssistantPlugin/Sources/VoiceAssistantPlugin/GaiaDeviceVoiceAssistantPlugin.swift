//
//  © 2020 - 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation
import GaiaBase
import PluginBase
import Packets

public class GaiaDeviceVoiceAssistantPlugin: GaiaDeviceVoiceAssistantPluginProtocol, GaiaNotificationSender {
    enum Commands: UInt16 {
        case getSelectedAssistant = 0
        case setSelectedAssistant = 1
        case getAssistantOptions = 2
    }

    enum Notifications: UInt8 {
        case assistantChanged = 0
    }

    // MARK: Private ivars
    private weak var device: GaiaDeviceIdentifierProtocol?
    private let devicePluginVersion: UInt8
    private let connection: GaiaDeviceConnectionProtocol
    private let notificationCenter : NotificationCenter

    private let possibleAssistantOptions: [VoiceAssistant] = [.none, .audioTuning, .googleAssistant, .amazonAlexa]

    // MARK: Public ivars
    public static let featureID: GaiaDeviceQCPluginFeatureID = .voiceAssistant

    public private(set) var availableAssistantOptions: [VoiceAssistant] = [.none]
    public private(set) var selectedAssistant: VoiceAssistant = .none

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
        getAssistantOptions()
        getSelectedAssistant()
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
            if let id = Notifications(rawValue: notificationID),
                id == .assistantChanged {
                if let aId = data.first {
                    selectedAssistant = VoiceAssistant(rawValue: aId) ?? .none
                    let notification = GaiaDeviceVoiceAssistantPluginNotification(sender: self,
                                                                                  payload: device,
                                                                                  reason: .optionChanged)
                    notificationCenter.post(notification)
                }
            }
        case .response(let command, let data):
            if let id = Commands(rawValue: command) {
                switch id {
                case .getSelectedAssistant:
                    if let aId = data.first {
                        selectedAssistant = VoiceAssistant(rawValue: aId) ?? .none
                        let notification = GaiaDeviceVoiceAssistantPluginNotification(sender: self,
                                                                                      payload: device,
                                                                                      reason: .optionChanged)
                        notificationCenter.post(notification)
                    }
                case .getAssistantOptions:
                    if let numberOfOptions = data.first {
                        if numberOfOptions == 0 {
                            availableAssistantOptions = [.none]
                        } else {
                            availableAssistantOptions = []
                            let opts = min(data.count - 1, Int(numberOfOptions))
                            for i in 0..<opts {
                                let id = data[i + 1]
                                if let option = VoiceAssistant(rawValue: id) {
                                    availableAssistantOptions.append(option)
                                }
                            }
                        }
                    }
                default:
                    break
                }
            }
        case .error(_ , _, _):
            break
        default:
            break
        }
    }

    public func didSendData(channel: GaiaDeviceConnectionChannel, error: GaiaError?) {

    }
}

// MARK: - Public "Setter" Methods
public extension GaiaDeviceVoiceAssistantPlugin {
    func selectOption(_ option: VoiceAssistant) {
        // Look up true identifier
        let message = GaiaV3GATTPacket(featureID: .voiceAssistant,
                                       commandID: Commands.setSelectedAssistant.rawValue,
                                       payload: Data([option.rawValue]))
        connection.sendData(channel: .command, payload: message.data, acknowledgementExpected: true)
    }
}

// MARK: - Private Methods
private extension GaiaDeviceVoiceAssistantPlugin {
    func getSelectedAssistant() {
        let message = GaiaV3GATTPacket(featureID: .voiceAssistant,
                                       commandID: Commands.getSelectedAssistant.rawValue,
                                       payload: Data())
        connection.sendData(channel: .command, payload: message.data, acknowledgementExpected: true)
    }

    func getAssistantOptions() {
        let message = GaiaV3GATTPacket(featureID: .voiceAssistant,
                                       commandID: Commands.getAssistantOptions.rawValue,
                                       payload: Data())
        connection.sendData(channel: .command, payload: message.data, acknowledgementExpected: true)
    }
}

