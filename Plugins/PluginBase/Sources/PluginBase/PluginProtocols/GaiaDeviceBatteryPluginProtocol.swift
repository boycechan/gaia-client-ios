//
//  © 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation
import GaiaBase

public enum BatteryTypes: ByteValueProtocol, Comparable, Hashable {
    public enum BatteryIDs: UInt8 {
        case single = 0
        case left = 1
        case right = 2
        case chargercase = 3
    }
    case known(id: BatteryIDs)
    case unknown(id: UInt8)

    public init(byteValue: UInt8) {
        if let knownID = BatteryIDs(rawValue: byteValue) {
            self = .known(id: knownID)
            return
        }
        self = .unknown(id: byteValue)
    }

    public func byteValue() -> UInt8 {
        switch self {
        case .known(let batteryID):
            return batteryID.rawValue
        case .unknown(let id):
            return id
        }
    }

    public static func ==(lhs: BatteryTypes, rhs: BatteryTypes) -> Bool {
        return lhs.byteValue() == rhs.byteValue()
    }

    public static func < (lhs: BatteryTypes, rhs: BatteryTypes) -> Bool {
        return lhs.byteValue() < rhs.byteValue()
    }
}

public protocol GaiaDeviceBatteryPluginProtocol: GaiaDevicePluginProtocol {
    var supportedBatteries: Set<BatteryTypes> { get }
    func level(battery: BatteryTypes) -> Int?

    func refreshLevels()
}
