//
//  © 2020 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import UIKit
import PluginBase

class BLEUpdateSettingsViewController: UIViewController, GaiaViewControllerProtocol {
    var viewModel: GaiaViewModelProtocol?

    @IBOutlet weak var messageSizeSlider: UISlider?
    @IBOutlet weak var messageSizeLabel: UILabel?

    @IBOutlet weak var windowSizeContainer: UIStackView?

    @IBOutlet weak var initialWindowSizeSlider: UISlider?
    @IBOutlet weak var initialWindowSizeLabel: UILabel?

    @IBOutlet weak var maxWindowSizeSlider: UISlider?
    @IBOutlet weak var maxWindowSizeLabel: UILabel?

    override var title: String? {
        get {
            return viewModel?.title
        }
        set {}
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let b = UIBarButtonItem(image: UIImage(systemName: "trash.circle"),
                                style: .done,
                                target: self,
                                action: #selector(resetToDefaults(_:)))
        navigationItem.setRightBarButton(b, animated: false)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewModel?.activate()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        viewModel?.deactivate()
    }

    @IBAction func messageSizeSliderChanged(_ slider: UISlider) {
        updateSettings()
    }

    @IBAction func initialWindowSizeSliderChanged(_ slider: UISlider) {
		updateSettings()
    }

    @IBAction func maxWindowSizeSliderChanged(_ slider: UISlider) {
		updateSettings()
    }

    @objc func resetToDefaults(_: Any) {
        UpdateSettingsContainer.shared.setUpDefaults()
        update()
    }
}

extension BLEUpdateSettingsViewController {
    func update() {
        guard
            let vm = viewModel as? BLEUpdateSettingsViewModel,
            let settings = UpdateSettingsContainer.shared.settings,
            let limits = vm.limits
        else {
            return
        }


        messageSizeSlider?.minimumValue = 16.0
        messageSizeSlider?.maximumValue = Float(limits.maxMessageSize)

        initialWindowSizeSlider?.minimumValue = 8.0
        initialWindowSizeSlider?.maximumValue = Float(UpdateTransportOptions.Constants.rwcpMaxWindow)

        maxWindowSizeSlider?.minimumValue = 8.0
        maxWindowSizeSlider?.maximumValue = Float(UpdateTransportOptions.Constants.rwcpMaxWindow)

        switch settings {
        case .ble(useDLE: _,
                  requestedMessageSize: let requestedMessageSize):
            windowSizeContainer?.isHidden = true
            messageSizeSlider?.setValue(Float(requestedMessageSize), animated: false)
            messageSizeLabel?.text = "\(requestedMessageSize)"
        case .bleRWCP(useDLE: _,
                      requestedMessageSize: let requestedMessageSize,
                      initialWindowSize: let initialWindowSize,
                      maxWindowSize: let maxWindowSize):
            windowSizeContainer?.isHidden = false
            messageSizeSlider?.setValue(Float(requestedMessageSize), animated: false)
            messageSizeLabel?.text = "\(requestedMessageSize)"

            initialWindowSizeSlider?.setValue(Float(initialWindowSize), animated: false)
            initialWindowSizeLabel?.text = "\(initialWindowSize)"

            maxWindowSizeSlider?.setValue(Float(maxWindowSize), animated: false)
            maxWindowSizeLabel?.text = "\(maxWindowSize)"
        default:
            break
        }
    }

    func updateSettings() {
        guard
            let vm = viewModel as? BLEUpdateSettingsViewModel,
        	let limits = vm.limits
        else {
            return
        }

        let messageSize = Int(roundf(messageSizeSlider?.value ?? 0))
        if limits.rwcpAvailable {
            let initial = Int(roundf(initialWindowSizeSlider?.value ?? 0))
            let max = Int(roundf(maxWindowSizeSlider?.value ?? 0))
            vm.updateSettings(newMessageSize: messageSize, initialWindowSize: initial, maxWindowSize: max)
        } else {
            vm.updateSettings(newMessageSize: messageSize)
        }
    }
}
