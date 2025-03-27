//
//  © 2019 - 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import UIKit

struct PlotColors {
    let frameColor: UIColor
    let gridColor: UIColor
    let curves: [UIColor]
}

@IBDesignable class PlotView: UIView {
    private static let curveColors = [UIColor.systemTeal,
                                     UIColor.systemBlue,
                                     UIColor.systemGreen,
                                     UIColor.systemPurple,
                                     UIColor.systemOrange,
                                     UIColor.systemYellow,
                                     UIColor.systemIndigo,
    ]
    enum Style {
        case freqResponse
        case phaseResponse
        case groupDelay
    }

    var style = Style.freqResponse {
        didSet {
            recalculate(rect: bounds)
            setNeedsDisplay()
        }
    }

    var filterBank = FilterBank() {
        didSet {
            recalculate(rect: bounds)
            setNeedsDisplay()
        }
    }

    var colors = PlotColors(frameColor: UIColor.systemGray2,
                            gridColor: UIColor.systemGray2,
                            curves: PlotView.curveColors)

    var totalCurveColor = UIColor.red

    let dbMaxMin = 12.0
    private let startFrequency = 20.0
    private let endFrequency = 20000.0

    private let marginInset: CGFloat = 20.0
    private var yMin = -20.0
    private var yMax = 20.0

    private var graphData = GraphData(filterCurves:[GraphCurve] (), totalCurve:[GraphPoint] ())

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        recalculate(rect: bounds)
    }

    required override public init(frame: CGRect) {
        super.init(frame: frame)
        recalculate(rect: bounds)
    }

    override func draw(_ rect: CGRect) {
        guard let _ = UIGraphicsGetCurrentContext() else {
            return
        }

        drawGraph(rect: bounds)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        recalculate(rect: bounds)
    }

    private func recalculate(rect: CGRect) {
        // work out frequency points we want to plot depending on width of graph
        var frequencies = [Double] ()

        if rect.size.width > marginInset * 2 {
            for xPos in Int(marginInset) ..< Int(rect.size.width - marginInset) {
                let freq = startFrequency * pow(10.0,
                                                Double((CGFloat(xPos) - marginInset) / (rect.size.width - (marginInset * 2))) * log10(endFrequency / startFrequency))

                if freq < (filterBank.frequency / 2) {
                    frequencies.append(freq)
                }
            }
        }

        switch style {
        case .freqResponse:
            graphData = filterBank.generateDbGainGraph(frequencies: frequencies)
        case .phaseResponse:
            graphData = filterBank.generatePhaseGraph(frequencies: frequencies)
        case .groupDelay:
			graphData = filterBank.generateGroupDelayGraph(frequencies: frequencies)
        }

        // Determine Y range by finding max/min values
        var minValue = 0.0
        var maxValue = 0.0
        graphData.filterCurves.forEach { curve in
            curve.forEach { point in
                minValue = min(minValue, point.result)
                maxValue = max(maxValue, point.result)
            }
        }

        graphData.totalCurve.forEach { point in
            minValue = min(minValue, point.result)
            maxValue = max(maxValue, point.result)
        }

        switch style {

        case .freqResponse:
            var temp = ceil(maxValue / dbMaxMin)
            yMax = max(dbMaxMin, dbMaxMin * temp)
            temp = floor(minValue / dbMaxMin)
            yMin = min(-dbMaxMin, dbMaxMin * temp)
            yMin = max(-96.0, yMin)
        case .phaseResponse:
            yMax = 90.0
            yMin = -90.0
        case .groupDelay:
            var temp = ceil(maxValue / 5.0)
            yMax = max(5.0, 5.0 * temp)
            temp = floor(minValue / 5.0)
            yMin = min(-5.0, 5.0 * temp)
        }
    }

    private func drawGraph(rect: CGRect) {
        drawScale(rect: rect)
        drawAxes(rect: rect)
        plotPoints(rect: rect)
    }

    private func screenPoint(graphPoint: GraphPoint, gridRect: CGRect) -> CGPoint {
		let yScale =  Double(gridRect.size.height) / (yMax - yMin)
		let freq = graphPoint.frequency
        let result = graphPoint.result
        let x = gridRect.origin.x +
            (gridRect.size.width * CGFloat((log(freq) - log(startFrequency)) /
            (log(endFrequency) - log(startFrequency))))

        let y = gridRect.origin.y + CGFloat((yMax - result) * yScale)
        return CGPoint(x: x, y: y)
    }

    private func drawCurve(_ curve: GraphCurve, gridRect: CGRect, penColor: UIColor) {
        penColor.set()
        let path = UIBezierPath()

        // Move to first point

        if curve.count > 1 {
            let firstPoint = screenPoint(graphPoint: curve[0], gridRect: gridRect)
            path.move(to: firstPoint)

            // Now add in extra points
            for pointIndex in 1 ..< curve.count {
                let point = screenPoint(graphPoint: curve[pointIndex], gridRect: gridRect)
                path.addLine(to: point)
            }
            path.stroke()
        }
    }

    private func plotPoints(rect: CGRect) {
        let frameRect = rect.insetBy(dx: marginInset, dy: marginInset)
        
        if colors.curves.count > 0 {
            for curveIndex in 0 ..< graphData.filterCurves.count {
                let curve = graphData.filterCurves[curveIndex]
                let penColor = colors.curves[curveIndex % colors.curves.count].withAlphaComponent(0.7)
                drawCurve(curve, gridRect: frameRect, penColor: penColor)
            }
        }

        // Draw combined
        drawCurve(graphData.totalCurve, gridRect: frameRect, penColor: totalCurveColor)
    }

    private func horizontalLineStep() -> Double {
        switch style {
        case .freqResponse:
            return dbMaxMin > 5.9 ? 6.0 : 1.0
        case .phaseResponse:
            return 90.0
        case .groupDelay:
            return 10.0
        }
    }


    private func drawAxes(rect: CGRect) {
        let frameRect = rect.insetBy(dx: marginInset, dy: marginInset)
        let yScale =  Double(frameRect.size.height) / (yMax - yMin)

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .right

        let attrs = [NSAttributedString.Key.font: UIFont(name: "HelveticaNeue-Thin", size: 8)!,
                     NSAttributedString.Key.foregroundColor: UIColor.secondaryLabel,
                     NSAttributedString.Key.paragraphStyle: paragraphStyle]

        var y = 0.0
        var level = 0.0
        let yStep = horizontalLineStep()

        //Draw Horizontal Axes

        while level <= yMax {
            y = ((yMax - level) * yScale) + Double(marginInset)
            let str = String(format: "%.0f", level)
            str.draw(with: CGRect(x: 0, y: CGFloat(y - 5.0), width: marginInset - 5.0, height: 10.0),
                     options: .usesLineFragmentOrigin,
                     attributes: attrs,
                     context: nil)

            level = level + yStep
        }

        level = -yStep

        while level >= yMin {
            y = ((yMax - level) * yScale) + Double(marginInset)
            let str = String(format: "%.0f", level)

            str.draw(with: CGRect(x: 0, y: CGFloat(y - 5.0), width: marginInset - 5.0, height: 10.0),
                     options: .usesLineFragmentOrigin,
                     attributes: attrs,
                     context: nil)

            level = level - yStep
        }

        // Draw Vertical Axes
        var freqExp = Int(log10(startFrequency))
        var freqMant = Int(ceil(startFrequency / pow(10.0, Double(freqExp))))

        var freq = 0.0
        repeat {
            freqMant = freqMant + 1
            if freqMant >= 10 {
                freqMant = 1
                freqExp = freqExp + 1
            }

            if freqMant == 1 {
                // Draw text
                freq = Double(freqMant) * pow(10.0, Double(freqExp))
                let x = frameRect.origin.x + (frameRect.size.width * CGFloat((log(freq) - log(startFrequency)) / (log(endFrequency) - log(startFrequency))))

                let str = freq < 1000.0 ? String(format: "%.0f", freq) : String(format: "%.0fk", freq/1000.0)

                let width = str.size(withAttributes: attrs).width
                str.draw(with: CGRect(x: x - (width / 2.0), y: rect.size.height - CGFloat(marginInset - 4), width: width , height: 10.0),
                         options: .usesLineFragmentOrigin,
                         attributes: attrs,
                         context: nil)
            }
        } while freq < endFrequency
    }

    private func drawScale(rect: CGRect) {
		// Draw outer frame
        UIColor.systemBackground.set()
        UIRectFill(rect)
        
        colors.frameColor.set()
        let frameRect = rect.insetBy(dx: marginInset, dy: marginInset)
        let framePath = UIBezierPath.init(rect: frameRect)
        framePath.stroke()

		let yScale =  Double(frameRect.size.height) / (yMax - yMin)

        var y = 0.0
        var level = 0.0
		let yStep = horizontalLineStep()

        colors.gridColor.set()

        //Draw Horizontal lines.

        while level <= yMax {
            y = ((yMax - level) * yScale) + Double(marginInset)
            let line = UIBezierPath()
            line.move(to: CGPoint(x: frameRect.origin.x + 1, y: CGFloat(y)))
            line.addLine(to: CGPoint(x: frameRect.origin.x + frameRect.size.width - 1, y: CGFloat(y)))

            line.stroke()
            level = level + yStep
        }

        level = -yStep
        while level >= yMin {
            y = ((yMax - level) * yScale) + Double(marginInset)
            let line = UIBezierPath()
            line.move(to: CGPoint(x: frameRect.origin.x + 1, y: CGFloat(y)))
            line.addLine(to: CGPoint(x: frameRect.origin.x + frameRect.size.width - 1, y: CGFloat(y)))

            line.stroke()
            level = level - yStep
        }

		// Draw Vertical lines
        var freqExp = Int(log10(startFrequency))
        var freqMant = Int(ceil(startFrequency / pow(10.0, Double(freqExp))))

        var freq = 0.0
        repeat {
            freqMant = freqMant + 1
            if freqMant >= 10 {
                freqMant = 1
                freqExp = freqExp + 1
            }
            freq = Double(freqMant) * pow(10.0, Double(freqExp))
            let x = frameRect.origin.x + (frameRect.size.width * CGFloat((log(freq) - log(startFrequency)) / (log(endFrequency) - log(startFrequency))))

            let line = UIBezierPath()
            line.move(to: CGPoint(x: x, y: frameRect.origin.y + 1))
            line.addLine(to: CGPoint(x: x, y: frameRect.origin.y + frameRect.size.height - 1))

            line.stroke()
        } while freq < endFrequency
    }
}
