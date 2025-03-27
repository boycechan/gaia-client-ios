//
//  © 2020 - 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation

public protocol GaiaDeviceLegacyANCPluginProtocol: GaiaDevicePluginProtocol {
    var enabled: Bool { get }
	func setEnabledState(_ enabled: Bool)

    var isLeftAdaptive: Bool { get }
    var isRightAdaptive: Bool { get }
    
    var currentMode: Int { get } //0...9
    var maxMode: Int { get } //0...9
    func setCurrentMode(_ value: Int) //0...9

    var staticGain: Int { get }
    var rightAdaptiveGain: Int { get }
    var leftAdaptiveGain: Int { get }
    func setStaticGain(_ value: Int)
}
