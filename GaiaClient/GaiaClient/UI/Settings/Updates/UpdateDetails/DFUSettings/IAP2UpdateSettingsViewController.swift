//
//  © 2020 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import UIKit

class IAP2UpdateSettingsViewController: UIViewController, GaiaViewControllerProtocol {
    var viewModel: GaiaViewModelProtocol?

    @IBOutlet weak var messageSizeSlider: UISlider?
    @IBOutlet weak var messageSizeLabel: UILabel?

    override var title: String? {
        get {
            return viewModel?.title
        }
        set {}
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let b = UIBarButtonItem(image: UIImage(systemName: "trash.circle"),
                                style: .plain,
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

    @objc func resetToDefaults(_: Any) {
        UpdateSettingsContainer.shared.setUpDefaults()
        update()
    }
}

extension IAP2UpdateSettingsViewController {
    func update() {
        guard
            let vm = viewModel as? IAP2UpdateSettingsViewModel,
            let settings = UpdateSettingsContainer.shared.settings,
            let limits = vm.limits
        else {
            return
        }

        messageSizeSlider?.minimumValue = roundf(Float(limits.maxMessageSize) / 8.0)
        messageSizeSlider?.maximumValue = Float(limits.maxMessageSize)
        
        switch settings {
        case .iap2(useDLE: _,
                   requestedMessageSize: let requestedMessageSize,
                   expectACKs: _):
            messageSizeSlider?.setValue(Float(requestedMessageSize), animated: false)
            messageSizeLabel?.text = "\(requestedMessageSize)"
        default:
            break
        }
    }
    
    func updateSettings() {
        guard
            let vm = viewModel as? IAP2UpdateSettingsViewModel
        else {
            return
        }
        
        let messageSize = Int(roundf(messageSizeSlider?.value ?? 0))
        vm.updateSettings(newMessageSize: messageSize)
    }
}
