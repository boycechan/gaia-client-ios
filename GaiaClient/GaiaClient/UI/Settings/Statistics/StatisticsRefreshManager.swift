//
//  © 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation
import GaiaCore
import GaiaBase
import PluginBase

protocol StatisticsRefreshManagerProtocol {
    func injectDevice(device: GaiaDeviceProtocol?)

    func startRefreshing(category: StatisticCategories)
    func stopRefreshing(category: StatisticCategories)
    func stopAll()

    func isRefreshing(category: StatisticCategories) -> Bool

    func refreshRate(category: StatisticCategories) -> TimeInterval
    func adjustRefreshRate(_ refreshRate: TimeInterval, category: StatisticCategories)
}

class StatisticsRefreshManager: StatisticsRefreshManagerProtocol  {
    static let shared = StatisticsRefreshManager()

    struct TimerInfo {
        let rate: TimeInterval
        let timer: Timer?
        let isPaused: Bool
    }

    private let categoryUserInfoKey = "Category"
    private var timerLookup = Dictionary<StatisticCategories, TimerInfo> ()

    private var device: GaiaDeviceProtocol?
    private var previousDeviceID: String?

    private var statisticsPlugin: GaiaDeviceStatisticsPluginProtocol? {
        return device?.plugin(featureID: .statistics) as? GaiaDeviceStatisticsPluginProtocol
    }

    func injectDevice(device newDevice: GaiaDeviceProtocol?) {
        if newDevice?.id == device?.id {
            return
        }

        if newDevice?.id == nil {
			// Probably a disconnection.
            // Pause all refreshes and save old ID
            pauseAll()
            previousDeviceID = device?.id
        } else {
            if device?.id == nil {
                // Connection
                if (previousDeviceID == newDevice?.id) {
                    // Reconnection of previous device
                    resumeAll()
                } else {
                    stopAll()
                }
            }
        }

        device = newDevice
    }

    func startRefreshing(category: StatisticCategories) {
        let entry = timerLookup[category] ?? TimerInfo(rate: category.defaultRefreshRate(), timer: nil, isPaused: false)
        guard entry.timer == nil else {
            return
        }

        let timer = startTimer(refreshRate: entry.rate, category: category)
        let newEntry = TimerInfo(rate: entry.rate, timer: timer, isPaused: false)
        timerLookup[category] = newEntry
    }

    func startTimer(refreshRate: TimeInterval, category: StatisticCategories) -> Timer {
        let t = Timer(timeInterval: refreshRate,
                      target: self,
                      selector: #selector(timerFired(_:)),
                      userInfo: category,
                      repeats: true)
        RunLoop.current.add(t, forMode: .common)
        return t
    }

    func stopRefreshing(category: StatisticCategories) {
        guard let entry = timerLookup[category] else {
            return
        }

        entry.timer?.invalidate()
        timerLookup[category] = TimerInfo(rate: entry.rate, timer: nil, isPaused: false)
    }

    func stopAll() {
        timerLookup.keys.forEach { category in
            if let value = timerLookup[category] {
                value.timer?.invalidate()
                timerLookup[category] = TimerInfo(rate: value.rate, timer: nil, isPaused: false)
            }
        }
    }

    func pauseAll() {
        timerLookup.keys.forEach { category in
            if let value = timerLookup[category] {
                if let t = value.timer {
                    t.invalidate()
                    timerLookup[category] = TimerInfo(rate: value.rate, timer: nil, isPaused: true)
                }
            }
        }
    }

    func resumeAll() {
        timerLookup.keys.forEach { category in
            if let value = timerLookup[category] {
                if value.isPaused {
                    startRefreshing(category: category)
                }
            }
        }
    }

    func adjustRefreshRate(_ refreshRate: TimeInterval, category: StatisticCategories) {
        let oldEntry = timerLookup[category]
        oldEntry?.timer?.invalidate()
        timerLookup[category] = TimerInfo(rate: refreshRate, timer: nil, isPaused: oldEntry?.isPaused ?? false)

        if oldEntry?.timer != nil {
            statisticsPlugin?.fetchAllStats(category: category.rawValue)
            startRefreshing(category: category)
        }
    }

    func isRefreshing(category: StatisticCategories) -> Bool {
        return timerLookup[category]?.timer != nil
    }

    func refreshRate(category: StatisticCategories) -> TimeInterval {
        return timerLookup[category]?.rate ?? category.defaultRefreshRate()
    }

    @objc func timerFired(_ timer: Timer) {
        if let category = timer.userInfo as? StatisticCategories{
            statisticsPlugin?.fetchAllStats(category: category.rawValue)
        }
    }
}
