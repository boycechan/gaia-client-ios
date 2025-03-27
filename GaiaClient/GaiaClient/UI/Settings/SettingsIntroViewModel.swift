//
//  © 2020 - 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation
import GaiaCore
import GaiaBase
import PluginBase

class SettingsIntroViewModel: GaiaTableViewModelProtocol {
    private struct FeatureItem {
        let id: GaiaDeviceQCPluginFeatureID
        let title: String
        let subtitle: String?
    }
    private weak var viewController: GaiaViewControllerProtocol?
    private let coordinator: AppCoordinator
    private let gaiaManager: GaiaManager
    private let notificationCenter: NotificationCenter

    var title: String {
        device?.name ?? ""
    }

    private var featureMap = [FeatureItem] ()
    var sections: [SettingSection] {
        let rows: [SettingRow] = featureMap.map {
            if let subtitle = $0.subtitle {
                return .titleAndSubtitle(title: $0.title,
                                         subtitle: subtitle,
                                         tapable: true)
            } else {
                return .title(title: $0.title,
                              tapable: true)
            }
        }
        let section = SettingSection(title: nil, rows: rows)
        return [section]
    }
    private(set) var checkmarkIndexPath: IndexPath? // Not used here

    private var device: GaiaDeviceProtocol? {
        didSet {
            refresh()
        }
    }

    var userFeatures: [String] {
        if let corePlugin = device?.plugin(featureID: .core) as? GaiaDeviceCorePluginProtocol {
            return corePlugin.userFeatures
        } else {
            return [String]()
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

        observerTokens.append(notificationCenter.addObserver(forType: GaiaDeviceNotification.self,
                                                             object: nil,
                                                             queue: OperationQueue.main,
                                                             using: { [weak self] notification in self?.deviceNotificationHandler(notification) }))

        observerTokens.append(notificationCenter.addObserver(forType: GaiaManagerNotification.self,
                                                             object: nil,
                                                             queue: OperationQueue.main,
                                                             using: { [weak self] notification in self?.deviceDiscoveryAndConnectionHandler(notification) }))

        observerTokens.append(notificationCenter.addObserver(forType: GaiaDeviceUpdaterPluginNotification.self,
                                                             object: nil,
                                                             queue: OperationQueue.main,
                                                             using: { [weak self] notification in self?.deviceUpdateHandler(notification) }))

        observerTokens.append(notificationCenter.addObserver(forType: GaiaDeviceEQPluginNotification.self,
                                                             object: nil,
                                                             queue: OperationQueue.main,
                                                             using: { [weak self] notification in self?.eqStateChangedHandler(notification) }))

        observerTokens.append(notificationCenter.addObserver(forType: GaiaDeviceCorePluginNotification.self,
                                                             object: nil,
                                                             queue: OperationQueue.main,
                                                             using: { [weak self] notification in self?.coreStateChangedHandler(notification) }))

        observerTokens.append(notificationCenter.addObserver(forType: GaiaDeviceAudioCurationPluginNotification.self,
                                                             object: nil,
                                                             queue: OperationQueue.main,
                                                             using: { [weak self] notification in self?.audioCurationStateChangedHandler(notification) }))

        observerTokens.append(notificationCenter.addObserver(forType: GaiaDeviceHandsetPluginNotification.self,
                                                             object: nil,
                                                             queue: OperationQueue.main,
                                                             using: { [weak self] notification in self?.handsetStateChangedHandler(notification) }))
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
        if let supportedFeatureIDs = device?.supportedFeatures {
            featureMap = supportedFeatureIDs.compactMap {
                if let plugin = device?.plugin(featureID: $0),
                   $0 != .earbud,
                   $0 != .battery,
                   $0 != .core {
                    return FeatureItem(id: $0, title: plugin.title, subtitle: plugin.subtitle)
                } else {
                    return nil
                }
            }
        } else {
            featureMap = []
        }
        viewController?.update()
    }
}

extension SettingsIntroViewModel {
    func selectedItem(indexPath: IndexPath) {
        guard indexPath.row < featureMap.count else {
            return
        }

        let feature = featureMap[indexPath.row].id
        coordinator.selectedFeature(feature, device: device!)
    }

    func toggledSwitch(indexPath: IndexPath) {
        abort()
    }

    func valueChanged(indexPath: IndexPath, newValue: Int) {
        abort()
    }

    func startFeedback() {
        guard let device else {
            return
        }
        coordinator.startFeedback(device: device)
    }

    func startLogViewer() {
        guard let device else {
            return
        }
        coordinator.startLogViewer(device: device)
    }
}

private extension SettingsIntroViewModel {
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

    func deviceUpdateHandler(_ notification: GaiaDeviceUpdaterPluginNotification) {
        guard notification.payload.id == device?.id else {
            return
        }
        refresh()
    }

    func eqStateChangedHandler(_ notification: GaiaDeviceEQPluginNotification) {
        guard notification.payload.id == device?.id else {
            return
        }
        refresh()
    }

    func coreStateChangedHandler(_ notification: GaiaDeviceCorePluginNotification) {
        guard case let .device(deviceIdentification) = notification.payload else {
            return
        }
        
        if deviceIdentification.id == device?.id &&
           notification.reason == .userFeaturesComplete {
            refresh()
        }
    }

    func handsetStateChangedHandler(_ notification: GaiaDeviceHandsetPluginNotification) {
        guard notification.payload.id == device?.id else {
            return
        }
        refresh()
    }

    func audioCurationStateChangedHandler(_ notification: GaiaDeviceAudioCurationPluginNotification) {
        guard notification.payload.id == device?.id else {
            return
        }

        if notification.reason == .enabledChanged {
            refresh()
        }
    }
}
