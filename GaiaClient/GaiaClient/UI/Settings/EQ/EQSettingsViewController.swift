//
//  © 2020 - 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import UIKit

class EQSettingsViewController: UIViewController, GaiaViewControllerProtocol  {
    var viewModel: GaiaViewModelProtocol?
    private var eqViewModel: EQSettingsViewModel? { viewModel as? EQSettingsViewModel }

    @IBOutlet weak var overlayView: UIView?
    @IBOutlet weak var overlayViewLabel: UILabel?

    @IBOutlet weak var customEQContainer: UIView?
    @IBOutlet weak var bandsStackView: UIStackView?
    @IBOutlet weak var plotView: PlotView?
    @IBOutlet weak var presetsStackView: UIStackView?

    @IBOutlet weak var eqLabelsView: EQLabelsView?

    private var allPresetButtons = [UIButton] ()

    override var title: String? {
        get {
            return viewModel?.title
        }
        set {}
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        plotView?.colors = PlotColors(frameColor: UIColor.systemGray2,
                                      gridColor: UIColor.systemGray2,
                                      curves: [UIColor]())

        // Set up actions

        getAllPresetButtons()
        hideAllPresetButtons()

        let colors = plotView?.colors.curves ?? [UIColor] ()
        let haveColorsForBands = colors.count > 0

        if let sv = bandsStackView {
            for index in 0 ..< sv.arrangedSubviews.count {
                if let bandView = sv.arrangedSubviews[index] as? EQSliderView {
                    bandView.tag = index
                    bandView.slider.tag = index
                    bandView.slider.valueChangedHandler = { [weak self] slider in
                        guard let vm = self?.eqViewModel else {
                            return
                        }
                        vm.changedUserBand(band: slider.tag, gain: Double(slider.value))
                    }
                    if haveColorsForBands {
                        bandView.slider.minimumTrackTintColor = colors[index % colors.count]
                    } else {
                        bandView.slider.minimumTrackTintColor = UIColor(named: "color-bannerBackground")
                    }
                }
            }
        }

        hideAllSliders()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewModel?.activate()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        viewModel?.deactivate()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        let maxEnabledIndex = min(eqViewModel?.presets.count ?? 0, allPresetButtons.count)
        for index in 0..<allPresetButtons.count {
			let btn = allPresetButtons[index]
            btn.setBackground(active: index < maxEnabledIndex)
        }
    }

    func hideAllSliders() {
        if let sv = bandsStackView {
            for view in sv.arrangedSubviews {
                if let bandView = view as? EQSliderView {
                    bandView.isHidden = true
                }
            }
        }
    }

    func update() {
        var connected = false
        if let vm = eqViewModel {
            connected = vm.isDeviceConnected()
        }

        if !connected {
            overlayView?.isHidden = false
            overlayViewLabel?.text = String(localized: "Device disconnected", comment: "Updates Overlay")
        } else {
            overlayView?.isHidden = true
        }

        if let vm = eqViewModel {
            if !vm.eqEnabled {
                overlayView?.isHidden = false
                overlayViewLabel?.text = String(localized: "EQ not in use.\n\nPlay music to enable.", comment: "EQ not in use")
            }
            let presets = vm.presets
            let selected = vm.selectedPreset

            let validIndex = selected >= 0 && selected < presets.count

            // Draw preset buttons

            let maxIndex = min(presets.count, allPresetButtons.count)
            for index in 0 ..< maxIndex {
                let button = allPresetButtons[index]
                let preset = presets[index]
                let buttonTitle = preset.userVisibleName()
                button.setTitle(buttonTitle, for: .normal)
                button.setTitle(buttonTitle, for: .selected)
                button.setTitle(buttonTitle, for: .highlighted)
                button.alpha = 1.0
                button.tag = index
                button.setBackground(active: index == selected)
                button.superview?.isHidden = false
            }

            // Custom EQ

            if validIndex {
                let isCustom = presets[selected] == .named(.user)
                customEQContainer?.alpha = isCustom ? 1.0 : 0.0

                if let pv = plotView {
                    let bank = isCustom ? FilterBank(bands: vm.userBands) : FilterBank()
                    pv.filterBank = bank
                }

                eqLabelsView?.isHidden = vm.userBands.count == 0

                if let sv = bandsStackView {
                    for index in 0 ..< sv.arrangedSubviews.count {
                        if let bandView = sv.arrangedSubviews[index] as? EQSliderView {
                            bandView.isHidden = index >= vm.userBands.count
                            bandView.slider.isEnabled = isCustom
                            if index < vm.userBands.count {
                                bandView.slider.isEnabled = isCustom && vm.userBands[index].filterType.hasGainInput()
                                bandView.frequency = vm.userBands[index].frequency
                                bandView.slider.value = isCustom ? Float(vm.userBands[index].gain) : 0
                            }
                        }
                    }
                }
            }
        }
    }

    @IBAction func resetToZero(_ button: UIButton) {
        eqViewModel?.resetAllBandsToZeroGain()
    }
}

extension EQSettingsViewController {
    func getAllPresetButtons() {
        allPresetButtons = [UIButton] ()
        if let outerSV = presetsStackView {
            for view in outerSV.arrangedSubviews {
                if let innerSV = view as? UIStackView {
                    for innerView in innerSV.arrangedSubviews {
                        if let button = innerView as? UIButton {
                            allPresetButtons.append(button)
                            button.addTarget(self, action: #selector(presetButtonTapped(_: )), for: .touchUpInside)
                            button.setBackground(active: false)
                        }
                    }
                }
            }
        }
    }

    func hideAllPresetButtons() {
        for button in allPresetButtons {
            button.alpha = 0.0
            button.superview?.isHidden = true
        }
    }

    @objc func presetButtonTapped(_ button: UIButton) {
        let presetIndex = button.tag
        eqViewModel?.changedPreset(index: presetIndex)
    }
}
