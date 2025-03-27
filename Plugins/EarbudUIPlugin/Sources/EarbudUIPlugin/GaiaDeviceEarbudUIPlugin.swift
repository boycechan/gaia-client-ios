//
//  © 2021 - 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation
import GaiaBase
import PluginBase
import Packets
import GaiaLogger

public class GaiaDeviceEarbudUIPlugin: GaiaDeviceEarbudUIPluginProtocol, GaiaNotificationSender {
    enum Commands: UInt16 {
        case getSupportedTouchpads = 0
        case getSupportedGestures = 1
        case getSupportedContexts = 2
        case getSupportedActions = 3
        case getGestureConfiguration = 4
        case setGestureConfiguration = 5
        case resetToDefaults = 6
    }

    enum Notifications: UInt8 {
        case gestureConfigurationChanged = 0
        case configurationDidReset = 1
    }
    
    public struct EarbudUIGestureRecord: EarbudUITouchpadActionsProtocol {
        public let action: EarbudUIAction
        public let context: EarbudUIContext
        public let touchpad: EarbudUITouchpad
    }

    // MARK: Private ivars
    private weak var device: GaiaDeviceIdentifierProtocol?
    private let devicePluginVersion: UInt8
    private let connection: GaiaDeviceConnectionProtocol
    private let notificationCenter : NotificationCenter
    private var didBeginInitialFetch = false
    private var setsSentAndNotAcked: Int = 0

    private var gestureRecords = [EarbudUIGesture : [EarbudUIGestureRecord]]()

    // MARK: Public ivars
    public static let featureID: GaiaDeviceQCPluginFeatureID = .earbudUI

    public private(set) var availableTouchpads = EarbudUIAvailableTouchpads.unknown
    public private(set) var supportedContexts = Set<EarbudUIContext>()
    public private(set) var supportedGestures = Set<EarbudUIGesture>()
    public private(set) var supportedActions = Set<EarbudUIAction>()

    public private(set) var isValid = false

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

    public func fetchIfNotLoaded() {
        if !didBeginInitialFetch {
            startFetch()
        }
    }

    public func startPlugin() {
        fetchAvailableTouchpads()
    }

    public func stopPlugin() {
    }

    public func handoverDidOccur() {
    }

    public func responseReceived(messageDescription: IncomingMessageDescription) {
        guard let _ = device else {
            return
        }

        switch messageDescription {
        case .notification(let notificationID, let data):
            if let id = Notifications(rawValue: notificationID) {
                LOG(.medium, "Notification for \(id): \(data.map { String(format: "%02x", $0) }.joined())")
                switch (id) {
                case .gestureConfigurationChanged:
                    processGestureConfigurationChangedNotification(data: data)
                case .configurationDidReset:
                    processConfigurationDidResetNotification(data: data)
                }
            }
        case .response(let command, let data):
            if let id = Commands(rawValue: command) {
                LOG(.medium, "Response for \(id): \(data.map { String(format: "%02x", $0) }.joined())")
                switch id {
                case .getSupportedTouchpads:
                    processGetSupportedTouchpads(data: data)
                case .getSupportedGestures:
                    processGetSupportedGestures(data: data)
                case .getSupportedContexts:
                    processGetSupportedContexts(data: data)
                case .getSupportedActions:
                    processGetSupportedActions(data: data)
                case .getGestureConfiguration:
                    processGetGestureConfiguration(data: data)
                case .setGestureConfiguration:
                    setsSentAndNotAcked = max(setsSentAndNotAcked - 1, 0)
                case .resetToDefaults:
                    break

                }
            }
        case .error(let command, _, _):
            if let id = Commands(rawValue: command) {
                LOG(.high, "**** Earbud UI command failed \(id) ****")
                if id == .resetToDefaults {
                    let notification = GaiaDeviceEarbudUIPluginNotification(sender: self,
                                                                            payload: device,
                                                                            reason: .resetFailed)
                    notificationCenter.post(notification)
                } else if id == .setGestureConfiguration {
                    setsSentAndNotAcked = max(setsSentAndNotAcked - 1, 0)
                }
            }

        default:
            break
        }

    }

    public func didSendData(channel: GaiaDeviceConnectionChannel, error: GaiaError?) {
    }
}

public extension GaiaDeviceEarbudUIPlugin {
    func supportedActions(gesture: EarbudUIGesture, context: EarbudUIContext) -> [EarbudUIAction] {
        switch context {
        case .general:
            if gesture == .known(id: .pressAndHold) {
                return supportedActionsFromPotential([.known(id: .volumeUp), .known(id: .volumeDown), .known(id: .ANCEnableDisableToggle), .known(id: .nextANCMode),
                                                      .known(id: .voiceAssistantPrivacyToggle), .known(id: .voiceAssistantFetchQuery), .known(id: .voiceAssistantPushToTalk),
                                                      .known(id: .voiceAssistantCancel), .known(id: .voiceAssistantFetch), .known(id: .voiceAssistantQuery)])
            } else {
                return supportedActionsFromPotential([.known(id: .volumeUp), .known(id: .volumeDown), .known(id: .ANCEnableDisableToggle), .known(id: .nextANCMode),
                                                      .known(id: .voiceAssistantPrivacyToggle), .known(id: .voiceAssistantPushToTalk),
                                                      .known(id: .voiceAssistantCancel), .known(id: .voiceAssistantFetch), .known(id: .voiceAssistantQuery)])
            }
        case .mediaPlayer(let id):
            switch id {
            case .streaming:
                if gesture == .known(id: .pressAndHold) {
                	return supportedActionsFromPotential([.known(id: .playPauseToggle), .known(id: .stop), .known(id: .nextTrack), .known(id: .previousTrack), .known(id: .seekForward), .known(id: .seekBackward)])
                } else {
                    return supportedActionsFromPotential([.known(id: .playPauseToggle), .known(id: .stop), .known(id: .nextTrack), .known(id: .previousTrack)])
                }
                case .idle:
                return supportedActionsFromPotential([.known(id: .playPauseToggle)])
            }
        case .call(let id):
            switch id {
            case .inCall:
                return supportedActionsFromPotential([.known(id: .hangupCall), .known(id: .transferCallAudio), .known(id: .cycleThroughCalls),
                        .known(id: .muteMicrophoneToggle),.known(id: .joinCalls),  .known(id: .voiceJoinCallsHangUp)])
            case .incoming:
                return supportedActionsFromPotential([.known(id: .acceptCall), .known(id: .rejectCall), .known(id: .hangupCall), .known(id: .transferCallAudio), .known(id: .cycleThroughCalls),
                                                      .known(id: .joinCalls), .known(id: .muteMicrophoneToggle), .known(id: .voiceJoinCallsHangUp)])
            case .outgoing:
                return supportedActionsFromPotential([.known(id: .hangupCall), .known(id: .transferCallAudio), .known(id: .cycleThroughCalls), .known(id: .joinCalls), 
                                                      .known(id: .muteMicrophoneToggle), .known(id: .voiceJoinCallsHangUp)])
            case .heldCall:
                return supportedActionsFromPotential([.known(id: .cycleThroughCalls)])
            }
        case .handset(let id):
            switch id {
            case .connected:
                return supportedActionsFromPotential([ .known(id: .gamingModeToggle), .known(id: .disconnectLeastRecentlyUsedHandset)])
            case .disconnected:
                return supportedActionsFromPotential([.known(id: .reconnectLastConnectedHandset)])
            }
        case .unknown(_):
            return [EarbudUIAction]()
        }
    }

    private func supportedActionsFromPotential(_ potentialActions: [EarbudUIAction]) -> [EarbudUIAction] {
		let potentialSet = Set(potentialActions)
        let intersection = supportedActions.intersection(potentialSet)
        return Array(intersection).sorted(by: { $0.byteValue() < $1.byteValue() })
    }

    func currentTouchpadActions(gesture: EarbudUIGesture, context: EarbudUIContext) -> [EarbudUITouchpadActionsProtocol] {
        if let gestureRecord = gestureRecords[gesture] {
            return gestureRecord.filter { record in
                record.context == context
            }
        } else {
            return [EarbudUIGestureRecord]()
        }
    }

    func validateChange(gesture: EarbudUIGesture, context: EarbudUIContext, action: EarbudUIAction, touchpad: EarbudUITouchpad?) -> EarbudUIValidationResult {
        if let gestureRecord = gestureRecords[gesture] {
            if touchpad == nil {
                return .allow
            }

            if context != .general {
                let general = gestureRecord.filter { record in
                    record.context == .general
                }

                if general.count > 0 {
                    // It would override existing setting
                    return .warn(reason: .settingOtherWouldOverwriteGeneral)
                }

                return .allow
            }

            // general
            let notGeneral = gestureRecord.filter { record in
                record.context != .general
            }

            if notGeneral.count > 0 {
                // It would override existing setting
                return .warn(reason: .settingGeneralWouldOverwriteOther)
            }

            return .allow
        } else {
            return .deny(reason: .neverAllowed)
        }
    }

    func performChange(gesture: EarbudUIGesture, context: EarbudUIContext, action: EarbudUIAction, touchpad: EarbudUITouchpad?) -> Bool {
        let validateResult = validateChange(gesture: gesture, context: context, action: action, touchpad: touchpad)

        var permitted = true
        switch validateResult {
        case .deny(_):
            permitted = false
        default:
            break
        }

        guard permitted else {
            return false
        }

        if let gestureRecordsForGesture = gestureRecords[gesture] {
            var newRecords = [EarbudUIGestureRecord]()
            var insertionIndex = -1

            for record in gestureRecordsForGesture {
                if (context == .general && record.context != .general) || // Setting a general overrides all others.
                    (context != .general && record.context == .general) || // Setting a non-general context removes a general
                    (touchpad == nil && record.context == context && record.action == action) {
                    // Do nothing - we don't need the old record
                } else if (touchpad == .both && record.context == context) ||
                    (record.touchpad == touchpad && record.context == context) {
                    // We drop the old entry but will probably need to replace it at it's old index
                    insertionIndex = newRecords.count
                } else if record.context == context && record.touchpad == .both && (touchpad == .left || touchpad == .right) {
                    // We need to modify the existing to remove the gesture we're adding else where
                    if action != record.action {
                        let newRecord = EarbudUIGestureRecord(action: record.action, context: record.context, touchpad: touchpad == .left ? .right : .left)
                        newRecords.append(newRecord)
                        // We will need to insert another one to go with this
                        insertionIndex = newRecords.count
                    } else {
                        // We're setting a new toupad for an existing action so it will be added shortly anyway
                        insertionIndex = newRecords.count
                    }
                } else {
                    newRecords.append(record)
                }
            }

            // Now add our new entry
            if touchpad != nil {
                let newEntry = EarbudUIGestureRecord(action: action, context: context, touchpad: touchpad!)
                if insertionIndex >= 0 && insertionIndex < newRecords.count {
                    newRecords.insert(newEntry, at: insertionIndex)
                } else {
                    // Order is call>music>handset
                    switch context {
                    case .call(_):
                        // New call entries go at the front.
                        newRecords.insert(newEntry, at: 0)
                    case .handset(_),
                         .general:
                        // Handset at the end and generals only exist with other generals.
                        newRecords.append(newEntry)
                    case .mediaPlayer(_):
                        // Music player goes before anything that's not call.
                        if let insertionIndex = newRecords.firstIndex (where: { record in
                            switch record.context {
                            case .call(_):
                                return false
                            default:
                                return true
                            }
                        }) {
                            newRecords.insert(newEntry, at: insertionIndex)
                        } else {
                            newRecords.append(newEntry)
                        }
                    case .unknown(_):
                        break
                    }
                }
            }

            // Now send. We send in blocks of seven records as this fits in all packets

            var payloads = [Data]()
            var outerIndex = 0
            repeat {
                var payload = Data()
                for recordIndex in outerIndex..<min(outerIndex + 7, newRecords.count) {
                    let entry = newRecords[recordIndex]
                    let dataForEntry = gesturePacketEntryForRecord(entry)
                    payload.append(dataForEntry)
                    outerIndex += 1
                }

                LOG(.low, "Generated Payload for sending: \(payload.map { String(format: "%02x", $0) }.joined())")
                payloads.append(payload)
            } while outerIndex < newRecords.count

            for packetIndex in 0..<payloads.count {
                let payload = payloads[packetIndex]
                let more = packetIndex != payloads.count - 1
                var fullPayload = Data()

                let gestureByte = gesture.byteValue() + (more ? 128 : 0) // Set MSB if more
                fullPayload.append(Data([gestureByte, UInt8(packetIndex * 7)]))
                fullPayload.append(payload)

                let message = GaiaV3GATTPacket(featureID: .earbudUI,
                                               commandID: Commands.setGestureConfiguration.rawValue,
                                               payload: fullPayload)
                connection.sendData(channel: .command, payload: message.data, acknowledgementExpected: true)
                setsSentAndNotAcked = setsSentAndNotAcked + 1
            }
        }
        return true
    }

    func performFactoryReset() {
        let message = GaiaV3GATTPacket(featureID: .earbudUI,
                                       commandID: Commands.resetToDefaults.rawValue)
        connection.sendData(channel: .command, payload: message.data, acknowledgementExpected: true)
    }
}

private extension GaiaDeviceEarbudUIPlugin {
    func startFetch() {
		didBeginInitialFetch = true
        fetchAllContexts()
        fetchAllActions()
        fetchAllGestures()
    }

    func gesturePacketEntryForRecord(_ gestureRecord: EarbudUIGestureRecord) -> Data {
        let touchPadBits = (UInt16(gestureRecord.touchpad.byteValue()) << 14 ) & 0b1100000000000000
        let contextBits = (UInt16(gestureRecord.context.byteValue()) << 7 ) & 0b0011111110000000
        let actionBits = UInt16(gestureRecord.action.byteValue()) & 0b0000000001111111

        let result = touchPadBits | contextBits | actionBits
        return result.data(bigEndian: true)
    }

    func processGetSupportedTouchpads(data: Data) {
        if let byte = data.first {
            switch byte {
            case 1:
                availableTouchpads = .one
            case 2:
                availableTouchpads = .two
            default:
                availableTouchpads = .unknown
            }
        }
    }

    func processGestureConfigurationChangedNotification(data: Data) {
        guard setsSentAndNotAcked == 0 else {
            // Device side sends notification on every set message... We just do something on the last one.
            return
        }

        if let id = data.first {
            let gesture = EarbudUIGesture(byteValue: id)
            gestureRecords[gesture] = nil

            fetchGestureConfig(gesture: gesture, from: 0)
        }
    }

    func processConfigurationDidResetNotification(data: Data) {
        isValid = false
        gestureRecords.removeAll()
        startGestureFetch()
    }

    func processGetSupportedGestures(data: Data) {
        supportedGestures = processBitFieldResponse(data: data)
		startGestureFetch()
        let notification = GaiaDeviceEarbudUIPluginNotification(sender: self,
                                                                payload: device,
                                                                reason: .updated)
        notificationCenter.post(notification)
    }

    func startGestureFetch() {
        if let firstGesture = getSupportedGesture(index: 0) {
            fetchGestureConfig(gesture: firstGesture, from: 0)
        } else {
            let notification = GaiaDeviceEarbudUIPluginNotification(sender: self,
                                                                    payload: device,
                                                                    reason: .updated)
            notificationCenter.post(notification)
        }
    }

    func processGetSupportedContexts(data: Data) {
		supportedContexts = processBitFieldResponse(data: data)
    }

    func processGetSupportedActions(data: Data) {
        supportedActions = processBitFieldResponse(data: data)
    }

    func processGetGestureConfiguration(data: Data) {
        guard
            let byte = data.first,
            data.count % 2 == 1 // It's always an odd number
        else {
            return
        }

        let more = (byte & 0b10000000) != 0
        let gestureID = byte & 0b01111111
        let gesture = EarbudUIGesture(byteValue: gestureID)

        var offset = 1
        var currentRecords = gestureRecords[gesture] ?? [EarbudUIGestureRecord]()

        while offset < data.count {
            if let entry = UInt16(data: data, offset: offset, bigEndian: true) {
                let originatingPadID = (entry & 0b1100000000000000) >> 14
                let originatingPad = EarbudUITouchpad(byteValue: UInt8(originatingPadID))

                let contextID = (entry & 0b0011111110000000) >> 7
                let context = EarbudUIContext(byteValue: UInt8(contextID))

                let actionID = entry & 0b0000000001111111
                let action = EarbudUIAction(byteValue: UInt8(actionID))

                let record = EarbudUIGestureRecord(action: action, context: context, touchpad: originatingPad)
                currentRecords.append(record)
            }

            offset += 2
        }

        gestureRecords[gesture] = currentRecords

        if more {
            let numberAlreadyFetched = UInt8(gestureRecords[gesture]?.count ?? 0)
            fetchGestureConfig(gesture: gesture, from: numberAlreadyFetched)
        } else {
            if gestureRecords.count >= supportedGestures.count {
                // We have all the gesture info so notify

                isValid = true

                let notification = GaiaDeviceEarbudUIPluginNotification(sender: self,
                                                                        payload: device,
                                                                        reason:	.updated)
                notificationCenter.post(notification)
            } else {
                // Find next gesture
                if let nextGesture = getSupportedGesture(index: gestureRecords.count) {
                    fetchGestureConfig(gesture: nextGesture, from: 0)
                } else {
                    isValid = true
                    let notification = GaiaDeviceEarbudUIPluginNotification(sender: self,
                                                                            payload: device,
                                                                            reason: .updated)
                    notificationCenter.post(notification)
                }
            }
        }
    }

    func processBitFieldResponse<T>(data: Data) -> Set<T> where T:ByteValueProtocol {
        var results = Set<T> ()
        for byteIndex in 0..<data.count {
            var byte = data[byteIndex]
            for bitIndex in 0...7 {
				let present = (byte & 0b00000001) == 1
                if present {
                    let index = UInt8((byteIndex * 8) + bitIndex)
                    let object = T(byteValue: index)
                    results.insert(object)
                }
                byte = byte >> 1
            }
        }
        return results
    }

    func getSupportedGesture(index: Int) -> EarbudUIGesture? {
        guard index < supportedGestures.count else {
            return nil
        }

        let sorted = Array(supportedGestures).sorted(by: { $0.byteValue() < $1.byteValue() })
        let nextGesture = sorted[index]
        return nextGesture
    }
}


private extension GaiaDeviceEarbudUIPlugin {
    func fetchAvailableTouchpads() {
        let message = GaiaV3GATTPacket(featureID: .earbudUI,
                                       commandID: Commands.getSupportedTouchpads.rawValue,
                                       payload: Data())
        connection.sendData(channel: .command, payload: message.data, acknowledgementExpected: true)
    }

    func fetchAllContexts() {
        let message = GaiaV3GATTPacket(featureID: .earbudUI,
                                       commandID: Commands.getSupportedContexts.rawValue,
                                       payload: Data())
        connection.sendData(channel: .command, payload: message.data, acknowledgementExpected: true)
    }

    func fetchAllGestures() {
        let message = GaiaV3GATTPacket(featureID: .earbudUI,
                                       commandID: Commands.getSupportedGestures.rawValue,
                                       payload: Data())
        connection.sendData(channel: .command, payload: message.data, acknowledgementExpected: true)
    }

    func fetchAllActions() {
        let message = GaiaV3GATTPacket(featureID: .earbudUI,
                                       commandID: Commands.getSupportedActions.rawValue,
                                       payload: Data())
        connection.sendData(channel: .command, payload: message.data, acknowledgementExpected: true)
    }

    func fetchGestureConfig(gesture: EarbudUIGesture, from: UInt8) {
        if from == 0 {
        	gestureRecords[gesture] = [EarbudUIGestureRecord]()
        }

        let message = GaiaV3GATTPacket(featureID: .earbudUI,
                                       commandID: Commands.getGestureConfiguration.rawValue,
                                       payload: Data([gesture.byteValue(), from]))
        connection.sendData(channel: .command, payload: message.data, acknowledgementExpected: true)
    }
}
