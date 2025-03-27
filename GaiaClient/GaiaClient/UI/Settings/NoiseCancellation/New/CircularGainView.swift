//
//  © 2021 - 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import UIKit

@IBDesignable
class CircularGainView: UIView {
    @IBInspectable
    var gain: UInt8 {
        set {
            progressView.progress = Float(newValue) / 255.0
            valueLabel.text = "\(newValue)"
            setNeedsLayout()
            setNeedsDisplay()
        }

        get {
            return UInt8(progressView.progress * 255)
        }
    }

    @IBInspectable
    var title: String? {
        didSet {
            titleLabel.text = title?.uppercased()
            setNeedsLayout()
            setNeedsDisplay()
        }
    }
    let progressView = CircularProgressView(frame: CGRect.zero)
    let valueLabel = UILabel(frame: CGRect.zero)
    let titleLabel = UILabel(frame: CGRect.zero)

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setUp()
    }

    required override public init(frame: CGRect) {
        super.init(frame: frame)
        setUp()
    }

    private func setUp() {
        progressView.lineColor = tintColor
        addSubview(progressView)

        valueLabel.textColor = tintColor
        valueLabel.font = UIFont.preferredFont(forTextStyle: .title3)
        addSubview(valueLabel)

        titleLabel.textColor = UIColor.systemGray
        titleLabel.font = UIFont.preferredFont(forTextStyle: .subheadline)
        addSubview(titleLabel)
    }

    override func layoutSubviews() {
        progressView.frame = bounds
        titleLabel.sizeToFit()
        valueLabel.sizeToFit()
        valueLabel.frame = CGRect(x: bounds.midX - valueLabel.bounds.midX,
                                  y: bounds.midY - valueLabel.bounds.height + 4,
                                  width: valueLabel.bounds.width,
                                  height: valueLabel.bounds.height)

        titleLabel.frame = CGRect(x: bounds.midX - titleLabel.bounds.midX,
                                  y: bounds.midY + 2,
                                  width: titleLabel.bounds.width,
                                  height: titleLabel.bounds.height)
    }
}
