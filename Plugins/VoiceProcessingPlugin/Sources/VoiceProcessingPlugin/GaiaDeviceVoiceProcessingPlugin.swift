//
//  © 2021 - 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation
import GaiaBase
import PluginBase
import Packets

public class GaiaDeviceVoiceProcessingPlugin: GaiaDeviceVoiceProcessingPluginProtocol, GaiaNotificationSender {

    enum Commands: UInt16 {
        case getSupportedEnhancements = 0
        case setConfigEnhancement = 1
        case getConfigEnhancement = 2
    }

    enum Notifications: UInt8 {
        case enhancementModeChanged = 0
    }

    // MARK: Private ivars
    private weak var device: GaiaDeviceIdentifierProtocol?
    private let devicePluginVersion: UInt8
    private let connection: GaiaDeviceConnectionProtocol
    private let notificationCenter : NotificationCenter

    private var supportedCapabilities = Set<VoiceProcessingCapabilities>()
    private var receivedCapabilities: Int = 0

    // MARK: Public ivars
    public static var featureID = GaiaDeviceQCPluginFeatureID.voiceProcessing

    public private(set) var cVcOperationMode = VoiceProcessing3MicCVCOperationMode.unknownOrUnavailable
    public private(set) var cVcMicrophonesMode = VoiceProcessingCVCMicrophoneMode.unknownOrUnavailable
    public private(set) var cVcBypassMode = VoiceProcessingCVCBypassMode.unknownOrUnavailable

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
        getCapabilities()
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
        case .notification(let notificationID, let data):
            if let id = Notifications(rawValue: notificationID),
               id == .enhancementModeChanged,
               let aId = data.first {

                let capability = VoiceProcessingCapabilities.init(byteValue: aId)
                let noteData = data.count > 1 ? data.advanced(by: 1) : Data()
                switch capability {
                case .cVc:
                    processCVCInfo(noteData)
                default:
                    break
                }
            }
        case .response(let command, let data):
            if let id = Commands(rawValue: command) {
                switch id {
                case .getSupportedEnhancements:
                    processGetSupportedEnhancements(data)
                case .setConfigEnhancement:
                    break
                case .getConfigEnhancement:
                    processGetConfigEnhancement(data)
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

extension GaiaDeviceVoiceProcessingPlugin {
    public func isCapabilityPresent(_ capability: VoiceProcessingCapabilities) -> Bool {
        return supportedCapabilities.contains(capability)
    }

    private func cvcSupported() -> Bool {
        return supportedCapabilities.contains(.cVc)
    }

    public func setCVCMicrophonesMode(_ mode: VoiceProcessingCVCMicrophoneMode) {
        guard cvcSupported(),
              mode != .unknownOrUnavailable,
              mode != cVcMicrophonesMode,
              cVcBypassMode != .unknownOrUnavailable
        else {
            return
        }

        let payload = Data([VoiceProcessingCapabilities.cVc.byteValue()!,
                            mode.byteValue()!,
                            cVcBypassMode.byteValue()!])

        let message = GaiaV3GATTPacket(featureID: .voiceProcessing,
                                       commandID: Commands.setConfigEnhancement.rawValue,
                                       payload: payload)
        connection.sendData(channel: .command, payload: message.data, acknowledgementExpected: true)
    }

    public func setCVCBypassMode(_ mode: VoiceProcessingCVCBypassMode) {
        guard cvcSupported(),
              mode != .unknownOrUnavailable,
              mode != cVcBypassMode,
              cVcMicrophonesMode != .unknownOrUnavailable
        else {
            return
        }

        let payload = Data([VoiceProcessingCapabilities.cVc.byteValue()!,
                            cVcMicrophonesMode.byteValue()!,
                            mode.byteValue()!])

        let message = GaiaV3GATTPacket(featureID: .voiceProcessing,
                                       commandID: Commands.setConfigEnhancement.rawValue,
                                       payload: payload)
        connection.sendData(channel: .command, payload: message.data, acknowledgementExpected: true)
    }
}

private extension GaiaDeviceVoiceProcessingPlugin {
    func processCVCInfo(_ data: Data) {
        guard
            let device = device,
            data.count >= 3
        else {
            return
        }

        let micMode = VoiceProcessingCVCMicrophoneMode(byteValue: data[0])
        if micMode != .unknownOrUnavailable && micMode != cVcMicrophonesMode {
            cVcMicrophonesMode = micMode
            let notification = GaiaDeviceVoiceProcessingPluginNotification(sender: self,
                                                                            payload: device,
                                                                            reason: .cVcMicrophonesModeChanged)
            notificationCenter.post(notification)
        }

        // Bypass mode
        let bypassMode = VoiceProcessingCVCBypassMode(byteValue: data[1])
        if bypassMode != .unknownOrUnavailable && bypassMode != cVcBypassMode {
            cVcBypassMode = bypassMode
            let notification = GaiaDeviceVoiceProcessingPluginNotification(sender: self,
                                                                            payload: device,
                                                                            reason: .cVcBypassModeChanged)
            notificationCenter.post(notification)
        }

        let opMode = VoiceProcessing3MicCVCOperationMode(byteValue: data[2])
        if opMode != .unknownOrUnavailable && opMode != cVcOperationMode {
            cVcOperationMode = opMode
            let notification = GaiaDeviceVoiceProcessingPluginNotification(sender: self,
                                                                            payload: device,
                                                                            reason: .cVcMicOperationModeChanged)
            notificationCenter.post(notification)
        }
    }

    func processGetSupportedEnhancements(_ data: Data) {
        guard
            let device = device,
            data.count > 0
        else {
            return
        }

        let more = data[0] != 0

        for index in 1 ..< data.count {
            let capByte: UInt8 = data[index]
            let capability = VoiceProcessingCapabilities(byteValue: capByte)

            if capability != .unknownOrUnavailable && capability != .none {
                supportedCapabilities.insert(capability)
            }
            receivedCapabilities += 1
        }

        if more {
            // Request more data
            let message = GaiaV3GATTPacket(featureID: .voiceProcessing,
                                           commandID: Commands.getSupportedEnhancements.rawValue,
                                           payload: Data([UInt8(receivedCapabilities)]))
            connection.sendData(channel: .command, payload: message.data, acknowledgementExpected: true)
        } else {
            let notification = GaiaDeviceVoiceProcessingPluginNotification(sender: self,
                                                                            payload: device,
                                                                            reason: .capabilityAvailabilityChanged)
            notificationCenter.post(notification)

            if cvcSupported() {
                getCVCInfo()
            }
        }
    }

    func processGetConfigEnhancement(_ data: Data) {
        if let aId = data.first {
            let capability = VoiceProcessingCapabilities(byteValue: aId)
            let noteData = data.count > 1 ? data.advanced(by: 1) : Data()

            switch capability {
            case .cVc:
                processCVCInfo(noteData)
            default:
                break
            }
        }
    }
}

private extension GaiaDeviceVoiceProcessingPlugin {
    func getCapabilities() {
        supportedCapabilities.removeAll()
        receivedCapabilities = 0
        let message = GaiaV3GATTPacket(featureID: .voiceProcessing,
                                       commandID: Commands.getSupportedEnhancements.rawValue,
                                       payload: Data([0x00])) // Start with first.
        connection.sendData(channel: .command, payload: message.data, acknowledgementExpected: true)
    }

    func getCVCInfo() {
        let payload = Data([VoiceProcessingCapabilities.cVc.byteValue()!])
        let message = GaiaV3GATTPacket(featureID: .voiceProcessing,
                                       commandID: Commands.getConfigEnhancement.rawValue,
                                       payload: payload)
        connection.sendData(channel: .command, payload: message.data, acknowledgementExpected: true)
    }
}
