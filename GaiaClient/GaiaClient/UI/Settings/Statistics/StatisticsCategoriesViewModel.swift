//
//  © 2021 - 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation
import GaiaCore
import GaiaBase
import PluginBase

class StatisticsCategoriesViewModel: GaiaDeviceViewModelProtocol {
    struct CategoryInfo {
        let title: String
        let recording: Bool
    }

    private weak var viewController: GaiaViewControllerProtocol?
    private let coordinator: AppCoordinator
    private let gaiaManager: GaiaManager
    private let notificationCenter: NotificationCenter

    private(set) weak var statisticsPlugin: GaiaDeviceStatisticsPluginProtocol?

    private(set) var title: String

    private(set) var rows = [CategoryInfo] ()
    private(set) var checkmarkIndexPath: IndexPath?

    private var device: GaiaDeviceProtocol? {
        didSet {
            statisticsPlugin = device?.plugin(featureID: .statistics) as? GaiaDeviceStatisticsPluginProtocol
            refresh()
        }
    }

    var isRecording: Bool {
        StatisticsRecorder.sharedRecorder.isRecording()
    }

    private(set) var observerTokens = [ObserverToken]()

    private var categories = [StatisticCategories]()

    required init(viewController: GaiaViewControllerProtocol,
                  coordinator: AppCoordinator,
                  gaiaManager: GaiaManager,
                  notificationCenter: NotificationCenter) {
        self.viewController = viewController
        self.coordinator = coordinator
        self.gaiaManager = gaiaManager
        self.notificationCenter = notificationCenter

        self.title = String(localized: "Statistics", comment: "Settings Screen Title")

        observerTokens.append(notificationCenter.addObserver(forType: GaiaDeviceNotification.self,
                                                             object: nil,
                                                             queue: OperationQueue.main,
                                                             using: { [weak self] notification in self?.deviceNotificationHandler(notification) }))

        observerTokens.append(notificationCenter.addObserver(forType: GaiaManagerNotification.self,
                                                             object: nil,
                                                             queue: OperationQueue.main,
                                                             using: { [weak self] notification in self?.deviceDiscoveryAndConnectionHandler(notification) }))

        observerTokens.append(notificationCenter.addObserver(forType: GaiaDeviceStatisticsPluginNotification.self,
                                                             object: nil,
                                                             queue: OperationQueue.main,
                                                             using: { [weak self] notification in self?.statisticsNotificationHandler(notification) }))
        observerTokens.append(notificationCenter.addObserver(forType: StatisticsRecorderNotification.self,
                                                             object: nil,
                                                             queue: OperationQueue.main,
                                                             using: { [weak self] notification in self?.statisticsRecorderNotificationHandler(notification) }))
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
    }

    func refresh() {
        guard let statisticsPlugin = statisticsPlugin else {
            rows = []
            viewController?.update()
            return
        }

        let newCategories = statisticsPlugin.supportedCategories.compactMap({ return StatisticCategories(rawValue: $0)}).sorted(by: { $0.userVisibleName() < $1.userVisibleName() })
        categories = newCategories

		var newRows = [CategoryInfo] ()

        for category in categories {
            let row = CategoryInfo(title: category.userVisibleName(), recording: StatisticsRecorder.sharedRecorder.isRecording(category: category))
        	newRows.append(row)
        }
        rows = newRows
        viewController?.update()
    }
}

extension StatisticsCategoriesViewModel {
    func selectedItem(indexPath: IndexPath) {
        guard let device = device else {
            return
        }
        coordinator.showStatisticsForCategory(device: device, category: categories[indexPath.row])
    }

    func toggledSwitch(indexPath: IndexPath) {
		abort()
    }

    func valueChanged(indexPath: IndexPath, newValue: Int) {
        abort()
    }

    func stopAllRecording() {
        StatisticsRecorder.sharedRecorder.stopAllRecording()
        // As not showing any categories we need to kill refresh as well
        StatisticsRefreshManager.shared.stopAll()
    }
}

private extension StatisticsCategoriesViewModel {
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

    func statisticsNotificationHandler(_ notification: GaiaDeviceStatisticsPluginNotification) {
        guard notification.payload?.id == device?.id else {
            return
        }

        switch notification.reason {
        case .categoriesUpdated:
            refresh()
        default:
            break
        }
    }

    func statisticsRecorderNotificationHandler(_ notification: StatisticsRecorderNotification) {
        refresh()
    }
}


