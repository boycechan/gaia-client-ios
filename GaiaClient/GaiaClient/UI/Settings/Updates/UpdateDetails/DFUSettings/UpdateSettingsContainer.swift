//
//  © 2023 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation
import GaiaCore
import GaiaBase
import PluginBase

class UpdateSettingsContainer {
    static let shared = UpdateSettingsContainer(notificationCenter: NotificationCenter.default)
    let notificationCenter: NotificationCenter

    var settings: UpdateTransportOptions?

    private var observerTokens = [ObserverToken]()

    init(notificationCenter: NotificationCenter) {
            self.notificationCenter = notificationCenter
            observerTokens.append(notificationCenter.addObserver(forType: GaiaDeviceUpdaterPluginNotification.self,
                                                                 object: nil,
                                                                 queue: OperationQueue.main,
                                                                 using: { [weak self] notification in self?.deviceUpdaterNotificationHandler(notification) }))
    }

    var device: GaiaDeviceProtocol? {
        didSet {
            setUpDefaults()
        }
    }

    func setUpDefaults() {
        if let updatesPlugin = device?.plugin(featureID: .upgrade) as? GaiaDeviceUpdaterPluginProtocol {
            let transportCaps = updatesPlugin.transportCapabilities
            switch transportCaps {
            case .iap2(let lengthExtensionAvailable, _, let optimumMessageSize):
                settings = .iap2(useDLE: lengthExtensionAvailable,
                                 requestedMessageSize: optimumMessageSize,
                                 expectACKs: true)




            case .ble(let lengthExtensionAvailable, let rwcpAvailable, _, let optimumMessageSize):
                settings = rwcpAvailable ?
                    .bleRWCP(useDLE: lengthExtensionAvailable,
                             requestedMessageSize: optimumMessageSize,
                             initialWindowSize: UpdateTransportOptions.Constants.rwcpInitialWindowSize,
                             maxWindowSize: UpdateTransportOptions.Constants.rwcpMaxWindow)
                :
                    .ble(useDLE: lengthExtensionAvailable,
                         requestedMessageSize: optimumMessageSize)

            case .none:
                settings = nil
            }
        } else {
            settings = nil
        }
    }

    func deviceUpdaterNotificationHandler(_ note: GaiaDeviceUpdaterPluginNotification) {
        if note.reason == .ready {
            setUpDefaults()
        }
    }
}
