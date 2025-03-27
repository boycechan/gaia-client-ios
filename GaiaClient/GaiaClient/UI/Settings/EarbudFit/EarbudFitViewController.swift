//
//  © 2021 - 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import UIKit

class EarbudFitViewController: UIViewController, GaiaViewControllerProtocol  {

    var viewModel: GaiaViewModelProtocol?

    @IBOutlet weak var overlayView: UIView?
    @IBOutlet weak var overlayViewLabel: UILabel?

    @IBOutlet weak var leftEarbudFitQualityIcon: UIImageView?
    @IBOutlet weak var rightEarbudFitQualityIcon: UIImageView?
    @IBOutlet weak var titleLabel: UILabel?
    @IBOutlet weak var bodyLabel: UILabel?
    @IBOutlet weak var inProgressSpinner: UIActivityIndicatorView?
    @IBOutlet weak var playCancelButton: UIButton?


    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewModel?.activate()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        viewModel?.deactivate()
    }

    func update() {
        guard let vm = viewModel as? EarbudFitViewModel else {
            overlayView?.isHidden = false
            overlayViewLabel?.text = String(localized: "No information", comment: "Overlay")
            return
        }

        if vm.isDeviceConnected() {
            overlayView?.isHidden = true
        } else {
            overlayView?.isHidden = false
            overlayViewLabel?.text = String(localized: "Device disconnected", comment: "Updates Overlay")
            return
        }

        switch vm.state {
        case .awaitingFirstRun:
            titleLabel?.text = String(localized: "Earbud Fit Test", comment: "Test screen title")
            bodyLabel?.text = String(localized: "Place both earbuds in your ears. Once they are secure, press start to test the fit.", comment:"Earbud test text")
            leftEarbudFitQualityIcon?.isHidden = true
            rightEarbudFitQualityIcon?.isHidden = true
            inProgressSpinner?.isHidden = true
            playCancelButton?.backgroundColor = UIColor(named: "color-fitbtn-play")
            setButtonText(String(localized: "Start", comment: "Button title"))
        case .testRunning:
            titleLabel?.text = String(localized: "Test in Progress", comment: "Test screen title")
            bodyLabel?.text = String(localized: "Do not remove earbuds.", comment:"Earbud test text")
            leftEarbudFitQualityIcon?.isHidden = true
            rightEarbudFitQualityIcon?.isHidden = true
            inProgressSpinner?.isHidden = false
            inProgressSpinner?.startAnimating()
            playCancelButton?.backgroundColor = Theming.destructiveButtonColor()
            setButtonText(String(localized: "Stop Test", comment: "Button title"))
        case .testDone(let leftResult, let rightResult):
            if leftResult == .failed && rightResult == .failed {
                titleLabel?.text = String(localized: "Test Failed", comment: "Test screen title")
            } else {
                titleLabel?.text = String(localized: "Test Complete", comment: "Test screen title")
            }

            bodyLabel?.text = generateTextForResults(leftResult: leftResult, rightResult: rightResult)
            leftEarbudFitQualityIcon?.isHidden = false
            showIconForResult(leftResult, inImageView: leftEarbudFitQualityIcon)
            rightEarbudFitQualityIcon?.isHidden = false
            showIconForResult(rightResult, inImageView: rightEarbudFitQualityIcon)
            inProgressSpinner?.isHidden = true
            inProgressSpinner?.stopAnimating()
            playCancelButton?.backgroundColor = UIColor(named: "color-fitbtn-play")
            setButtonText(String(localized: "Start", comment: "Button title"))
        }
    }

    func setButtonText(_ str: String) {
        playCancelButton?.setTitle(str, for: .normal)
        playCancelButton?.setTitle(str, for: .highlighted)
        playCancelButton?.setTitle(str, for: .selected)
    }

    func resultText(_ result: EarbudFitViewModel.FitTestResult, isLeft: Bool) -> String{
        if isLeft {
            switch result {
            case .good:
                return String(localized: "Your left earbud is a good fit.", comment: "Fit result - left good.")
            case .poor:
                return String(localized: "Your left earbud is a poor fit.\nTry changing the earbud tip and press Start to test again.", comment: "Fit result - left poor.")
            case .failed:
                return String(localized: "The test failed for your left earbud.\nPress Start to test again.", comment: "Fit result - left Failed.")
            }
        } else {
            switch result {
            case .good:
                return String(localized: "Your right earbud is a good fit.", comment: "Fit result - right good.")
            case .poor:
                return String(localized: "Your right earbud is a poor fit.\nTry changing the earbud tip and press Start to test again.", comment: "Fit result - right poor.")
            case .failed:
                return String(localized: "The test failed for your right earbud.\nPress Start to test again.", comment: "Fit result - right Failed.")
            }
        }
    }

    func generateTextForResults(leftResult: EarbudFitViewModel.FitTestResult,
                                rightResult: EarbudFitViewModel.FitTestResult) -> String {

        if leftResult == rightResult {
            // Both the same
            switch leftResult {
            case .good:
                return String(localized: "Both your earbuds are a good fit.", comment: "Fit result - both good.")
            case .poor:
                return String(localized: "Both your earbuds are a poor fit.\n\nTry changing the earbud tips and press Start to test again.", comment: "Fit result - both poor.")
            case .failed:
                return String(localized: "The test was not completed.\n\nPress the Start button to test again.", comment: "Fit result - both failed.")
            }
        }

		var res = ""
        res.append(resultText(leftResult, isLeft: true))
        res.append("\n\n")
        res.append(resultText(rightResult, isLeft: false))

        return res
    }

    func showIconForResult(_ result: EarbudFitViewModel.FitTestResult,
                           inImageView iv: UIImageView?) {
        switch result {
        case .good:
            iv?.image = UIImage(systemName: "checkmark.circle.fill")
            iv?.tintColor = UIColor.systemGreen
        case .poor:
            iv?.image = UIImage(systemName: "exclamationmark.circle.fill")
            iv?.tintColor = UIColor.systemYellow
        case .failed:
            iv?.image = UIImage(systemName: "xmark.circle.fill")
            iv?.tintColor = UIColor.systemRed
        }
    }

    @IBAction func playStopTapped(_ btn: UIButton) {
        guard let vm = viewModel as? EarbudFitViewModel else {
            return
        }

        if vm.isTestRunning {
            vm.cancelTest()
        } else {
            vm.startTest()
        }
    }
}
