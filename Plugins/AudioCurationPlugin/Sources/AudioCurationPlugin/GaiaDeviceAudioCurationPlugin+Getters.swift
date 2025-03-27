//
//  © 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation
import GaiaBase
import PluginBase
import Packets
import GaiaLogger

// MARK: Basic Support
internal extension GaiaDeviceAudioCurationPlugin {
    func getCurrentState() {
        let message = GaiaV3GATTPacket(featureID: .audioCuration,
                                       commandID: Commands.getACState.rawValue,
                                       payload: Data([StateTypes.anc.byteValue()!]))
        connection.sendData(channel: .command, payload: message.data, acknowledgementExpected: true)
    }

    func getNumberOfModes() {
        let message = GaiaV3GATTPacket(featureID: .audioCuration,
                                       commandID: Commands.getModesCount.rawValue,
                                       payload: Data())
        connection.sendData(channel: .command, payload: message.data, acknowledgementExpected: true)
    }

    func getCurrentMode() {
        let message = GaiaV3GATTPacket(featureID: .audioCuration,
                                       commandID: Commands.getCurrentMode.rawValue,
                                       payload: Data())
        connection.sendData(channel: .command, payload: message.data, acknowledgementExpected: true)
    }

    func getGain() {
        let message = GaiaV3GATTPacket(featureID: .audioCuration,
                                       commandID: Commands.getGain.rawValue,
                                       payload: Data())
        connection.sendData(channel: .command, payload: message.data, acknowledgementExpected: true)
    }

    func getNumberOfToggles() {
        let message = GaiaV3GATTPacket(featureID: .audioCuration,
                                       commandID: Commands.getToggleConfigCount.rawValue,
                                       payload: Data())
        connection.sendData(channel: .command, payload: message.data, acknowledgementExpected: true)
    }

    func getToggleConfig(toggle: Int) {
        let message = GaiaV3GATTPacket(featureID: .audioCuration,
                                       commandID: Commands.getToggleConfig.rawValue,
                                       payload: Data([UInt8(toggle)]))
        connection.sendData(channel: .command, payload: message.data, acknowledgementExpected: true)
    }

    func getScenarioConfig(scenario: GaiaDeviceAudioCurationScenario) {
        if let scenarioByte = scenario.byteValue() {
            let message = GaiaV3GATTPacket(featureID: .audioCuration,
                                           commandID: Commands.getScenarioConfig.rawValue,
                                           payload: Data([scenarioByte]))
            connection.sendData(channel: .command, payload: message.data, acknowledgementExpected: true)
        }
    }

    func getDemoModeSupport() {
        let message = GaiaV3GATTPacket(featureID: .audioCuration,
                                       commandID: Commands.getDemoModeSupport.rawValue)
        connection.sendData(channel: .command, payload: message.data, acknowledgementExpected: true)
    }

    func getDemoModeState() {
        let message = GaiaV3GATTPacket(featureID: .audioCuration,
                                       commandID: Commands.getDemoModeState.rawValue)
        connection.sendData(channel: .command, payload: message.data, acknowledgementExpected: true)
    }

    func getAdaptationControlState() {
        let message = GaiaV3GATTPacket(featureID: .audioCuration,
                                       commandID: Commands.getAdaptationControlState.rawValue)
        connection.sendData(channel: .command, payload: message.data, acknowledgementExpected: true)
    }
}

// MARK: Stepped Gain / Wind Noise
internal extension GaiaDeviceAudioCurationPlugin {
    func getSteppedGainState() {
        let message = GaiaV3GATTPacket(featureID: .audioCuration,
                                       commandID: Commands.getLeakthroughSteppedGaiaInfo.rawValue)
        connection.sendData(channel: .command, payload: message.data, acknowledgementExpected: true)
    }

    func getBalance() {
        let message = GaiaV3GATTPacket(featureID: .audioCuration,
                                       commandID: Commands.getBalance.rawValue)
        connection.sendData(channel: .command, payload: message.data, acknowledgementExpected: true)
    }

    func getWNDSupport() {
        let message = GaiaV3GATTPacket(featureID: .audioCuration,
                                       commandID: Commands.getWNDSupport.rawValue)
        connection.sendData(channel: .command, payload: message.data, acknowledgementExpected: true)
    }
    func getWNDState() {
        let message = GaiaV3GATTPacket(featureID: .audioCuration,
                                       commandID: Commands.getWNDState.rawValue)
        connection.sendData(channel: .command, payload: message.data, acknowledgementExpected: true)
    }
}

// MARK: Autotransparency
internal extension GaiaDeviceAudioCurationPlugin {
    func getAutoTransparencySupported() {
        let message = GaiaV3GATTPacket(featureID: .audioCuration,
                                       commandID: Commands.getAutoTransparencySupport.rawValue)
        connection.sendData(channel: .command, payload: message.data, acknowledgementExpected: true)
    }

    func getAutoTransparencyState() {
        let message = GaiaV3GATTPacket(featureID: .audioCuration,
                                       commandID: Commands.getAutoTransparencyState.rawValue)
        connection.sendData(channel: .command, payload: message.data, acknowledgementExpected: true)
    }

    func getAutoTransparencyReleaseTime() {
        let message = GaiaV3GATTPacket(featureID: .audioCuration,
                                       commandID: Commands.getAutoTransparencyReleaseTime.rawValue)
        connection.sendData(channel: .command, payload: message.data, acknowledgementExpected: true)
    }
}

// MARK: Howling
internal extension GaiaDeviceAudioCurationPlugin {
    func getHowlingDetectionSupported() {
        let message = GaiaV3GATTPacket(featureID: .audioCuration,
                                       commandID: Commands.getHowlingDetectionSupport.rawValue)
        connection.sendData(channel: .command, payload: message.data, acknowledgementExpected: true)
    }

    func getHowlingDetectionState() {
        let message = GaiaV3GATTPacket(featureID: .audioCuration,
                                       commandID: Commands.getHowlingDetectionState.rawValue)
        connection.sendData(channel: .command, payload: message.data, acknowledgementExpected: true)
    }

    func getHowlingDetectionFBGain() {
        let message = GaiaV3GATTPacket(featureID: .audioCuration,
                                       commandID: Commands.getHowlingDetectionFBGain.rawValue)
        connection.sendData(channel: .command, payload: message.data, acknowledgementExpected: true)
    }
}

// MARK: Noise ID
internal extension GaiaDeviceAudioCurationPlugin {
    func getNoiseIDSupported() {
        let message = GaiaV3GATTPacket(featureID: .audioCuration,
                                       commandID: Commands.getNoiseIDSupport.rawValue)
        connection.sendData(channel: .command, payload: message.data, acknowledgementExpected: true)
    }

    func getNoiseIDState() {
        let message = GaiaV3GATTPacket(featureID: .audioCuration,
                                       commandID: Commands.getNoiseIDState.rawValue)
        connection.sendData(channel: .command, payload: message.data, acknowledgementExpected: true)
    }

    func getNoiseIDCategory() {
        let message = GaiaV3GATTPacket(featureID: .audioCuration,
                                       commandID: Commands.getNoiseIDCategory.rawValue)
        connection.sendData(channel: .command, payload: message.data, acknowledgementExpected: true)
    }
}

// MARK: AAH
internal extension GaiaDeviceAudioCurationPlugin {
    func getAAHSupported() {
        let message = GaiaV3GATTPacket(featureID: .audioCuration,
                                       commandID: Commands.getAdverseAcousticHandlerSupport.rawValue)
        connection.sendData(channel: .command, payload: message.data, acknowledgementExpected: true)
    }

    func getAAHState() {
        let message = GaiaV3GATTPacket(featureID: .audioCuration,
                                       commandID: Commands.getAdverseAcousticHandlerState.rawValue)
        connection.sendData(channel: .command, payload: message.data, acknowledgementExpected: true)
    }
}

// MARK: Filter Topology
internal extension GaiaDeviceAudioCurationPlugin {
    func getANCFilterTopology() {
        let message = GaiaV3GATTPacket(featureID: .audioCuration,
                                       commandID: Commands.getANCFilterTopology.rawValue)
        connection.sendData(channel: .command, payload: message.data, acknowledgementExpected: true)
    }
}
