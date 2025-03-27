//
//  © 2019-2020 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import UIKit

extension UIImage {
    static func image(batteryLevel: Int) -> UIImage {
        switch batteryLevel {
        case 95...Int.max:
            return UIImage(named: "ic_battery_full")?.withRenderingMode(.alwaysTemplate) ?? UIImage()
        case 85..<95:
            return UIImage(named: "ic_battery_90")?.withRenderingMode(.alwaysTemplate) ?? UIImage()
        case 70..<85:
            return UIImage(named: "ic_battery_80")?.withRenderingMode(.alwaysTemplate) ?? UIImage()
        case 55..<70:
            return UIImage(named: "ic_battery_60")?.withRenderingMode(.alwaysTemplate) ?? UIImage()
        case 40..<55:
            return UIImage(named: "ic_battery_50")?.withRenderingMode(.alwaysTemplate) ?? UIImage()
        case 25..<40:
            return UIImage(named: "ic_battery_30")?.withRenderingMode(.alwaysTemplate) ?? UIImage()
        case 10..<25:
            return UIImage(named: "ic_battery_20")?.withRenderingMode(.alwaysTemplate) ?? UIImage()
        case 5..<10:
            return UIImage(named: "ic_battery_05")?.withRenderingMode(.alwaysTemplate) ?? UIImage()
        default:
            return UIImage(named: "ic_battery_00")?.withRenderingMode(.alwaysTemplate) ?? UIImage()
        }
    }

    static func image(signalRSSI: Int) -> UIImage {
        switch signalRSSI {
        case Int.min ..< -90:
            return UIImage(named: "ic_signal_0")?.withRenderingMode(.alwaysTemplate) ?? UIImage()
        case -90 ..< -80:
            return UIImage(named: "ic_signal_1")?.withRenderingMode(.alwaysTemplate) ?? UIImage()
        case -80 ..< -70:
            return UIImage(named: "ic_signal_2")?.withRenderingMode(.alwaysTemplate) ?? UIImage()
        case -70 ..< -60:
            return UIImage(named: "ic_signal_3")?.withRenderingMode(.alwaysTemplate) ?? UIImage()
        case -60 ..< 0:
            return UIImage(named: "ic_signal_4")?.withRenderingMode(.alwaysTemplate) ?? UIImage()
        default:
            return UIImage(named: "ic_signal_unknown")?.withRenderingMode(.alwaysTemplate) ?? UIImage()
        }
    }
}

extension UIImageView {
    func setImage(batteryLevel: Int) {
        image = UIImage.image(batteryLevel: batteryLevel)
    }

    func setImage(signalRSSI: Int) {
        image = UIImage.image(signalRSSI: signalRSSI)
    }
}
