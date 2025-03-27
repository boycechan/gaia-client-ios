//
//  © 2020 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import UIKit

extension UIColor {
    func backgroundImage(size: CGSize)-> UIImage {
        guard size != CGSize.zero else {
            return UIImage()
        }

        return UIGraphicsImageRenderer(size: size).image { (context) in
            setFill()
            let rect = CGRect(origin: CGPoint.zero, size: size)
            UIRectFill(rect)
        }
    }
}

extension UIButton {
    func setBackground(active: Bool) {
        let color = active ? UIColor.systemGray4 : UIColor.systemGray6
        let backgroundImage = color.backgroundImage(size: bounds.size)
        setBackgroundImage(backgroundImage, for: .normal)
    }
}
