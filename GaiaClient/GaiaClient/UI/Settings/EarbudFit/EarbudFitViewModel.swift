//
//  © 2021 - 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation
import GaiaCore
import GaiaBase
import PluginBase

class EarbudFitViewModel: GaiaDeviceViewModelProtocol {
    enum FitTestResult {
        case good
        case poor
        case failed
    }
    enum FitTestState {
        case awaitingFirstRun
        case testRunning
        case testDone(leftResult: FitTestResult, rightResult: FitTestResult)
    }

    private weak var viewController: GaiaViewControllerProtocol?
    private let coordinator: AppCoordinator
    private let gaiaManager: GaiaManager
    private let notificationCenter: NotificationCenter

    var title: String

    private(set) var state: FitTestState = .awaitingFirstRun {
        didSet {
			refresh()
        }
    }

    var isTestRunning: Bool {
        var testRunning = false
        switch state {
        case .testRunning:
            testRunning = true
        default:
            break
        }
        return testRunning
    }
    
    private(set) weak var fitPlugin: GaiaDeviceEarbudFitPluginProtocol?
    private(set) var observerTokens = [ObserverToken]()

    private var device: GaiaDeviceProtocol? {
        didSet {
            fitPlugin = device?.plugin(featureID: .earbudFit) as? GaiaDeviceEarbudFitPluginProtocol
            refresh()
        }
    }

    required init(viewController: GaiaViewControllerProtocol, coordinator: AppCoordinator, gaiaManager: GaiaManager, notificationCenter: NotificationCenter) {
        self.viewController = viewController
        self.coordinator = coordinator
        self.gaiaManager = gaiaManager
        self.notificationCenter = notificationCenter

        self.title = String(localized: "Earbud Fit", comment: "Settings Screen Title")

        observerTokens.append(notificationCenter.addObserver(forType: GaiaDeviceNotification.self,
                                                             object: nil,
                                                             queue: OperationQueue.main,
                                                             using: { [weak self] notification in self?.deviceNotificationHandler(notification) }))

        observerTokens.append(notificationCenter.addObserver(forType: GaiaManagerNotification.self,
                                                             object: nil,
                                                             queue: OperationQueue.main,
                                                             using: { [weak self] notification in self?.deviceDiscoveryAndConnectionHandler(notification) }))

        observerTokens.append(notificationCenter.addObserver(forType: GaiaDeviceEarbudFitPluginNotification.self,
                                                             object: nil,
                                                             queue: OperationQueue.main,
                                                             using: { [weak self] notification in self?.fitNotificationHandler(notification) }))
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
        refresh()
    }

    func deactivate() {
        if isTestRunning {
            // We need to cancel the test.
            cancelTest()
        }
    }

    func refresh() {
        viewController?.update()
    }
}

extension EarbudFitViewModel {
    func cancelTest() {
        fitPlugin?.stopFitQualityTest()
    }

    func startTest() {
        fitPlugin?.startFitQualityTest()
    }
}

private extension EarbudFitViewModel {
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

    func pluginResultToVMResult(pluginResult: GaiaDeviceFitQuality) -> FitTestResult? {
        switch pluginResult {
        case .unknown:
            return nil
        case .good:
            return .good
        case .poor:
            return .poor
        case .failed:
            return .failed
        case .determining:
            return nil
        }
    }

    func fitNotificationHandler(_ notification: GaiaDeviceEarbudFitPluginNotification) {
        guard notification.payload.id == device?.id else {
            return
        }

        let leftResult = fitPlugin?.leftFitQuality ?? .unknown
        let rightResult = fitPlugin?.rightFitQuality ?? .unknown

        if leftResult == .unknown || rightResult == .unknown {
            state = .awaitingFirstRun
        } else if leftResult == .determining || rightResult == .determining {
            state = .testRunning
        } else {
            // We should be left with just actual results so if we get nil that's wrong.
            let myLeft = pluginResultToVMResult(pluginResult: leftResult) ?? .failed
            let myRight = pluginResultToVMResult(pluginResult: rightResult) ?? .failed

            state = .testDone(leftResult: myLeft, rightResult: myRight)
        }

		// No need to refresh as should happen on didSet
    }
}
