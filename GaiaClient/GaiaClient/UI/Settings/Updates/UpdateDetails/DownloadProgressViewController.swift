//
//  © 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import UIKit

class DownloadProgressViewController: UIViewController, GaiaViewControllerProtocol {
    var viewModel: GaiaViewModelProtocol?

    @IBOutlet weak var actionButton: UIButton?
    @IBOutlet weak var progressBar: UIProgressView?
    @IBOutlet weak var statusLabel: UILabel?
    @IBOutlet weak var progressLabel: UILabel?
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

extension DownloadProgressViewController {
    func update() {
        guard let vm = viewModel as? DownloadProgressViewModel else {
            return
        }

        actionButton?.setTitle(String(localized: "Cancel", comment: "Cancel"), for: .normal)
        actionButton?.setTitle(String(localized: "Cancel", comment: "Cancel"), for: .highlighted)
        actionButton?.setTitle(String(localized: "Cancel", comment: "Cancel"), for: .selected)

        switch vm.state {
        case .waiting:
            actionButton?.isHidden = true
            progressBar?.isHidden = true
            statusLabel?.isHidden = false
            statusLabel?.text = String(localized: "Preparing.", comment: "Starting download.")
            progressLabel?.isHidden = true
            statusIcon?.image = UIImage(systemName: "arrow.down.circle")
            statusIcon?.tintColor = Theming.regularButtonColor()
        case .starting:
            actionButton?.isHidden = false
            progressBar?.isHidden = false
            progressBar?.progress = 0.0
            statusLabel?.isHidden = false
            statusLabel?.text = String(localized: "Starting download.", comment: "Starting download.")
            progressLabel?.isHidden = true
            statusIcon?.image = UIImage(systemName: "arrow.down.circle")
            statusIcon?.tintColor = Theming.regularButtonColor()
        case .transferring(percent: let percent):
            actionButton?.isHidden = false
            progressBar?.isHidden = false
            progressBar?.progress = Float(percent / 100.0)
            statusLabel?.isHidden = false
            statusLabel?.text = String(localized: "Downloading.", comment: "Downloading.")
            progressLabel?.isHidden = false
            let integerPercent = Int(percent)
            progressLabel?.text = String(localized: "\(integerPercent) %", comment: "DFU progress label")
            statusIcon?.image = UIImage(systemName: "arrow.down.circle")
            statusIcon?.tintColor = Theming.regularButtonColor()
        case .failed(reason: let reason):
            actionButton?.isHidden = true
            progressBar?.isHidden = true
            statusLabel?.isHidden = false
            statusLabel?.text = reason.count > 0 ? reason : String(localized: "Unable to download file.", comment: "Unable to download file.")
            
            progressLabel?.isHidden = true
            statusIcon?.image = UIImage(systemName: "xmark.circle")
            statusIcon?.tintColor = Theming.destructiveButtonColor()
        case .aborting:
            actionButton?.isHidden = true
            progressBar?.isHidden = true
            progressBar?.progress = 0.0
            statusLabel?.isHidden = false
            statusLabel?.text = String(localized: "Cancelling download.", comment: "Cancelling download.")
            progressLabel?.isHidden = true
            statusIcon?.image = UIImage(systemName: "xmark.circle")
            statusIcon?.tintColor = Theming.destructiveButtonColor()
        case .aborted:
            actionButton?.isHidden = true
            progressBar?.isHidden = true
            progressBar?.progress = 0.0
            statusLabel?.isHidden = false
            statusLabel?.text = String(localized: "Download cancelled.", comment: "Download cancelled.")
            progressLabel?.isHidden = true
            statusIcon?.image = UIImage(systemName: "xmark.circle")
            statusIcon?.tintColor = Theming.destructiveButtonColor()
        case .completed(data: _):
            progressBar?.isHidden = true
            progressBar?.progress = 0.0
            statusLabel?.isHidden = false
            actionButton?.isHidden = false
            actionButton?.isEnabled = vm.isDeviceConnected()
            progressLabel?.isHidden = true

            actionButton?.setTitle(String(localized: "Upgrade", comment: "Upgrade"), for: .normal)
            actionButton?.setTitle(String(localized: "Upgrade", comment: "Upgrade"), for: .highlighted)
            actionButton?.setTitle(String(localized: "Upgrade", comment: "Upgrade"), for: .selected)

            if vm.isDeviceConnected() {
                statusLabel?.text = String(localized: "File ready.", comment: "File ready.")
                statusIcon?.image = UIImage(systemName: "checkmark.circle")
                statusIcon?.tintColor = Theming.affirmativeButtonColor()
            } else {
                statusLabel?.text = String(localized: "Disconnected.", comment: "File ready.")
                statusIcon?.image = UIImage(systemName: "exclamationmark.circle")
                statusIcon?.tintColor = Theming.destructiveButtonColor()
            }
        }
    }

    @IBAction func buttonTapped(_ : Any) {
        guard let vm = viewModel as? DownloadProgressViewModel else {
            return
        }

        switch vm.state {
        case .transferring(percent: _),
                .starting,
                .waiting:
            vm.abortRequested()
        case .completed:
            if vm.isDeviceConnected() {
                vm.upgradeRequested()
            } else {
                
            }
        default:
            break
        }
    }
}
