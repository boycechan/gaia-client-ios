//
//  ConcentricGainView.swift
//  GaiaClient
//
//  Created by Stephen Flack on 04/10/2023.
//  Copyright © 2023 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import UIKit
import GaiaBase

class ConcentricGainView: UIView {    
    private var _instanceValues = [GainContainer.Value]()
    
    var instanceValues: [GainContainer.Value] {
        set {
            if _instanceValues.count != newValue.count {
                progressViews.forEach({ $0.removeFromSuperview() })
                progressViews.removeAll()
                let svs = valueStackView.arrangedSubviews
                svs.forEach({ $0.removeFromSuperview() })
                
                for index in 0 ..< newValue.count {
                    let color = (index % 2 == 0 ? Theming.dialColor1() : Theming.dialColor2()) ?? UIColor.systemRed
                    let view = CircularProgressView(frame: CGRect.zero)
                    view.lineColor = color
                    self.addSubview(view)
                    progressViews.append(view)
                    
                    let label = UILabel(frame: CGRect.zero)
                    label.textAlignment = .center
                    label.textColor = color
                    label.font = UIFont.preferredFont(forTextStyle: newValue.count == 1 ? .callout : .caption1)
                    valueStackView.addArrangedSubview(label)
                }
            }
            
            _instanceValues = newValue            
            
            if newValue.count == 1 {
                if let label = valueStackView.arrangedSubviews.first as? UILabel,
                   let value = newValue.first {
                    if let total = value.totalGain {
                        label.text = String(format: "%.1f dB", total)
                    } else {
                        label.text = "\(value.gain)"
                    }
                    label.sizeToFit()
                }
            } else {
                for (index, (view, value)) in zip(newValue.indices, zip(valueStackView.arrangedSubviews, newValue)) {
                    if let label = view as? UILabel {
                        if let total = value.totalGain {
                            label.text = String(format: "%i: %.1f dB", index, total)
                        } else {
                            label.text = "\(index): \(value.gain)"
                        }
                        label.sizeToFit()
                    }
                }
            }
            
                    
            for (progressView, value) in zip(progressViews, newValue) {
                progressView.progress = Float(value.gain) / 255.0
            }

            setNeedsLayout()
            setNeedsDisplay()
        }

        get {
            return _instanceValues
        }
    }

    @IBInspectable
    var title: String? {
        didSet {
            setNeedsLayout()
            setNeedsDisplay()
        }
    }
    private var progressViews = [CircularProgressView]()
    private let valueStackView = UIStackView()

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setUp()
    }

    required override public init(frame: CGRect) {
        super.init(frame: frame)
        setUp()
    }

    private func setUp() {
        valueStackView.axis = .vertical
        valueStackView.alignment = .center
        valueStackView.distribution = .equalSpacing
        addSubview(valueStackView)
    }

    override func layoutSubviews() {
        var circleBounds = bounds
        progressViews.forEach( {
            $0.frame = circleBounds
            circleBounds = circleBounds.insetBy(dx: $0.lineWidth + 2.0,
                                       dy: $0.lineWidth + 2.0)
        })

        let valueStackHeight = valueStackView.arrangedSubviews.reduce(0.0, { $0 + $1.frame.height }) +
            CGFloat(valueStackView.arrangedSubviews.count - 1) * valueStackView.spacing
        
        valueStackView.frame = CGRect(x: circleBounds.origin.x,
                                      y: bounds.midY - (valueStackHeight / 2.0),
                                  width: circleBounds.width,
                                  height: valueStackHeight)
    }

}
