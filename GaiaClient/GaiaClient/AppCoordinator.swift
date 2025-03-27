//
//  © 2020 - 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import UIKit
import GaiaCore
import GaiaBase
import PluginBase
import GaiaLogger

struct AppCoordinator {
    enum Storyboard: String {
        case main = "Main"
        case feedback = "Feedback"
        case updates = "Updates"
        case audioCuration = "AudioCuration"
        case statistics = "Statistics"
        case earbudUI = "EarbudUI"
        case voiceProcessing = "VoiceProcessing"
        case logViewer = "LogViewer"
    }

    class CloseHandler {
        let tabBarController: UITabBarController
        init(tabBarController: UITabBarController) {
            self.tabBarController = tabBarController
        }
        @objc func closeButton(_ btn: AnyObject) {
            tabBarController.dismiss(animated: true, completion: nil)
        }
    }

    private let window: UIWindow
    private let gaiaManager: GaiaManager
    private let notificationCenter: NotificationCenter
    private let tabBarController = UITabBarController()
    private let settingsNavigationController = UINavigationController()
    private let deviceInfoNavigationController = UINavigationController()
    private let closeHandler: CloseHandler

	private var observers = [ObserverToken] ()

    init(window: UIWindow,
         gaiaManager: GaiaManager,
         notificationCenter: NotificationCenter) {
        self.closeHandler = CloseHandler(tabBarController: tabBarController)
        self.window = window
        self.gaiaManager = gaiaManager
        self.notificationCenter = notificationCenter

        observers.append(notificationCenter.addObserver(forType: GaiaDeviceNotification.self,
                                                        object: nil,
                                                        queue: OperationQueue.main,
                                                        using: deviceNotificationHandler)) // Note retain cycle here.
        
        observers.append(notificationCenter.addObserver(forType: GaiaDeviceCorePluginNotification.self,
                                                        object: nil,
                                                        queue: OperationQueue.main,
                                                        using: coreHandler)) // Note retain cycle here.

        observers.append(notificationCenter.addObserver(forType: GaiaManagerNotification.self,
                                                        object: nil,
                                                        queue: OperationQueue.main,
                                                        using: managerNotificationHandler)) // Note retain cycle here.

        observers.append(notificationCenter.addObserver(forType: GaiaDeviceUpdaterPluginNotification.self,
                                                        object: nil,
                                                        queue: OperationQueue.main,
                                                        using: updaterNotificationHandler)) // Note retain cycle here.

        Reachability.shared.start()
    }
}

extension AppCoordinator {
    func instantiateVCFromStoryboard<T>(viewControllerClass: T.Type,
                                        storyboard: Storyboard = .main) -> T where T: GaiaViewControllerProtocol {
        let className = String(describing: T.self)
        let storyboard = UIStoryboard(name: storyboard.rawValue, bundle: nil)
        guard let viewController = storyboard.instantiateViewController(withIdentifier: className) as? T else {
            fatalError("Cannot instantiate \(className) from \(storyboard)")
        }
        return viewController
    }

    @discardableResult func showNextViewController<VC, VM>(viewControllerClass: VC.Type,
                                                           viewModelClass: VM.Type,
                                                           storyboard: Storyboard = .main,
                                                           presentInSheet: Bool = false,
                                                           presentModally: Bool = false) -> VC where VC: GaiaViewControllerProtocol, VM:GaiaViewModelProtocol {
        let vc = instantiateVCFromStoryboard(viewControllerClass: VC.self, storyboard: storyboard)
        let viewModel = VM(viewController: vc,
                           coordinator: self,
                           gaiaManager: gaiaManager,
                           notificationCenter: notificationCenter)
        vc.viewModel = viewModel
        if presentInSheet {
            let container = UINavigationController()
            container.viewControllers = [vc]
            container.modalPresentationStyle = .formSheet
            container.isModalInPresentation = presentModally
            if !presentModally {
                let close = UIBarButtonItem(barButtonSystemItem: .close,
                                            target: closeHandler,
                                            action: #selector(CloseHandler.closeButton(_:)))
                vc.navigationItem.leftBarButtonItems = [close]
            }
            tabBarController.present(container,
                                     animated: true,
                                     completion: nil)
        } else {
            settingsNavigationController.pushViewController(vc, animated: true)
        }
        return vc
    }
}

extension AppCoordinator {
    func deviceNotificationHandler(notification: GaiaDeviceNotification) {
        let notificationDeviceID = notification.payload.id
        guard
            let connectedDeviceID = gaiaManager.connectedDeviceConnectionID,
            let notificationDevice = gaiaManager.device(connectionID: notificationDeviceID)
        else {
            return
        }

        if notification.reason == .stateChanged &&
            notificationDevice.state == .gaiaReady &&
            notificationDeviceID == connectedDeviceID {
            // Reconnection of device
            setDeviceOnAllViewModels(notificationDevice)
            UpdateSettingsContainer.shared.device = notificationDevice
        }
    }

    func managerNotificationHandler(notification: GaiaManagerNotification) {
        var devID: String? = nil
        switch notification.payload {
        case .device(let d):
            devID = d.id
        default:
            break
        }
        guard
            let notificationDeviceID = devID,
            let connectedDeviceID = gaiaManager.connectedDeviceConnectionID
        else {
            return
        }

        if notification.reason == .disconnect &&
            notificationDeviceID == connectedDeviceID {
            // Cancel all dialogs

            setDeviceOnAllViewModels(nil)

            let top = tabBarController.findTopVC()
            if top is UIAlertController {
                top.presentingViewController? .dismiss(animated: false, completion: nil)
            }
        }
    }
    
    func coreHandler(_ notification: GaiaDeviceCorePluginNotification) {
        guard case let .upgradeRequired(deviceIdentifier, upgradeInfo) = notification.payload,
              let device = gaiaManager.device(connectionID: deviceIdentifier.id) else {
            return
        }
        
        guard UIApplication.shared.applicationState == .active else {
            return
        }
        
        tabBarController.showVersionMismatchDialog(upgradeInfo: upgradeInfo,
                                                   ok: {
            selectedFeature(.upgrade, device: device)
        }, cancel: { } )
    }
}

extension AppCoordinator {
    func updaterNotificationHandler(notification: GaiaDeviceUpdaterPluginNotification) {
        guard
            let device = gaiaManager.device(connectionID: notification.payload.id),
            let plugin = device.plugin(featureID: .upgrade) as? GaiaDeviceUpdaterPluginProtocol else {
            return
        }

        switch plugin.updateState  {
        case .busy(let progress):
            handleUpdateStatus(progress, plugin: plugin)
        default:
            break
        }
    }

    func handleUpdateStatus(_ status: UpdateStateProgress, plugin: GaiaDeviceUpdaterPluginProtocol) {
        let isForeground = UIApplication.shared.applicationState == .active

        switch status {
        case .awaitingConfirmation:
            if !isForeground {
                LOG(.high, "UNATTENDED DFU - accepting - awaitingConfirmation")
                plugin.commitConfirm(value: true)
            } else {
                tabBarController.showConfirmationDialog(ok: {
                    plugin.commitConfirm(value: true)
                }, cancel: {
                    plugin.commitConfirm(value: false)
                } )
            }
        case .awaitingConfirmForceUpgrade:
            if !isForeground {
                LOG(.high, "UNATTENDED DFU - accepting - awaitingConfirmForceUpgrade")
                plugin.confirmForceUpgradeResponse(value: true)
            } else {
                tabBarController.showConfirmForceUpgradeDialog(ok: {
                    plugin.confirmForceUpgradeResponse(value: true)
                }, cancel: {
                    plugin.confirmForceUpgradeResponse(value: false)
                } )
            }
        case .awaitingConfirmTransferRequired:
            if !isForeground {
                LOG(.high, "UNATTENDED DFU - accepting - awaitingConfirmTransferRequired")
                plugin.commitTransferRequired(value: plugin.silentCommitSupported ? .silent : .interactive)
            } else {
                tabBarController.showConfirmTransferRequiredDialog(
                    silentPermitted: plugin.silentCommitSupported,
                    ok: { doSilent in
                        plugin.commitTransferRequired(value: doSilent ? .silent : .interactive)
                    },
                    cancel: {
                        plugin.commitTransferRequired(value: .cancel)
                    } )
            }
        case .awaitingConfirmBatteryLow:
            if !isForeground {
                LOG(.high, "UNATTENDED DFU - accepting - awaitingConfirmBatteryLow")
                plugin.batteryWarningConfirmed()
            } else {
                tabBarController.showConfirmBatteryLowDialog {
                    plugin.batteryWarningConfirmed()
                }
            }
        case .awaitingEarbudsInCase:
            tabBarController.showPutInCaseDialog {
                plugin.abort()
            }
        case .awaitingEarbudsInCaseConfirmed,
             .awaitingEarbudsInCaseTimedOut:
            let top = tabBarController.findTopVC()
            if top is UIAlertController {
                top.presentingViewController? .dismiss(animated: false, completion: nil)
            }
        default:
            break

        }
    }
}

//MARK: App Launch
extension AppCoordinator {
    func onLaunch() {
        let deviceInfoVC = instantiateVCFromStoryboard(viewControllerClass: DeviceInfoViewController.self)
        let deviceInfoVM = DeviceInfoViewModel(viewController: deviceInfoVC,
                                               coordinator: self,
                                               gaiaManager: gaiaManager,
                                               notificationCenter: notificationCenter)
        deviceInfoVC.viewModel = deviceInfoVM

        deviceInfoNavigationController.viewControllers = [deviceInfoVC]
        deviceInfoNavigationController.tabBarItem = UITabBarItem(title: "Info", image: UIImage(named: "icon-info"), tag: 0)

        let settingsVC = instantiateVCFromStoryboard(viewControllerClass: SettingsIntroViewController.self)
        let settingsVM = SettingsIntroViewModel(viewController: settingsVC,
                                                coordinator: self,
                                                gaiaManager: gaiaManager,
                                                notificationCenter: notificationCenter)
        settingsVC.viewModel = settingsVM

		settingsNavigationController.viewControllers = [settingsVC]
        settingsNavigationController.tabBarItem = UITabBarItem(title: "Settings", image: UIImage(named: "icon-settings"), tag: 1)

        tabBarController.viewControllers = [deviceInfoNavigationController, settingsNavigationController]

        window.rootViewController = tabBarController
        window.makeKeyAndVisible()

        if gaiaManager.connectedDeviceConnectionID == nil {
            showDeviceSelection()
        }
    }

    func didBecomeActive() {
        gaiaManager.startScanning()
    }

    func didEnterBackground() {
        gaiaManager.stopScanning()
    }

    func showDeviceSelection() {
        showNextViewController(viewControllerClass: DevicesViewController.self,
                               viewModelClass: DevicesViewModel.self,
                               presentInSheet: true,
                               presentModally: true)
        setDeviceOnAllViewModels(nil)
    }

    func setDeviceOnAllViewModels(_ device: GaiaDeviceProtocol?) {
        if let presentedViewController = tabBarController.presentedViewController as? UINavigationController {
            // Modally presented VCs are in UINavigationControllers
            presentedViewController.viewControllers.forEach {
                if let vc = $0 as? GaiaViewControllerProtocol,
                    let vm = vc.viewModel as? GaiaDeviceViewModelProtocol {
                    vm.injectDevice(device: device)
                }
            }
        }

        deviceInfoNavigationController.viewControllers.forEach {
            if let vc = $0 as? GaiaViewControllerProtocol,
                let vm = vc.viewModel as? GaiaDeviceViewModelProtocol {
                vm.injectDevice(device: device)
            }
        }

        settingsNavigationController.viewControllers.forEach {
            if let vc = $0 as? GaiaViewControllerProtocol,
                let vm = vc.viewModel as? GaiaDeviceViewModelProtocol {
                vm.injectDevice(device: device)
            }
        }

        StatisticsRefreshManager.shared.injectDevice(device: device)
        StatisticsRecorder.sharedRecorder.injectDevice(device: device)
    }

    func onSelectDevice(_ device: GaiaDeviceProtocol) {
        tabBarController.dismiss(animated: true, completion: nil)
        setDeviceOnAllViewModels(device)
    }

    func userRequestedDisconnect(_ device: GaiaDeviceProtocol) {
        if device.state != .disconnected {
            gaiaManager.disconnect(device: device)
        }
        showDeviceSelection()
    }

    func userRequestedConnect(_ device: GaiaDeviceProtocol?) {
        if let d = device {
        	gaiaManager.start(device: d)
        } else {
            showDeviceSelection()
        }
    }
    
    func selectedFeature(_ featureID: GaiaDeviceQCPluginFeatureID, device: GaiaDeviceProtocol) {
        var vc: GaiaViewControllerProtocol? = nil
        switch featureID {
        case .upgrade:
            if let plugin = device.plugin(featureID: .upgrade) as? GaiaDeviceUpdaterPluginProtocol,
                plugin.isUpdating {
                showCurrentDFUProgressRequested(device: device)
            } else {
                vc = showNextViewController(viewControllerClass: UpdatesIntroViewController.self,
                                            viewModelClass: UpdatesIntroViewModel.self,
                                            storyboard: .updates)
            }
        case .legacyANC:
            vc = showNextViewController(viewControllerClass: LegacyANCSettingsViewController.self,
                                        viewModelClass: LegacyANCSettingsViewModel.self,
                                        storyboard: .audioCuration)
        case .audioCuration:
            vc = showNextViewController(viewControllerClass: AudioCurationIntroViewController.self,
                                        viewModelClass: AudioCurationIntroViewModel.self,
                                        storyboard: .audioCuration)
        case .voiceAssistant:
            vc = showNextViewController(viewControllerClass: VoiceAssistantSettingsViewController.self,
                                        viewModelClass: VoiceAssistantSettingsViewModel.self)
        case .eq:
            vc = showNextViewController(viewControllerClass: EQSettingsViewController.self,
                                        viewModelClass: EQSettingsViewModel.self)
        case .handset:
            vc = showNextViewController(viewControllerClass: HandsetSettingsViewController.self,
                                        viewModelClass: HandsetSettingsViewModel.self)
        case .earbudFit:
            vc = showNextViewController(viewControllerClass: EarbudFitViewController.self,
                                        viewModelClass: EarbudFitViewModel.self)
        case .voiceProcessing:
            vc = showNextViewController(viewControllerClass: VoiceProcessingSettingsViewController.self,
                                        viewModelClass: VoiceProcessingSettingsViewModel.self,
                                        storyboard: .voiceProcessing)
        case .earbudUI:
            vc = showNextViewController(viewControllerClass: EarbudUIIntroViewController.self,
                                        viewModelClass: EarbudUIIntroViewModel.self,
                                        storyboard: .earbudUI)
        case .statistics:
            vc = showNextViewController(viewControllerClass: StatisticsCategoriesViewController.self,
                                        viewModelClass: StatisticsCategoriesViewModel.self,
                                        storyboard: .statistics)
        default:
            break
        }

        if let vm = vc?.viewModel as? GaiaDeviceViewModelProtocol {
            vm.injectDevice(device: device)
        }
    }

    //MARK: Feedback

    func startFeedback(device: GaiaDeviceProtocol) {
        let vc = showNextViewController(viewControllerClass: FeedbackEntryViewController.self,
                                        viewModelClass: FeedbackEntryViewModel.self,
                                        storyboard: .feedback)

        if let vm = vc.viewModel as? GaiaDeviceViewModelProtocol {
            vm.injectDevice(device: device)
        }
    }

    func startFeedbackSend(device: GaiaDeviceProtocol, feedbackInfo: FeedbackInfo) {
        let vc = showNextViewController(viewControllerClass: FeedbackSendingViewController.self,
                                        viewModelClass: FeedbackSendingViewModel.self,
                                        storyboard: .feedback)

        if let vm = vc.viewModel as? FeedbackSendingViewModel {
            vm.injectDevice(device: device)
            vm.injectFeedbackInfo(feedbackInfo: feedbackInfo)
        }
    }

    //MARK: Log Viewer

    func startLogViewer(device: GaiaDeviceProtocol) {
        let vc = showNextViewController(viewControllerClass: LogViewerViewController.self,
                                        viewModelClass: LogViewerViewModel.self,
                                        storyboard: .logViewer)

        if let vm = vc.viewModel as? GaiaDeviceViewModelProtocol {
            vm.injectDevice(device: device)
        }
    }

    //MARK: Updates

    func updateIntroProceedRequested(_ device: GaiaDeviceProtocol, showRemote: Bool) {
        var vc: GaiaViewControllerProtocol?
        if showRemote {
            vc = showNextViewController(viewControllerClass: RemoteUpdatesSettingsViewController.self,
                                        viewModelClass: RemoteUpdatesSettingsViewModel.self,
                                        storyboard: .updates)
        } else {
            vc = showNextViewController(viewControllerClass: UpdateFilesViewController.self,
                                        viewModelClass: UpdateFilesViewModel.self,
                                        storyboard: .updates)
        }

        if let vm = vc?.viewModel as? GaiaDeviceViewModelProtocol {
            vm.injectDevice(device: device)
        }
    }

    func updateShowRemoteUpdates(_ device: GaiaDeviceProtocol, hardwareID: String) {
        let vc = showNextViewController(viewControllerClass: RemoteUpdatesViewController.self,
                                        viewModelClass: RemoteUpdatesViewModel.self,
                                        storyboard: .updates)

        if let vm = vc.viewModel as? RemoteUpdatesViewModel {
            vm.injectDevice(device: device)
            vm.injectHardwareId(hardwareID)
        }
    }

    func showRemoteUpdateDetailRequested(device: GaiaDeviceProtocol, info: UpdateEntry) {
        let vc = showNextViewController(viewControllerClass: UpdateDetailViewController.self,
                                        viewModelClass: UpdateDetailViewModel.self,
                                        storyboard: .updates)

        if let vm = vc.viewModel as? UpdateDetailViewModel {
            vm.injectDevice(device: device)
            vm.startForRemote(id: info.id, info: info)
        }
    }

    func fileSelectionError(error: Error) {
        tabBarController.showFileSelectionError(error: error)
    }

    func selectedUpdateFile(_ data: Data, device: GaiaDeviceProtocol, info: UpdateEntry) {
        let vc = showNextViewController(viewControllerClass: UpdateDetailViewController.self,
                                        viewModelClass: UpdateDetailViewModel.self,
                                        storyboard: .updates)

        if let vm = vc.viewModel as? UpdateDetailViewModel {
            vm.injectDevice(device: device)
            vm.startForLocal(data: data, info: info)
        }
    }

    func showCurrentDFUProgressRequested(device: GaiaDeviceProtocol) {
        let vc = showNextViewController(viewControllerClass: UpdateDetailViewController.self,
                                        viewModelClass: UpdateDetailViewModel.self,
                                        storyboard: .updates)

        if let vm = vc.viewModel as? UpdateDetailViewModel {
            vm.injectDevice(device: device)
            vm.startForOngoing()
        }
    }

    // ANC

    func showModes(device: GaiaDeviceProtocol) {
        let vc = showNextViewController(viewControllerClass: LegacyANCModesViewController.self,
                                        viewModelClass: LegacyANCModesViewModel.self,
                                        storyboard: .audioCuration)

        if let vm = vc.viewModel as? GaiaDeviceViewModelProtocol {
            vm.injectDevice(device: device)
        }
    }

    func showV2ANCModes(device: GaiaDeviceProtocol,
                        title: String,
                        availableModesGetter: @escaping (GaiaDeviceAudioCurationPluginProtocol) -> ([GaiaDeviceAudioCurationModeInfo]),
                        currentModeGetter: @escaping (GaiaDeviceAudioCurationPluginProtocol) -> (GaiaDeviceAudioCurationMode),
                        currentModeSetter: @escaping (GaiaDeviceAudioCurationPluginProtocol, GaiaDeviceAudioCurationMode) -> ()) {

        let vc = showNextViewController(viewControllerClass: AudioCurationModesViewController.self,
                                        viewModelClass: AudioCurationModesViewModel.self,
                                        storyboard: .audioCuration)

        if let vm = vc.viewModel as? AudioCurationModesViewModel {
            vm.injectDevice(device: device)
            vm.injectClosures(title: title,
                              availableModesGetter: availableModesGetter,
                              currentModeGetter: currentModeGetter,
                              currentModeSetter: currentModeSetter)
        }
    }

    func showANCGeneralOptions(device: GaiaDeviceProtocol,
                               title: String,
                               availableOptionsGetter: @escaping (GaiaDeviceAudioCurationPluginProtocol) -> ([String]),
                               currentOptionGetter: @escaping (GaiaDeviceAudioCurationPluginProtocol) -> (Int),
                               currentOptionSetter: @escaping (GaiaDeviceAudioCurationPluginProtocol, Int) -> ()) {

        let vc = showNextViewController(viewControllerClass: AudioCurationGeneralOptionsViewController.self,
                                        viewModelClass: AudioCurationGeneralOptionsViewModel.self,
                                        storyboard: .audioCuration)

        if let vm = vc.viewModel as? AudioCurationGeneralOptionsViewModel {
            vm.injectDevice(device: device)
            vm.injectClosures(title: title,
                              availableOptionsGetter: availableOptionsGetter,
                              currentOptionGetter: currentOptionGetter,
                              currentOptionSetter: currentOptionSetter)
        }
    }

    func showANCDemoModeRequested(device: GaiaDeviceProtocol) {
        let vc = showNextViewController(viewControllerClass: AudioCurationDemoViewController.self,
                                        viewModelClass: AudioCurationDemoViewModel.self,
                                        storyboard: .audioCuration)

        if let vm = vc.viewModel as? GaiaDeviceViewModelProtocol {
            vm.injectDevice(device: device)
        }
    }

    // Voice Enhancement

    func showVoiceProcessingCVCOptions(device: GaiaDeviceProtocol,
                                       title: String,
                                       availableModesGetter: @escaping (GaiaDeviceVoiceProcessingPluginProtocol) -> ([String]),
                                       currentModeGetter: @escaping (GaiaDeviceVoiceProcessingPluginProtocol) -> (Int),
                                       currentModeSetter: @escaping (GaiaDeviceVoiceProcessingPluginProtocol, Int) -> ()) {

        let vc = showNextViewController(viewControllerClass: VoiceProcessingCVCOptionsViewController.self,
                                        viewModelClass: VoiceProcessingCVCOptionsViewModel.self,
                                        storyboard: .voiceProcessing)

        if let vm = vc.viewModel as? VoiceProcessingCVCOptionsViewModel {
            vm.injectDevice(device: device)
            vm.injectClosures(title: title,
                              availableModesGetter: availableModesGetter,
                              currentModeGetter: currentModeGetter,
                              currentModeSetter: currentModeSetter)
        }
    }

    // EarbudUI

    func showContextsForGesture(device: GaiaDeviceProtocol, gesture: EarbudUIGesture) {
        let vc = showNextViewController(viewControllerClass: EarbudUIContextsViewController.self,
                                        viewModelClass: EarbudUIContextsViewModel.self,
                                        storyboard: .earbudUI)

        if let vm = vc.viewModel as? EarbudUIContextsViewModel {
            vm.injectDevice(device: device)
            vm.injectGesture(gesture: gesture)
        }
    }

    // Statistics

    func showStatisticsForCategory(device: GaiaDeviceProtocol, category: StatisticCategories) {
        let vc = showNextViewController(viewControllerClass: StatisticsCategoryViewController.self,
                                        viewModelClass: StatisticsCategoryViewModel.self,
                                        storyboard: .statistics)

        if let vm = vc.viewModel as? StatisticsCategoryViewModel {
            vm.injectDevice(device: device)
            vm.injectCategory(category: category)
        }
    }
}

private extension UITabBarController {
    func findTopVC() -> UIViewController {
        var vc: UIViewController = self
        while let presented = vc.presentedViewController {
            vc = presented
        }
        return vc
    }

    func showFileSelectionError(error: Error) {
        let alert = UIAlertController(title: String(localized: "Error Selecting File", comment: "Updater Dialog"),
                                      message: error.localizedDescription,
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: String(localized: "OK", comment: "OK"), style: .default, handler: nil))

        findTopVC().present(alert, animated: true, completion: nil)
    }

    func showConfirmationDialog(ok: @escaping ()->(),
                                cancel: @escaping ()->()) {
        let alert = UIAlertController(title: String(localized: "Finalize Update", comment: "Updater Dialog"),
                                      message: String(localized: "Would you like to complete the upgrade?", comment: "Updater Dialog"),
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: String(localized: "OK", comment: "OK"),
                                      style: .default) { _ in ok() })

        alert.addAction(UIAlertAction(title: String(localized: "Cancel", comment: "Cancel"),
                                      style: .cancel) { _ in cancel() })

        findTopVC().present(alert, animated: true, completion: nil)
    }

    func showConfirmBatteryLowDialog(ok: @escaping ()->()) {
        let alert = UIAlertController(title: String(localized: "Battery Low", comment: "Updater Dialog"),
                                      message: String(localized: "The battery is low on your audio device. Please connect it to a charger", comment: "Updater Dialog"),
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: String(localized: "OK", comment: "OK"),
                                      style: .default) { _ in ok() })

        findTopVC().present(alert, animated: true, completion: nil)
    }

    func showConfirmForceUpgradeDialog(ok: @escaping ()->(), cancel: @escaping ()->()){
        let alert = UIAlertController(title: String(localized: "Synchronisation Failed", comment: "Updater Dialog"),
                                      message: String(localized: "Another update has already been started. Would you like to force the upgrade?", comment: "Updater Dialog"),
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: String(localized: "OK", comment: "OK"),
                                      style: .default) { _ in ok() })

        alert.addAction(UIAlertAction(title: String(localized: "Cancel", comment: "Cancel"),
                                      style: .cancel) { _ in cancel() })

        findTopVC().present(alert, animated: true, completion: nil)
    }

    func showConfirmTransferRequiredDialog(silentPermitted: Bool, ok: @escaping (_ silent: Bool)->(), cancel: @escaping ()->()) {
        if silentPermitted {
            let alert = UIAlertController(title: String(localized: "File transfer complete", comment: "Updater Dialog"),
                                          message: String(localized: "Would you like to proceed? A device reboot may be required. The update can be applied now or later when the device is not being used.", comment: "Updater Dialog"),
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: String(localized: "OK, reboot now", comment: "OK"),
                                          style: .default) { _ in ok(false) })

            alert.addAction(UIAlertAction(title: String(localized: "OK, reboot later", comment: "OK"),
                                          style: .default) { _ in ok(true) })

            alert.addAction(UIAlertAction(title: String(localized: "Cancel", comment: "Cancel"),
                                          style: .cancel) { _ in cancel() })

            findTopVC().present(alert, animated: true, completion: nil)
        } else {
            let alert = UIAlertController(title: String(localized: "File transfer complete", comment: "Updater Dialog"),
                                          message: String(localized: "Would you like to proceed? A device reboot may be required.", comment: "Updater Dialog"),
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: String(localized: "OK", comment: "OK"),
                                          style: .default) { _ in ok(false) })

            alert.addAction(UIAlertAction(title: String(localized: "Cancel", comment: "Cancel"),
                                          style: .cancel) { _ in cancel() })

            findTopVC().present(alert, animated: true, completion: nil)
        }
    }

    func showPutInCaseDialog(abort: @escaping ()->()) {
        let alert = UIAlertController(title: String(localized: "Put earbuds in case", comment: "Updater Dialog"),
                                      message: String(localized: "Please put both earbuds in the case and close the lid to continue the upgrade. Do not open the lid until the upgrade is complete.\n\n This message will disappear once the earbuds are in the case and the lid closed.", comment: "Updater Dialog"),
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: String(localized: "Abort", comment: "Abort"),
                                      style: .destructive) { _ in abort() })

        findTopVC().present(alert, animated: true, completion: nil)
    }
    
    func showVersionMismatchDialog(upgradeInfo: CoreUpgradeRequiredPayload, ok: @escaping ()->(), cancel: @escaping ()->()) {
        let alert = UIAlertController(title: String(localized: "Upgrade Required", comment: "Dialog warning of earbud version mismatch"),
                                      message: String(localized: "Please upgrade the Earbuds to version \(upgradeInfo.majorVersion).\(upgradeInfo.minorVersion).\(upgradeInfo.psStoreVersion).", comment: "Dialog warning of earbud version mismatch"),
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: String(localized: "OK", comment: "OK"),
                                      style: .default) { _ in ok() })

        alert.addAction(UIAlertAction(title: String(localized: "Cancel", comment: "Cancel"),
                                      style: .cancel) { _ in cancel() })

        findTopVC().present(alert, animated: true, completion: nil)
    }
}
