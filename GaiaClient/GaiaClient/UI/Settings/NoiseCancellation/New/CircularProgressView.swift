//
//  © 2021 - 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import UIKit

@IBDesignable
class CircularProgressView: UIView {
    private let maskLayer = CAShapeLayer()
    private let progressLayer = CAShapeLayer()
    private let progressBackgroundLayer = CAShapeLayer()

    @IBInspectable var lineWidth: CGFloat = 8.0 {
        didSet {
            setNeedsDisplay()
        }
    }

    @IBInspectable var lineColor: UIColor = UIColor.systemTeal {
        didSet {
            setNeedsDisplay()
        }
    }

    @IBInspectable var lineBackgroundColor: UIColor = UIColor.systemGray6 {
        didSet {
            setNeedsDisplay()
        }
    }

    @IBInspectable var progress: Float = 0.5 {
        didSet {
            setNeedsDisplay()
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
        maskLayer.fillColor = nil
        maskLayer.strokeColor = UIColor.black.cgColor // Color not important, any color will do.
        maskLayer.lineWidth = lineWidth
        layer.mask = maskLayer

        progressBackgroundLayer.fillColor = nil
        progressBackgroundLayer.lineWidth = lineWidth
        layer.addSublayer(progressBackgroundLayer)

        progressLayer.fillColor = nil
        progressLayer.lineWidth = lineWidth
        layer.addSublayer(progressLayer)

        // We need to rotate it so it starts at the bottom
        layer.transform = CATransform3DMakeRotation(CGFloat(90 * Double.pi / 180), 0, 0, 1)
    }

    override func draw(_ rect: CGRect) {
        // We want a circle so find min dimension
        let minDimension = min(rect.height, rect.width)
        let xInset: CGFloat = (rect.width - minDimension) / 2.0
        let yInset: CGFloat = (rect.height - minDimension) / 2.0
        let ringInset = lineWidth / 2.0

        let ringPath = UIBezierPath(ovalIn: rect.insetBy(dx: xInset + ringInset, dy: yInset + ringInset))
        maskLayer.path = ringPath.cgPath
        progressBackgroundLayer.path = ringPath.cgPath
        progressLayer.path = ringPath.cgPath

        let midPoint = CGFloat(min(progress, 1.0))
        progressBackgroundLayer.strokeStart = midPoint
        progressBackgroundLayer.strokeEnd = 1.0
        progressBackgroundLayer.strokeColor = lineBackgroundColor.cgColor

        progressLayer.strokeStart = 0
        progressLayer.strokeEnd = midPoint
        progressLayer.strokeColor = lineColor.cgColor
    }
}
