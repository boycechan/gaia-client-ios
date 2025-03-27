//
//  © 2021 - 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import UIKit

@IBDesignable
class OptionSlider: ClosureSlider {
    @IBInspectable
    var trackColor: UIColor = Theming.regularButtonColor() ?? UIColor.blue {
        didSet {
            setNeedsDisplay()
        }
    }

    @IBInspectable
    var numberOfOptions: Int = 1 {
        didSet {
            maximumValue = Float(numberOfOptions - 1)
            minimumValue = 0.0
            value = round(value)
            setNeedsDisplay()
        }
    }

    private let lineInset: CGFloat = 12.0

    // Init methods seem necessary for IBDesignable to work.
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    required override public init(frame: CGRect) {
        super.init(frame: frame)
    }

    private func trackImage(rect: CGRect, color: UIColor) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(rect.size, false, 1.0)

        defer {
            UIGraphicsEndImageContext()
        }

        guard let ctx = UIGraphicsGetCurrentContext() else {
            return nil
        }

        let rectMidY = rect.height/2.0

        var circleRects = [CGRect]()
        ctx.setLineWidth(3.0)
        ctx.setStrokeColor(trackColor.cgColor)

        for value in 0...Int(maximumValue) {
            let valuePercent = Float(value) / maximumValue
            let x = lineInset + round(CGFloat(valuePercent) * (rect.size.width - (lineInset * 2)))
            let center = CGPoint(x: x, y: rectMidY)
            let circleRect = CGRect(x: center.x - 6.0, y: center.y - 6.0, width: 13.0, height: 13.0)
            circleRects.append(circleRect)
            ctx.addEllipse(in: circleRect)
            ctx.strokePath()
        }

        ctx.setLineWidth(4.0)
        if circleRects.count > 1 {
            for index in 0..<circleRects.count - 1 {
                // Draw the line between

                let xStart = circleRects[index].origin.x + circleRects[index].size.width
                let xEnd = circleRects[index + 1].origin.x

                ctx.move(to: CGPoint(x: xStart, y: rectMidY))
                ctx.addLine(to: CGPoint(x: xEnd, y: rectMidY))
                ctx.strokePath()
            }
        }

        return UIGraphicsGetImageFromCurrentImageContext()?.resizableImage(withCapInsets: UIEdgeInsets.zero)
    }

    override func draw(_ rect: CGRect) {
        let trackRect = trackRect(forBounds: bounds)
        let minImage = trackImage(rect: trackRect, color: minimumTrackTintColor ?? UIColor.systemGray6)
        let maxImage = trackImage(rect: trackRect, color: maximumTrackTintColor ?? UIColor.systemGray2)

        setMinimumTrackImage(minImage, for: .normal)
        setMaximumTrackImage(maxImage, for: .normal)

        super.draw(rect)
    }

    override func valueChanged(_: UISlider) {
        value = roundf(value)
        super.valueChanged(self)
    }

    override func trackRect(forBounds bounds: CGRect) -> CGRect {
        var rect = super.trackRect(forBounds: bounds)
        let newHeight = CGFloat(18.0)
        let currentHeight = rect.height
        let offset = round((newHeight - currentHeight) / 2.0)
        rect.size.height = newHeight
        rect.origin.y -= offset
        return rect
    }
}
