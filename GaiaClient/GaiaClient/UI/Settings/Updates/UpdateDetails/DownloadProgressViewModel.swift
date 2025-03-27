//
//  © 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation
import GaiaBase
import GaiaCore

protocol DownloadProgressViewModelDelegate: AnyObject {
    func didFinishDownloadAndRequestDFU(data: Data)
}

class DownloadProgressViewModel: GaiaDeviceViewModelProtocol {
    enum State {
        case waiting
        case starting
        case transferring(percent: Double)
        case failed(reason: String)
        case aborting
        case aborted
        case completed(data: Data)
    }

    private weak var viewController: GaiaViewControllerProtocol?
    private let coordinator: AppCoordinator
    private let gaiaManager: GaiaManager
    private unowned let notificationCenter: NotificationCenter

    weak var delegate: DownloadProgressViewModelDelegate?

    var title: String

    private var device: GaiaDeviceProtocol?

    private var observerTokens = [ObserverToken]()

    private(set) var state = State.waiting {
        didSet {
            self.refresh()
        }
    }

    private var fetchTask: Task<Data, Error>?

    required init(viewController: GaiaViewControllerProtocol,
                  coordinator: AppCoordinator,
                  gaiaManager: GaiaManager,
                  notificationCenter: NotificationCenter) {
        self.viewController = viewController
        self.coordinator = coordinator
        self.gaiaManager = gaiaManager
        self.notificationCenter = notificationCenter

        self.title = String(localized: "Download Progress", comment: "Progress Screen Title")

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

    func injectDownloadID(_ id: String) {
        fetchTask = Task {
            return try await RemoteDFUServer.shared.fetchUpdate(id: id, progress: self.updateProgress)
        }

        state = .starting
        Task {
            do {
                let data = try await fetchTask!.value
                DispatchQueue.main.async { [weak self] in
                    guard
                        let self = self
                    else {
                        return
                    }
                    self.state = .completed(data: data)
                }
            } catch let error as RemoteServerError  {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    if error == .aborted {
                        self.state = .aborted
                    } else {
                        switch error {
                        case .configuration:
                            self.state = .failed(reason: String(localized: "", comment: "Updates Fetch Error"))
                        case .connectivity:
                            self.state = .failed(reason: String(localized: "Cannot reach server.", comment: "Updates Fetch Error"))
                        case .errorResponse(let errorResponse):
                            self.state = .failed(reason: errorResponse.userVisibleDescriptionConcise())
                        case .aborted:
                            self.state = .failed(reason: String(localized: "Cancelled.", comment: "Updates Fetch Error"))
                        case .format:
                            self.state = .failed(reason: String(localized: "Unexpected Response.", comment: "Updates Fetch Error"))
                        }
                    }
                }
            }
        }
    }

    func updateProgress(downloaded: Int, expected: Int) {
        switch state {
        case .aborting:
            return
        default:
            state = .transferring(percent: Double(downloaded)/Double(expected) * 100.0)
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

extension DownloadProgressViewModel {
    func abortRequested() {
        fetchTask?.cancel()
        state = .aborting
    }

    func upgradeRequested() {
        switch state {
        case .completed(data: let data):
            delegate?.didFinishDownloadAndRequestDFU(data: data)
        default:
            break
        }
    }
}

private extension DownloadProgressViewModel {
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
            refresh()
        case .poweredOn:
            refresh()
        case .dfuReconnectTimeout:
            refresh()
        }
    }
}



