//
//  © 2023 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation
import GaiaCore
import GaiaBase
import PluginBase

class TagsEditViewModel: GaiaDeviceViewModelProtocol {
    internal enum TagType {
        case required
        case excluded
    }

    private weak var viewController: GaiaViewControllerProtocol?
    private let coordinator: AppCoordinator
    private let gaiaManager: GaiaManager
    private let notificationCenter: NotificationCenter

    private(set) weak var updatesPlugin: GaiaDeviceUpdaterPluginProtocol?

    private(set) var title: String = ""

    private var device: GaiaDeviceProtocol?

    private(set) var tagType: TagType = .required

    private var observerTokens = [ObserverToken]()

    var filters: [RemoteDFUServer.PropertyFilter] {
        return RemoteDFUServer.shared.filters.compactMap({
            switch $0 {
            case .property(let propertyFilter):
                if tagType == .required && propertyFilter.state != .excluded {
                    return propertyFilter
                }
                if tagType == .excluded && propertyFilter.state != .required {
                    return propertyFilter
                }
            default:
                break
            }
            return nil
        })
    }

    required init(viewController: GaiaViewControllerProtocol,
                  coordinator: AppCoordinator,
                  gaiaManager: GaiaManager,
                  notificationCenter: NotificationCenter) {
        self.viewController = viewController
        self.coordinator = coordinator
        self.gaiaManager = gaiaManager
        self.notificationCenter = notificationCenter
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

    func injectTagType(tagType: TagType) {
        self.tagType = tagType
        switch tagType {
        case .required:
            self.title = String(localized: "Required Tags", comment: "Settings Screen Title")
        case .excluded:
            self.title = String(localized: "Excluded Tags", comment: "Settings Screen Title")
        }
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

extension TagsEditViewModel {
    func didToggleFilter(at indexPath: IndexPath) {
        let filter = filters[indexPath.row]
        let includedState: RemoteDFUServer.FilterState = tagType == .required ? .required : .excluded
        let newState: RemoteDFUServer.FilterState = filter.state == .none ? includedState : .none
        let newFilters: [RemoteDFUServer.Filter] = RemoteDFUServer.shared.filters.map({
            switch $0 {
            case .property(let propertyFilter):
                if propertyFilter.id == filter.id {
                    let newPropertyFilter = RemoteDFUServer.PropertyFilter(id: propertyFilter.id,
                                                                           description: propertyFilter.description,
                                                                           state: newState)
                    return .property(newPropertyFilter)
                } else {
                    return $0
                }
            default:
                return $0
            }
        })
        RemoteDFUServer.shared.filters = newFilters
        if let vc = viewController as? TagsEditViewController {
            vc.updateRow(indexPath: indexPath)
        } else {
            refresh()
        }
    }
}
