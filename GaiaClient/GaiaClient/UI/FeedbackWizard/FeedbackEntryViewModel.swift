//
//  © 2023 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation
import GaiaCore
import GaiaBase
import PluginBase
import UIKit

class FeedbackEntryViewModel: GaiaDeviceViewModelProtocol {
    private weak var viewController: GaiaViewControllerProtocol?
    private let coordinator: AppCoordinator
    private let gaiaManager: GaiaManager
    private let notificationCenter: NotificationCenter

    private(set) var title: String
    private var device: GaiaDeviceProtocol?

    required init(viewController: GaiaViewControllerProtocol,
                  coordinator: AppCoordinator,
                  gaiaManager: GaiaManager,
                  notificationCenter: NotificationCenter) {
        self.viewController = viewController
        self.coordinator = coordinator
        self.gaiaManager = gaiaManager
        self.notificationCenter = notificationCenter

        self.title = String(localized: "Enter Feedback", comment: "Settings Screen Title")
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
        viewController?.update()
    }

    func sendFeedback(title: String, description: String, reporter: String?, hardwareBuildID: String?) {
        if let corePlugin = device?.plugin(featureID: .core) as? GaiaDeviceCorePluginProtocol,
           let infoDictionary = Bundle.main.infoDictionary,
           feedbackValid(title: title, description: description, reporter: reporter, hardwareBuildID: hardwareBuildID) {
            let appID = corePlugin.applicationVersion
            let buildID = corePlugin.applicationBuildID

            var hardwareBuildIDEmpty = true
            if let hardwareBuildID, hardwareBuildID.count > 0 {
                hardwareBuildIDEmpty = false
            }
            let device = FeedbackInfo.DeviceDescription(applicationVersion: appID,
                                                        applicationBuildId: buildID.isEmpty ? nil : buildID,
                                                        hardwareVersion: hardwareBuildIDEmpty ? nil : hardwareBuildID)

            let appName = infoDictionary["CFBundleName"] as? String ?? ""
            let version = infoDictionary["CFBundleShortVersionString"] as? String ?? ""
            let build = infoDictionary["CFBundleVersion"] as? String ?? ""
            let appVersion = String(localized: "\(version) (build \(build))", comment: "App Build Info")

            let client = FeedbackInfo.ClientDescription(name: appName,
                                                        appVersion: appVersion,
                                                        system: UIDevice.current.systemName,
                                                        systemVersion: UIDevice.current.systemVersion,
                                                        device: getModelIdentifier())

            var reporterEmpty = true
            if let reporter, reporter.count > 0 {
                reporterEmpty = false
            }

            let feedbackInfo = FeedbackInfo(title: title,
                                            description: description,
                                            reporter: reporterEmpty ? nil : reporter,
                                            client: client,
                                            device: device)
            coordinator.startFeedbackSend(device: self.device!, feedbackInfo: feedbackInfo)
        }
    }

    func feedbackValid(title: String, description: String, reporter: String?, hardwareBuildID: String?) -> Bool {
        return title.count > 0 && description.count > 0
    }
}

private extension FeedbackEntryViewModel {
    func getModelIdentifier() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        return String(bytes: Data(bytes: &systemInfo.machine, count: Int(_SYS_NAMELEN)), encoding: .ascii)?.trimmingCharacters(in: .controlCharacters) ?? "Unknown"
    }
}
