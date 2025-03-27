//
//  © 2021 - 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import UIKit
import GaiaBase
import PluginBase
import GaiaLogger

enum GainType {
    case feedForward
    case feedBack
    
    func title() -> String {
        switch self {
        case .feedForward:
            return String(localized: "Feed Forward Gain", comment: "Gain Type Title")
        case .feedBack:
            return String(localized: "Feed Back Gain", comment: "Gain Type Title")
        }
    }
}

class AudioCurationDemoViewController: UIViewController, GaiaViewControllerProtocol {
    @IBOutlet weak var ancEnabledSwitch: ClosureSwitch?

    @IBOutlet weak var modesStackView: UIStackView?

    @IBOutlet weak var balanceSlider: ClosureSlider?
    @IBOutlet weak var balanceValueLabel: UILabel?
    @IBOutlet weak var wndSwitch: ClosureSwitch?
    @IBOutlet weak var leftWNDIndicatorImageView: UIImageView?
    @IBOutlet weak var rightWNDIndicatorImageView: UIImageView?

    // Depending on plugin version there are two types of Leakthrough gain UI
    @IBOutlet weak var nonSteppedLeakthroughGainSlider: ClosureSlider?
    @IBOutlet weak var nonSteppedLeakthroughGainValueLabel: UILabel?

    @IBOutlet weak var steppedLeakthroughGainSlider: OptionSlider?
    @IBOutlet weak var steppedLeakthroughGainValueLabel: UILabel?

    @IBOutlet weak var adaptationSwitch: ClosureSwitch?

    @IBOutlet weak var howlingDetectionSwitch: ClosureSwitch?
    @IBOutlet weak var leftHCGainReductionIndicatorImageView: UIImageView?
    @IBOutlet weak var rightHCGainReductionIndicatorImageView: UIImageView?

    @IBOutlet weak var noiseIDCategoryTitleLabel: UILabel?
    @IBOutlet weak var noiseIDCategoryValueLabel: UILabel?

    @IBOutlet weak var AAHSwitch: ClosureSwitch?
    @IBOutlet weak var leftAAHGainReductionIndicatorImageView: UIImageView?
    @IBOutlet weak var rightAAHGainReductionIndicatorImageView: UIImageView?

    @IBOutlet weak var mainStackView: UIStackView?
    @IBOutlet weak var modesContainer: UIView?
    @IBOutlet weak var balanceContainer: UIView?
    @IBOutlet weak var wndContainer: UIView?
    @IBOutlet weak var nonSteppedLeakthroughGainContainer: UIView?
    @IBOutlet weak var steppedLeakthroughGainContainer: UIView?
    
    @IBOutlet weak var gainsContainer: UIView?
    @IBOutlet weak var leftFeedForwardGainView: ConcentricGainView?
    @IBOutlet weak var rightFeedForwardGainView: ConcentricGainView?
    @IBOutlet weak var leftFeedBackGainView: ConcentricGainView?
    @IBOutlet weak var rightFeedBackGainView: ConcentricGainView?
    
    @IBOutlet weak var feedForwardGainContainer: UIView?
    @IBOutlet weak var howlingDetectionContainer: UIView?
    @IBOutlet weak var HCGainReductionContainer: UIView?
    @IBOutlet weak var noiseIDContainer: UIView?
    @IBOutlet weak var AAHContainer: UIView?

    @IBOutlet weak var overlayView: UIView?
    @IBOutlet weak var overlayViewLabel: UILabel?

    var viewModel: GaiaViewModelProtocol?
    var allModeButtons = [ANCModeButton]()

    override var title: String? {
        get {
            return viewModel?.title
        }
        set {}
    }

    func update() {
        guard
            let vm = viewModel as? AudioCurationDemoViewModel,
            isViewLoaded
        else {
            if isViewLoaded {
                overlayView?.isHidden = false
                overlayViewLabel?.text = String(localized: "No information", comment: "Overlay")
            }
            return
        }

        if !vm.isDeviceConnected() {
            overlayView?.isHidden = false
            overlayViewLabel?.text = String(localized: "Device disconnected", comment: "Overlay")
            return
        }

        overlayView?.isHidden = true
        
        updateOnEnabledState()
        updateOnModeState()
        updateOnGainState()
        updateOnAdaptationState()
        updateOnSteppedGainConfigChanged()
        updateOnBalanceChanged()
        updateOnWNDStateChanged()
        updateOnWNDDetectionChanged()
        updateOnHowlingDetectionState()
        updateOnHowlingDetectionGainState()
        updateOnHCGainReductionChanged()

        updateOnNoiseID()

        updateOnAAHStateChanged()
        updateOnAAHGainReductionChanged()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
       	getAllModeButtons()
        setUpClosures()
        viewModel?.activate()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        viewModel?.deactivate()
    }

    func setUpClosures() {
        balanceSlider?.valueChangedHandler = { [weak self] slider in
            if abs (slider.value - 0.5) < 0.05 {
                // If the slider is moved near the middle we set it to the middle.
                slider.setValue(0.5, animated: false)
            }
            self?.userChangedBalance(slider.value)
        }

        wndSwitch?.tapHandler = { [weak self] sw in
            self?.userChangedWNDSwitch(isOn: sw.isOn)
        }

        nonSteppedLeakthroughGainSlider?.valueChangedHandler = { [weak self] slider in
            self?.userChangedNonSteppedLeakthroughGain(Int(slider.value))
        }

        steppedLeakthroughGainSlider?.valueChangedHandler = { [weak self] slider in
            self?.userChangedSteppedLeakthroughGain(Int(slider.value) + 1)
        }

        adaptationSwitch?.tapHandler = { [weak self] sw in
            self?.userChangedAdaptationSwitch(isOn: sw.isOn)
        }

        howlingDetectionSwitch?.tapHandler = { [weak self] sw in
            self?.userChangedHowlingDetectionSwitch(isOn: sw.isOn)
        }

        ancEnabledSwitch?.tapHandler = { [weak self] sw in
            self?.userChangedEnabledSwitch(isOn: sw.isOn)
        }

        AAHSwitch?.tapHandler = { [weak self] sw in
            self?.userChangedAAHSwitch(isOn: sw.isOn)
        }
    }
    
    @IBAction func didTapSegmentedControl(_ control: UISegmentedControl) {
        updateGainDials()
    }
}

extension AudioCurationDemoViewController {
    func updateOnEnabledState() {
        guard
            let vm = viewModel as? AudioCurationDemoViewModel,
            isViewLoaded
        else {
            return
        }
        
        if !vm.isEnabled {
            modesContainer?.isHidden = true
            modesContainer?.alpha = 0.0
            nonSteppedLeakthroughGainContainer?.isHidden = true
            nonSteppedLeakthroughGainContainer?.alpha = 0.0
            steppedLeakthroughGainContainer?.isHidden = true
            steppedLeakthroughGainContainer?.alpha = 0.0
            feedForwardGainContainer?.isHidden = true
            feedForwardGainContainer?.alpha = 0.0
            balanceContainer?.isHidden = true
            balanceContainer?.alpha = 0.0
            wndContainer?.isHidden = true
            wndContainer?.alpha = 0.0
            howlingDetectionContainer?.isHidden = true
            howlingDetectionContainer?.alpha = 0.0
            HCGainReductionContainer?.isHidden = true
            HCGainReductionContainer?.alpha = 0.0
            noiseIDContainer?.isHidden = true
            noiseIDContainer?.alpha = 0.0
            AAHContainer?.isHidden = true
            AAHContainer?.alpha = 0.0
            
            gainsContainer?.isHidden = true
            gainsContainer?.alpha = 0.0

        } else {
            modesContainer?.isHidden = !vm.canSelectDemoModeMode
            modesContainer?.alpha = vm.canSelectDemoModeMode ? 1.0 : 0.0
            nonSteppedLeakthroughGainContainer?.isHidden = !vm.canSetLeakthroughGain || vm.showSteppedLeakthroughGainUI
            nonSteppedLeakthroughGainContainer?.alpha = vm.canSetLeakthroughGain && !vm.showSteppedLeakthroughGainUI ? 1.0 : 0.0

            steppedLeakthroughGainContainer?.isHidden = !vm.canSetLeakthroughGain && !vm.showSteppedLeakthroughGainUI
            steppedLeakthroughGainContainer?.alpha = vm.canSetLeakthroughGain && vm.showSteppedLeakthroughGainUI ? 1.0 : 0.0
            feedForwardGainContainer?.isHidden = !vm.feedForwardGainActive
            feedForwardGainContainer?.alpha = vm.feedForwardGainActive ? 1.0 : 0.0

            howlingDetectionContainer?.isHidden = !vm.howlingDetectionSupported
            howlingDetectionContainer?.alpha = vm.howlingDetectionSupported ? 1.0 : 0.0
            HCGainReductionContainer?.isHidden = !vm.howlingControlGainReductionIndicationSupported
            HCGainReductionContainer?.alpha = vm.howlingControlGainReductionIndicationSupported ? 1.0 : 0.0

            noiseIDContainer?.isHidden = !vm.noiseIDSupported
            noiseIDContainer?.alpha = vm.noiseIDSupported ? 1.0 : 0.0

            AAHContainer?.isHidden = !vm.AAHSupported
            AAHContainer?.alpha = vm.AAHSupported ? 1.0 : 0.0

            balanceContainer?.isHidden = !vm.balanceAdjustmentSupported
            balanceContainer?.alpha = vm.balanceAdjustmentSupported ? 1.0 : 0.0
            wndContainer?.isHidden = !vm.wndDetectionSupported
            wndContainer?.alpha = vm.wndDetectionSupported ? 1.0 : 0.0
            
            gainsContainer?.isHidden = false
            gainsContainer?.alpha = 1.0
            updateGainDials()
        }
        
        ancEnabledSwitch?.setOn(vm.isEnabled, animated: false)
    }
    
    func updateGainDials() {
        guard
            let vm = viewModel as? AudioCurationDemoViewModel
        else {
            return
        }
             
        leftFeedForwardGainView?.instanceValues = vm.feedForwardGains.leftValues
        rightFeedForwardGainView?.instanceValues = vm.feedForwardGains.rightValues
        
        leftFeedBackGainView?.instanceValues = vm.howlingDetectionFeedbackGains.leftValues
        rightFeedBackGainView?.instanceValues = vm.howlingDetectionFeedbackGains.rightValues
    }

    func updateOnModeState() {
        guard
            let vm = viewModel as? AudioCurationDemoViewModel,
        	isViewLoaded
        else {
            return
        }

        if vm.canSelectDemoModeMode {
            presentModesButtons()
        }
    }

    func updateOnGainState() {
        guard
            let vm = viewModel as? AudioCurationDemoViewModel,
            isViewLoaded
        else {
            return
        }

        if vm.canSetLeakthroughGain {
            updateLeakthroughGain()
        }

        updateGainDials()
    }

    func updateOnAdaptationState() {
        guard
            let vm = viewModel as? AudioCurationDemoViewModel,
            isViewLoaded
        else {
            return
        }

        adaptationSwitch?.isEnabled = vm.canChangeAdaptation
        if vm.canChangeAdaptation {
            updateAdaptationSlider()
        }
    }

    func updateOnSteppedGainConfigChanged() {
        guard
            let vm = viewModel as? AudioCurationDemoViewModel,
            isViewLoaded
        else {
            return
        }

        steppedLeakthroughGainSlider?.numberOfOptions = vm.leakthroughSteppedGainNumberOfSteps
    }

    func updateOnBalanceChanged() {
        guard
            let vm = viewModel as? AudioCurationDemoViewModel,
            isViewLoaded
        else {
            return
        }

        var balanceString = String(localized: "CENTER", comment: "Balance")
        let scaled = Int(round(vm.balance * 200.0))
        if scaled > 100 {
            // right
            balanceString = String(localized: "\(scaled - 100)% R", comment: "Audio Curation Balance")
        } else if scaled < 100 {
            balanceString = String(localized: "\(100 - scaled)% L", comment: "Audio Curation Balance")
        }
        balanceValueLabel?.text = balanceString
        balanceSlider?.value = vm.balance
    }

    func updateOnWNDStateChanged() {
        guard
            let vm = viewModel as? AudioCurationDemoViewModel,
            isViewLoaded
        else {
            return
        }

        wndSwitch?.setOn(vm.wndDetectionEnabled, animated: false)

        if !vm.wndDetectionEnabled {
            leftWNDIndicatorImageView?.tintColor = UIColor.systemGray4
            rightWNDIndicatorImageView?.tintColor = UIColor.systemGray4
        }
    }

    func updateOnWNDDetectionChanged() {
        guard
            let vm = viewModel as? AudioCurationDemoViewModel,
            isViewLoaded
        else {
            return
        }

        if vm.wndDetectionEnabled {
            let detectionState = vm.wndDetected()
            leftWNDIndicatorImageView?.tintColor = detectionState.left ? view.tintColor : UIColor.systemGray4
            rightWNDIndicatorImageView?.tintColor = detectionState.right ? view.tintColor : UIColor.systemGray4
        }
    }

    func updateOnHowlingDetectionState() {
        guard
            let vm = viewModel as? AudioCurationDemoViewModel,
            isViewLoaded
        else {
            return
        }

        howlingDetectionSwitch?.isEnabled = vm.howlingDetectionAvailableForCurrentMode
        updateHowlingDetectionSlider()
    }

    func updateOnHowlingDetectionGainState() {
        guard
            let vm = viewModel as? AudioCurationDemoViewModel,
            isViewLoaded
        else {
            return
        }

        if vm.howlingDetectionState {
            updateHowlingDetectionGainDials()
        }
    }

    func updateOnHCGainReductionChanged() {
        guard
            let vm = viewModel as? AudioCurationDemoViewModel,
            isViewLoaded
        else {
            return
        }

        if vm.howlingControlGainReductionIndicationSupported {
            let activeState = vm.howlingControlGainReductionActive()
            leftHCGainReductionIndicatorImageView?.tintColor = activeState.left ? view.tintColor : UIColor.systemGray4
            rightHCGainReductionIndicatorImageView?.tintColor = activeState.right ? view.tintColor : UIColor.systemGray4
        }
    }

    func updateOnNoiseID() {
        guard
            let vm = viewModel as? AudioCurationDemoViewModel,
            isViewLoaded
        else {
            return
        }

        if vm.noiseIDSupported {
            noiseIDCategoryTitleLabel?.alpha = vm.noiseIDState ? 1.0 : 0.5
            noiseIDCategoryValueLabel?.alpha = vm.noiseIDState ? 1.0 : 0.5

            noiseIDCategoryValueLabel?.text = vm.noiseIDCategoryDescription
        }
    }

    func updateOnAAHStateChanged() {
        guard
            let vm = viewModel as? AudioCurationDemoViewModel,
            isViewLoaded
        else {
            return
        }

        AAHSwitch?.setOn(vm.AAHState, animated: false)

        if !vm.AAHGainReductionIndicationSupported {
            leftAAHGainReductionIndicatorImageView?.tintColor = UIColor.systemGray4
            rightAAHGainReductionIndicatorImageView?.tintColor = UIColor.systemGray4
        }
    }

    func updateOnAAHGainReductionChanged() {
        guard
            let vm = viewModel as? AudioCurationDemoViewModel,
            isViewLoaded
        else {
            return
        }

        if vm.AAHGainReductionIndicationSupported {
            let activeState = vm.AAHGainReductionActive()
            leftAAHGainReductionIndicatorImageView?.tintColor = activeState.left ? view.tintColor : UIColor.systemGray4
            rightAAHGainReductionIndicatorImageView?.tintColor = activeState.right ? view.tintColor : UIColor.systemGray4
        }
    }
}

// leakthrough gain
private extension AudioCurationDemoViewController {
    func userChangedNonSteppedLeakthroughGain(_ newValue: Int) {
        guard let vm = viewModel as? AudioCurationDemoViewModel else {
            return
        }
        vm.setNonSteppedLeakthroughGain(newValue)
    }

    func userChangedSteppedLeakthroughGain(_ newValue: Int) {
        guard let vm = viewModel as? AudioCurationDemoViewModel else {
            return
        }
        vm.setSteppedLeakthroughGain(newValue)
    }

    func updateLeakthroughGain() {
        guard let vm = viewModel as? AudioCurationDemoViewModel else {
            return
        }

        let canSet = vm.canSetLeakthroughGain

        if vm.showSteppedLeakthroughGainUI {
            steppedLeakthroughGainSlider?.isEnabled = canSet
            steppedLeakthroughGainValueLabel?.text = "\(vm.leakthroughSteppedGainDB) dB"
            steppedLeakthroughGainSlider?.value = Float(vm.leakthroughSteppedGainLevel - 1) // Slider is 0 based. Value is 1 based
        } else {
            let gain = vm.leakthroughGain

            nonSteppedLeakthroughGainSlider?.isEnabled = canSet
            nonSteppedLeakthroughGainValueLabel?.text = "\(gain)"
            nonSteppedLeakthroughGainSlider?.value = Float(gain)
        }
    }
}

// Enabled

extension AudioCurationDemoViewController {
    func userChangedEnabledSwitch(isOn: Bool) {
        guard let vm = viewModel as? AudioCurationDemoViewModel else {
            return
        }
        vm.setEnabledState(isOn: isOn)
    }

    func userChangedBalance(_ newValue: Float) {
        guard let vm = viewModel as? AudioCurationDemoViewModel else {
            return
        }
        vm.setNewBalance(newValue)
    }

    func userChangedWNDSwitch(isOn: Bool) {
        guard let vm = viewModel as? AudioCurationDemoViewModel else {
            return
        }
        vm.setNewWNDEnabledState(isOn: isOn)
    }

    func userChangedAAHSwitch(isOn: Bool) {
        guard let vm = viewModel as? AudioCurationDemoViewModel else {
            return
        }
        vm.setNewAAHEnabledState(isOn: isOn)
    }
}

// Gain / Adaptation
extension AudioCurationDemoViewController {
    private func updateAdaptationSlider() {
        guard
            let vm = viewModel as? AudioCurationDemoViewModel
        else {
            return
        }
        adaptationSwitch?.setOn(vm.adaptationIsActive, animated: false)
    }

    func userChangedAdaptationSwitch(isOn: Bool) {
        guard let vm = viewModel as? AudioCurationDemoViewModel else {
            return
        }
        vm.setAdaptationState(isOn: isOn)
    }
}

// Howling Control
extension AudioCurationDemoViewController {
    private func updateHowlingDetectionSlider() {
        guard
            let vm = viewModel as? AudioCurationDemoViewModel
        else {
            return
        }
        howlingDetectionSwitch?.setOn(vm.howlingDetectionState, animated: false)
    }

    func userChangedHowlingDetectionSwitch(isOn: Bool) {
        guard let vm = viewModel as? AudioCurationDemoViewModel else {
            return
        }
        vm.setHowlingDetectionState(isOn: isOn)
    }

    private func updateHowlingDetectionGainDials() {
        guard
            let _ = viewModel as? AudioCurationDemoViewModel
        else {
            return
        }
        
        updateGainDials()
    }
}

// Modes
extension AudioCurationDemoViewController {
    private func getAllModeButtons() {
        allModeButtons = [ANCModeButton]()
        var tag = 0
        if let outerSV = modesStackView {
            for view in outerSV.arrangedSubviews {
                if let innerSV = view as? UIStackView {
                    for innerView in innerSV.arrangedSubviews {
                        if let button = innerView as? ANCModeButton {
                            button.activeColor = view.tintColor
                            button.activeBubbleColor = UIColor.systemTeal
                            allModeButtons.append(button)
                            button.addTarget(self, action: #selector(modeButtonTapped(_:)), for: .touchUpInside)
                            button.tag = tag
                            tag += 1
                        }
                    }
                }
            }
        }
    }

    private func presentModesButtons() {
        guard
            let vm = viewModel as? AudioCurationDemoViewModel
        else {
            return
        }

        let modes = vm.availableDemoModes

        for index in (0..<allModeButtons.count).reversed() {
            let button = allModeButtons[index]
            if index < modes.count {
                // Draw mode
                button.superview?.isHidden = false
                button.alpha = 1.0
				let mode = modes[index]
                button.setTitle(mode.action.userVisibleDescription(), for: .normal)
                switch mode.mode {
                case .off:
                    button.bubbleText = "O"
                case .numberedMode(let modeNumber):
                    button.bubbleText = "\(modeNumber)"
                default:
                    button.bubbleText = "?"
                }

                button.active = index == vm.demoModeModeIndex
            } else {
                button.superview?.isHidden = true
            	button.alpha = 0.0
            }
        }
    }

    @objc func modeButtonTapped(_ btn: ANCModeButton) {
        guard let vm = viewModel as? AudioCurationDemoViewModel else {
            return
        }

        let index = btn.tag
        vm.selectDemoModeMode(index: index)
    }
}
