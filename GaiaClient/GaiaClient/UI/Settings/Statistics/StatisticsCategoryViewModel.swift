//
//  © 2021 - 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation
import GaiaCore
import GaiaBase
import PluginBase

class StatisticsCategoryViewModel: GaiaTableViewModelProtocol {
    private weak var viewController: GaiaViewControllerProtocol?
    private let coordinator: AppCoordinator
    private let gaiaManager: GaiaManager
    private let notificationCenter: NotificationCenter

    private(set) weak var statisticsPlugin: GaiaDeviceStatisticsPluginProtocol?

    private(set) var title: String

    private(set) var sections = [SettingSection] ()
    private(set) var checkmarkIndexPath: IndexPath?

    private var device: GaiaDeviceProtocol? {
        didSet {
            statisticsPlugin = device?.plugin(featureID: .statistics) as? GaiaDeviceStatisticsPluginProtocol
            refresh()
        }
    }

    private var category: StatisticCategories?
    private var statistics = [StatisticValueUITreatment]()

    private(set) var observerTokens = [ObserverToken]()

    private var categories = [StatisticCategories]()

    var refreshInterval: TimeInterval {
        if let category = category {
            return StatisticsRefreshManager.shared.refreshRate(category: category)
        }

        return 5.0
    }

    var isRecording: Bool {
        if let category = category {
            return StatisticsRecorder.sharedRecorder.isRecording(category: category)
        }

        return false
    }

    required init(viewController: GaiaViewControllerProtocol,
                  coordinator: AppCoordinator,
                  gaiaManager: GaiaManager,
                  notificationCenter: NotificationCenter) {
        self.viewController = viewController
        self.coordinator = coordinator
        self.gaiaManager = gaiaManager
        self.notificationCenter = notificationCenter

        self.title = String(localized: "", comment: "Settings Screen Title")

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

    func injectCategory(category: StatisticCategories) {
        self.category = category
        title = category.userVisibleName()
        statisticsPlugin?.fetchAllStats(category: category.rawValue)
        StatisticsRefreshManager.shared.startRefreshing(category: category)
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

        if let category = category {
        	StatisticsRefreshManager.shared.startRefreshing(category: category)
        }
    }

    func deactivate() {
        guard let category = category else {
            return

        }

        if !StatisticsRecorder.sharedRecorder.isRecording(category: category) {
            // Let refresh continue if recording
			StatisticsRefreshManager.shared.stopRefreshing(category: category)
        }
    }

    func refresh() {
        guard
            let statisticsPlugin = statisticsPlugin,
        	let category = category
        else {
            sections = []
            viewController?.update()
            return
        }

        statistics = category.allStatistics().sorted(by: { $0.userVisibleName() < $1.userVisibleName() }).filter({ $0.userVisibleValue(plugin: statisticsPlugin) != nil })

        var firstSection = [SettingRow] ()
        for stat in statistics {
            let value = stat.userVisibleValue(plugin: statisticsPlugin)!
        	let title = stat.userVisibleName()

            let row = SettingRow.titleAndSubtitle(title: title, subtitle: value , tapable: false)
            firstSection.append(row)
        }

        sections = [SettingSection(title: nil, rows: firstSection)]
        viewController?.update()
    }
}

extension StatisticsCategoryViewModel {
    func selectedItem(indexPath: IndexPath) {
		abort()
    }

    func toggledSwitch(indexPath: IndexPath) {
        abort()
    }

    func valueChanged(indexPath: IndexPath, newValue: Int) {
        abort()
    }
}

extension StatisticsCategoryViewModel {
    @discardableResult
    func startRecording() -> Bool {
        guard
            let category = category,
            !isRecording
        else {
            return false
        }

        return StatisticsRecorder.sharedRecorder.startRecording(category: category)
    }

    @discardableResult
    func stopRecording() -> Bool{
        guard
            let category = category,
            isRecording
        else {
            return false
        }

        return StatisticsRecorder.sharedRecorder.stopRecording(category: category)
    }
}

extension StatisticsCategoryViewModel {
    func adjustRefreshRate(secs: TimeInterval) {
        guard let category = category else {
            return
        }
        StatisticsRefreshManager.shared.adjustRefreshRate(secs, category: category)
    }
}

private extension StatisticsCategoryViewModel {
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
        case .statisticUpdated(_, let moreComing):
            if !moreComing {
                refresh()
            }
        default:
            break
        }
    }

    func statisticsRecorderNotificationHandler(_ notification: StatisticsRecorderNotification) {
		refresh()
    }
}
