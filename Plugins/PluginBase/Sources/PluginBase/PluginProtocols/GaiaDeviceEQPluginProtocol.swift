//
//  © 2020 - 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation

public struct EQPreset: Equatable {
    public init(byteValue: UInt8) {
        self.byteValue = byteValue
    }

    public let byteValue: UInt8

    public static func ==(lhs: EQPreset, rhs: EQPreset) -> Bool {
        return lhs.byteValue == rhs.byteValue
    }
}

public enum FilterType: UInt8 {
   case bypass = 0
   case lp1 = 1
   case hp1 = 2
   case ap1 = 3
   case ls1 = 4
   case hs1 = 5
   case tilt1 = 6
   case lp2 = 7
   case hp2 = 8
   case ap2 = 9
   case ls2 = 10
   case hs2 = 11
   case tilt2 = 12
   case peq = 13
}

public struct EQUserBandInfo {
    public init(frequency: Int, gain: Double, q: Double, filterType: FilterType) {
        self.frequency = frequency
        self.gain = gain
        self.q = q
        self.filterType = filterType
    }

    public let frequency: Int
    public var gain: Double
    public let q: Double
    public let filterType: FilterType
}

public protocol GaiaDeviceEQPluginProtocol: GaiaDevicePluginProtocol {
    var eqEnabled: Bool { get }
    var currentPresetIndex: Int { get }
    var availablePresets: [EQPreset] { get }
    var userBands: [EQUserBandInfo] { get }

    func setCurrentPresetIndex(_ index: Int)
    func setUserBand(index: Int, gain: Double)
    func resetAllBandsToZeroGain() 
}
