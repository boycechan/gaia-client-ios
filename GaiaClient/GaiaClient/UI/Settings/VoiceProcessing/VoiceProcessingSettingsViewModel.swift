//
//  © 2021 - 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation
import GaiaCore
import GaiaBase
import PluginBase

class VoiceProcessingSettingsViewModel: GaiaTableViewModelProtocol {
    private weak var viewController: GaiaViewControllerProtocol?
    private let coordinator: AppCoordinator
    private let gaiaManager: GaiaManager
    private let notificationCenter: NotificationCenter

    private(set) weak var vePlugin: GaiaDeviceVoiceProcessingPluginProtocol?

    private(set) var title: String

    private(set) var sections = [SettingSection] ()
    private(set) var checkmarkIndexPath: IndexPath?

    private var device: GaiaDeviceProtocol? {
        didSet {
            vePlugin = device?.plugin(featureID: .voiceProcessing) as? GaiaDeviceVoiceProcessingPluginProtocol
            refresh()
        }
    }

    private(set) var observerTokens = [ObserverToken]()

    required init(viewController: GaiaViewControllerProtocol,
                  coordinator: AppCoordinator,
                  gaiaManager: GaiaManager,
                  notificationCenter: NotificationCenter) {
        self.viewController = viewController
        self.coordinator = coordinator
        self.gaiaManager = gaiaManager
        self.notificationCenter = notificationCenter

        self.title = String(localized: "Voice Processing", comment: "Settings Screen Title")

        observerTokens.append(notificationCenter.addObserver(forType: GaiaDeviceNotification.self,
                                                             object: nil,
                                                             queue: OperationQueue.main,
                                                             using: { [weak self] notification in self?.deviceNotificationHandler(notification) }))

        observerTokens.append(notificationCenter.addObserver(forType: GaiaManagerNotification.self,
                                                             object: nil,
                                                             queue: OperationQueue.main,
                                                             using: { [weak self] notification in self?.deviceDiscoveryAndConnectionHandler(notification) }))

        observerTokens.append(notificationCenter.addObserver(forType: GaiaDeviceVoiceProcessingPluginNotification.self,
                                                             object: nil,
                                                             queue: OperationQueue.main,
                                                             using: { [weak self] notification in self?.voiceProcessingNotificationHandler(notification) }))
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
        guard let vePlugin = vePlugin else {
            return
        }

        let canUseCVC = vePlugin.isCapabilityPresent(.cVc)

        sections.removeAll()

        if canUseCVC {
            var firstSectionRows = [SettingRow] ()

            var sub = ""
            switch vePlugin.cVcOperationMode {
            case .unknownOrUnavailable:
                sub = String(localized: "Not known", comment: "cVc Operation Mode Option")
            case .twoMic:
                sub = String(localized: "Two Mic", comment: "cVc Operation Mode Option")
            case .threeMic:
                sub = String(localized: "Three Mic", comment: "cVc Operation Mode Option")
            }
            let opModeRow = SettingRow.titleAndSubtitle(title: String(localized: "Operation Mode", comment: "cVc Operation Mode Option"),
                                                        subtitle: sub,
                                                        tapable: false)
            firstSectionRows.append(opModeRow)

            // Microphone mode
			sub = ""
            switch vePlugin.cVcMicrophonesMode {
            case .unknownOrUnavailable:
                sub = String(localized: "Not known", comment: "cVc Microphone Mode Option")
            case .oneMic:
                sub = String(localized: "One Mic", comment: "cVc Microphone Mode Option")
            case .twoMic:
                sub = String(localized: "Two Mic", comment: "cVc Microphone Mode Option")
            case .threeMic:
                sub = String(localized: "Three Mic", comment: "cVc Microphone Mode Option")
            case .bypass:
                sub = String(localized: "Bypass", comment: "cVc Microphone Mode Option")
            }
            let micModeRow = SettingRow.titleAndSubtitle(title: String(localized: "Microphone Mode", comment: "cVc Microphone Mode Option"),
                                                        subtitle: sub,
                                                        tapable: vePlugin.cVcMicrophonesMode != .unknownOrUnavailable)
            firstSectionRows.append(micModeRow)

            if vePlugin.cVcMicrophonesMode == .bypass {
                // Bypass/transparent mode
                sub = ""
                switch vePlugin.cVcBypassMode {
                case .unknownOrUnavailable:
                    sub = String(localized: "Not known", comment: "cVc Bypass Mode Option")
                case .voiceMic:
                    sub = String(localized: "Voice Mic Bypass", comment: "cVc Bypass Mode Option")
                case .externalMic:
                    sub = String(localized: "Background Mic Bypass", comment: "cVc Bypass Mode Option")
                case .internalMic:
                    sub = String(localized: "In-Ear Mic Bypass", comment: "cVc Bypass Mode Option")
                }
                let bypassModeRow = SettingRow.titleAndSubtitle(title: String(localized: "Bypass Mode", comment: "cVc Bypass Mode Option"),
                                                            subtitle: sub,
                                                            tapable: vePlugin.cVcBypassMode != .unknownOrUnavailable)

                firstSectionRows.append(bypassModeRow)
            }

            // Note the casing of the section is enforced in the view controller.
            sections.append(SettingSection(title: String(localized: "QUALCOMM® cVc™ 3-MIC", comment: "cVc"), rows: firstSectionRows))
        }

        viewController?.update()
    }
}

extension VoiceProcessingSettingsViewModel {
    func toggledSwitch(indexPath: IndexPath) {
    }

    func selectedItem(indexPath: IndexPath) {
        guard let device = device else {
            return
        }

        switch indexPath.section {
        case 0:
            // cVc
            switch indexPath.row {
            case 1:
                // Mic mode
                coordinator.showVoiceProcessingCVCOptions(device: device,
                                                          title: String(localized: "Microphone Mode", comment: "cVc Microphone Mode Option"),
                                                          availableModesGetter: { _ in
                                                            return [String(localized: "One Mic", comment: "cVc Microphone Mode Option"),
                                                                    String(localized: "Two Mic", comment: "cVc Microphone Mode Option"),
                                                                    String(localized: "Three Mic", comment: "cVc Microphone Mode Option"),
                                                                    String(localized: "Bypass", comment: "cVc Microphone Mode Option")
                                                            ]
                                                          },
                                                          currentModeGetter: { plugin in
                                                            switch plugin.cVcMicrophonesMode {
                                                            case .oneMic:
                                                                return 0
                                                            case .twoMic:
                                                                return 1
                                                            case .threeMic:
                                                                return 2
                                                            case .bypass:
                                                                return 3
                                                            default:
                                                                return -1
                                                            }
                                                          },
                                                          currentModeSetter: { plugin, newIndex in
                                                            switch newIndex {
                                                            case 0:
                                                                plugin.setCVCMicrophonesMode(.oneMic)
                                                            case 1:
                                                                plugin.setCVCMicrophonesMode(.twoMic)
                                                            case 2:
                                                                plugin.setCVCMicrophonesMode(.threeMic)
                                                            case 3:
                                                                plugin.setCVCMicrophonesMode(.bypass)
                                                            default:
                                                                break
                                                            }
                                                          })
            case 2:
                // Bypass mode
                coordinator.showVoiceProcessingCVCOptions(device: device,
                                                          title: String(localized: "Bypass Mode", comment: "cVc Microphone Mode Option"),
                                                          availableModesGetter: { _ in
                                                            return [String(localized: "Voice Mic Bypass", comment: "cVc Bypass Mode Option"),
                                                                    String(localized: "Background Mic Bypass", comment: "cVc Bypass Mode Option"),
                                                                    String(localized: "In-Ear Mic Bypass", comment: "cVc Bypass Mode Option")
                                                            ]
                                                          },
                                                          currentModeGetter: { plugin in
                                                            switch plugin.cVcBypassMode {
                                                            case .voiceMic:
                                                                return 0
                                                            case .externalMic:
                                                                return 1
                                                            case .internalMic:
                                                                return 2
                                                            default:
                                                                return -1
                                                            }
                                                          },
                                                          currentModeSetter: { plugin, newIndex in
                                                            switch newIndex {
                                                            case 0:
                                                                plugin.setCVCBypassMode(.voiceMic)
                                                            case 1:
                                                                plugin.setCVCBypassMode(.externalMic)
                                                            case 2:
                                                                plugin.setCVCBypassMode(.internalMic)
                                                            default:
                                                                break
                                                            }
                                                          })
            default:
                break
            }
        default:
            break
        }
    }

    func valueChanged(indexPath: IndexPath, newValue: Int) {
    }
}

private extension VoiceProcessingSettingsViewModel {
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

    func voiceProcessingNotificationHandler(_ notification: GaiaDeviceVoiceProcessingPluginNotification) {
        guard notification.payload.id == device?.id else {
            return
        }

        refresh()
    }
}
