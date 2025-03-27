//
//  © 2021 - 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation
import GaiaBase

public enum EarbudUIContext: ByteValueProtocol, Equatable, Hashable {
    public struct ContextIDs {
        static let general: UInt8 = 0

        public enum MediaPlayer: UInt8 {
            case streaming = 1
            case idle = 2
        }

        public enum Call: UInt8 {
            case inCall = 3
            case incoming = 4
            case outgoing = 5
            case heldCall = 6
        }

        public enum Handset: UInt8 {
            case disconnected = 7
            case connected = 8
        }
    }

    case general // General is a meta context that overrides the others.
    case mediaPlayer(id: ContextIDs.MediaPlayer)
    case call(id: ContextIDs.Call)
    case handset(id: ContextIDs.Handset)
    case unknown(id: UInt8)

    public init(byteValue: UInt8) {
        if byteValue == ContextIDs.general {
            self = .general
            return
        }
        if let mediaPlayerID = ContextIDs.MediaPlayer(rawValue: byteValue) {
            self = .mediaPlayer(id: mediaPlayerID)
            return
        }
        if let callID = ContextIDs.Call(rawValue: byteValue) {
            self = .call(id: callID)
            return
        }
        if let handsetID = ContextIDs.Handset(rawValue: byteValue) {
            self = .handset(id: handsetID)
            return
        }
        self = .unknown(id: byteValue)
    }

    public func byteValue() -> UInt8 {
        switch self {
        case .general:
            return ContextIDs.general
        case .mediaPlayer(let id):
            return id.rawValue
        case .call(let id):
            return id.rawValue
        case .handset(let id):
            return id.rawValue
        case .unknown(let id):
            return id
        }
    }

    public static func ==(lhs: EarbudUIContext, rhs: EarbudUIContext) -> Bool {
        return lhs.byteValue() == rhs.byteValue()
    }
}

public enum EarbudUIGesture: ByteValueProtocol, Comparable, Hashable {

    public enum GestureIDs: UInt8 {
        case singlePress = 0
        case slideUp = 1
        case slideDown = 2
        case tapSlideUp = 3
        case tapSlideDown = 4
        case doublePress = 5
        case longPress = 6
        case pressAndHold = 7
    }
    case known(id: GestureIDs)
    case unknown(id: UInt8)

    public init(byteValue: UInt8) {
        if let knownID = GestureIDs(rawValue: byteValue) {
            self = .known(id: knownID)
            return
        }
        self = .unknown(id: byteValue)
    }

    public func byteValue() -> UInt8 {
        switch self {
        case .known(let gestureID):
            return gestureID.rawValue
        case .unknown(let id):
            return id
        }
    }

    public static func ==(lhs: EarbudUIGesture, rhs: EarbudUIGesture) -> Bool {
        return lhs.byteValue() == rhs.byteValue()
    }

    public static func < (lhs: EarbudUIGesture, rhs: EarbudUIGesture) -> Bool {
        return lhs.byteValue() < rhs.byteValue()
    }
}

public enum EarbudUIAction: ByteValueProtocol, Equatable, Hashable {
    public enum ActionIDs: UInt8 {
        case playPauseToggle = 0
        case stop = 1
        case nextTrack = 2
        case previousTrack = 3
        case seekForward = 4
        case seekBackward = 5
        case acceptCall = 6
        case rejectCall = 7
        case hangupCall = 8
        case transferCallAudio = 9
        case cycleThroughCalls = 10
        case joinCalls = 11
        case muteMicrophoneToggle = 12
        case gamingModeToggle = 13
        case ANCEnableDisableToggle = 14
        case nextANCMode = 15
        case volumeUp = 16
        case volumeDown = 17
        case reconnectLastConnectedHandset = 18
        case voiceAssistantPrivacyToggle = 19
        case voiceAssistantFetchQuery = 20
        case voiceAssistantPushToTalk = 21
        case voiceAssistantCancel = 22
        case voiceAssistantFetch = 23
        case voiceAssistantQuery = 24
        case disconnectLeastRecentlyUsedHandset = 25
        case voiceJoinCallsHangUp = 26
    }

    case known(id: ActionIDs)
    case unknown(id: UInt8)

    public init(byteValue: UInt8) {
        if let knownID = ActionIDs(rawValue: byteValue) {
            self = .known(id: knownID)
            return
        }
        self = .unknown(id: byteValue)
    }

    public func byteValue() -> UInt8 {
        switch self {
        case .known(let actionID):
            return actionID.rawValue
        case .unknown(let id):
            return id
        }
    }

    public static func ==(lhs: EarbudUIAction, rhs: EarbudUIAction) -> Bool {
        return lhs.byteValue() == rhs.byteValue()
    }
}

public enum EarbudUITouchpad: Equatable, Hashable {
    case single
    case right
    case left
    case both
    case unknown(id: UInt8)

    public init(byteValue: UInt8) {
        switch byteValue {
        case 0:
            self = .single
        case 1:
            self = .right
        case 2:
            self = .left
        case 3:
            self = .both
        default:
            self = .unknown(id: byteValue)
        }
    }

    public func byteValue() -> UInt8 {
        switch self {
        case .single:
            return 0
        case .right:
            return 1
        case .left:
            return 2
        case .both:
            return 3
        case .unknown(let id):
            return id
        }
    }

    public static func ==(lhs: EarbudUITouchpad, rhs: EarbudUITouchpad) -> Bool {
        return lhs.byteValue() == rhs.byteValue()
    }
}

public enum EarbudUIValidationResult {
    public enum EarbudUIValidationResultReason {
        case settingGeneralWouldOverwriteOther
        case settingOtherWouldOverwriteGeneral
        case neverAllowed
        case incompatible
    }
    case allow
    case deny(reason: EarbudUIValidationResultReason)
    case warn(reason: EarbudUIValidationResultReason)
}

public enum EarbudUIAvailableTouchpads {
    case unknown
    case one
    case two
}

public protocol EarbudUITouchpadActionsProtocol {
    var action: EarbudUIAction { get }
    var touchpad: EarbudUITouchpad { get }
}

public protocol GaiaDeviceEarbudUIPluginProtocol: GaiaDevicePluginProtocol {
    var isValid: Bool { get }

    var availableTouchpads: EarbudUIAvailableTouchpads { get }
    var supportedContexts: Set<EarbudUIContext> { get }
    var supportedGestures: Set<EarbudUIGesture> { get }
    var supportedActions: Set<EarbudUIAction> { get }

    func fetchIfNotLoaded()

    func supportedActions(gesture: EarbudUIGesture, context: EarbudUIContext) -> [EarbudUIAction]
    func currentTouchpadActions(gesture: EarbudUIGesture, context: EarbudUIContext) -> [EarbudUITouchpadActionsProtocol] // An array as you can have more than one action - for example one per touchpad.

    // If touchpad is nil it means no action/remove action.
    func validateChange(gesture: EarbudUIGesture, context: EarbudUIContext, action: EarbudUIAction, touchpad: EarbudUITouchpad?) -> EarbudUIValidationResult

    @discardableResult
    func performChange(gesture: EarbudUIGesture, context: EarbudUIContext, action: EarbudUIAction, touchpad: EarbudUITouchpad?) -> Bool

    func performFactoryReset()
}
