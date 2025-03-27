//
//  © 2020 - 2022  Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation
import GaiaCore
import GaiaBase
import PluginBase

class EQSettingsViewModel: GaiaDeviceViewModelProtocol {
	private let maxBands = 7 // Maximum number of bands shown in UI

    private weak var viewController: GaiaViewControllerProtocol?
    private let coordinator: AppCoordinator
    private let gaiaManager: GaiaManager
    private let notificationCenter: NotificationCenter

    private(set) weak var eqPlugin: GaiaDeviceEQPluginProtocol?

    private(set) var title: String

    var eqEnabled: Bool { eqPlugin?.eqEnabled ?? false }
    var presets: [EQPresetInfo] {
        if let eqPlugin = eqPlugin {
            return eqPlugin.availablePresets.map({ return EQPresetInfo(byteValue: $0.byteValue) })
        } else {

        }
        return [EQPresetInfo]()
    }

    var selectedPreset: Int {
        eqPlugin?.currentPresetIndex ?? -1
    }

    var userBands: [EQUserBandInfo] {
        eqPlugin?.userBands ?? [EQUserBandInfo] ()
    }

    private var device: GaiaDeviceProtocol? {
        didSet {
            eqPlugin = device?.plugin(featureID: .eq) as? GaiaDeviceEQPluginProtocol
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

        self.title = String(localized: "Equalizer", comment: "Settings Screen Title")

        observerTokens.append(notificationCenter.addObserver(forType: GaiaDeviceNotification.self,
                                                             object: nil,
                                                             queue: OperationQueue.main,
                                                             using: { [weak self] notification in self?.deviceNotificationHandler(notification) }))

        observerTokens.append(notificationCenter.addObserver(forType: GaiaManagerNotification.self,
                                                             object: nil,
                                                             queue: OperationQueue.main,
                                                             using: { [weak self] notification in self?.deviceDiscoveryAndConnectionHandler(notification) }))

        observerTokens.append(notificationCenter.addObserver(forType: GaiaDeviceEQPluginNotification.self,
                                                             object: nil,
                                                             queue: OperationQueue.main,
                                                             using: { [weak self] notification in self?.eqNotificationHandler(notification) }))
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
        viewController?.update()
    }
}

extension EQSettingsViewModel {
    func changedUserBand(band: Int, gain: Double) {
        eqPlugin?.setUserBand(index: band, gain: gain)
    }

    func changedPreset(index: Int) {
        eqPlugin?.setCurrentPresetIndex(index)
    }

    func resetAllBandsToZeroGain() {
        eqPlugin?.resetAllBandsToZeroGain()
    }
}

private extension EQSettingsViewModel {
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

    func eqNotificationHandler(_ notification: GaiaDeviceEQPluginNotification) {
        guard notification.payload.id == device?.id else {
            return
        }

        refresh()
    }
}
