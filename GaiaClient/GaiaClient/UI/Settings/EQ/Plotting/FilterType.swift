//
//  © 2019-2020 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation
import GaiaCore
import PluginBase

public enum AdjustableParameters {
    case gain
    case frequency
    case q
}

extension FilterType {
    func uiName() -> String {
        switch self {
        case .bypass:
            return String(localized: "Bypass", comment: "filter type")
        case .lp1:
            return String(localized: "Low Pass Filter 1", comment: "filter type")
        case .hp1:
            return String(localized: "High Pass Filter 1", comment: "filter type")
        case .ap1:
            return String(localized: "All Pass Filter 1", comment: "filter type")
        case .ls1:
            return String(localized: "Low Shelf Filter 1", comment: "filter type")
        case .hs1:
            return String(localized: "High Shelf Filter 1", comment: "filter type")
        case .tilt1:
            return String(localized: "Tilt Filter 1", comment: "filter type")
        case .lp2:
            return String(localized: "Low Pass Filter 2", comment: "filter type")
        case .hp2:
            return String(localized: "High Pass Filter 2", comment: "filter type")
        case .ap2:
            return String(localized: "All Pass Filter 2", comment: "filter type")
        case .ls2:
            return String(localized: "Low Shelf Filter 2", comment: "filter type")
        case .hs2:
            return String(localized: "High Shelf Filter 2", comment: "filter type")
        case .tilt2:
            return String(localized: "Tilt Filter 2", comment: "filter type")
        case .peq:
            return String(localized: "Parametric Equalizer", comment: "filter type")
        }
    }

    func hasGainInput() -> Bool {
        switch self {
        case .bypass:
            return false
        case .lp1:
            return false
        case .hp1:
            return false
        case .ap1:
            return false
        case .ls1:
            return true
        case .hs1:
            return true
        case .tilt1:
            return true
        case .lp2:
            return false
        case .hp2:
            return false
        case .ap2:
            return false
        case .ls2:
            return true
        case .hs2:
            return true
        case .tilt2:
            return true
        case .peq:
            return true
        }
    }
/*
    func adjustableParameterRange(param: AdjustableParameters) -> ParameterRange {
        switch self {
        case .bypass:
            return ParameterRange.emptyRange()
        case .lp1:
            switch param {
            case .frequency:
                return ParameterRange(lower: 0.333, upper: 20000.0)
            case .gain:
                return ParameterRange.emptyRange()
            case .q:
                return ParameterRange.emptyRange()
            }
        case .hp1:
            switch param {
            case .frequency:
                return ParameterRange(lower: 0.333, upper: 20000.0)
            case .gain:
                return ParameterRange.emptyRange()
            case .q:
                return ParameterRange.emptyRange()
            }
        case .ap1:
            switch param {
            case .frequency:
                return ParameterRange(lower: 0.333, upper: 20000.0)
            case .gain:
                return ParameterRange.emptyRange()
            case .q:
                return ParameterRange.emptyRange()
            }
        case .ls1:
            switch param {
            case .frequency:
                return ParameterRange(lower: 20.0, upper: 20000.0)
            case .gain:
                return ParameterRange(lower: -12.0, upper: 12.0)
            case .q:
                return ParameterRange.emptyRange()
            }
        case .hs1:
            switch param {
            case .frequency:
                return ParameterRange(lower: 20.0, upper: 20000.0)
            case .gain:
                return ParameterRange(lower: -12.0, upper: 12.0)
            case .q:
                return ParameterRange.emptyRange()
            }
        case .tilt1:
            switch param {
            case .frequency:
                return ParameterRange(lower: 20.0, upper: 20000.0)
            case .gain:
                return ParameterRange(lower: -12.0, upper: 12.0)
            case .q:
                return ParameterRange.emptyRange()
            }
        case .lp2:
            switch param {
            case .frequency:
                return ParameterRange(lower: 40.0, upper: 20000.0)
            case .gain:
                return ParameterRange.emptyRange()
            case .q:
                return ParameterRange(lower: 0.25, upper: 2.0)
            }
        case .hp2:
            switch param {
            case .frequency:
                return ParameterRange(lower: 40.0, upper: 20000.0)
            case .gain:
                return ParameterRange.emptyRange()
            case .q:
                return ParameterRange(lower: 0.25, upper: 2.0)
            }
        case .ap2:
            switch param {
            case .frequency:
                return ParameterRange(lower: 40.0, upper: 20000.0)
            case .gain:
                return ParameterRange.emptyRange()
            case .q:
                return ParameterRange(lower: 0.25, upper: 2.0)
            }
        case .ls2:
            switch param {
            case .frequency:
                return ParameterRange(lower: 40.0, upper: 20000.0)
            case .gain:
                return ParameterRange(lower: -12.0, upper: 12.0)
            case .q:
                return ParameterRange(lower: 0.25, upper: 2.0)
            }
        case .hs2:
            switch param {
            case .frequency:
                return ParameterRange(lower: 40.0, upper: 20000.0)
            case .gain:
                return ParameterRange(lower: -12.0, upper: 12.0)
            case .q:
                return ParameterRange(lower: 0.25, upper: 2.0)
            }
        case .tilt2:
            switch param {
            case .frequency:
                return ParameterRange(lower: 40.0, upper: 20000.0)
            case .gain:
                return ParameterRange(lower: -12.0, upper: 12.0)
            case .q:
                return ParameterRange(lower: 0.25, upper: 2.0)
            }
        case .peq:
            switch param {
            case .frequency:
                return ParameterRange(lower: 20.0, upper: 20000.0)
            case .gain:
                return ParameterRange(lower: -36.0, upper: 12.0)
            case .q:
                return ParameterRange(lower: 0.25, upper: 8.0)
            }
        }
    }
 */
}
