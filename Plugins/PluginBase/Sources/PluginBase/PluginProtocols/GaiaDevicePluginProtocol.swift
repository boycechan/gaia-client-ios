//
//  © 2020 - 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation
import GaiaBase
import GaiaLogger

public protocol GaiaDevicePluginProtocol: AnyObject {
    static var featureID: GaiaDeviceQCPluginFeatureID { get }

    var featureID: GaiaDeviceQCPluginFeatureID { get }
//    var title: String { get }
//    var subtitle: String? { get }
    
    func startPlugin()
    func stopPlugin()
    func handoverDidOccur()

    func responseReceived(messageDescription: IncomingMessageDescription)
    func didSendData(channel: GaiaDeviceConnectionChannel, error: GaiaError?)

    func notificationStateDidChange(_ registered: Bool)
}

extension GaiaDevicePluginProtocol {
    public var featureID: GaiaDeviceQCPluginFeatureID {
        return Self.featureID
    }

    public func notificationStateDidChange(_ registered: Bool) {
        LOG(.high, "GaiaDevicePluginProtocol fallback logging for: \(featureID)")
    }
}
