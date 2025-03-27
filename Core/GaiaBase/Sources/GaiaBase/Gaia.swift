//
//  © 2020 - 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation

public extension Bundle {
    func plistValue<T>(key: String) -> T? {
        return object(forInfoDictionaryKey: key) as? T
    }
}

public enum Gaia {


    public static var bleServiceUUID: String {
        if let customKeyValue: String = Bundle.main.plistValue(key: bleServiceUUIDPlistKey) {
            return customKeyValue
        }

		return defaultBLEserviceUUID
    }

    public static var iap2ProtocolName: String {
        if let customKeyValue: String = Bundle.main.plistValue(key: iap2ProtocolNamePlistKey) {
            return customKeyValue
        }

        if let iapArray: [String] = Bundle.main.plistValue(key: iap2ProtocolNamesArrayPlistKey),
           let first = iapArray.first {
            return first
        }

        return defaultIAP2ProtocolName
    }
    
    public static let chargingCaseAdvertisementKey = "0000cc00-d102-11e1-9b23-00025b00a5a5"

    private static let bleServiceUUIDPlistKey = "GAIABLEServiceUUID"
    private static let iap2ProtocolNamePlistKey = "GAIAIAP2ProtocolName"
    private static let iap2ProtocolNamesArrayPlistKey = "UISupportedExternalAccessoryProtocols"

    private static let defaultIAP2ProtocolName = "com.qtil.gaia"
    private static let defaultBLEserviceUUID = "00001100-D102-11E1-9B23-00025B00A5A5"

    public static let commandCharacteristicUUID = "00001101-D102-11E1-9B23-00025B00A5A5"
    public static let responseCharacteristicUUID = "00001102-D102-11E1-9B23-00025B00A5A5"
    public static let dataCharacteristicUUID = "00001103-D102-11E1-9B23-00025B00A5A5"

    public enum CommandErrorCodes: UInt8 {
        /// The command succeeded.
        case success                          = 0x00
        /// An invalid Command ID was specified.
        case failedNotSupported               = 0x01
        /// The host is not authenticated to use a Command ID orcontrol a Feature Type.
        case failedNotAuthenticated           = 0x02
        /// The command was valid, but the device could not successfully carry out the command.
        case failedInsufficientResources      = 0x03
        /// The device is in the process of authenticating the host.
        case authenticating                   = 0x04
        /// An invalid parameter was used in the command.
        case invalidParameter                 = 0x05
        /// The device is not in the correct state to process the command.
        case incorrectState                   = 0x06
        /// The command is in progress
        case inProgress                       = 0x07
        /// Undocumented
        case noStatusAvailable                = 0xFF
    }
}
