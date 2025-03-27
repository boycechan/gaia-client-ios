//
//  © 2020 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//
import UIKit

enum Theming {
    static func applyGlobalTheming(window: UIWindow) {
        UISwitch.appearance().onTintColor = regularButtonColor()

        let bannerBackground = UIColor(named: "color-bannerBackground")
        let bannerTint = UIColor(named: "color-bannerTint") ?? UIColor.white

        let backButtonAppearance = UIBarButtonItemAppearance(style: .plain)
        backButtonAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.clear]
        backButtonAppearance.highlighted.titleTextAttributes = [.foregroundColor: UIColor.clear]

        UIBarButtonItem.appearance(whenContainedInInstancesOf: [UINavigationBar.self]).tintColor = bannerTint // Back arrow white

        let navBarAppearance = UINavigationBarAppearance()
        navBarAppearance.configureWithOpaqueBackground()
        navBarAppearance.backgroundColor = bannerBackground
        navBarAppearance.setBackIndicatorImage(UIImage(named: "icon-appbar-back"), transitionMaskImage: UIImage(named: "icon-appbar-back"))
        navBarAppearance.backButtonAppearance = backButtonAppearance
        navBarAppearance.titleTextAttributes = [
            NSAttributedString.Key.foregroundColor: bannerTint
        ]
        UINavigationBar.appearance().standardAppearance = navBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navBarAppearance

        UIButton.appearance(whenContainedInInstancesOf: [UINavigationBar.self]).tintColor = bannerTint

        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = bannerBackground

        let tabBarItemAppearance = UITabBarItemAppearance()
        tabBarItemAppearance.normal.iconColor = UIColor(named: "color-tabBarUnselectedItem")
        tabBarItemAppearance.selected.iconColor = bannerTint

        tabBarAppearance.stackedLayoutAppearance = tabBarItemAppearance
        tabBarAppearance.inlineLayoutAppearance = tabBarItemAppearance
        tabBarAppearance.compactInlineLayoutAppearance = tabBarItemAppearance

        UITabBar.appearance().standardAppearance = tabBarAppearance
        if #available(iOS 15.0, *) {
        	UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        }

        // Fix up the doc picker

        let standardTabBarAppearance = UITabBarAppearance()
        UITabBar.appearance(whenContainedInInstancesOf: [UIDocumentBrowserViewController.self]).standardAppearance = standardTabBarAppearance
    }

    static func navBarAppImage() -> UIImage? {
        return UIImage(named: "navBarImage")
    }

    static func regularButtonColor() -> UIColor? {
        return UIColor(named: "color-buttonText")
    }

    static func destructiveButtonColor() -> UIColor? {
		return UIColor(named: "color-btn-destructive")
    }

    static func affirmativeButtonColor() -> UIColor? {
        return UIColor(named: "color-btn-affirmative")
    }

    static func dialColor1() -> UIColor? {
        return UIColor(named: "color-dial-blue")
    }
    
    static func dialColor2() -> UIColor? {
        return UIColor(named: "color-dial-teal")
    }
}
