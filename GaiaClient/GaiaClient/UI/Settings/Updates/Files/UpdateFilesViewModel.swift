//
//  © 2020 - 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import UIKit
import GaiaCore
import GaiaBase
import PluginBase

class UpdateFilesViewModel: GaiaTableViewModelProtocol {
    private weak var viewController: GaiaViewControllerProtocol?
    private let coordinator: AppCoordinator
    private let gaiaManager: GaiaManager
    private let notificationCenter: NotificationCenter

    private(set) weak var updatesPlugin: GaiaDeviceUpdaterPluginProtocol?

    let fileProvider = GaiaDocumentsFileProvider()
    let fileBrowserProvider = GaiaFileBrowserFileProvider()

    private(set) var title: String

    private var files = [UpdateEntry] ()
    var sections: [SettingSection] {
        let rows = files.map {
            return SettingRow.title(title: $0.title , tapable: true)
        }
        let section = SettingSection(title: nil, rows: rows)
        return [section]
    }
    private(set) var checkmarkIndexPath: IndexPath? // Not used here

    private var device: GaiaDeviceProtocol? {
        didSet {
            updatesPlugin = device?.plugin(featureID: .upgrade) as? GaiaDeviceUpdaterPluginProtocol
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

        self.title = String(localized: "Available Updates", comment: "Settings Screen Title")

        observerTokens.append(notificationCenter.addObserver(forType: GaiaDeviceNotification.self,
                                                             object: nil,
                                                             queue: OperationQueue.main,
                                                             using: { [weak self] notification in self?.deviceNotificationHandler(notification) }))

        observerTokens.append(notificationCenter.addObserver(forType: GaiaManagerNotification.self,
                                                             object: nil,
                                                             queue: OperationQueue.main,
                                                             using: { [weak self] notification in self?.deviceDiscoveryAndConnectionHandler(notification) }))

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
        fileProvider.availableUpdates { items in
            self.files = items
            self.viewController?.update()
        }
    }
}

extension UpdateFilesViewModel {
    func validateUpdateFile(data: Data) throws {
        if data.count == 0 {
            let reasonStr = String(localized: "File has no contents.", comment: "General error reason")
            let error = NSError(domain: "com.qualcomm.qti.gaiaclient", code: 0, userInfo: [NSLocalizedDescriptionKey : reasonStr])
            throw error
        }
    }
}

extension UpdateFilesViewModel {
    func showFileBrowser() {
        guard let viewController = viewController else {
            return
        }
        fileBrowserProvider.showPicker(viewController: viewController,
                                       completion:
                                        { [weak self] result in
                                            guard let self = self else {
                                                return
                                            }

                                            switch result {
                                            case .success(let bundle):
                                                do {
                                                    try self.validateUpdateFile(data: bundle.data)
                                                    self.coordinator.selectedUpdateFile(bundle.data, device: self.device!, info: bundle.info)
                                                } catch {
                                                    self.coordinator.fileSelectionError(error: error)
                                                }
                                            case .failure(let error):
                                                self.coordinator.fileSelectionError(error: error)
                                            }
                                        },
                                       cancellation: { })
    }
}

extension UpdateFilesViewModel {
    func selectedItem(indexPath: IndexPath) {
        guard indexPath.row < files.count else {
            return
        }

        let entry = files[indexPath.row]
        fileProvider.dataForUpdateEntry(entry,
                                        completion:
                                            { result in
                                                switch result {
                                                case .success(let bundle):
                                                    do {
                                                        try self.validateUpdateFile(data: bundle.data)
                                                        self.coordinator.selectedUpdateFile(bundle.data, device: self.device!, info: bundle.info)
                                                    } catch {
                                                        self.coordinator.fileSelectionError(error: error)
                                                    }
                                                case .failure(let error):
                                                    self.coordinator.fileSelectionError(error: error)
                                                }
                                            },
                                        cancellation: {})

    }

    func toggledSwitch(indexPath: IndexPath) {
        abort()
    }
    
    func valueChanged(indexPath: IndexPath, newValue: Int) {
        abort()
    }
}

private extension UpdateFilesViewModel {
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
}
