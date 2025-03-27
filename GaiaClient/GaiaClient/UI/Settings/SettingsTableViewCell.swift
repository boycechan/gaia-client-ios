//
//  © 2020 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import UIKit

class ClosureSwitch: UISwitch {
    typealias DidTapHandler = (ClosureSwitch) -> ()

    var tapHandler: DidTapHandler? {
        didSet {
            if tapHandler != nil {
                addTarget(self, action: #selector(didTouchUpInside(_:)), for: .touchUpInside)
            } else {
                removeTarget(self, action: #selector(didTouchUpInside(_:)), for: .touchUpInside)
            }
        }
    }

    @objc func didTouchUpInside(_ : UISwitch) {
        if let tapHandler = tapHandler {
            tapHandler(self)
        }
    }
}

class ClosureButton: UIButton {
    typealias DidTapHandler = (ClosureButton) -> ()

    var tapHandler: DidTapHandler? {
        didSet {
            if tapHandler != nil {
                addTarget(self, action: #selector(didTouchUpInside(_:)), for: .touchUpInside)
            } else {
                removeTarget(self, action: #selector(didTouchUpInside(_:)), for: .touchUpInside)
            }
        }
    }

    @objc func didTouchUpInside(_ : UIButton) {
        if let tapHandler = tapHandler {
            tapHandler(self)
        }
    }
}

class ClosureSlider: UISlider {
    typealias DidChangeHandler = (ClosureSlider) -> ()
    var valueChangedHandler: DidChangeHandler? {
        didSet {
            if valueChangedHandler != nil {
                addTarget(self, action: #selector(valueChanged(_:)), for: .valueChanged)
            } else {
                removeTarget(self, action: #selector(valueChanged(_:)), for: .valueChanged)
            }
        }
    }

    @objc func valueChanged(_ : UISlider) {
        if let handler = valueChangedHandler {
            handler(self)
        }
    }
}

class SettingsTableViewCell: UITableViewCell {
    enum ViewOption {
        case titleOnly
        case titleAndSwitch
        case titleAndSubtitle
        case titleSubtitleAndSlider
    }

    @IBOutlet weak var titleLabel: UILabel?
    @IBOutlet weak var subtitleLabel: UILabel?
    @IBOutlet weak var onOffSwitch: ClosureSwitch?
    @IBOutlet weak var slider: ClosureSlider?

    var viewOption = ViewOption.titleOnly {
        didSet {
            switch viewOption {
            case .titleOnly:
                subtitleLabel?.isHidden = true
                onOffSwitch?.isHidden = true
                slider?.isHidden = true

                isAccessibilityElement = true
            case .titleAndSwitch:
                subtitleLabel?.isHidden = true
                onOffSwitch?.isHidden = false
                slider?.isHidden = true

                isAccessibilityElement = false
                onOffSwitch?.isAccessibilityElement = true
            case .titleAndSubtitle:
                subtitleLabel?.isHidden = false
                onOffSwitch?.isHidden = true
                slider?.isHidden = true

                isAccessibilityElement = true
            case .titleSubtitleAndSlider:
                subtitleLabel?.isHidden = false
                onOffSwitch?.isHidden = true
                slider?.isHidden = false

                isAccessibilityElement = false
                onOffSwitch?.isAccessibilityElement = true
            }
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        onOffSwitch?.tapHandler = nil
        slider?.valueChangedHandler = nil
    }
}
