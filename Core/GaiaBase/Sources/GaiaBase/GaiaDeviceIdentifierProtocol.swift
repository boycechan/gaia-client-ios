//
//  © 2020 - 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation

public enum GaiaDeviceState: Equatable {
    case disconnected
    case awaitingTransportSetUp
    case settingUpTransport
    case transportReady
    case settingUpGaia
    case gaiaReady
    case failed(reason: GaiaError)

    public static func ==(lhs: GaiaDeviceState, rhs: GaiaDeviceState) -> Bool {
        switch lhs {
        case .disconnected:
            switch rhs {
            case .disconnected:
                return true
            default:
                return false
            }
        case .awaitingTransportSetUp:
            switch rhs {
            case .awaitingTransportSetUp:
                return true
            default:
                return false
            }
        case .settingUpTransport:
            switch rhs {
            case .settingUpTransport:
                return true
            default:
                return false
            }
        case .transportReady:
            switch rhs {
            case .transportReady:
                return true
            default:
                return false
            }
        case .settingUpGaia:
            switch rhs {
            case .settingUpGaia:
                return true
            default:
                return false
            }
        case .gaiaReady:
            switch rhs {
            case .gaiaReady:
                return true
            default:
                return false
            }
        case .failed(_):
            switch rhs {
            case .failed(_):
                return true
            default:
                return false
            }
        }
    }
}

public enum GaiaDeviceVersion {
    case unknown
    case v2
    case v3
}

public enum GaiaDeviceType{
	case unknown
    case earbud
    case headset
    case chargingCase
}

public protocol GaiaDeviceIdentifierProtocol: AnyObject {
    /// The type of API used by the device. The older v2 API is supported only to allow DFU. No other functionality is supported.
    var version: GaiaDeviceVersion { get }

    /// This id is used to recognize a device for reconnection.
    var connectionID: String { get }

    /// The type of the device, for example headset, earbud etc.
    var deviceType: GaiaDeviceType { get }
}

public extension GaiaDeviceIdentifierProtocol {
    var id: String {
        connectionID
    }
}

