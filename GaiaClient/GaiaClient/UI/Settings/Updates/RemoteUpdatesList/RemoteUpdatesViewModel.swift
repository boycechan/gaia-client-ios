//
//  © 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import UIKit
import GaiaCore
import GaiaBase
import PluginBase
import GaiaLogger

class RemoteUpdatesViewModel: GaiaDeviceViewModelProtocol {
    enum OverlayState {
        case hidden
        case fetching
        case noUpdates
        case error(message: String)
    }
    private weak var viewController: GaiaViewControllerProtocol?
    private let coordinator: AppCoordinator
    private let gaiaManager: GaiaManager
    private let notificationCenter: NotificationCenter

    private var observerToken: ObserverToken?

    private(set) var title: String
    private(set) var overlay: OverlayState = .hidden {
        didSet {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.refresh()
            }
        }
    }
    
    private(set) var updates = [UpdateEntry] ()

    private var buildID = ""
    private var appID = ""
    private var hardwareId = ""

    private var device: GaiaDeviceProtocol?

    required init(viewController: GaiaViewControllerProtocol,
                  coordinator: AppCoordinator,
                  gaiaManager: GaiaManager,
                  notificationCenter: NotificationCenter) {
        self.viewController = viewController
        self.coordinator = coordinator
        self.gaiaManager = gaiaManager
        self.notificationCenter = notificationCenter

        self.title = String(localized: "Updates", comment: "Remote Updates Screen Title")

        observerToken = notificationCenter.addObserver(forType: GaiaManagerNotification.self,
                                                        object: nil,
                                                        queue: OperationQueue.main,
                                                        using: { [weak self] notification in self?.deviceDiscoveryAndConnectionHandler(notification) })
    }

    deinit {
        notificationCenter.removeObserver(observerToken!)
    }

    func injectDevice(device: GaiaDeviceProtocol?) {
        self.device = device
        let corePlugin = device?.plugin(featureID: .core) as? GaiaDeviceCorePluginProtocol
        appID = corePlugin?.applicationVersion ?? ""
        buildID = corePlugin?.applicationBuildID ?? ""
    }

    func injectHardwareId(_ id: String) {
        self.hardwareId = id
        fetchUpdates()
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

    func fetchUpdates() {
        overlay = .fetching
        Task {
            do {
                updates = try await RemoteDFUServer.shared.checkForUpdatesNow(buildId:buildID, appId: appID, hardwareId: hardwareId)

                overlay = updates.count > 0 ? .hidden : .noUpdates
            } catch let error as RemoteServerError {
                switch error {
                case .configuration:
                    overlay = .error(message: String(localized: "Incorrect Configuration", comment: "Updates Fetch Error"))
                case .connectivity:
                    overlay = .error(message: String(localized: "Cannot reach server or timed out.", comment: "Updates Fetch Error"))
                case .errorResponse(let errorResponse):
                    overlay = .error(message: errorResponse.userVisibleDescription())
                case .aborted:
                    overlay = .error(message: String(localized: "Cancelled", comment: "Updates Fetch Error"))
                case .format:
                    overlay = .error(message: String(localized: "Invalid Format", comment: "Updates Fetch Error"))
                }
            } catch {
                overlay = .error(message: String(localized: "Error fetching updates", comment: "Updates Fetch Error"))
            }
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.refresh()
            }
        }
    }
}

extension RemoteUpdatesViewModel {
    func didSelect(info: UpdateEntry) {

        guard
            let device = device
        else {
            return
        }
        coordinator.showRemoteUpdateDetailRequested(device: device, info: info)
    }
}

private extension RemoteUpdatesViewModel {
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
