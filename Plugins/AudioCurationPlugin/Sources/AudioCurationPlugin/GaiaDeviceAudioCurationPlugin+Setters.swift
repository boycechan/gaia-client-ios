//
//  © 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation
import GaiaBase
import PluginBase
import Packets

public extension GaiaDeviceAudioCurationPlugin {
    func setEnabledState(_ enabled: Bool) {
        let message = GaiaV3GATTPacket(featureID: .audioCuration,
                                       commandID: Commands.setACState.rawValue,
                                       payload: Data([StateTypes.anc.byteValue()!, enabled ? 0x01 : 0x00]))
        connection.sendData(channel: .command, payload: message.data, acknowledgementExpected: true)
    }

    func setCurrentFilterMode(_ value: Int) {
        // New API is 1-numberOfFilterModes input value 1...numberOfFilterModes
        assert(value > 0 && value <= numberOfFilterModes)
        guard numberOfFilterModes > 0 else {
            return
        }

        let mode = UInt8(max(min(value, numberOfFilterModes), 1))
        let message = GaiaV3GATTPacket(featureID: .audioCuration,
                                       commandID: Commands.setCurrentMode.rawValue,
                                       payload: Data([mode]))
        connection.sendData(channel: .command, payload: message.data, acknowledgementExpected: true)
    }

    func setGain(_ value: Int) {
        let valueToSet = UInt8(min(255, max(0, value)))

        let message = GaiaV3GATTPacket(featureID: .audioCuration,
                                       commandID: Commands.setGain.rawValue,
                                       payload: Data([valueToSet,valueToSet]))
        connection.sendData(channel: .command, payload: message.data, acknowledgementExpected: true)
    }
}

public extension GaiaDeviceAudioCurationPlugin {
    func setLeakthroughSteppedGainLevel(_ step: Int) {
        guard step >= 1 && step <= state.adState.leakthroughGainSteps else {
            return
        }

        let message = GaiaV3GATTPacket(featureID: .audioCuration,
                                       commandID: Commands.setLeakthroughSteppedGaiaStep.rawValue,
                                       payload: Data([UInt8(step)]))
        connection.sendData(channel: .command, payload: message.data, acknowledgementExpected: true)
    }

    func setBalance(_ balance: Double) {
        let normalized = max(0.0, min(balance, 1.0))
        let scaled = UInt8(round(normalized * 200.0))
        var sideByte: UInt8 = 0x00
        var valueByte: UInt8 = 0x00
        if scaled > 100 {
            // right
            sideByte = 0x01
            valueByte = scaled - 100
        } else {
            sideByte = 0x00
            valueByte = 100 - scaled
        }

        let message = GaiaV3GATTPacket(featureID: .audioCuration,
                                       commandID: Commands.setBalance.rawValue,
                                       payload: Data([sideByte, valueByte]))
        connection.sendData(channel: .command, payload: message.data, acknowledgementExpected: true)
    }

    func setWindNoiseReductionEnabled(_ state: Bool) {
        let message = GaiaV3GATTPacket(featureID: .audioCuration,
                                       commandID: Commands.setWNDState.rawValue,
                                       payload: Data([state ? 0x01 : 0x00]))
        connection.sendData(channel: .command, payload: message.data, acknowledgementExpected: true)
    }
}

public extension GaiaDeviceAudioCurationPlugin {
    func setAutoTransparencyEnabled(_ state: Bool) {
        let message = GaiaV3GATTPacket(featureID: .audioCuration,
                                       commandID: Commands.setAutoTransparencyState.rawValue,
                                       payload: Data([state ? 0x01 : 0x00]))
        connection.sendData(channel: .command, payload: message.data, acknowledgementExpected: true)
    }

    func setAutoTransparencyReleaseTime(_ time: GaiaDeviceAudioCurationAutoTransparencyReleaseTime) {
        let message = GaiaV3GATTPacket(featureID: .audioCuration,
                                       commandID: Commands.setAutoTransparencyReleaseTime.rawValue,
                                       payload: Data([time.byteValue()]))
        connection.sendData(channel: .command, payload: message.data, acknowledgementExpected: true)
    }
}

public extension GaiaDeviceAudioCurationPlugin {
    func setHowlingDetectionState(_ state: Bool) {
        let message = GaiaV3GATTPacket(featureID: .audioCuration,
                                       commandID: Commands.setHowlingDetectionState.rawValue,
                                       payload: Data([state ? 0x01 : 0x00]))
        connection.sendData(channel: .command, payload: message.data, acknowledgementExpected: true)
    }
}

public extension GaiaDeviceAudioCurationPlugin {
    func setNoiseIDState(_ state: Bool) {
        let message = GaiaV3GATTPacket(featureID: .audioCuration,
                                       commandID: Commands.setNoiseIDState.rawValue,
                                       payload: Data([state ? 0x01 : 0x00]))
        connection.sendData(channel: .command, payload: message.data, acknowledgementExpected: true)
    }
}

public extension GaiaDeviceAudioCurationPlugin {
    func setAAHState(_ state: Bool) {
        let message = GaiaV3GATTPacket(featureID: .audioCuration,
                                       commandID: Commands.setAdverseAcousticHandlerState.rawValue,
                                       payload: Data([state ? 0x01 : 0x00]))
        connection.sendData(channel: .command, payload: message.data, acknowledgementExpected: true)
    }
}

