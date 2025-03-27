//
//  © 2020 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import UIKit

class UpdateProgressViewController: UIViewController, GaiaViewControllerProtocol {
	var viewModel: GaiaViewModelProtocol?
    
    @IBOutlet weak var exitButton: UIButton?
    @IBOutlet weak var progressBar: UIProgressView?
    @IBOutlet weak var statusText: UILabel?
    @IBOutlet weak var etaText: UILabel?
    @IBOutlet weak var statusIcon: UIImageView?
    
    override var title: String? {
        get {
            return viewModel?.title
        }
        set {}
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewModel?.activate()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        viewModel?.deactivate()
    }
}

extension UpdateProgressViewController {
    func update() {
        guard let vm = viewModel as? UpdateProgressViewModel else {
            return
        }

        let btnText = vm.canExit ?
            String(localized: "Done", comment: "Button Text") :
            String(localized: "Cancel", comment: "Button Text")

        exitButton?.setTitle(btnText, for: .normal)
        exitButton?.setTitle(btnText, for: .highlighted)
        exitButton?.setTitle(btnText, for: .selected)

        statusText?.text = vm.statusText

        if vm.progressText.count > 0 {
            etaText?.isHidden = false
            etaText?.text = vm.progressText
        } else {
            etaText?.isHidden = true
        }

        progressBar?.isHidden = !(vm.state != .waitingToStart && !vm.canExit)
        progressBar?.progress = Float(vm.progress)

        if vm.canExit {
            switch vm.state {
            case .waitingToStart, .running:
                statusIcon?.image = UIImage(systemName: "arrow.up.circle")
                statusIcon?.tintColor = Theming.regularButtonColor()
            case .finishedWithSuccess:
                statusIcon?.image = UIImage(systemName: "checkmark.circle")
                statusIcon?.tintColor = Theming.affirmativeButtonColor()
            case .finishedWithFailure:
                statusIcon?.image = UIImage(systemName: "xmark.circle")
                statusIcon?.tintColor = Theming.destructiveButtonColor()
            }
        } else {
            statusIcon?.image = UIImage(systemName: "arrow.up.circle")
            statusIcon?.tintColor = Theming.regularButtonColor()
        }
    }

    @IBAction func buttonTapped(_ : Any) {
        guard let vm = viewModel as? UpdateProgressViewModel else {
			return
        }

        if vm.canExit {
            vm.doneRequested()
        } else {
            vm.abortRequested()
        }
    }
}
