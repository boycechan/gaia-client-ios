//
//  © 2023 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation
import GaiaCore
import GaiaLogger

class LogViewerViewModel: GaiaDeviceViewModelProtocol {
    private weak var viewController: GaiaViewControllerProtocol?
    private let coordinator: AppCoordinator
    private let gaiaManager: GaiaManager
    private let notificationCenter: NotificationCenter

    private(set) var title: String
    private(set) var logLines = [String]()
    private var device: GaiaDeviceProtocol?

    required init(viewController: GaiaViewControllerProtocol,
                  coordinator: AppCoordinator,
                  gaiaManager: GaiaManager,
                  notificationCenter: NotificationCenter) {
        self.viewController = viewController
        self.coordinator = coordinator
        self.gaiaManager = gaiaManager
        self.notificationCenter = notificationCenter

        self.title = String(localized: "Log Viewer", comment: "Log View Screen Title")
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
        self.logLines = [String(localized: "Fetching Logs.", comment: "Fetching Logs.")]
        refresh()
        getEntries()
    }

    func getEntries() {
        Task {
            if let logger = GaiaLogger.shared.logRetrievalProvider(),
               let text = try? await logger.previousEntries(limit: 500) {
                self.logLines = text
            } else {
                self.logLines = [String(localized: "No Logs Available.", comment: "No Logs Available.")]
            }
            await updateAfterFetch()
        }
    }

    @MainActor
    func updateAfterFetch() {
        refresh()
    }

    func deactivate() {
    }

    func refresh() {
        viewController?.update()
    }
}
