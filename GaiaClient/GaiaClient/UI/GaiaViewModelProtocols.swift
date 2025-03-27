//
//  © 2020 - 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import UIKit
import GaiaCore
import GaiaBase

/// Base protocol that all view models conform to - either directly or via a child protocol.
protocol GaiaViewModelProtocol: AnyObject {
    /// The title to be shown onscreen usually in a navigation bar.
    var title: String { get }

    // Initializer
    init(viewController: GaiaViewControllerProtocol,
         coordinator: AppCoordinator,
         gaiaManager: GaiaManager,
         notificationCenter: NotificationCenter)

    /// Method to be called when the UI will appear on screen.
    func activate()

    /// Method to be called when the UI will disappear from screen.
    func deactivate()
}

/// Protocol that view models that deal with a specific device almost all conform to. Allows injection of the current selected device into the entire UI stack
protocol GaiaDeviceViewModelProtocol: GaiaViewModelProtocol {
    func injectDevice(device: GaiaDeviceProtocol?)
    func isDeviceConnected() -> Bool
}

/// Protocol adopted by view models that show lists of selectable options.
protocol GaiaTableViewModelProtocol: GaiaDeviceViewModelProtocol {
    /// The sections shown in the table
    var sections : [SettingSection] { get }

    /// The indexpath of the option to be shown with a checkmark. This is not used by all view models that conform to this protocol
    var checkmarkIndexPath: IndexPath? { get }

    /// Used when the user has toggled a switch in the UI
    /// - Parameter indexPath: The row in the tableview containing the toggled switch
    func toggledSwitch(indexPath: IndexPath)

    /// Used when the user has selected a row in the UI
    /// - Parameter indexPath: The row in the tableview that was selected
    func selectedItem(indexPath: IndexPath)

    /// Used when the user has changed a value in the UI - for example with a slider.
    /// - Parameter indexPath: The row in the tableview that corresponds to the changed value
    /// - Parameter newValue: The changed value
    func valueChanged(indexPath: IndexPath, newValue: Int)
}

