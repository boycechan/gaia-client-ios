//
//  © 2020 - 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation
import GaiaCore
import GaiaBase
import PluginBase

protocol UpdateProgressViewModelDelegate: AnyObject {
    func didFinishUpdate(cancelled: Bool)
}

extension UpdateCompletionStatus {
    func userVisisibleDescription(isEarbud: Bool) -> String {
        switch self {
        case .success:
            if isEarbud {
                return String(localized: "Successfully Completed.\nIf earbuds are in their case, you can now remove them.", comment: "Update Progress Screen")
            } else {
                return String(localized: "Successfully Completed.", comment: "Update Progress Screen")
            }

        case .updateSuccessButSecurityUpdateFailed:
            return String(localized: "Upgrade successful but security version update failed. This may resolve if retried.", comment: "Update Progress Screen")
        }
    }
}

class UpdateProgressViewModel: GaiaDeviceViewModelProtocol {
    enum SummaryState {
        case waitingToStart
        case running
        case finishedWithFailure
        case finishedWithSuccess
    }

    private weak var viewController: GaiaViewControllerProtocol?
    private let coordinator: AppCoordinator
    private let gaiaManager: GaiaManager
    private unowned let notificationCenter: NotificationCenter

    private(set) weak var updatesPlugin: GaiaDeviceUpdaterPluginProtocol?

    weak var delegate: UpdateProgressViewModelDelegate?

    var title: String

    private var device: GaiaDeviceProtocol? {
        didSet {
            updatesPlugin = device?.plugin(featureID: .upgrade) as? GaiaDeviceUpdaterPluginProtocol
            refresh()
        }
    }

    private var observerTokens = [ObserverToken]()

    private(set) var canExit: Bool = false
    private(set) var progress: Double = 0.0
    private(set) var progressText: String = ""
    private(set) var statusText: String = ""
    private(set) var didTimeoutReconnection = false
    private(set) var state = SummaryState.waitingToStart

    private weak var updateTimer: Timer?

    private var isEarbud: Bool {
        device?.deviceType == .earbud
    }

    required init(viewController: GaiaViewControllerProtocol,
                  coordinator: AppCoordinator,
                  gaiaManager: GaiaManager,
                  notificationCenter: NotificationCenter) {
        self.viewController = viewController
        self.coordinator = coordinator
        self.gaiaManager = gaiaManager
        self.notificationCenter = notificationCenter

        self.title = String(localized: "Update Progress", comment: "Progress Screen Title")

        observerTokens.append(notificationCenter.addObserver(forType: GaiaDeviceNotification.self,
                                                             object: nil,
                                                             queue: OperationQueue.main,
                                                             using: { [weak self] notification in self?.deviceNotificationHandler(notification) }))

        observerTokens.append(notificationCenter.addObserver(forType: GaiaManagerNotification.self,
                                                             object: nil,
                                                             queue: OperationQueue.main,
                                                             using: { [weak self] notification in self?.deviceDiscoveryAndConnectionHandler(notification) }))

        observerTokens.append(notificationCenter.addObserver(forType: GaiaDeviceUpdaterPluginNotification.self,
                                                             object: nil,
                                                             queue: OperationQueue.main,
                                                             using: { [weak self] notification in self?.deviceUpdaterNotificationHandler(notification) }))
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

    func isDeviceConnected() -> Bool {
        if let device = device {
            return device.state != .disconnected
        } else {
            return false
        }
    }

    func activate() {
        statusText = String(localized: "", comment: "Update State")
        refresh()
    }

    func deactivate() {
        updateTimer?.invalidate()
    }

    func refresh() {
        guard let plugin = updatesPlugin else {
            return
        }

        if didTimeoutReconnection {
            allowExit(reason: String(localized: "Reconnection timed out", comment: "Update State"))
            progress = 0.0
            viewController?.update()
            return
        }

        if !isDeviceConnected() {
            if plugin.isUpdating {
                allowExit(reason: String(localized: "Awaiting Reconnection.", comment: "Update State"))
                progress = 0.0
                viewController?.update()
                return
            } else {
            }
        }

        switch plugin.updateState  {
        case .ready:
            state = .waitingToStart
            updateTimer?.invalidate()
            statusText = String(localized: "Ready.", comment: "Update State")
            progressText = ""
            canExit = true
        case .busy(let progress):
            state = .running
            didTimeoutReconnection = false
            handleUpdateStatus(progress)
        case .stopped(let reason):
            updateTimer?.invalidate()
            switch reason {
            case .aborted(let error):
                state = .finishedWithFailure
                allowExit(reason: String(localized: "Cancelled: ", comment: "Update State") + error.userVisibleDescription())
            case .userAbortPending:
                state = .finishedWithFailure
                allowExit(reason: String(localized: "Cancelling.", comment: "Update State"))
            case .completedAwaitingReboot:
                state = .finishedWithSuccess
                allowExit(reason: String(localized: "Transfer complete. Update will finish later after reboot.", comment: "Update State"))
            case .completed(let status):
                state = .finishedWithSuccess
                allowExit(reason: status.userVisisibleDescription(isEarbud: isEarbud))
            }
        }

        viewController?.update()
    }

    private func allowExit(reason: String) {
        canExit = true
        statusText = reason
        progressText = ""
    }

    private func handleUpdateStatus(_ status: UpdateStateProgress) {
        canExit = false
        
        if status != .transferring {
            updateTimer?.invalidate()
        }

        switch status {
        case .awaitingConfirmation,
             .awaitingConfirmForceUpgrade,
             .awaitingConfirmTransferRequired,
             .awaitingConfirmBatteryLow,
             .awaitingEarbudsInCase,
             .awaitingEarbudsInCaseConfirmed,
             .awaitingEarbudsInCaseTimedOut:
            // These are now handled by the app controller.
            break
        case .transferring:
            if updateTimer?.isValid ?? false {
				return
            }
            
            let t = Timer(timeInterval: 1.0,
                          target: self,
                          selector: #selector(timerFired(_:)),
                          userInfo: nil,
                          repeats: true)
            RunLoop.current.add(t, forMode: .common)
            updateTimer = t
        case .connecting:
            state = .waitingToStart
            updateTimer?.invalidate()
            statusText = String(localized: "Starting update.", comment: "Update State")
            progressText = ""
            canExit = false
        case .validating:
            statusText = String(localized: "Validating update.", comment: "Update State")
            progressText = ""
            progress = 1.0

            viewController?.update()
        case .restarting:
            statusText = String(localized: "Restarting device.", comment: "Update State")
            progressText = ""
            progress = 1.0

            viewController?.update()
        case .paused,
             .unpausing:
            allowExit(reason: String(localized: "Paused.", comment: "Update State"))

            viewController?.update()
        }
    }

    @objc func timerFired(_: Any) {
        if didTimeoutReconnection {
            allowExit(reason: String(localized: "Reconnection timed out", comment: "Update State"))
            progress = 0.0
            viewController?.update()
            return
        }

        guard let updatesPlugin = updatesPlugin else {
            if state == .running {
                allowExit(reason: String(localized: "Awaiting Reconnection.", comment: "Update State"))
                progress = 0.0
                viewController?.update()
            }
            return
        }

        let eta = determineEtaString(timeRemaining: updatesPlugin.timeRemaining)
        statusText = String(localized: "Transferring.", comment: "Update State")
        progressText = eta
        progress = updatesPlugin.percentProgress / 100.0

        viewController?.update()
    }
}

extension UpdateProgressViewModel {
    func abortRequested() {
        updatesPlugin?.abort()
    }

    func doneRequested() {
        delegate?.didFinishUpdate(cancelled: state == .running)
    }

    func determineEtaString(timeRemaining: TimeInterval) -> String {
        guard progress > 0.01 else {
            return ""
        }

        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .full
        formatter.includesApproximationPhrase = false
        formatter.includesTimeRemainingPhrase = true
        formatter.allowedUnits = [.minute,.second]

        // Use the configured formatter to generate the string.
        if let txt = formatter.string(from: timeRemaining) {
            return txt + "."
        } else {
            return ""
        }
    }
}

private extension UpdateProgressViewModel {
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
            refresh()
        case .poweredOn:
            refresh()
        case .dfuReconnectTimeout:
            didTimeoutReconnection = true
            refresh()
        }
    }

    func deviceUpdaterNotificationHandler(_ notification: GaiaDeviceUpdaterPluginNotification) {
        guard notification.payload.id == device?.id else {
            return
        }
        
        switch notification.reason {
        case .statusChanged:
            refresh()
        case .ready:
            break
        }
    }
}



