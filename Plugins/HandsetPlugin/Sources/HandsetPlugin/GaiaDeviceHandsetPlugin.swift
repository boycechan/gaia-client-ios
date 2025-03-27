//
//  © 2021 - 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation
import GaiaBase
import PluginBase
import Packets

public class GaiaDeviceHandsetPlugin: GaiaDeviceHandsetPluginProtocol, GaiaNotificationSender {
    enum Commands: UInt16 {
        case setEnableMultipoint = 0
    }

    enum Notifications: UInt8 {
        case multipointEnabledChanged = 0
    }

    // MARK: Private ivars
    private weak var device: GaiaDeviceIdentifierProtocol?
    private let devicePluginVersion: UInt8
    private let connection: GaiaDeviceConnectionProtocol
    private let notificationCenter : NotificationCenter


    // MARK: Public ivars
    public static let featureID: GaiaDeviceQCPluginFeatureID = .handset

    public private(set) var multipointEnabled: Bool = false


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
        guard let device = device else {
            return
        }

        switch messageDescription {
        case .notification(let notificationID, let payload):
            if let notification = Notifications(rawValue: notificationID) {
                switch notification {
                case .multipointEnabledChanged:
                    multipointEnabled = (payload.first ?? 0) == 1
                    notificationCenter.post(GaiaDeviceHandsetPluginNotification(sender: self,
                                                                                payload: device,
                                                                                reason: .multipointEnabledChanged))
                }
            }

        default:
            break
        }
    }

    public func didSendData(channel: GaiaDeviceConnectionChannel, error: GaiaError?) {
    }


    public func setEnableMultipoint(_ state: Bool) {
        let message = GaiaV3GATTPacket(featureID: .handset,
                                   commandID: Commands.setEnableMultipoint.rawValue,
                                   payload: Data([state ? 0x01 : 0x00]))
        connection.sendData(channel: .command, payload: message.data, acknowledgementExpected: true)
    }
}
