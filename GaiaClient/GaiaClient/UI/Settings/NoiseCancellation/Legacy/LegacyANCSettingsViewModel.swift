//
//  © 2020 - 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation
import GaiaCore
import GaiaBase
import PluginBase

class LegacyANCSettingsViewModel: GaiaTableViewModelProtocol {
    private weak var viewController: GaiaViewControllerProtocol?
    private let coordinator: AppCoordinator
    private let gaiaManager: GaiaManager
    private let notificationCenter: NotificationCenter

    private(set) weak var ncPlugin: GaiaDeviceLegacyANCPluginProtocol?

    private(set) var title: String

    private(set) var sections = [SettingSection] ()
    private(set) var checkmarkIndexPath: IndexPath?

    private var device: GaiaDeviceProtocol? {
        didSet {
            ncPlugin = device?.plugin(featureID: .legacyANC) as? GaiaDeviceLegacyANCPluginProtocol
            refresh()
        }
    }

    private var observerTokens = [ObserverToken]()

    required init(viewController: GaiaViewControllerProtocol,
                  coordinator: AppCoordinator,
                  gaiaManager: GaiaManager,
                  notificationCenter: NotificationCenter) {
        self.viewController = viewController
        self.coordinator = coordinator
        self.gaiaManager = gaiaManager
        self.notificationCenter = notificationCenter

        self.title = String(localized: "Legacy ANC", comment: "Settings Screen Title")

        observerTokens.append(notificationCenter.addObserver(forType: GaiaDeviceNotification.self,
                                                             object: nil,
                                                             queue: OperationQueue.main,
                                                             using: { [weak self] notification in self?.deviceNotificationHandler(notification) }))

        observerTokens.append(notificationCenter.addObserver(forType: GaiaManagerNotification.self,
                                                             object: nil,
                                                             queue: OperationQueue.main,
                                                             using: { [weak self] notification in self?.deviceDiscoveryAndConnectionHandler(notification) }))

        observerTokens.append(notificationCenter.addObserver(forType: GaiaDeviceLegacyANCPluginNotification.self,
                                                             object: nil,
                                                             queue: OperationQueue.main,
                                                             using: { [weak self] notification in self?.noiseCancellationNotificationHandler(notification) }))

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
        guard let ncPlugin = ncPlugin else {
            return
        }

        var firstSectionRows = [SettingRow] ()

        let enabledRow = SettingRow.titleAndSwitch(title: String(localized: "Active Noise Cancellation", comment: "Enabled Option"),
                                                   switchOn: ncPlugin.enabled)
        firstSectionRows.append(enabledRow)

        if ncPlugin.enabled {
            let leftTypeValue = ncPlugin.isLeftAdaptive ?
                String(localized: "Left: Adaptive", comment: "ANC Type") :
                String(localized: "Left: Static", comment: "ANC Type")

            let rightTypeValue = ncPlugin.isRightAdaptive ?
                String(localized: "Right: Adaptive", comment: "ANC Type") :
                String(localized: "Right: Static", comment: "ANC Type")
            let ancTypeRow = SettingRow.titleAndSubtitle(title: String(localized: "ANC Type", comment: "ANC Type"),
                                                         subtitle: leftTypeValue + " - " + rightTypeValue,
                                                         tapable: false)
            firstSectionRows.append(ancTypeRow)

            let maxMode = min(9, max(0, ncPlugin.maxMode)) // constrain 0..9
            let modeCurrent = min(maxMode, max(0, ncPlugin.currentMode))
            let modeStr = LegacyANCShared.modeOptions[modeCurrent]

            let modeRow = SettingRow.titleAndSubtitle(title: String(localized: "Mode", comment: "ANC Mode"),
                                                      subtitle: modeStr,
                                                      tapable: maxMode != 0)
            firstSectionRows.append(modeRow)


            if ncPlugin.isLeftAdaptive || ncPlugin.isRightAdaptive {
                // Gain is not user modifiable
                let leftGainRow = SettingRow.titleAndSubtitle(title: String(localized: "Left Gain", comment: "ANC Gain"),
                                                              subtitle: "\(ncPlugin.leftAdaptiveGain)",
                                                              tapable: false)
                firstSectionRows.append(leftGainRow)

                let rightGainRow = SettingRow.titleAndSubtitle(title: String(localized: "Right Gain", comment: "ANC Gain"),
                                                               subtitle: "\(ncPlugin.rightAdaptiveGain)",
                                                               tapable: false)
                firstSectionRows.append(rightGainRow)
            } else {
                if modeCurrent != 0 {
                    let gainRow = SettingRow.titleSubtitleAndSlider(title: String(localized: "Static Gain", comment: "ANC Gain"),
                                                                    subtitle: "\(ncPlugin.staticGain)",
                                                                    value: ncPlugin.staticGain,
                                                                    min: 0,
                                                                    max: 255)
                    firstSectionRows.append(gainRow)
                }
            }
        }
        sections = [SettingSection(title: nil, rows: firstSectionRows)]
        viewController?.update()
    }
}

extension LegacyANCSettingsViewModel {
    func toggledSwitch(indexPath: IndexPath) {
        guard let ncPlugin = ncPlugin else {
            return
        }

        ncPlugin.setEnabledState(!ncPlugin.enabled)
    }


    func valueChanged(indexPath: IndexPath, newValue: Int) {
        guard let ncPlugin = ncPlugin else {
            return
        }
        if indexPath.row == 3 {
            if ncPlugin.isLeftAdaptive || ncPlugin.isRightAdaptive {
                return
            }
            ncPlugin.setStaticGain(newValue)
        }
    }

    func selectedItem(indexPath: IndexPath) {
        switch indexPath.row {
        case 2: // Mode
            coordinator.showModes(device: device!)
            break
        default:
            break
        }
    }
}

private extension LegacyANCSettingsViewModel {
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

    func noiseCancellationNotificationHandler(_ notification: GaiaDeviceLegacyANCPluginNotification) {
        guard notification.payload.id == device?.id else {
            return
        }
        
        refresh()
    }
}

