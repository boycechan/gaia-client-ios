//
//  © 2020 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation
import GaiaBase
import PluginBase

/// There are two concrete implementations of this protocol - one for V2 devices and the other for V3 devices.
/// Each implementation creates or handles updater packets in the relevant format. This allows the updater plugin to
/// use one consistent interface regardless of the packet format.
internal protocol GaiaDeviceUpdaterProtocol {
    var dataPacketsRequireACKs: Bool { get set }

    func isSetDataEndpointModeCommand(_ code: UInt16) -> Bool
    func isUpgradeCommand(_ code: UInt16) -> Bool
    func isUpgradeConnectCommand(_ code: UInt16) -> Bool
    func isUpgradeDisconnectCommand(_ code: UInt16) -> Bool
    func isUpgradeControlCommand(_ code: UInt16) -> Bool
    func isRegisterNotificationCommand(_ code: UInt16) -> Bool
    func isGetNotificationCommand(_ code: UInt16) -> Bool
    func isCancelNotificationCommand(_ code: UInt16) -> Bool
    func isEventNotificationCommand(_ code: UInt16) -> Bool

    func isVMUpgradeProtocolPacket(_ notificationID: UInt8) -> Bool

    func getDataEndpointMode()
    func setDataEndpointMode(_ newValue: Bool)
    func registerForUpgradeNotifications()
    func cancelUpgradeNotificationRegistration()
    func vmUpgradeConnect()
    func vmUpgradeDisconnect()
    func vmUpgradeAbort()
    func vmUpgradeStartDataRequest()
    func vmUpgradeStartRequest()
    func vmUpgradeSyncRequest(md5: Data)
    func vmUpgradeIsValidationDoneRequest(md5: Data)
    func vmUpgradeTransferConfirmRequest(reply: UpdateCommitOptions)
    func vmUpgradeUpdateComplete()
    func vmUpgradeRequestIsSilentCommitAvailable()
    func vmUpgradeCommitConfirmRequest(reply: Bool)
    func vmUpgradeConfirmError(errorCode: UInt16)
    func vmUpgradeDataPacket(bytes: Data, moreComing: Bool) -> Data
    func vmUpgradeSendPreformedDataPacketViaGaia(_ packet: Data)
}

extension GaiaDeviceUpdaterProtocol {
    func isUpgradeCommand(_ code: UInt16) -> Bool {
        return isUpgradeConnectCommand(code) ||
            isUpgradeDisconnectCommand(code) ||
            isUpgradeControlCommand(code) ||
            isRegisterNotificationCommand(code) ||
            isGetNotificationCommand(code) ||
            isCancelNotificationCommand(code) ||
            isEventNotificationCommand(code)
    }
}
