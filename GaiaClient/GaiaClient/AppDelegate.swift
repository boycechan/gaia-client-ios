//
//  © 2020 - 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import UIKit
import GaiaCore
import GaiaLogger
import OSLog



@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    private var coordinator: AppCoordinator?
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Register vendor specific extensions

        /*
		// How to register vendor specific extension with different Vendor ID

        VendorExtensionManager.shared.register { (device, connection, notificationCenter) -> GaiaDeviceVendorExtensionProtocol in
            return ExampleVendorExtension(device: device, connection: connection, notificationCenter: notificationCenter)
        }

 		*/

        // Example of setting up log handler for GaiaCore library
        GaiaLogger.shared.registerHandler(DefaultLogger())
        GaiaLogger.shared.logLevel = .medium

        window = UIWindow(frame: UIScreen.main.bounds)
        Theming.applyGlobalTheming(window: window!)

        initializeStack()
        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        coordinator?.didBecomeActive()
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        coordinator?.didEnterBackground()
    }
}

private extension AppDelegate {
    func initializeStack() {
        let cFactory = GaiaConnectionFactory(kinds: [.ble, .iap2], notificationCenter: NotificationCenter.default)
        let gaiaManager = GaiaManager(connectionFactory: cFactory, notificationCenter: NotificationCenter.default)
        
        coordinator = AppCoordinator(window: window!,
                                     gaiaManager: gaiaManager,
                                     notificationCenter: NotificationCenter.default)

        coordinator?.onLaunch()
    }
}

