//
//  © 2020 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import UIKit

@IBDesignable class EQSliderView: UIView {

    let slider = NotchedSlider()

    private let sliderWidth: CGFloat = 32.0
    private let label = UILabel()

    let formatter = NumberFormatter()

    var frequency: Int = 1000 {
        didSet {
            if frequency > 999 {
                let thousands = Double(frequency)/1000.0
                let numStr = formatter.string(from: NSNumber(value: thousands)) ?? "?"
                label.text = numStr + "K"
            } else {
                label.text = String(frequency)
            }
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

    private func setUp() {
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 1

        frequency = 1600
        label.textColor = UIColor.label
        label.font = UIFont.preferredFont(forTextStyle: .subheadline)
        label.adjustsFontForContentSizeCategory = true

        slider.transform = CGAffineTransform(rotationAngle: -CGFloat(Double.pi / 2.0))/*.scaledBy(x: 1, y: -1)*/
        slider.isContinuous = false // Gaia can't handle continuous updates.
        slider.minimumValue = -12.0
        slider.maximumValue = 3.0
        slider.value = 0
        slider.maximumTrackTintColor = UIColor.systemGray

        addSubview(slider)
        addSubview(label)
    }

    override open func layoutSubviews() {
        super.layoutSubviews()

        if bounds.height > 40.0 && bounds.width > 33.0 {
            slider.frame = CGRect(x: (bounds.width - sliderWidth)/2, y: 0, width: sliderWidth, height: bounds.height - 25.0)
            slider.setNeedsDisplay()
        } else {
            slider.frame = CGRect.zero
        }

		label.sizeToFit()
        label.center.x = bounds.midX
        label.center.y = bounds.height - label.bounds.midY
    }
}
