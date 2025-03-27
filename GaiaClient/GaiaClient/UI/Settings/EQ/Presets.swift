//
//  © 2021 - 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation

enum EQPresetsNamed: UInt8 {
    case flat = 0
    case preset1 = 1
    case preset2 = 2
    case preset3 = 3
    case preset4 = 4
    case preset5 = 5
    case preset6 = 6
    case preset7 = 7
    case preset8 = 8
    case preset9 = 9
    case user = 63

    public func userVisibleName () -> String {
        switch self {
        case .flat:
            return String(localized: "Flat", comment: "EQ Preset Description")
        case .user:
            return String(localized: "User", comment: "EQ Preset Description")
        case .preset1:
            return String(localized: "Rock", comment: "EQ Preset Description")
        case .preset2:
            return String(localized: "Pop", comment: "EQ Preset Description")
        case .preset3:
            return String(localized: "Classical", comment: "EQ Preset Description")
        case .preset4:
            return String(localized: "Techno", comment: "EQ Preset Description")
        case .preset5:
            return String(localized: "R&B", comment: "EQ Preset Description")
        case .preset6:
            return String(localized: "Ambient", comment: "EQ Preset Description")
        case .preset7:
            return String(localized: "Metal", comment: "EQ Preset Description")
        case .preset8:
            return String(localized: "Funk", comment: "EQ Preset Description")
        case .preset9:
            return String(localized: "Speech", comment: "EQ Preset Description")
        }
    }
}

enum EQPresetInfo: Equatable {
    case named(_ named: EQPresetsNamed)
    case unnamed(byte: UInt8)

    init(byteValue: UInt8) {
        if let named = EQPresetsNamed(rawValue: byteValue) {
            self = .named(named)
        } else {
            self = .unnamed(byte: byteValue)
        }
    }

    public func byteValue() -> UInt8 {
        switch self {
        case .named(let namedPreset):
            return namedPreset.rawValue
        case .unnamed(let byteValue):
            return byteValue
        }
    }

    public func userVisibleName () -> String {
        switch self {
        case .named(let namedPreset):
            return namedPreset.userVisibleName()
        case .unnamed(let value):
            return String(localized: "Preset ", comment: "Unknown EQ Preset Description") + "\(value)"
        }
    }

    public static func ==(lhs: EQPresetInfo, rhs: EQPresetInfo) -> Bool {
        return lhs.byteValue() == rhs.byteValue()
    }
}
