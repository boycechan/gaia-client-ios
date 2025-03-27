//
//  © 2021 - 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import UIKit

class EQLabelsView: UIView {

    private let minimumValue = -12.0
    private let maximumValue = 3.0
    private let step = 6.0

    private let topYInset: CGFloat = 12.0
    private let bottomYInset: CGFloat = 37.0

    @IBOutlet private weak var resetButton: UIButton?

    override open func layoutSubviews() {
        super.layoutSubviews()

        if bounds.height > topYInset + bottomYInset && bounds.width > 30.0 {
            resetButton?.isHidden = false
            resetButton?.sizeToFit()
            doLayout()
            setNeedsDisplay()
        } else {
            resetButton?.isHidden = true
        }
    }

    func doLayout() {
        let range = maximumValue - minimumValue
        let height = bounds.height - (topYInset + bottomYInset)

        // We only position the 0 dB button here.

        let valuePercentFromMax = maximumValue / range
        let y = topYInset + round(CGFloat(valuePercentFromMax) * height)

        let btnHeightOffset = (resetButton?.bounds.height ?? 0.0) / 2.0
        let buttonY = y - btnHeightOffset
        resetButton?.frame = CGRect(x: 2.0, y: buttonY, width: bounds.width - 2.0, height: resetButton?.bounds.height ?? 0.0)
    }

    override func draw(_ rect: CGRect) {
        super.draw(rect)

        let baseInterval = Double(Int(minimumValue / step)) * step

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .right

        let attrs = [NSAttributedString.Key.font: UIFont.preferredFont(forTextStyle: .caption2),
                     NSAttributedString.Key.foregroundColor: UIColor.secondaryLabel,
                     NSAttributedString.Key.paragraphStyle: paragraphStyle]

        if abs(baseInterval - minimumValue) > 1.0 {
            // We won't have draw the lowest value
			drawTextForValue(round(minimumValue), attributes: attrs)
        }

        for value in stride(from: baseInterval, to: maximumValue, by: step) {
            let isNearZero = abs(value) < 0.01
            if !isNearZero {
                drawTextForValue(value, attributes: attrs)
            }
        }

        if (maximumValue - baseInterval).truncatingRemainder(dividingBy: step) > 0.5 {
            // We won't have drawn the maximum either.
            drawTextForValue(round(maximumValue), attributes: attrs)
        }
    }

    private func drawTextForValue(_ value: Double, attributes: [NSAttributedString.Key : Any]) {
        let range = maximumValue - minimumValue
        let height = bounds.height - (topYInset + bottomYInset)

        let valuePercentFromMax = (maximumValue - value) / range
        let y = topYInset + round(CGFloat(valuePercentFromMax) * height)

        let text = "\(Int(value)) dB" as NSString
        let size = text.size(withAttributes: attributes)
        let txtHeightOffset = size.height / 2.0
        let textY = y - txtHeightOffset
        let textX = bounds.width - (size.width + 5.0)
        text.draw(at: CGPoint(x: textX, y: textY), withAttributes: attributes)
    }
}
