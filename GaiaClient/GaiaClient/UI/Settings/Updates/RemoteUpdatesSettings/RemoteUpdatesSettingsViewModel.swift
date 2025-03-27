//
//  © 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation
import GaiaCore
import GaiaBase
import PluginBase

class RemoteUpdatesSettingsViewModel: GaiaDeviceViewModelProtocol {
    private weak var viewController: GaiaViewControllerProtocol?
    private let coordinator: AppCoordinator
    private let gaiaManager: GaiaManager
    private let notificationCenter: NotificationCenter

    private(set) var title: String

    private var device: GaiaDeviceProtocol?

    var hardwareId: String = ""
    var server: String {
        get {
            return RemoteDFUServer.shared.baseServerURL ?? ""
        }
        set {
            RemoteDFUServer.shared.baseServerURL = newValue
        }
    }

    var filters: [RemoteDFUServer.Filter] {
        get {
            return RemoteDFUServer.shared.filters
        }
        set {
            RemoteDFUServer.shared.filters = newValue
        }
    }

    private var buildID: String?

    public enum HardwareIDRequirement {
        case notRequired
        case optional
        case mandatory
    }

    public var hardwareIDRequired: HardwareIDRequirement {
        let corePlugin = device?.plugin(featureID: .core) as? GaiaDeviceCorePluginProtocol
        let appID = corePlugin?.applicationVersion ?? ""
        let buildID = corePlugin?.applicationBuildID ?? ""

        if buildID.isValidHex() {
            return .optional
        }

        if let last = appID.components(separatedBy: ".").last,
           last.isValidHex() {
            return .optional
        } else {
            return .mandatory
        }
    }

    required init(viewController: GaiaViewControllerProtocol,
                  coordinator: AppCoordinator,
                  gaiaManager: GaiaManager,
                  notificationCenter: NotificationCenter) {
        self.viewController = viewController
        self.coordinator = coordinator
        self.gaiaManager = gaiaManager
        self.notificationCenter = notificationCenter

        self.title = String(localized: "Search for Updates", comment: "Settings Screen Title")
    }

    func injectDevice(device: GaiaDeviceProtocol?) {
        self.device = device
        if hardwareIDRequired == .notRequired {
            hardwareId = ""
        }
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
}

extension RemoteUpdatesSettingsViewModel {
    func viewControllerForTagEdit(tagType: TagsEditViewModel.TagType) -> TagsEditViewController {
        let vc = coordinator.instantiateVCFromStoryboard(viewControllerClass: TagsEditViewController.self,
                                                         storyboard: .updates)
        let viewModel = TagsEditViewModel(viewController: vc,
                                          coordinator: coordinator,
                                          gaiaManager: gaiaManager,
                                          notificationCenter: notificationCenter)
        viewModel.injectDevice(device: device)
        viewModel.injectTagType(tagType: tagType)
        vc.viewModel = viewModel
        return vc
    }

    func continueSelected() {
        guard let device = device else {
            return
        }

        coordinator.updateShowRemoteUpdates(device, hardwareID: hardwareId)
    }
}

extension String {
    func isValidHex() -> Bool {
        return (!isEmpty) && allSatisfy({$0.isHexDigit})
    }
}
