//
//  © 2021 - 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import UIKit
import GaiaCore
import PluginBase

struct EarbudUIContextTreeEntry {
    let mainName: String
    let subContexts: [EarbudUIContext]
}
typealias EarbudUIContextTree = [EarbudUIContextTreeEntry]

extension EarbudUIContext {
    func userVisibleName() -> String {
        switch self {
        case .general:
            return String(localized: "General", comment: "General Context Name")
        case .mediaPlayer(let id):
            switch id {
            case .streaming:
                return String(localized: "While streaming", comment: "Media Player Context Name")
            case .idle:
                return String(localized: "While idle", comment: "Media Player Context Name")
            }
        case .call(let id):
            switch id {
            case .inCall:
                return String(localized: "When in a voice call", comment: "Voice Call Context Name")
            case .incoming:
                return String(localized: "When there is an incoming call ringing", comment: "Voice Call Context Name")
            case .outgoing:
                return String(localized: "When there is an outgoing call ringing", comment: "Voice Call Context Name")
            case .heldCall:
                return String(localized: "With a held call", comment: "Voice Call Context Name")
            }
        case .handset(let id):
            switch id {
            case .connected:
                return String(localized: "When connected", comment: "Voice Call Context Name")
            case .disconnected:
                return String(localized: "When disconnected", comment: "Voice Call Context Name")
            }
        case .unknown(let id):
            return String(localized: "Unknown context \(id)", comment: "Unknown Context Name")
        }
    }

    static func nestedContextsForUI(contexts: Set<EarbudUIContext>) -> EarbudUIContextTree {
        // Currently we have
        var generalEntries = [EarbudUIContext]()
        var mediaPlayerEntries = [EarbudUIContext]()
        var callEntries = [EarbudUIContext]()
        var handsetEntries = [EarbudUIContext]()
        var unknownEntries = [EarbudUIContext]()

        for context in contexts {
            switch context {
            case .general:
                generalEntries.append(context)
            case .mediaPlayer(_):
                mediaPlayerEntries.append(context)
            case .call(_):
                callEntries.append(context)
            case .handset(_):
                handsetEntries.append(context)
            case .unknown(_):
                unknownEntries.append(context)
            }
        }

        var nested = EarbudUIContextTree()
        if mediaPlayerEntries.count > 0 {
            nested.append(EarbudUIContextTreeEntry(mainName: String(localized: "Music", comment: "Media Player Panel Name"),
                                                   subContexts: mediaPlayerEntries.sorted(by: { $0.userVisibleName() < $1.userVisibleName() })))
        }
        if callEntries.count > 0 {
            nested.append(EarbudUIContextTreeEntry(mainName: String(localized: "Call", comment: "Call Panel Name"),
                                                   subContexts: callEntries.sorted(by: { $0.userVisibleName() < $1.userVisibleName() })))
        }
        if handsetEntries.count > 0 {
            nested.append(EarbudUIContextTreeEntry(mainName: String(localized: "Handset", comment: "Handset Panel Name"),
                                                   subContexts: handsetEntries.sorted(by: { $0.userVisibleName() < $1.userVisibleName() })))
        }
        
        if generalEntries.count > 0 {
            nested.append(EarbudUIContextTreeEntry(mainName: String(localized: "General", comment: "General Panel Name"),
                                                   subContexts: generalEntries.sorted(by: { $0.userVisibleName() < $1.userVisibleName() })))
        }
        return nested
    }
}


extension EarbudUIGesture {
    func userVisibleName() -> String {
        switch self {
        case .known(let gestureID):
            switch gestureID {
            case .singlePress:
                return String(localized: "Single Tap", comment: "Gesture Name")
            case .slideUp:
                return String(localized: "Swipe Up", comment: "Gesture Name")
            case .slideDown:
                return String(localized: "Swipe Down", comment: "Gesture Name")
            case .tapSlideUp:
                return String(localized: "Tap + Swipe Up", comment: "Gesture Name")
            case .tapSlideDown:
                return String(localized: "Tap + Swipe Down", comment: "Gesture Name")
            case .doublePress:
                return String(localized: "Double Tap", comment: "Gesture Name")
            case .longPress:
                return String(localized: "Long Press", comment: "Gesture Name")
            case .pressAndHold:
                return String(localized: "Press + Hold", comment: "Gesture Name")
            }
        case .unknown(let id):
            return String(localized: "Unknown Gesture \(id)", comment: "Gesture Name")
        }
    }

    func userVisibleImage() -> UIImage {
        switch self {
        case .known(let gestureID):
            switch gestureID {
            case .singlePress:
                return UIImage(named: "ic_tap" ) ?? UIImage()
            case .slideUp:
                return UIImage(named: "ic_swipe_up" ) ?? UIImage()
            case .slideDown:
                return UIImage(named: "ic_swipe_down" ) ?? UIImage()
            case .tapSlideUp:
                return UIImage(named: "ic_tap_and_swipe_up" ) ?? UIImage()
            case .tapSlideDown:
                return UIImage(named: "ic_tap_and_swipe_down" ) ?? UIImage()
            case .doublePress:
                return UIImage(named: "ic_double_tap" ) ?? UIImage()
            case .longPress:
                return UIImage(named: "ic_long_press" ) ?? UIImage()
            case .pressAndHold:
                return UIImage(named: "ic_press_and_hold" ) ?? UIImage()
            }
        case .unknown(_):
            return UIImage()
        }
    }
}

extension EarbudUIAction {
    func userVisibleName() -> String {
        switch self {
        case .known(let actionID):
            switch actionID {
            case .playPauseToggle:
                return String(localized: "Play/Pause", comment: "Action Name")
            case .stop:
                return String(localized: "Stop", comment: "Action Name")
            case .nextTrack:
                return String(localized: "Next track", comment: "Action Name")
            case .previousTrack:
                return String(localized: "Previous track", comment: "Action Name")
            case .seekForward:
                return String(localized: "Seek forward", comment: "Action Name")
            case .seekBackward:
                return String(localized: "Seek backward", comment: "Action Name")
            case .acceptCall:
                return String(localized: "Accept call", comment: "Action Name")
            case .rejectCall:
                return String(localized: "Reject call", comment: "Action Name")
            case .hangupCall:
                return String(localized: "End call", comment: "Action Name")
            case .transferCallAudio:
                return String(localized: "Transfer call back to phone", comment: "Action Name")
            case .cycleThroughCalls:
                return String(localized: "Cycle through calls", comment: "Action Name")
            case .joinCalls:
                return String(localized: "Join calls", comment: "Action Name")
            case .muteMicrophoneToggle:
                return String(localized: "Mute/Unmute microphone", comment: "Action Name")
            case .gamingModeToggle:
                return String(localized: "Enable/Disable gaming mode", comment: "Action Name")
            case .ANCEnableDisableToggle:
                return String(localized: "Enable/Disable audio curation", comment: "Action Name")
            case .nextANCMode:
                return String(localized: "Next audio curation mode", comment: "Action Name")
            case .volumeUp:
                return String(localized: "Volume up", comment: "Action Name")
            case .volumeDown:
                return String(localized: "Volume down", comment: "Action Name")
            case .reconnectLastConnectedHandset:
                return String(localized: "Reconnect last connected handset", comment: "Action Name")
            case .voiceAssistantPrivacyToggle:
                return String(localized: "Enable/Disable voice assistant privacy", comment: "Action Name")
            case .voiceAssistantFetchQuery:
                return String(localized: "Voice assistant fetch query", comment: "Action Name")
            case .voiceAssistantPushToTalk:
                return String(localized: "Voice assistant push to talk", comment: "Action Name")
            case .voiceAssistantCancel:
                return String(localized: "Voice assistant cancel", comment: "Action Name")
            case .voiceAssistantFetch:
                return String(localized: "Voice assistant fetch", comment: "Action Name")
            case .voiceAssistantQuery:
                return String(localized: "Voice assistant query", comment: "Action Name")
            case .voiceJoinCallsHangUp:
                return String(localized: "Join calls/hang up", comment: "Action Name")
            case .disconnectLeastRecentlyUsedHandset:
                return String(localized: "Disconnect least recently used handset", comment: "Action Name")
            }
        case .unknown(let id):
            return String(localized: "Unknown action \(id)", comment: "Action Name")
        }
    }
}
