//
//  © 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation
import GaiaCore
import GaiaBase
import PluginBase

class AudioCurationGeneralOptionsViewModel: GaiaTableViewModelProtocol {
    private weak var viewController: GaiaViewControllerProtocol?
    private let coordinator: AppCoordinator
    private let gaiaManager: GaiaManager
    private let notificationCenter: NotificationCenter

    private(set) weak var ncPlugin: GaiaDeviceAudioCurationPluginProtocol?

    private(set) var title: String

    private(set) var sections = [SettingSection] ()
    private(set) var checkmarkIndexPath: IndexPath?

    // Closures

    private var availableOptionsGetter: ((GaiaDeviceAudioCurationPluginProtocol) -> ([String]))?
    private var currentOptionGetter: ((GaiaDeviceAudioCurationPluginProtocol) -> (Int))?
    private var currentOptionSetter: ((GaiaDeviceAudioCurationPluginProtocol, Int) -> ())?

    private var device: GaiaDeviceProtocol? {
        didSet {
            ncPlugin = device?.plugin(featureID: .audioCuration) as? GaiaDeviceAudioCurationPluginProtocol
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

        self.title = String(localized: "Mode", comment: "Settings Screen Title")

        observerTokens.append(notificationCenter.addObserver(forType: GaiaDeviceNotification.self,
                                                             object: nil,
                                                             queue: OperationQueue.main,
                                                             using: { [weak self] notification in self?.deviceNotificationHandler(notification) }))

        observerTokens.append(notificationCenter.addObserver(forType: GaiaManagerNotification.self,
                                                             object: nil,
                                                             queue: OperationQueue.main,
                                                             using: { [weak self] notification in self?.deviceDiscoveryAndConnectionHandler(notification) }))

        observerTokens.append(notificationCenter.addObserver(forType: GaiaDeviceAudioCurationPluginNotification.self,
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

    func injectClosures(title: String,
                        availableOptionsGetter: @escaping (GaiaDeviceAudioCurationPluginProtocol) -> ([String]),
                        currentOptionGetter: @escaping (GaiaDeviceAudioCurationPluginProtocol) -> (Int),
                        currentOptionSetter: @escaping (GaiaDeviceAudioCurationPluginProtocol, Int) -> ()) {
        self.title = title
        self.availableOptionsGetter = availableOptionsGetter
        self.currentOptionGetter = currentOptionGetter
        self.currentOptionSetter = currentOptionSetter
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
}

extension AudioCurationGeneralOptionsViewModel {
    func toggledSwitch(indexPath: IndexPath) {
    }

    func selectedItem(indexPath: IndexPath) {
        guard let ncPlugin = ncPlugin,
            let options = availableOptionsGetter?(ncPlugin),
            indexPath.row < options.count
        else {
            return
        }

        let currentOption = currentOptionGetter?(ncPlugin) ?? 0

        if indexPath.row != currentOption {
            currentOptionSetter?(ncPlugin, indexPath.row)
        }
    }

    func valueChanged(indexPath: IndexPath, newValue: Int) {
        abort()
    }
}

private extension AudioCurationGeneralOptionsViewModel {
    func refresh() {
        guard
            let plugin = ncPlugin,
            let options = availableOptionsGetter?(plugin),
            let currentOption = currentOptionGetter?(plugin)
        else {
            sections = [SettingSection]()
            viewController?.update()
            return
        }

        checkmarkIndexPath = IndexPath(row: currentOption, section: 0)

        var rows = [SettingRow]()

        for option in options {
            let row = SettingRow.title(title: option, tapable: true)
            rows.append(row)
        }


        sections = [SettingSection(title: nil, rows: rows)]

        viewController?.update()
    }
}

private extension AudioCurationGeneralOptionsViewModel {
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

    func noiseCancellationNotificationHandler(_ notification: GaiaDeviceAudioCurationPluginNotification) {
        guard notification.payload.id == device?.id else {
            return
        }

        if notification.reason == .autoTransparencyReleaseTimeChanged {
            refresh()
        }
    }
}

