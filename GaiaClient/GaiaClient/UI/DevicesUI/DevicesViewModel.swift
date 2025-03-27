//
//  © 2020 - 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import UIKit
import GaiaCore
import GaiaBase
import GaiaLogger

class DevicesViewModel: GaiaViewModelProtocol {
    private weak var viewController: GaiaViewControllerProtocol?
    private let coordinator: AppCoordinator
    private let gaiaManager: GaiaManager
    private let notificationCenter: NotificationCenter

    private var observerToken: ObserverToken?

    private(set) var title: String
    private(set) var devices = [GaiaDeviceProtocol] ()


    required init(viewController: GaiaViewControllerProtocol,
                  coordinator: AppCoordinator,
                  gaiaManager: GaiaManager,
                  notificationCenter: NotificationCenter) {
        self.viewController = viewController
        self.coordinator = coordinator
        self.gaiaManager = gaiaManager
        self.notificationCenter = notificationCenter
        
        self.title = String(localized: "Select a Device", comment: "Devices Screen Title")

        observerToken = notificationCenter.addObserver(forType: GaiaManagerNotification.self,
                                                        object: nil,
                                                        queue: OperationQueue.main,
                                                        using: { [weak self] notification in self?.deviceDiscoveryAndConnectionHandler(notification) })
    }

    deinit {
        notificationCenter.removeObserver(observerToken!)
    }

    func activate() {
        if gaiaManager.isAvailable {
            gaiaManager.stopScanning()
            gaiaManager.clearDeviceList()
        	gaiaManager.startScanning()
        } else {
            LOG(.medium, "Cannot start scanning")
        }
        refresh()
    }

    func deactivate() {
        devices = []
        gaiaManager.stopScanning()
    }

    func refresh() {
        devices = gaiaManager.devices
        viewController?.update()
    }
}

extension DevicesViewModel {
    func connect(_ device: GaiaDeviceProtocol) {
        gaiaManager.start(device: device)
    }

    func selected(_ device: GaiaDeviceProtocol) {
        coordinator.onSelectDevice(device)
    }

    func rescan() {
        if gaiaManager.isScanning {
        	gaiaManager.stopScanning()
        }
        if gaiaManager.isAvailable {
            gaiaManager.clearDeviceList()
            gaiaManager.startScanning()
        }
        refresh()
    }
}

private extension DevicesViewModel {
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
}
