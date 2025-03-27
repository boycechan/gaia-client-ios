//
//  © 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation
import GaiaBase
import PluginBase

// MARK: Basic Support
internal extension GaiaDeviceAudioCurationPlugin {
    func processNewANCState(data: Data) {
        guard
            let device = device,
            data.count > 1
        else {
            return
        }

        let stateType = StateTypes(byteValue: data[0])

        guard stateType == .anc else {
            // We only handle anc at current time.
            return
        }

        enabled = data[1] == 1
        let notification = GaiaDeviceAudioCurationPluginNotification(sender: self,
                                                                            payload: device,
                                                                            reason: .enabledChanged)
        notificationCenter.post(notification)
    }

    func processNewANCModeAndTypeInfo(data: Data) {
        guard
            let device = device,
            data.count >= 4
        else {
            return
        }

        currentFilterMode = max(1, min(Int(data[0]), numberOfFilterModes))

        let modeIndex = currentFilterMode - 1
        let ancModeType = AudioCurationModeType(byteValue: data[1])
        let adaptationControlSupported = data[2] == 0x01
        let gainControlSupported = data[3] == 0x01

        var antiHowlingSupported = false
        if devicePluginVersion >= 5 && data.count >= 5 {
            antiHowlingSupported = data[4] == 0x01
        }

        var supportedFeatures: AudioCurationModeSupportedFeatures = [AudioCurationModeSupportedFeatures.updatesFeedForwardGain]
        if adaptationControlSupported {
            supportedFeatures.insert(.changeAdaptiveState)
        }
        if gainControlSupported {
            supportedFeatures.insert(.changeLeakthroughGain)
        }
        if antiHowlingSupported {
            supportedFeatures.insert(.antiHowlingControl)
        }

        if modeIndex < state.modes.filterModes.count {
            let oldEntry = state.modes.filterModes[modeIndex]
            let newEntry = GaiaDeviceAudioCurationModeInfo(mode: oldEntry.mode,
                                                           action: oldEntry.action,
                                                           type: ancModeType,
                                                           supportedFeatures: supportedFeatures)
            state.modes.filterModes[modeIndex] = newEntry
        }


        let notification = GaiaDeviceAudioCurationPluginNotification(sender: self,
                                                                     payload: device,
                                                                     reason: .modeChanged)
        notificationCenter.post(notification)
    }

    func processNewGain(data: Data) {
        guard
            let device = device,
            data.count >= 4
        else {
            return
        }

        let mode = Int(data[0])

        guard mode == currentFilterMode else {
            return
        }

        // let gainType = Int(data[1])
        
        let inst0LeftGain = data[2]
        let inst0RightGain = data[3]
        
        if devicePluginVersion < 8 || data.count == 4 {
            state.feedForwardGains = GainContainer(instances: [GainContainer.Instance(left: GainContainer.Value(gain: inst0LeftGain, totalGain: nil),
                                                                                      right: GainContainer.Value(gain: inst0RightGain, totalGain: nil))])
        } else {
            // Try to decode the lot
            if data.count >= 5 {
                state.filterTopology = FilterTopology(byteValue: data[4])
            }
            
            if state.filterTopology == .dual && data.count >= 15 {
                let inst1LeftGain = data[5]
                let inst1RightGain = data[6]
                
                let inst0LeftTotalGain = Float(Int16(data: data, offset: 7, bigEndian: true) ?? 0) / 10.0
                let inst0RightTotalGain = Float(Int16(data: data, offset: 9, bigEndian: true) ?? 0) / 10.0
                
                let inst1LeftTotalGain = Float(Int16(data: data, offset: 11, bigEndian: true) ?? 0) / 10.0
                let inst1RightTotalGain = Float(Int16(data: data, offset: 13, bigEndian: true) ?? 0) / 10.0
                
                let inst0Container = GainContainer.Instance(left: GainContainer.Value(gain: inst0LeftGain, totalGain: inst0LeftTotalGain),
                                                            right: GainContainer.Value(gain: inst0RightGain, totalGain: inst0RightTotalGain))
                let inst1Container = GainContainer.Instance(left: GainContainer.Value(gain: inst1LeftGain, totalGain: inst1LeftTotalGain),
                                                            right: GainContainer.Value(gain: inst1RightGain, totalGain: inst1RightTotalGain))
                
                state.feedForwardGains = GainContainer(instances: [inst0Container, inst1Container])
            } else {
                state.feedForwardGains = GainContainer(instances: [GainContainer.Instance(left: GainContainer.Value(gain: inst0LeftGain, totalGain: nil),
                                                                                          right: GainContainer.Value(gain: inst0RightGain, totalGain: nil))])
            }
        }
        
        let notification = GaiaDeviceAudioCurationPluginNotification(sender: self,
                                                                     payload: device,
                                                                     reason: .gainChanged)
        notificationCenter.post(notification)
    }

    func processNewANCDemoModeSupport(data: Data) {
        guard
            data.count > 0
        else {
            return
        }

        state.state.demoModeAvailable = data[0] == 0x01
    }

    func processNewToggleConfig(data: Data) {
        guard
            let device = device,
            data.count >= 2
        else {
            return
        }

        let toggle = Int(data[0])
        let modeByte = data[1]
        let mode = GaiaDeviceAudioCurationMode(byteValue: modeByte)

        guard
            toggle <= numberOfToggles,
            toggle > 0,
            mode != .unknown
        else {
            return
        }


        let toggleIndex = toggle - 1
        state.modes.toggleOptions[toggleIndex] = mode

        let notification = GaiaDeviceAudioCurationPluginNotification(sender: self,
                                                                     payload: device,
                                                                     reason: .toggleConfigChanged)
        notificationCenter.post(notification)
    }

    func processNewScenarioConfig(data: Data) {
        guard
            let device = device,
            data.count >= 2
        else {
            return
        }

        let scenario = GaiaDeviceAudioCurationScenario(byteValue: data[0])
        let mode = GaiaDeviceAudioCurationMode(byteValue: data[1])

        guard
            scenario != .unknown,
            mode != . unknown
        else {
            return
        }

        state.modes.scenarioModes[scenario] = mode
        let notification = GaiaDeviceAudioCurationPluginNotification(sender: self,
                                                                     payload: device,
                                                                     reason: .scenarioConfigChanged)
        notificationCenter.post(notification)
    }

    func processNewDemoModeState(data: Data) {
        guard
            let device = device,
            data.count > 0
        else {
            return
        }

        state.state.inDemoMode = data[0] != 0x00

        let notification = GaiaDeviceAudioCurationPluginNotification(sender: self,
                                                                     payload: device,
                                                                     reason: .demoModeStateChanged)
        notificationCenter.post(notification)
    }

    func processNewAdaptationState(data: Data) {
        guard let device = device,
            data.count > 0
        else {
            return
        }

        state.state.adaptationIsEnabled = data[0] == 0x01

        let notification = GaiaDeviceAudioCurationPluginNotification(sender: self,
                                                                     payload: device,
                                                                     reason: .adaptationStateChanged)
        notificationCenter.post(notification)
    }
}

// MARK: Stepped Gain / Wind Noise
internal extension GaiaDeviceAudioCurationPlugin {
    func processNewLeakthroughSteppedGainInfo(data: Data) {
        guard let device = device,
            data.count >= 5
        else {
            return
        }

        //let mode = Int(data[0])
        let numberOfSteps = max(min(Int(data[1]), 10), 3) // Range 3->10
        let dbStepSize = max(min(Int(data[2]), 5), 2) // Range 2->5

        let minDB = Int8(bitPattern: data[3])
        let currentStep = max(min(Int(data[4]), numberOfSteps), 1)

        state.adState.leakthroughGainSteps = numberOfSteps
        state.adState.leakthroughGainStepSize = dbStepSize
        state.adState.leakthroughGainMinStepDb = Int(minDB)
        state.adState.leakthroughGainLevel = currentStep

        let notification = GaiaDeviceAudioCurationPluginNotification(sender: self,
                                                                     payload: device,
                                                                     reason: .leakthoughSteppedGainConfigChanged)
        notificationCenter.post(notification)

        let notification2 = GaiaDeviceAudioCurationPluginNotification(sender: self,
                                                                     payload: device,
                                                                     reason: .gainChanged)
        notificationCenter.post(notification2)
    }

    func processNewLeakthroughSteppedGainStep(data: Data) {
        guard let device = device,
            data.count >= 2
        else {
            return
        }

        //let mode = Int(data[0])
        let step = Int(data[1])

        guard step >= 1 && step <= state.adState.leakthroughGainSteps else {
            return
        }

        state.adState.leakthroughGainLevel = step
        let notification = GaiaDeviceAudioCurationPluginNotification(sender: self,
                                                                     payload: device,
                                                                     reason: .gainChanged)
        notificationCenter.post(notification)
    }

    func processNewBalance(data: Data) {
        guard let device = device,
            data.count >= 2
        else {
            return
        }

        let isLeft = data[0] == 0x00
        let gain = min(Int(data[1]), 100)
        let scaledGain = Double(gain) / 200.0 // range now 0 to 0.5

        let newValue = isLeft ? 0.5 - scaledGain : 0.5 + scaledGain // Now 0 to 1.0, right values > 0.5 left < 0.5

        state.adState.balance = newValue

        let notification = GaiaDeviceAudioCurationPluginNotification(sender: self,
                                                                     payload: device,
                                                                     reason: .balanceChanged)
        notificationCenter.post(notification)
    }

    func processNewWNDSupport(data: Data) {
        guard let _ = device,
            data.count >= 1
        else {
            return
        }

        state.adState.windNoiseReductionSupported = data[0] != 0x00

        if state.adState.windNoiseReductionSupported {
            getWNDState()
        }
    }

    func processNewWNDState(data: Data) {
        guard let device = device,
            data.count >= 1
        else {
            return
        }

        state.adState.windNoiseReductionEnabled = data[0] != 0x00

        let notification = GaiaDeviceAudioCurationPluginNotification(sender: self,
                                                                     payload: device,
                                                                     reason: .wndStatusChanged)
        notificationCenter.post(notification)
    }

    func processNewWNDDetectionState(data: Data) {
        guard let device = device,
            data.count >= 2
        else {
            return
        }

        state.adState.windNoiseReductionActiveLeft = data[0] != 0x00
        state.adState.windNoiseReductionActiveRight = data[1] != 0x00

        let notification = GaiaDeviceAudioCurationPluginNotification(sender: self,
                                                                     payload: device,
                                                                     reason: .wndDetectionStateChanged)
        notificationCenter.post(notification)
    }
}

// MARK: Autotransparency
internal extension GaiaDeviceAudioCurationPlugin {
    func processNewAutoTransparencySupported(data: Data) {
        guard let _ = device,
            data.count >= 1
        else {
            return
        }

        state.autoTransparencyState.isSupported = data[0] != 0x00

        if state.autoTransparencyState.isSupported {
            getAutoTransparencyState()
            getAutoTransparencyReleaseTime()
        }
    }

    func processNewAutoTransparencyState(data: Data) {
        guard let device = device,
            data.count >= 1
        else {
            return
        }

        state.autoTransparencyState.isEnabled = data[0] != 0x00

        let notification = GaiaDeviceAudioCurationPluginNotification(sender: self,
                                                                     payload: device,
                                                                     reason: .autoTransparencyStateChanged)
        notificationCenter.post(notification)
    }

    func processNewAutoTransparencyReleaseTime(data: Data) {
        guard let device = device,
            data.count >= 1
        else {
            return
        }

        let rt = GaiaDeviceAudioCurationAutoTransparencyReleaseTime(byteValue: data[0])
        state.autoTransparencyState.releaseTime = rt

        let notification = GaiaDeviceAudioCurationPluginNotification(sender: self,
                                                                     payload: device,
                                                                     reason: .autoTransparencyReleaseTimeChanged)
        notificationCenter.post(notification)
    }
}

// MARK: Howling
internal extension GaiaDeviceAudioCurationPlugin {
    func processNewHowlingDetectionSupport(data: Data) {
        guard let _ = device,
            data.count >= 1
        else {
            return
        }

        state.howlingDetectionState.isSupported = data[0] != 0
        state.howlingDetectionState.gainReductionIndicationSupported = devicePluginVersion >= 7 && state.howlingDetectionState.isSupported
        if state.howlingDetectionState.isSupported {
            getHowlingDetectionState()
            getHowlingDetectionFBGain()
        }
    }

    func processNewHowlingDetectionState(data: Data) {
        guard let device = device,
            data.count >= 1
        else {
            return
        }

        state.howlingDetectionState.isEnabled = data[0] != 0

        let notification = GaiaDeviceAudioCurationPluginNotification(sender: self,
                                                                     payload: device,
                                                                     reason: .howlingDetectionStateChanged)
        notificationCenter.post(notification)
    }

    func processNewHowlingDetectionFBGain(data: Data) {
        guard
            let device = device,
            data.count >= 4
        else {
            return
        }

        let mode = Int(data[0])

        guard mode == currentFilterMode else {
            return
        }
        
        // let gainType = Int(data[1])
        
        let inst0LeftGain = data[2]
        let inst0RightGain = data[3]
        
        if devicePluginVersion < 8 || data.count == 4 {
            state.howlingDetectionState.gains = GainContainer(instances: [GainContainer.Instance(left: GainContainer.Value(gain: inst0LeftGain, totalGain: nil),
                                                                                                 right: GainContainer.Value(gain: inst0RightGain, totalGain: nil))])
        } else {
            // Try to decode the lot
            if data.count >= 5 {
                state.filterTopology = FilterTopology(byteValue: data[4])
            }
            
            if state.filterTopology == .dual && data.count >= 15 {
                let inst1LeftGain = data[5]
                let inst1RightGain = data[6]
                
                let inst0LeftTotalGain = Float(Int16(data: data, offset: 7, bigEndian: true) ?? 0) / 10.0
                let inst0RightTotalGain = Float(Int16(data: data, offset: 9, bigEndian: true) ?? 0) / 10.0
                
                let inst1LeftTotalGain = Float(Int16(data: data, offset: 11, bigEndian: true) ?? 0) / 10.0
                let inst1RightTotalGain = Float(Int16(data: data, offset: 13, bigEndian: true) ?? 0) / 10.0
                
                let inst0Container = GainContainer.Instance(left: GainContainer.Value(gain: inst0LeftGain, totalGain: inst0LeftTotalGain),
                                                            right: GainContainer.Value(gain: inst0RightGain, totalGain: inst0RightTotalGain))
                let inst1Container = GainContainer.Instance(left: GainContainer.Value(gain: inst1LeftGain, totalGain: inst1LeftTotalGain),
                                                            right: GainContainer.Value(gain: inst1RightGain, totalGain: inst1RightTotalGain))
                
                state.howlingDetectionState.gains = GainContainer(instances: [inst0Container, inst1Container])
            } else {
                state.howlingDetectionState.gains = GainContainer(instances: [GainContainer.Instance(left: GainContainer.Value(gain: inst0LeftGain, totalGain: nil),
                                                                                                     right: GainContainer.Value(gain: inst0RightGain, totalGain: nil))])
            }
        }
        
        let notification = GaiaDeviceAudioCurationPluginNotification(sender: self,
                                                                     payload: device,
                                                                     reason: .howlingDetectionGainChanged)
        notificationCenter.post(notification)
    }

    func processNewHowlingDetectionGainReduction(data: Data) {
        guard let device = device,
            data.count >= 2
        else {
            return
        }

        state.howlingDetectionState.gainReductionActiveLeft = data[0] != 0x00
        state.howlingDetectionState.gainReductionActiveRight = data[1] != 0x00

        let notification = GaiaDeviceAudioCurationPluginNotification(sender: self,
                                                                     payload: device,
                                                                     reason: .howlingDetectionGainReductionStateChanged)
        notificationCenter.post(notification)
    }
}

// MARK: Noise ID
internal extension GaiaDeviceAudioCurationPlugin {
    func processNewNoiseIDSupport(data: Data) {
        guard let _ = device,
            data.count >= 1
        else {
            return
        }

        state.noiseIDState.isSupported = data[0] != 0
        if state.noiseIDState.isSupported {
            getNoiseIDState()
            getNoiseIDCategory()
        }
    }

    func processNewNoiseIDState(data: Data) {
        guard let device = device,
            data.count >= 1
        else {
            return
        }

        state.noiseIDState.isEnabled = data[0] != 0

        let notification = GaiaDeviceAudioCurationPluginNotification(sender: self,
                                                                     payload: device,
                                                                     reason: .noiseIDStateChanged)
        notificationCenter.post(notification)
    }

    func processNewNoiseIDCategory(data: Data) {
        guard
            let device = device,
            data.count >= 1
        else {
            return
        }

        state.noiseIDState.category = GaiaDeviceAudioCurationNoiseIDCategory(byteValue: data[0])

        let notification = GaiaDeviceAudioCurationPluginNotification(sender: self,
                                                                            payload: device,
                                                                            reason: .noiseIDCategoryChanged)
        notificationCenter.post(notification)
    }
}

// MARK: AAH
internal extension GaiaDeviceAudioCurationPlugin {
    func processNewAAHSupport(data: Data) {
        guard let _ = device,
              data.count >= 1
        else {
            return
        }

        state.aahState.isSupported = data[0] != 0
        state.aahState.gainReductionIndicationSupported = devicePluginVersion >= 7 && state.aahState.isSupported
        if state.aahState.isSupported {
            getAAHState()
        }
    }

    func processNewAAHState(data: Data) {
        guard let device = device,
              data.count >= 1
        else {
            return
        }

        state.aahState.isEnabled = data[0] != 0

        let notification = GaiaDeviceAudioCurationPluginNotification(sender: self,
                                                                     payload: device,
                                                                     reason: .AAHStateChanged)
        notificationCenter.post(notification)
    }

    func processNewAAHGainReduction(data: Data) {
        guard let device = device,
            data.count >= 2
        else {
            return
        }

        state.aahState.gainReductionActiveLeft = data[0] != 0x00
        state.aahState.gainReductionActiveRight = data[1] != 0x00

        let notification = GaiaDeviceAudioCurationPluginNotification(sender: self,
                                                                     payload: device,
                                                                     reason: .AAHGainReductionStateChanged)
        notificationCenter.post(notification)
    }
}

// MARK: Filter Topology
internal extension GaiaDeviceAudioCurationPlugin {
    func processNewANCFilterTopology(data: Data) {
        guard let device,
              data.count >= 1
        else {
            return
        }
        
        state.filterTopology = FilterTopology(byteValue: data[0])
        
        let notification2 = GaiaDeviceAudioCurationPluginNotification(sender: self,
                                                                     payload: device,
                                                                     reason: .gainChanged)
        notificationCenter.post(notification2)
    }
}
