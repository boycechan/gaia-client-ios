//
//  © 2021 - 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation
public enum GaiaDeviceFitQuality {
    case unknown
    case good
    case poor
    case failed
    case determining

    public init(byteValue: UInt8) {
        switch byteValue {
        case 0x01:
            self = .good
        case 0x02:
            self = .poor
        case 0x03:
            self = .failed
        default:
            self = .unknown
        }
    }
}

public protocol GaiaDeviceEarbudFitPluginProtocol: GaiaDevicePluginProtocol {
    var leftFitQuality: GaiaDeviceFitQuality { get }
    var rightFitQuality: GaiaDeviceFitQuality { get }

    func startFitQualityTest()
    func stopFitQualityTest()
}
