//
//  © 2020 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation
import GaiaBase
import PluginBase
import Packets
import GaiaLogger

/// Gaia Client supports two GAIA API versions. Support for "v2" of the API is limited primarily to
/// allowing the update to the newer "v3" API. To support the update of both API variants there are
/// two concrete implementations of GaiaDeviceUpdaterProtocol
class GaiaV3Updater: NSObject, GaiaDeviceUpdaterProtocol {
    enum Commands: UInt16 {
        case vmUpgradeConnect               = 0x0000
        case vmUpgradeDisconnect            = 0x0001
        case vmUpgradeControl               = 0x0002
        case getDataEndPointMode            = 0x0003
        case setDataEndPointMode            = 0x0004
    }

    enum Events: UInt8 {
        case vmUpgradeProtocolPacket = 0x00
        case vmUpgradeStopRequest = 0x01
        case vmUpgradeStartRequest = 0x02
    }

    let connection: GaiaDeviceConnectionProtocol

    var dataPacketsRequireACKs: Bool = false

    required init(connection: GaiaDeviceConnectionProtocol) {
        self.connection = connection
    }

    func isSetDataEndpointModeCommand(_ code: UInt16) -> Bool {
        return code == Commands.setDataEndPointMode.rawValue
    }

    func isUpgradeConnectCommand(_ code: UInt16) -> Bool {
        return code == Commands.vmUpgradeConnect.rawValue
    }

    func isUpgradeDisconnectCommand(_ code: UInt16) -> Bool {
        return code == Commands.vmUpgradeDisconnect.rawValue
    }

    func isUpgradeControlCommand(_ code: UInt16) -> Bool {
        return code == Commands.vmUpgradeControl.rawValue
    }

    func isRegisterNotificationCommand(_ code: UInt16) -> Bool {
        return false
        //return code == Gaia.V3BasicCommands.registerNotification.rawValue
    }

    func isGetNotificationCommand(_ code: UInt16) -> Bool {
        return false
        //return code == Gaia.V3BasicCommands.getNotification.rawValue
    }

    func isCancelNotificationCommand(_ code: UInt16) -> Bool {
        return false
        //return code == Gaia.V3BasicCommands.cancelNotification.rawValue
    }

    func isEventNotificationCommand(_ code: UInt16) -> Bool {
        return false
        //return code == Gaia.V3BasicCommands.eventNotification.rawValue
    }

    func isVMUpgradeProtocolPacket(_ notificationID: UInt8) -> Bool {
        return notificationID == Events.vmUpgradeProtocolPacket.rawValue
    }

    func getDataEndpointMode() {
        let message = GaiaV3GATTPacket(featureID: .upgrade,
                                       commandID: Commands.getDataEndPointMode.rawValue,
                                       payload: Data())
        connection.sendData(channel: .command, payload: message.data, acknowledgementExpected: true)
    }

    func setDataEndpointMode(_ newValue: Bool) {
        let message = GaiaV3GATTPacket(featureID: .upgrade,
                                       commandID: Commands.setDataEndPointMode.rawValue,
                                       payload: Data([newValue ? 0x01 : 0x00]))
        connection.sendData(channel: .command, payload: message.data, acknowledgementExpected: true)
    }

    func registerForUpgradeNotifications() {
        // Not handled here
    }

    func cancelUpgradeNotificationRegistration() {
        // Not handled here
    }

    func vmUpgradeConnect() {
        LOG(.medium, "Sending connect")
        let message = GaiaV3GATTPacket(featureID: .upgrade,
                                       commandID: Commands.vmUpgradeConnect.rawValue,
                                       payload: Data())
        connection.sendData(channel: .command, payload: message.data, acknowledgementExpected: true)
    }

    func vmUpgradeDisconnect() {
        LOG(.medium, "Sending Disconnect")
        let message = GaiaV3GATTPacket(featureID: .upgrade,
                                       commandID: Commands.vmUpgradeDisconnect.rawValue,
                                       payload: Data())
        connection.sendData(channel: .command, payload: message.data, acknowledgementExpected: true)
    }

    func vmUpgradeAbort() {
        sendVMUpgradeControlCommand(.UPGRADE_ABORT_REQ)
    }

    func vmUpgradeStartDataRequest() {
        sendVMUpgradeControlCommand(.UPGRADE_START_DATA_REQ)
    }

    func vmUpgradeStartRequest() {
        sendVMUpgradeControlCommand(.UPGRADE_START_REQ)
    }

    func vmUpgradeSyncRequest(md5: Data) {
        sendVMUpgradeControlCommand(.UPGRADE_SYNC_REQ, md5: md5)
    }

    func vmUpgradeIsValidationDoneRequest(md5: Data) {
        sendVMUpgradeControlCommand(.UPGRADE_IS_VALIDATION_DONE_REQ, md5: md5)
    }

    func vmUpgradeTransferConfirmRequest(reply: UpdateCommitOptions) {
        let payload = Data([UpdateControlOperations.UPGRADE_TRANSFER_COMPLETE_RES.rawValue,
                            0x00,
                            0x01,
                            reply.rawValue
        ])
        let message = GaiaV3GATTPacket(featureID: .upgrade,
                                       commandID: Commands.vmUpgradeControl.rawValue,
                                       payload: payload)
        connection.sendData(channel: .command, payload: message.data, acknowledgementExpected: true)
    }

    func vmUpgradeTransferComplete() {
        sendVMUpgradeControlCommand(command: .UPGRADE_TRANSFER_COMPLETE_RES, shouldContinue: true)
    }

    func vmUpgradeTransferAborted() {
        sendVMUpgradeControlCommand(command: .UPGRADE_TRANSFER_COMPLETE_RES, shouldContinue: false)
    }

    func vmUpgradeUpdateComplete() {
        sendVMUpgradeControlCommand(command: .UPGRADE_PROCEED_TO_COMMIT, shouldContinue: true)
    }

    func vmUpgradeRequestIsSilentCommitAvailable() {
        sendVMUpgradeControlCommand(.UPGRADE_SILENT_COMMIT_SUPPORTED_REQ)
    }

    func vmUpgradeCommitConfirmRequest(reply: Bool) {
        sendVMUpgradeControlCommand(command: .UPGRADE_COMMIT_CFM, shouldContinue: reply)
    }

    func vmUpgradeConfirmError(errorCode: UInt16) {
        var payload = Data([UpdateControlOperations.UPGRADE_ERROR_RES.rawValue,
                            0x00,
                            0x02
        ])
        payload.append(errorCode.data(bigEndian: true))
        let message = GaiaV3GATTPacket(featureID: .upgrade,
                                       commandID: Commands.vmUpgradeControl.rawValue,
                                       payload: payload)
        connection.sendData(channel: .command, payload: message.data, acknowledgementExpected: true)
    }

    func vmUpgradeDataPacket(bytes: Data, moreComing: Bool) -> Data {
        var payload = Data([UpdateControlOperations.UPGRADE_DATA.rawValue])
        let lengthToSend = UInt16(bytes.count + 1)
        payload.append(lengthToSend.data(bigEndian: true))
        payload.append(Data([moreComing ? 0x00 : 0x01]))
        payload.append(bytes)

        let message = GaiaV3GATTPacket(featureID: .upgrade,
                                       commandID: Commands.vmUpgradeControl.rawValue,
                                       payload: payload)
        return message.data
    }

    func vmUpgradeSendPreformedDataPacketViaGaia(_ packet: Data) {
        connection.sendData(channel: .command, payload: packet, acknowledgementExpected: dataPacketsRequireACKs)
    }
}

private extension GaiaV3Updater {
    func sendVMUpgradeControlCommand(_ command: UpdateControlOperations) {
        LOG(.medium, "Sending: \(command)")
        let payload = Data([command.rawValue, 0x00, 0x00])
        let message = GaiaV3GATTPacket(featureID: .upgrade,
                                       commandID: Commands.vmUpgradeControl.rawValue,
                                       payload: payload)
        connection.sendData(channel: .command, payload: message.data, acknowledgementExpected: true)
    }

    func sendVMUpgradeControlCommand(_ command: UpdateControlOperations, md5: Data) {
        precondition(md5.count > 15)
        LOG(.medium, "Sending: \(command)")

        var payload = Data([command.rawValue, 0x00, 0x04])
        payload.append(md5[12...15])
        let message = GaiaV3GATTPacket(featureID: .upgrade,
                                       commandID: Commands.vmUpgradeControl.rawValue,
                                       payload: payload)
        connection.sendData(channel: .command, payload: message.data, acknowledgementExpected: true)
    }

    func sendVMUpgradeControlCommand(command: UpdateControlOperations, shouldContinue: Bool) {
        LOG(.medium, "Sending: \(command)")
        let payload = Data([command.rawValue,
                            0x00,
                            0x01,
                            shouldContinue ? UpdateDataAction.noAbort.rawValue : UpdateDataAction.abort.rawValue
        ])
        let message = GaiaV3GATTPacket(featureID: .upgrade,
                                       commandID: Commands.vmUpgradeControl.rawValue,
                                       payload: payload)
        connection.sendData(channel: .command, payload: message.data, acknowledgementExpected: true)
    }
}
