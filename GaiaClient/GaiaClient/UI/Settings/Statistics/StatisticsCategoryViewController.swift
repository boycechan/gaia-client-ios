//
//  © 2021 - 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import UIKit

class StatisticsCategoryViewController: BaseTableViewController {
    @IBOutlet weak var settingsView: UIView?
    @IBOutlet weak var refreshRateSlider: UISlider?
    @IBOutlet weak var refreshRateLabel: UILabel?
    @IBOutlet weak var recordButton: UIButton?

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "gearshape.fill"),
                                                            style: .plain,
                                                            target: self,
                                                            action: #selector(didTapSettingsButton(_:)))
        settingsView?.alpha = 0.0
    }

    override func update() {
        super.update()

        guard let vm = viewModel as? GaiaTableViewModelProtocol else {
            navigationItem.rightBarButtonItem?.isEnabled = false
            closeSettingsUIIfNeeded()
            return
        }

        let connected = vm.isDeviceConnected()
        navigationItem.rightBarButtonItem?.isEnabled = connected

        if !connected {
            closeSettingsUIIfNeeded()
        }
        updateSettingsUI()
    }

    @objc func didTapSettingsButton(_ button: Any?) {
        updateSettingsUI()
        UIView.animate(withDuration: 0.5) {
            self.settingsView?.alpha = 1.0
        }
    }

    @IBAction func didTapCloseSettingsButton(_ button: Any?) {
        closeSettingsUIIfNeeded()
    }

    func closeSettingsUIIfNeeded() {
        if self.settingsView?.alpha ?? 0.0 > 0.5 {
            UIView.animate(withDuration: 0.5) {
                self.settingsView?.alpha = 0.0
            }
        }
    }

    @IBAction func didTapRecordButton(_ button: Any?) {
        guard let vm = viewModel as? StatisticsCategoryViewModel else {
            return
        }

        if vm.isRecording {
            vm.stopRecording()
        } else {
            vm.startRecording()
        }

        updateSettingsUI()
    }

    @IBAction func didMoveSlider(_ slider: Any?) {
        refreshRateLabel?.text = String(format: "%.1f s", refreshRateSlider?.value ?? 5.0)
    }

    @IBAction func didEndSliderMove(_ slider: Any?) {
        guard let vm = viewModel as? StatisticsCategoryViewModel else {
            return
        }

        vm.adjustRefreshRate(secs: Double(refreshRateSlider?.value ?? 5.0))
    }

    private func updateSettingsUI() {
        guard let vm = viewModel as? StatisticsCategoryViewModel else {
            return
        }

        refreshRateSlider?.setValue(Float(vm.refreshInterval), animated: false)
        refreshRateLabel?.text = String(format: "%.1f s", vm.refreshInterval)

        let title = vm.isRecording ?
        	String(localized: "Stop Recording", comment: "Text for button") :
        	String(localized: "Start Recording", comment: "Text for button")

        recordButton?.setTitle(title, for: .normal)
        recordButton?.setTitle(title, for: .normal)
        recordButton?.setTitle(title, for: .normal)

        recordButton?.tintColor = vm.isRecording ? Theming.destructiveButtonColor() : UIColor(named: "color-fitbtn-play")
    }
}
