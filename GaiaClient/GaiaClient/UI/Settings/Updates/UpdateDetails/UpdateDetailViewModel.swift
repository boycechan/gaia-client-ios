//
//  © 2023 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation
import GaiaBase
import GaiaCore
import PluginBase
import GaiaLogger

class UpdateDetailViewModel: GaiaDeviceViewModelProtocol {
    internal struct UpdateExtendedInfo {
        enum UpdateSource {
            case unknown
            case local // From file manager.
            case remote // From update service
        }

        let entryInfo: UpdateEntry
        let source: UpdateSource
    }

    internal enum ChildViewState: Equatable {
        case none
        case showDetailsForRemote(id: String, info: UpdateExtendedInfo)
        case showDetailsForLocal(data: Data, info: UpdateExtendedInfo)
        case download(id: String, info: UpdateExtendedInfo)
        case update(data: Data, info: UpdateExtendedInfo)
        case done(info: UpdateExtendedInfo)
        case failed(message: String, info: UpdateExtendedInfo)

        public static func == (lhs: ChildViewState, rhs: ChildViewState) -> Bool {
            switch lhs {
            case .none:
                return rhs == .none
            case .showDetailsForRemote(id: _, info: _):
                switch rhs {
                case .showDetailsForRemote(id: _, info: _):
                    return true
                default:
                    return false
                }
            case .showDetailsForLocal(data: _, info: _):
                switch rhs {
                case .showDetailsForLocal(data: _, info: _):
                    return true
                default:
                    return false
                }
            case .download(id: _, info: _):
                switch rhs {
                case .download(id: _, info: _):
                    return true
                default:
                    return false
                }
            case .update(data: _, info: _):
                switch rhs {
                case .update(data: _, info: _):
                    return true
                default:
                    return false
                }
            case .done(info: _):
                switch rhs {
                case .done(info: _):
                    return true
                default:
                    return false
                }
            case .failed(message: _, info: _):
                switch rhs {
                case .failed(message: _, info: _):
                    return true
                default:
                    return false
                }
            }
        }
    }



    private weak var viewController: GaiaViewControllerProtocol?
    private let coordinator: AppCoordinator
    private let gaiaManager: GaiaManager
    private unowned let notificationCenter: NotificationCenter

    static private var updateInfo: UpdateExtendedInfo?

    var title: String
    var state: ChildViewState = .none {
        didSet {
            if oldValue != state {
                if let vc = viewController as? UpdateDetailViewController {
                    vc.updateForNewState()
                }
            }
        }
    }

    private var device: GaiaDeviceProtocol?

    private var observerTokens = [ObserverToken]()

    private var fetchTask: Task<Data, Error>?

    required init(viewController: GaiaViewControllerProtocol,
                  coordinator: AppCoordinator,
                  gaiaManager: GaiaManager,
                  notificationCenter: NotificationCenter) {
        self.viewController = viewController
        self.coordinator = coordinator
        self.gaiaManager = gaiaManager
        self.notificationCenter = notificationCenter

        self.title = String(localized: "Update", comment: "Update Title")
        /*
         observerTokens.append(notificationCenter.addObserver(forType: GaiaDeviceNotification.self,
         object: nil,
         queue: OperationQueue.main,
         using: { [weak self] notification in self?.deviceNotificationHandler(notification) }))

         observerTokens.append(notificationCenter.addObserver(forType: GaiaManagerNotification.self,
         object: nil,
         queue: OperationQueue.main,
         using: { [weak self] notification in self?.deviceDiscoveryAndConnectionHandler(notification) }))
         */
    }

    deinit {
        observerTokens.forEach { token in
            notificationCenter.removeObserver(token)
        }
        observerTokens.removeAll()
    }

    func injectDevice(device: GaiaDeviceProtocol?) {
        self.device = device
        if let vc = viewController as? UpdateDetailViewController {
            if let downloadVM = vc.downloadViewController?.viewModel as? DownloadProgressViewModel {
                downloadVM.injectDevice(device: device)
            }

            if let upgradeVM = vc.upgradeViewController?.viewModel as? UpdateProgressViewModel {
                upgradeVM.injectDevice(device: device)
            }
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

        if let vc = viewController as? UpdateDetailViewController {
            if let downloadVC = vc.downloadViewController,
               downloadVC.viewModel == nil {
                let vm = DownloadProgressViewModel(viewController: downloadVC,
                                                   coordinator: coordinator,
                                                   gaiaManager: gaiaManager,
                                                   notificationCenter: notificationCenter)
                vm.delegate = self
                vm.injectDevice(device: device)
                downloadVC.viewModel = vm
                vm.activate()
            }

            if let upgradeVC = vc.upgradeViewController,
               upgradeVC.viewModel == nil {
                let vm = UpdateProgressViewModel(viewController: upgradeVC,
                                                 coordinator: coordinator,
                                                 gaiaManager: gaiaManager,
                                                 notificationCenter: notificationCenter)
                vm.delegate = self
                vm.injectDevice(device: device)
                upgradeVC.viewModel = vm
                vm.activate()
            }
        }
    }

    func deactivate() {
        if let vc = viewController as? UpdateDetailViewController {
            if let downloadVM = vc.downloadViewController?.viewModel {
                downloadVM.deactivate()
            }

            if let upgradeVM = vc.upgradeViewController?.viewModel {
                upgradeVM.deactivate()
            }
        }
    }

    func refresh() {
        viewController?.update()
    }

    func startForOngoing() {
        if let updatesPlugin = device?.plugin(featureID: .upgrade) as? GaiaDeviceUpdaterPluginProtocol,
           updatesPlugin.isUpdating {
            if Self.updateInfo == nil {
                Self.updateInfo = UpdateExtendedInfo(entryInfo: UpdateEntry(id: "",
                                                                            title: String(localized: "Update Source Not Known.", comment: "Update Source Not Known.")),
                                                     source: .unknown)
            }
            state = .update(data: Data(), info: Self.updateInfo!)
        }
    }

    func startForRemote(id: String, info: UpdateEntry) {
        Self.updateInfo = UpdateExtendedInfo(entryInfo: info, source: .remote)
        state = .showDetailsForRemote(id: id, info: Self.updateInfo!)
    }

    func startForLocal(data: Data, info: UpdateEntry) {
        Self.updateInfo = UpdateExtendedInfo(entryInfo: info, source: .local)
        state = .showDetailsForLocal(data: data, info: Self.updateInfo!)
    }

    func viewControllerForUpgradeSettings() -> GaiaViewControllerProtocol? {
        if let updatesPlugin = device?.plugin(featureID: .upgrade) as? GaiaDeviceUpdaterPluginProtocol,
           !updatesPlugin.isUpdating {
            let transportCaps = updatesPlugin.transportCapabilities
            switch transportCaps {
            case .iap2(_, _, _):
                let vc = coordinator.instantiateVCFromStoryboard(viewControllerClass: IAP2UpdateSettingsViewController.self,
                                                                 storyboard: .updates)
                let viewModel = IAP2UpdateSettingsViewModel(viewController: vc,
                                                            coordinator: coordinator,
                                                            gaiaManager: gaiaManager,
                                                            notificationCenter: notificationCenter)
                viewModel.injectDevice(device: device)
                vc.viewModel = viewModel
                return vc
            case .ble(_, _, _, _):
                let vc = coordinator.instantiateVCFromStoryboard(viewControllerClass: BLEUpdateSettingsViewController.self,
                                                                 storyboard: .updates)
                let viewModel = BLEUpdateSettingsViewModel(viewController: vc,
                                                           coordinator: coordinator,
                                                           gaiaManager: gaiaManager,
                                                           notificationCenter: notificationCenter)
                viewModel.injectDevice(device: device)
                vc.viewModel = viewModel
                return vc
            default:
                break
            }
        }
        return nil
    }
}

extension UpdateDetailViewModel {
    func startDownload() {
        switch state {
        case .showDetailsForRemote(id: let id, info: let info):
            state = .download(id: id, info: info)
            if let vc = viewController as? UpdateDetailViewController,
               let downloadVM = vc.downloadViewController?.viewModel as? DownloadProgressViewModel {
                downloadVM.injectDownloadID(id)
            }
        default:
            break
        }
    }

    func startDFUForLocal() {
        switch state {
        case .showDetailsForLocal(data: let data, info: let info):
            state = .update(data: data, info: info)
            startDFUWithDefaults(data: data)
        default:
            break
        }
    }

    private func startDFUWithDefaults(data: Data) {
        if let vc = viewController as? UpdateDetailViewController,
           let updateVM = vc.upgradeViewController?.viewModel as? UpdateProgressViewModel,
           let updatesPlugin = device?.plugin(featureID: .upgrade) as? GaiaDeviceUpdaterPluginProtocol,
           let settings = UpdateSettingsContainer.shared.settings,
           !updatesPlugin.isUpdating {
            updatesPlugin.startUpdate(fileData: data, requestedSettings: settings)
            updateVM.refresh()
        }
    }
}

extension UpdateDetailViewModel: DownloadProgressViewModelDelegate {
    func didFinishDownloadAndRequestDFU(data: Data) {
        if let info = Self.updateInfo {
            state = .update(data: data, info: info)
			startDFUWithDefaults(data: data)
        }
    }
}

extension UpdateDetailViewModel: UpdateProgressViewModelDelegate {
    func didFinishUpdate(cancelled: Bool) {
        viewController?.navigationController?.popToRootViewController(animated: true)
    }
}
