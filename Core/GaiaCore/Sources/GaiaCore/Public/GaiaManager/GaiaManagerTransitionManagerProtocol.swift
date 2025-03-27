//
//  © 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation
import GaiaBase

/// An object conforming to  GaiaManagerTransitionManagerProtocol is used by GaiaManager to handle specific device lifecycle
/// events (for example handover or DFU restart) often where a disconnection event maybe resonably expected. They are device instance
/// specific and handle such things as timeouts or the restart of a DFU after a reconnection.
protocol GaiaManagerTransitionManagerProtocol {

	/// Create a transition manager instance for a given GAIA device.
	/// - Parameters:
    ///		- device: The GAIA device that may undergo the lifecycle transition that this transition manager handles.
    /// 	- connectionFactory: The connection factory instance that is currently in use the application.
    ///     - notificationCenter: The notification center to be used when sending or listening for notifications.
    init(device: GaiaDeviceProtocol,
         connectionFactory: GaiaConnectionFactory,
         notificationCenter: NotificationCenter)

    /// Used to notify the transition manager that a device has been disconnected.
    ///	- Parameter device: The device that has been disconnected. This may not be the one for which the transition manager was created.
    func deviceDisconnected(_ device: GaiaDeviceProtocol)

    /// Used to notify the transition manager that a device has been connected.
    ///	- Parameter device: The device that has been disconnected. This may not be the one for which the transition manager was created.
    func deviceConnected(_ device: GaiaDeviceProtocol)

    /// Used to notify the transition manager that a device's state property has changed.
    ///	- Parameter device: The device that has been disconnected. This may not be the one for which the transition manager was created.
    func deviceStateChanged(_ device: GaiaDeviceProtocol)
}
