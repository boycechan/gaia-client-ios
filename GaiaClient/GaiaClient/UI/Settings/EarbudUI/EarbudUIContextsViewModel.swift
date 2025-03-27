//
//  © 2021 - 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation
import GaiaCore
import GaiaBase
import PluginBase

class EarbudUIContextsViewModel: GaiaDeviceViewModelProtocol {
    internal struct TableViewRow: Equatable {
        enum TableViewRowType {
            case toggle(enabled: Bool, isOn: Bool)
            case action(touchpadInfo: TouchpadInfo)
        }

        let type: TableViewRowType
        let title: String

        static func == (lhs: TableViewRow, rhs: TableViewRow) -> Bool {
            switch lhs.type {
            case .toggle(let enabled, let isOn):
                switch rhs.type {
                case .toggle(let enabled2, let isOn2):
                    return enabled == enabled2 && isOn == isOn2
                default:
                    return false
                }
            case .action(let info):
                switch rhs.type {
                case .action(let info2):
                    return info == info2
                default:
                    return false
                }
            }
        }
    }

    internal struct TableViewSection: Equatable {
        let title: String?
        let showLeftRight: Bool
        let rows: [TableViewRow]

        static func == (lhs: TableViewSection, rhs: TableViewSection) -> Bool {
            return lhs.rows == rhs.rows && lhs.showLeftRight == rhs.showLeftRight
        }
    }

    internal enum TouchpadInfo {
        case none
        case single
        case right
        case left
        case both
    }

    struct ActionInfo: Equatable {
        fileprivate let action: EarbudUIAction
        let selectionStatus: TouchpadInfo
        var name: String {
            action.userVisibleName()
        }
        static func == (lhs: ActionInfo, rhs: ActionInfo) -> Bool {
            return lhs.action == rhs.action && lhs.selectionStatus == rhs.selectionStatus
        }
    }

    struct ContextInfo: Equatable {
        fileprivate let context: EarbudUIContext
        let actions: [ActionInfo]
        var name: String {
            context.userVisibleName()
        }

        static func == (lhs: ContextInfo, rhs: ContextInfo) -> Bool {
            return lhs.context == rhs.context && lhs.actions == rhs.actions
        }
    }

    struct ContextCategory {
        var name: String
        var contexts: [ContextInfo]
    }

    private weak var viewController: GaiaViewControllerProtocol?
    private let coordinator: AppCoordinator
    private let gaiaManager: GaiaManager
    private let notificationCenter: NotificationCenter

    private weak var uiPlugin: GaiaDeviceEarbudUIPluginProtocol?
    private(set) var title: String = ""

    private var gesture: EarbudUIGesture? = nil
    private var contextTree = [ContextCategory]()

    private var device: GaiaDeviceProtocol? {
        didSet {
            uiPlugin = device?.plugin(featureID: .earbudUI) as? GaiaDeviceEarbudUIPluginProtocol
            if let vc = viewController,
               vc.isViewLoaded,
               vc.view.window != nil {
                // We're on screen so we should load if not already present.
                uiPlugin?.fetchIfNotLoaded()
            }
            refresh()
        }
    }

    private(set) var currentSelectedPage: Int = 0
    private(set) var tableViewStructure = [TableViewSection]()
    var pageTitles: [String] {
        return contextTree.map({ $0.name })
    }

    private(set) var observerTokens = [ObserverToken]()

    required init(viewController: GaiaViewControllerProtocol,
                  coordinator: AppCoordinator,
                  gaiaManager: GaiaManager,
                  notificationCenter: NotificationCenter) {
        self.viewController = viewController
        self.coordinator = coordinator
        self.gaiaManager = gaiaManager
        self.notificationCenter = notificationCenter

        observerTokens.append(notificationCenter.addObserver(forType: GaiaDeviceNotification.self,
                                                             object: nil,
                                                             queue: OperationQueue.main,
                                                             using: { [weak self] notification in self?.deviceNotificationHandler(notification) }))

        observerTokens.append(notificationCenter.addObserver(forType: GaiaManagerNotification.self,
                                                             object: nil,
                                                             queue: OperationQueue.main,
                                                             using: { [weak self] notification in self?.deviceDiscoveryAndConnectionHandler(notification) }))

        observerTokens.append(notificationCenter.addObserver(forType: GaiaDeviceEarbudUIPluginNotification.self,
                                                             object: nil,
                                                             queue: OperationQueue.main,
                                                             using: { [weak self] notification in self?.earbudUINotificationHandler(notification) }))
    }

    deinit {
        observerTokens.forEach { token in
            notificationCenter.removeObserver(token)
        }
        observerTokens.removeAll()
    }

    func injectDevice(device: GaiaDeviceProtocol?) {
        self.device = device
    }

    func injectGesture(gesture: EarbudUIGesture) {
        self.gesture = gesture
        title = String(localized: "\(gesture.userVisibleName()) Actions", comment: "Title for Gesture UI Contexts Screen")
    }

    func isDeviceConnected() -> Bool {
        if let device = device {
            return device.state != .disconnected
        } else {
            return false
        }
    }

    func activate() {
        refresh()
    }

    func deactivate() {
    }

    func refresh() {
        refresh(newSelectedPage: currentSelectedPage)
    }
}

extension EarbudUIContextsViewModel {
    func selectNewPage(index: Int) {
        guard index != currentSelectedPage else {
            return
        }
        refresh(newSelectedPage: index)
    }

    func didToggleShowLeftRight(newState: Bool, section: Int) {
        guard
            let uiPlugin = uiPlugin,
            let _ = gesture,
            uiPlugin.isValid,
            uiPlugin.availableTouchpads == .two,
            section < tableViewStructure.count
        else {
            return
        }

        let oldSection = tableViewStructure[section]

        if let firstRow = oldSection.rows.first {
            switch firstRow.type {
            case .toggle(let enabled, _):
                let newFirstRow = TableViewRow(type: .toggle(enabled: enabled, isOn: newState), title: firstRow.title)
                var newRows = oldSection.rows
                newRows[0] = newFirstRow
                let newSection = TableViewSection(title: oldSection.title,
                                                  showLeftRight: !oldSection.showLeftRight,
                                                  rows: newRows)
                tableViewStructure[section] = newSection
                if let vm = viewController as? EarbudUIContextsViewController {
                    vm.reloadSection(section)
                }
            default:
                break
            }

        }
    }

    func didSelectTouchpad(touchpad: TouchpadInfo, indexPath: IndexPath) {
        guard
            let uiPlugin = uiPlugin,
            let gesture = gesture,
            let viewController = viewController as? EarbudUIContextsViewController,
            indexPath.section < tableViewStructure.count,
            indexPath.row < tableViewStructure[indexPath.section].rows.count
        else {
            return
        }

        // Is it a change to enable another touchpad or just mashing an already enabled one.

    	// Fetch the current setting

        let leftRightAvailable = uiPlugin.availableTouchpads == .two
        let currentRow = tableViewStructure[indexPath.section].rows[indexPath.row]
        var currentTouchpads = TouchpadInfo.none

        switch currentRow.type {
        case .toggle(_, _):
            return
        case .action(let info):
            currentTouchpads = info
        }

        // So we now know what to set the new touchpad to be.

        let actionIndex = indexPath.row - (leftRightAvailable ? 1 : 0)
        let contextIndex = indexPath.section
        let page = contextTree[currentSelectedPage]
        let context = page.contexts[contextIndex]

        if actionIndex == context.actions.count {
            // The "Do nothing action that isn't really an action more a removal from somewhere else
            // Find "real" action that is losing the touchpad.
            if actionIndex == 0 {
                return // We only have the do nothing option.
            }

            for index in 0..<context.actions.count {
                let action = context.actions[index]
                let touchpadsForAction = action.selectionStatus
                var newTouchpadsForAction = touchpadsForAction

                switch touchpadsForAction {
                case .none:
                    break
                case .single:
                    if touchpad == .single {
                        newTouchpadsForAction = .none
                    }
                case .right:
                    if touchpad == .right || touchpad == .both{
                        newTouchpadsForAction = .none
                    }
                case .left:
                    if touchpad == .left || touchpad == .both {
                        newTouchpadsForAction = .none
                    }
                case .both:
                    if touchpad == .both {
                        newTouchpadsForAction = .none
                    } else if touchpad == .left {
                        newTouchpadsForAction = .right
                    } else if touchpad == .right {
                        newTouchpadsForAction = .left
                    }
                }
                if newTouchpadsForAction != touchpadsForAction {
                    // There was a change
                    let convertedTouchpads = convertTouchPadInfo(info: newTouchpadsForAction)
                    uiPlugin.performChange(gesture: gesture,
                                           context: context.context,
                                           action: action.action,
                                           touchpad: convertedTouchpads)
                }
            }


        } else {
            var newTouchpads = TouchpadInfo.none

            switch touchpad {
            case .none:
                return
            case .single:
                if currentTouchpads == .single || leftRightAvailable {
                    return
                }
                newTouchpads = .single
            case .right:
                if currentTouchpads == .right || currentTouchpads == .both || !leftRightAvailable {
                    return
                }
                if currentTouchpads == .left {
                    newTouchpads = .both
                } else {
                    newTouchpads = .right
                }
            case .left:
                if currentTouchpads == .left || currentTouchpads == .both || !leftRightAvailable {
                    return
                }
                if currentTouchpads == .right {
                    newTouchpads = .both
                } else {
                    newTouchpads = .left
                }
            case .both:
                if currentTouchpads == .both || !leftRightAvailable {
                    return
                }
                newTouchpads = .both
            }

            // Really an action
            let action = context.actions[actionIndex]
			// Validate

            let convertedTouchpads = convertTouchPadInfo(info: newTouchpads)
            let validation = uiPlugin.validateChange(gesture: gesture,
                                                     context: context.context,
                                                     action: action.action,
                                                     touchpad: convertedTouchpads)

            switch validation {
            case .allow:
                uiPlugin.performChange(gesture: gesture,
                                       context: context.context,
                                       action: action.action,
                                       touchpad: convertedTouchpads)
            case .deny(let reason):
				let strings = titleAndMessageForReason(reason, gesture: gesture)
                viewController.showDenialAlert(title: strings.title,
                                               message: strings.message) { }
            case .warn(let reason):
                let strings = titleAndMessageForReason(reason, gesture: gesture)
                viewController.showWarningAlert(title: strings.title,
                                                message: strings.message)  { overwrite in
                    if overwrite {
                        uiPlugin.performChange(gesture: gesture,
                                               context: context.context,
                                               action: action.action,
                                               touchpad: convertedTouchpads)
                    }
                }
            }
        }
    }

    func titleAndMessageForReason(_ reason: EarbudUIValidationResult.EarbudUIValidationResultReason, gesture: EarbudUIGesture) -> (title: String, message: String) {
        switch reason {
        case .settingGeneralWouldOverwriteOther:
            let title = String(localized: "Reassign \(gesture.userVisibleName())", comment: "Warning message title for gesture reassignment")
            let message = String(localized: "\(gesture.userVisibleName()) is assigned to other actions. If you assign it to this action, it will override the others.\n\n Do you want to continue?", comment: "Warning message for gesture reassignment")
            return (title: title, message: message)
        case .settingOtherWouldOverwriteGeneral:
            let title = String(localized: "Reassign \(gesture.userVisibleName())", comment: "Warning message title for gesture reassignment")
            let message = String(localized: "\(gesture.userVisibleName()) is assigned to a \"General\" action. If you assign it to this action, it will override that general action.\n\n Do you want to continue?", comment: "Warning message for gesture reassignment")
            return (title: title, message: message)
        case .neverAllowed:
            let title = String(localized: "Cannot assign \(gesture.userVisibleName())", comment: "Warning message title for gesture reassignment")
            let message = String(localized: "The assignment of this action to \(gesture.userVisibleName()) is not permitted.", comment: "Warning message for gesture reassignment")
            return (title: title, message: message)
        case .incompatible:
            let title = String(localized: "Cannot assign \(gesture.userVisibleName())", comment: "Warning message title for gesture reassignment")
            let message = String(localized: "The assignment of this action to \(gesture.userVisibleName()) is not compatible with other assignments.", comment: "Warning message for gesture reassignment")
            return (title: title, message: message)
        }
    }

    func convertTouchPadInfo(info: TouchpadInfo) -> EarbudUITouchpad? {
        switch info {
        case .single:
            return .single
        case .right:
            return .right
        case .left:
            return .left
        case .both:
            return .both
        case .none:
            return nil
        }
    }
}

private extension EarbudUIContextsViewModel {
    func refresh(newSelectedPage: Int) {
        if let uiPlugin = uiPlugin,
           let gesture = gesture,
           uiPlugin.isValid {
            let supportedContexts = uiPlugin.supportedContexts
            let nestedContexts = EarbudUIContext.nestedContextsForUI(contexts: supportedContexts)
            var newContextTree = [ContextCategory]()
            for heading in nestedContexts {
                let unmappedContexts = heading.subContexts
                var mappedContexts = [ContextInfo]()
                for unmappedContext in unmappedContexts {
                    let unmapppedActionsForContext = uiPlugin.supportedActions(gesture: gesture, context: unmappedContext)
                    let touchpadActions = uiPlugin.currentTouchpadActions(gesture: gesture, context: unmappedContext)
                    var mappedActions = [ActionInfo]()
                    for unmappedAction in unmapppedActionsForContext {
                        var touchpadInfo = TouchpadInfo.none
                        if let matchedTouchpadAction = touchpadActions.first(where: { $0.action == unmappedAction }) {
                            switch matchedTouchpadAction.touchpad {
                            case .single:
                                touchpadInfo = .single
                            case .right:
                                touchpadInfo = .right
                            case .left:
                                touchpadInfo = .left
                            case .both:
                                touchpadInfo = .both
                            case .unknown(_):
                                touchpadInfo = .none
                            }
                        }
                        let mappedAction = ActionInfo(action: unmappedAction, selectionStatus: touchpadInfo)
                        mappedActions.append(mappedAction)
                    }

                    let mappedContext = ContextInfo(context: unmappedContext, actions: mappedActions)
                    mappedContexts.append(mappedContext)
                }
                let newCategory = ContextCategory(name: heading.mainName, contexts: mappedContexts)
                newContextTree.append(newCategory)
            }
            contextTree = newContextTree

            // Do we need new expansion tree
        } else {
            // Plugin is not valid.
            contextTree = [ContextCategory]()
        }

        // Now generate tableView

        if newSelectedPage >= contextTree.count {
            tableViewStructure.removeAll()
            viewController?.update()
            return
        }

        let selectedPageContexts = contextTree[newSelectedPage]
        let leftRightAvailable = uiPlugin?.availableTouchpads == .two
        var newTableViewStructure = [TableViewSection]()

        let updatingOldStructure = newSelectedPage == currentSelectedPage &&
            tableViewStructure.count == selectedPageContexts.contexts.count

        for context in selectedPageContexts.contexts {
            let name = selectedPageContexts.contexts.count > 1 ? context.name : nil
            var rows = [TableViewRow]()

            var actionRows = [TableViewRow]()
            var forceShowLeftRight = false
            var noActionTouchpads = leftRightAvailable ? TouchpadInfo.both : TouchpadInfo.single
            for action in context.actions {
                let touchpads = action.selectionStatus

                switch touchpads {
                case .single:
                    if noActionTouchpads == .single {
                        noActionTouchpads = .none
                    }
                case .right:
                    forceShowLeftRight = true
                    if noActionTouchpads == .right {
                        noActionTouchpads = .none
                    } else if noActionTouchpads == .both {
                        noActionTouchpads = .left
                    }
                case .left:
                    forceShowLeftRight = true
                    if noActionTouchpads == .left {
                        noActionTouchpads = .none
                    } else if noActionTouchpads == .both {
                        noActionTouchpads = .right
                    }
                case .both:
                    noActionTouchpads = .none
                default:
                    break
                }

                let row = TableViewRow(type: .action(touchpadInfo: action.selectionStatus),
                                       title: action.name)
                actionRows.append(row)
            }

            var oldShowLeftRight = false
            if updatingOldStructure && leftRightAvailable {
                // We need to know old expanded state
                if let contextIndex = selectedPageContexts.contexts.firstIndex(of: context) {
                   oldShowLeftRight = tableViewStructure[contextIndex].showLeftRight
                }
            }
        	let showLeftRight = oldShowLeftRight || forceShowLeftRight

            if leftRightAvailable {
                // Insert slider row
                let row = TableViewRow(type: .toggle(enabled: !forceShowLeftRight, isOn: showLeftRight),
                                       title: String(localized: "Show left and right", comment: "Earbud UI action"))
                rows.append(row)
            }

            rows.append(contentsOf: actionRows)

            // Insert null action
            let row = TableViewRow(type: .action(touchpadInfo: noActionTouchpads),
                                   title: String(localized: "Do nothing", comment: "Earbud UI action"))
            rows.append(row)

            let section = TableViewSection(title: name, showLeftRight: showLeftRight, rows: rows)

            newTableViewStructure.append(section)
        }

        if updatingOldStructure {
			// Diffs?
        }
		tableViewStructure = newTableViewStructure
		currentSelectedPage = newSelectedPage

        viewController?.update()
    }
}

private extension EarbudUIContextsViewModel {
    func deviceNotificationHandler(_ notification: GaiaDeviceNotification) {
        guard notification.payload.id == device?.id else {
            return
        }

        switch notification.reason {
        case .stateChanged:
            refresh()
        default:
            break
        }
    }

    func deviceDiscoveryAndConnectionHandler(_ notification: GaiaManagerNotification) {
        switch notification.reason {
        case .discover,
             .connectFailed,
             .connectSuccess,
             .disconnect:
            refresh()
        case .poweredOff:
            break
        case .poweredOn:
            break
        case .dfuReconnectTimeout:
            break
        }
    }

    func earbudUINotificationHandler(_ notification: GaiaDeviceEarbudUIPluginNotification) {
        guard
            notification.payload?.id == device?.id
        else {
            return
        }

        switch notification.reason {
        default:
            refresh()
        }
    }
}
