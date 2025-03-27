//
//  © 2021 - 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation
import GaiaBase
import PluginBase
import Packets
import GaiaLogger

public class GaiaDeviceEarbudFitPlugin: GaiaDeviceEarbudFitPluginProtocol, GaiaNotificationSender {
    enum Commands: UInt16 {
    	case setFitStatusState = 0
    }

    enum Notifications: UInt8 {
        case fitStatusIndicationResult = 0
    }

    // MARK: Private ivars
    private weak var device: GaiaDeviceIdentifierProtocol?
    private let devicePluginVersion: UInt8
    private let connection: GaiaDeviceConnectionProtocol
    private let notificationCenter : NotificationCenter


    // MARK: Public ivars
    public static let featureID: GaiaDeviceQCPluginFeatureID = .earbudFit

    public private(set) var leftFitQuality = GaiaDeviceFitQuality.unknown
    public private(set) var rightFitQuality = GaiaDeviceFitQuality.unknown

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
    }

    public func stopPlugin() {
    }

    public func handoverDidOccur() {
    }

    public func responseReceived(messageDescription: IncomingMessageDescription) {
        switch messageDescription {
        case .notification(let notificationID, let data):
            guard let notification = Notifications(rawValue: notificationID) else {
                LOG(.medium, "Earbud Fit Non valid notification id")
                return
            }
            switch notification {
            case .fitStatusIndicationResult:
                processNewFitStatusIndicationResult(data: data)
            }
        case .error(let command, _, _):
            guard let cmd = Commands(rawValue: command) else {
                LOG(.medium, "Earbud Fit Non valid command id")
                return
            }
            if cmd == .setFitStatusState {
                leftFitQuality = .failed
                rightFitQuality = .failed
                sendNotification()
            }
        default:
            break
        }
    }

    public func didSendData(channel: GaiaDeviceConnectionChannel, error: GaiaError?) {
    }
}

public extension GaiaDeviceEarbudFitPlugin {
    private func processNewFitStatusIndicationResult(data: Data) {
        guard
            let _ = device,
            data.count > 1
        else {
            return
        }

        leftFitQuality = GaiaDeviceFitQuality(byteValue: data[0])
        rightFitQuality = GaiaDeviceFitQuality(byteValue: data[1])

        sendNotification()
    }

    private func setFitQualityState(enabled: Bool) {
        let message = GaiaV3GATTPacket(featureID: .earbudFit,
                                       commandID: Commands.setFitStatusState.rawValue,
                                       payload: Data([enabled ? 0x01 : 0x00]))
        connection.sendData(channel: .command, payload: message.data, acknowledgementExpected: true)
    }

    private func sendNotification() {
        let notification = GaiaDeviceEarbudFitPluginNotification(sender: self,
                                                                 payload: device!,
                                                                 reason: .resultChanged)
        notificationCenter.post(notification)
    }

    func startFitQualityTest() {
        guard leftFitQuality != .determining && rightFitQuality != .determining else {
            return
        }
        leftFitQuality = .determining
        rightFitQuality = .determining
        sendNotification()

        setFitQualityState(enabled: true)
    }

    func stopFitQualityTest() {
        guard leftFitQuality == .determining || rightFitQuality == .determining else {
            return
        }

        leftFitQuality = .unknown
        rightFitQuality = .unknown
        sendNotification()

        setFitQualityState(enabled: false)
    }
}
