//
//  © 2020 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import UIKit

class NotchedSlider: ClosureSlider {
    var notchColor: UIColor = UIColor.systemGray6.withAlphaComponent(0.5) {
        didSet {
            setNeedsDisplay()
        }
    }
    var interval: Float = 6.0 {
        didSet {
            setNeedsDisplay()
        }
    }

    private let lineInset: CGFloat = 12.0

    private func trackImage(rect: CGRect, color: UIColor) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(rect.size, false, 1.0)

        defer {
            UIGraphicsEndImageContext()
        }

        guard let ctx = UIGraphicsGetCurrentContext() else {
            return nil
        }

        let rectMidY = rect.height/2.0

        ctx.setLineCap(.round)
        ctx.setLineWidth(rect.size.height)
        ctx.move(to: CGPoint(x: lineInset, y: rectMidY))
        ctx.addLine(to: CGPoint(x: rect.size.width - lineInset, y: rectMidY))
        ctx.setStrokeColor(color.cgColor)
        ctx.strokePath()

        let range = maximumValue - minimumValue
        let baseInterval = Float(Int(minimumValue / interval)) * interval

        for value in stride(from: baseInterval, to: maximumValue, by: interval) {
            let isNearZero = abs(value) < 0.01
            let lineWidth: CGFloat = isNearZero ? 2.0 : 2.0
            let color = isNearZero ? UIColor.systemGray6 : notchColor
            let valuePercent = (value - minimumValue) / range
            let x = lineInset + round(CGFloat(valuePercent) * (rect.size.width - (lineInset * 2)))

            ctx.setLineWidth(lineWidth)
            ctx.move(to: CGPoint(x: x, y: 0))
            ctx.addLine(to: CGPoint(x: x, y: rect.size.height))
            ctx.setStrokeColor(color.cgColor)
            ctx.strokePath()
        }

        return UIGraphicsGetImageFromCurrentImageContext()?.resizableImage(withCapInsets: UIEdgeInsets.zero)
    }

    override func draw(_ rect: CGRect) {
        let innerRect = bounds.insetBy(dx: 1, dy: 12)

        let minImage = trackImage(rect: innerRect, color: minimumTrackTintColor ?? UIColor.systemGray6)
        let maxImage = trackImage(rect: innerRect, color: maximumTrackTintColor ?? UIColor.systemGray2)

        setMinimumTrackImage(minImage, for: .normal)
        setMaximumTrackImage(maxImage, for: .normal)

        super.draw(rect)
    }
}
