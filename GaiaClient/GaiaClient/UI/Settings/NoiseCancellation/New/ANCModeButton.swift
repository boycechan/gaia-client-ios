//
//  © 2020 - 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import UIKit

@IBDesignable
class ANCModeButton: UIButton {
    @IBInspectable
    var roundCorners: Bool = false {
        didSet {
            layer.cornerRadius = roundCorners ? 10.0 : 0.0
            layer.masksToBounds = roundCorners
        }
    }

    @IBInspectable
    var activeColor: UIColor = UIColor.systemGray4 {
        didSet {
            updateBackgroundImage()
        }
    }

    @IBInspectable
    var inactiveColor: UIColor = UIColor.systemGray6 {
        didSet {
            updateBackgroundImage()
        }
    }

    @IBInspectable
    var activeBubbleColor: UIColor = UIColor.systemGray2 {
        didSet {
            updateBackgroundImage()
        }
    }

    @IBInspectable
    var inactiveBubbleColor: UIColor = UIColor.systemGray4 {
        didSet {
            updateBackgroundImage()
        }
    }

    @IBInspectable
    var active: Bool = false {
        didSet {
            updateBackgroundImage()
        }
    }

    @IBInspectable
    var bubbleText: String = "" {
        didSet {
            updateBackgroundImage()
        }
    }

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setUp()
    }

    required override public init(frame: CGRect) {
        super.init(frame: frame)
        setUp()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        updateBackgroundImage()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        var labelRect = bounds.inset(by: UIEdgeInsets(top: bubbleText.count > 0 ? 46 : 8, left: 8, bottom: 8, right: 8))
        if let fitSize = titleLabel?.sizeThatFits(labelRect.size) {
            labelRect.size.width = fitSize.width
            labelRect.size.height = min(fitSize.height, labelRect.size.height)
        }
        titleLabel?.frame = labelRect
    }

    func setUp() {
        updateBackgroundImage()
        titleLabel?.textAlignment = .left
        titleLabel?.numberOfLines = 0
    }

    func updateBackgroundImage() {
        let textColor = active ? UIColor.white : UIColor.label
        setTitleColor(textColor, for: .normal)
        setTitleColor(textColor, for: .highlighted)
        setTitleColor(textColor, for: .selected)
        
        let color = active ? activeColor : inactiveColor
        let image = UIGraphicsImageRenderer(size: bounds.size).image { (context) in
            color.setFill()
            UIRectFill(bounds)

            if bubbleText.count > 0 {
                // Draw a bubble
				let bubbleColor = active ? activeBubbleColor : inactiveBubbleColor
                bubbleColor.setFill()
                let rect = CGRect(x: 8, y: 8, width: 28, height: 28)
                context.cgContext.addEllipse(in: rect)
                context.cgContext.drawPath(using: .fill)

                let font = UIFont.preferredFont(forTextStyle: .headline)
                let attributes: [NSAttributedString.Key : Any] = [.font: font, .foregroundColor: UIColor.white]

                let nsText = bubbleText as NSString
                let size = nsText.size(withAttributes: attributes)

                // Position in bubble
                let x = floor(rect.midX - (size.width / 2.0))
                let y = floor(rect.midY - (size.height / 2.0))
                (bubbleText as NSString).draw(in: CGRect(x: x, y: y, width: size.width, height: size.height),
                                              withAttributes: attributes)
            }
        }

        setBackgroundImage(image, for: .normal)
        setBackgroundImage(image, for: .highlighted)
        setBackgroundImage(image, for: .selected)
    }
}
