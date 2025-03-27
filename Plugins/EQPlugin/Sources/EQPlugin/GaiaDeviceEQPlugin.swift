//
//  © 2020 - 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation
import GaiaBase
import PluginBase
import Packets
import GaiaLogger


private extension EQUserBandInfo {

    enum EQConstants {
        //Gain Parameter
        //The gain is a 16-bit signed number. The parameter value is 60 times the gain in decibels. For example a gain of 9.6 dB is represented by a parameter value of 576 (0x0240).
        static let PARAMETER_TO_GAIN_DIVISOR = 60.0

        //Q Parameter
        //The filter Q is a 16-bit unsigned number. The parameter value is 4096 times the Q. For example a Q of 4.0 is represented by a parameter value of 16384 (0x4000). A parameter value of 2896 (0x0b50) represents a Q of 0.70703125 (the nearest value to ).
        static let PARAMETER_TO_Q_DIVISOR = 4096.0
    }

    static let sizeInPacket = 7

    init?(data: Data, offset: Int = 0) {
        guard offset + Self.sizeInPacket <= data.count else {
            return nil
        }

        let frequencyPacketValue = UInt16(data: data, offset: offset) ?? 0
        let qPacketValue = UInt16(data: data, offset: offset + 2) ?? 0
        let filterTypePacketValue = data[offset + 4]
        let gainPacketValue = UInt16(data: data, offset: offset + 5) ?? 0
        let signedGainPacketValue = Int16(bitPattern: gainPacketValue)

        if let type = FilterType(rawValue: filterTypePacketValue) {
            self.init(frequency: Int(frequencyPacketValue),
                      gain: Double(signedGainPacketValue) / EQConstants.PARAMETER_TO_GAIN_DIVISOR,
                      q: Double(qPacketValue) / EQConstants.PARAMETER_TO_Q_DIVISOR,
                      filterType: type)
        } else {
            return nil
        }
    }

    func data() -> Data {
        var data = Data()
        data.append(UInt16(frequency).data())
        let qInt = UInt16(q * EQConstants.PARAMETER_TO_Q_DIVISOR)
        data.append(qInt.data())
        data.append(filterType.rawValue)

        let gainInt = Int16(gain * EQConstants.PARAMETER_TO_GAIN_DIVISOR)
        let gainUInt = UInt16(bitPattern: gainInt)
        data.append(gainUInt.data())
		return data
    }
}

// MARK: -

public class GaiaDeviceEQPlugin: GaiaDeviceEQPluginProtocol, GaiaNotificationSender {

    enum Commands: UInt16 {
        case getEQState = 0
        case getAvailableEQPresets = 1
        case getCurrentEQSet = 2
        case setCurrentEQSet = 3
        case getUserSetNumberOfBands = 4
        case getUserSetConfig = 5
        case setUserSetConfig = 6
    }

    enum Notifications: UInt8 {
        case eqStateChanged = 0
        case eqPresetChanged = 1
        case eqBandsChanged = 2
    }

    // MARK: Private ivars
    private weak var device: GaiaDeviceIdentifierProtocol?
    private let devicePluginVersion: UInt8
    private let connection: GaiaDeviceConnectionProtocol
    private let notificationCenter : NotificationCenter

    private var bandsPerPacket = 1
    private var expectedNumberOfBands = 0

    // MARK: Public ivars
    public static let featureID: GaiaDeviceQCPluginFeatureID = .eq

    public private(set) var eqEnabled: Bool = false
    public private(set) var currentPresetIndex: Int = -1
    public private(set) var availablePresets = [EQPreset] ()
    public private(set) var userBands = [EQUserBandInfo] ()

    // MARK: init/deinit
    public required init(version: UInt8,
                  device: GaiaDeviceIdentifierProtocol,
                  connection: GaiaDeviceConnectionProtocol,
                  notificationCenter: NotificationCenter) {
        self.devicePluginVersion = version
        self.device = device
        self.connection = connection
        self.notificationCenter = notificationCenter
    }

    // MARK: Public Methods
    public func startPlugin() {
		getEnabledState()
        getPresets()
        getCurrentPreset()
        getUserSetNumberOfBands()
    }

    public func stopPlugin() {
    }

    public func handoverDidOccur() {
    }

    public func responseReceived(messageDescription: IncomingMessageDescription) {
        guard let device = device else {
            return
        }
        
        switch messageDescription {
        case .notification(let notificationID, let data):
            if let id = Notifications(rawValue: notificationID) {
                switch (id) {
                case .eqStateChanged:
                    processNewEQState(data: data)
                case .eqPresetChanged:
                    processSetChanged(data: data)
                case .eqBandsChanged:
                    processBandsChanged(data: data)
                }
            }
        case .response(let command, let data):
            if let id = Commands(rawValue: command) {
                switch id {
                case .getEQState:
                    processNewEQState(data: data)
                case .getAvailableEQPresets:
                    processGetAvailablePresets(data: data)
                case .getCurrentEQSet:
                    processSetChanged(data: data)
                case .getUserSetConfig:
                    processGetUserSetConfig(data: data)
                case .getUserSetNumberOfBands:
                    processGetUserSetNumberOfBands(data: data)
                default:
                    break
                }
            }
        case .error(let command, _, _):
            if let id = Commands(rawValue: command) {
                LOG(.high, "**** EQ command failed \(id) ****")
                let notification = GaiaDeviceEQPluginNotification(sender: self,
                                                                  payload: device,
                                                                  reason: .enabledChanged)
                notificationCenter.post(notification)
            }

        default:
            break
        }
    }

    public func didSendData(channel: GaiaDeviceConnectionChannel, error: GaiaError?) {
    }
}

// MARK: - Public "Setter" Methods
public extension GaiaDeviceEQPlugin {
    func setCurrentPresetIndex(_ index: Int) {
        guard index < availablePresets.count else {
            return
        }

        let preset = availablePresets[index]

        let message = GaiaV3GATTPacket(featureID: .eq,
                                       commandID: Commands.setCurrentEQSet.rawValue,
                                       payload: Data([preset.byteValue]))
        connection.sendData(channel: .command, payload: message.data, acknowledgementExpected: true)
    }

    func setUserBand(index: Int, gain: Double) {
        // We set one band at a time.
        guard index < userBands.count else {
            return
        }

        var payload = Data([UInt8(index), UInt8(index)])
        let gainInt = Int16(gain * EQUserBandInfo.EQConstants.PARAMETER_TO_GAIN_DIVISOR)
        let gainUInt = UInt16(bitPattern: gainInt)
        payload.append(gainUInt.data())

        let message = GaiaV3GATTPacket(featureID: .eq,
                                       commandID: Commands.setUserSetConfig.rawValue,
                                       payload: payload)
        connection.sendData(channel: .command, payload: message.data, acknowledgementExpected: true)
    }

    func resetAllBandsToZeroGain() {
        guard userBands.count > 0 else {
            return
        }

        var payload = Data([UInt8(0), UInt8(userBands.count - 1)])
        payload.append(Data(repeating: 0x00, count: userBands.count * 2))

        let message = GaiaV3GATTPacket(featureID: .eq,
                                       commandID: Commands.setUserSetConfig.rawValue,
                                       payload: payload)
        connection.sendData(channel: .command, payload: message.data, acknowledgementExpected: true)
    }
}

// MARK: - Private Methods
private extension GaiaDeviceEQPlugin {
    func processNewEQState(data: Data) {
        guard
            let device = device,
            data.count > 0
        else {
            return
        }

        let oldEqEnabled = eqEnabled
        eqEnabled = data[0] == 1

        guard oldEqEnabled != eqEnabled else {
            return
        }

        if eqEnabled {
			startFetchingBandsIfPossible()
        }

        let notification = GaiaDeviceEQPluginNotification(sender: self,
                                                    payload: device,
                                                    reason: .enabledChanged)
        notificationCenter.post(notification)
    }

    func processSetChanged(data: Data) {
        guard
            let device = device,
            data.count > 0
        else {
            return
        }

        let presetChosen = EQPreset(byteValue: data[0])
        if let index = availablePresets.firstIndex(of: presetChosen) {
            if index == currentPresetIndex {
                return
            }

            currentPresetIndex = index
            let notification = GaiaDeviceEQPluginNotification(sender: self,
                                                        payload: device,
                                                        reason: .presetChanged)
            notificationCenter.post(notification)
        } else {
            currentPresetIndex = -1
        }
    }

    func processGetAvailablePresets(data: Data) {
        guard
            let device = device,
            data.count > 0
        else {
            return
        }

        let numberOfPresets = data[0]

        guard
            numberOfPresets > 0,
            data.count > numberOfPresets else {
            return
        }

        availablePresets.removeAll()
        for byteIndex in 1...Int(numberOfPresets) {
            let byte = data[byteIndex]
            let preset = EQPreset(byteValue: byte)
            availablePresets.append(preset)
        }

        let notification = GaiaDeviceEQPluginNotification(sender: self,
                                                    payload: device,
                                                    reason: .presetChanged)
        notificationCenter.post(notification)
    }

    func processBandsChanged(data: Data) {
        guard
            let _ = device,
            data.count > 0
        else {
            return
        }

        let numberOfChangedBands = data[0]

        guard
            numberOfChangedBands > 0,
            data.count > numberOfChangedBands else {
            return
        }

        for byteIndex in 1...Int(numberOfChangedBands) {
            let band = data[byteIndex]
            if band < expectedNumberOfBands {
                let message = GaiaV3GATTPacket(featureID: .eq,
                                               commandID: Commands.getUserSetConfig.rawValue,
                                               payload: Data([band, band]))

                LOG(.low, "Requesting band \(band)")
                connection.sendData(channel: .command, payload: message.data, acknowledgementExpected: true)
            } else {
                LOG(.high, "Changed Band Exceeds Expected Number Of Bands!!!")
            }
        }
    }

    func processGetUserSetConfig(data: Data) {
        guard
            let device = device,
            data.count > 1
        else {
            return
        }

		let firstBand = max(0,Int(data[0]))
        let lastBand = min(Int(data[1]), expectedNumberOfBands - 1)

        guard lastBand >= firstBand else {
            LOG(.medium, "EQ bands last < first")
            return
        }

        let numberBandsInPacket = (lastBand - firstBand) + 1
		let bytesRequiredForBands = numberBandsInPacket * 6

        guard data.count >= bytesRequiredForBands + 2 else {
            LOG(.medium, "EQ Packet too small for contained bands")
            return
        }

        LOG(.low, "Received bands: \(firstBand)-\(lastBand)")

        if expectedNumberOfBands == userBands.count {
            LOG(.low, "expectedNumberOfBands == userBands.count")
            var offset = 2
            // This is an update so just replace and notify
            for bandIndex in firstBand...lastBand {
                if let band = EQUserBandInfo(data: data, offset: offset) {
                    LOG(.low, "Band Index: \(bandIndex) info: \(band)")
                    userBands[bandIndex] = band
                }  else {
                    LOG(.medium, "EQ Dropped band at index: \(bandIndex)")
                }
                offset = offset + EQUserBandInfo.sizeInPacket
            }
            let notification = GaiaDeviceEQPluginNotification(sender: self,
                                                        payload: device,
                                                        reason: .bandChanged)
            notificationCenter.post(notification)
        } else {
            LOG(.low, "We're still doing an initial fetch of the bands")
            // We're still doing an initial fetch of the bands

            // Check first band is the next band we need.

            var nextFirstBand = -1
            if firstBand == userBands.count {
                // It is the one we need.
                var offset = 2
                // This is an update so just replace and notify
                for bandIndex in firstBand...lastBand {
                    if let band = EQUserBandInfo(data: data, offset: offset) {
                        LOG(.low, "Band Index: \(bandIndex) info: \(band)")
                        userBands.append(band)
                    } else {
                        LOG(.medium, "EQ Dropped band at index: \(bandIndex)")
                        // Skip all the other and start from where we got to
                        break
                    }
                    offset = offset + EQUserBandInfo.sizeInPacket
                }

                nextFirstBand = userBands.count

            } else {
                // It's not. Drop this request and start from where we were

                nextFirstBand = userBands.count
            }

            if nextFirstBand != expectedNumberOfBands {
                // Request more
				let lastBand = UInt8(min(nextFirstBand + bandsPerPacket, expectedNumberOfBands) - 1)
                LOG(.low, "Now requesting bands \(nextFirstBand)-\(lastBand)")
                let message = GaiaV3GATTPacket(featureID: .eq,
                                               commandID: Commands.getUserSetConfig.rawValue,
                                               payload: Data([UInt8(nextFirstBand), lastBand]))
                connection.sendData(channel: .command, payload: message.data, acknowledgementExpected: true)
            } else {
                // All bands loaded
                let notification = GaiaDeviceEQPluginNotification(sender: self,
                                                            payload: device ,
                                                            reason: .bandChanged)
                notificationCenter.post(notification)
            }
        }

    }

    func processGetUserSetNumberOfBands(data: Data) {
        guard data.count > 0 else {
            return
        }
        expectedNumberOfBands = min(Int(data[0]), 7)

        let availablePacketSpace = connection.maxReceivePayloadSizeForGaia - 2 // 2 for start and end band bytes
        bandsPerPacket = Int(availablePacketSpace / 6)

        startFetchingBandsIfPossible()
    }

    func startFetchingBandsIfPossible() {
        userBands.removeAll()

        if expectedNumberOfBands > 0 && eqEnabled {

            // Get first bunch of packets

            let message = GaiaV3GATTPacket(featureID: .eq,
                                           commandID: Commands.getUserSetConfig.rawValue,
                                           payload: Data([0, UInt8(min(bandsPerPacket, expectedNumberOfBands) - 1)]))

            LOG(.low, "Sending band request for 0 to \(UInt8(min(bandsPerPacket, expectedNumberOfBands) - 1))")
            connection.sendData(channel: .command, payload: message.data, acknowledgementExpected: true)
        }
    }
}

private extension GaiaDeviceEQPlugin {
    func getEnabledState() {
        let message = GaiaV3GATTPacket(featureID: .eq,
                                       commandID: Commands.getEQState.rawValue,
                                       payload: Data())
        connection.sendData(channel: .command, payload: message.data, acknowledgementExpected: true)
    }

    func getCurrentPreset() {
        let message = GaiaV3GATTPacket(featureID: .eq,
                                       commandID: Commands.getCurrentEQSet.rawValue,
                                       payload: Data())
        connection.sendData(channel: .command, payload: message.data, acknowledgementExpected: true)
    }

    func getPresets() {
        let message = GaiaV3GATTPacket(featureID: .eq,
                                       commandID: Commands.getAvailableEQPresets.rawValue,
                                       payload: Data())
        connection.sendData(channel: .command, payload: message.data, acknowledgementExpected: true)
    }

    func getUserSetNumberOfBands() {
        let message = GaiaV3GATTPacket(featureID: .eq,
                                       commandID: Commands.getUserSetNumberOfBands.rawValue,
                                       payload: Data())
        connection.sendData(channel: .command, payload: message.data, acknowledgementExpected: true)
    }
}
