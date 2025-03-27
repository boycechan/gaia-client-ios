//
//  © 2023 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import UIKit

class FeedbackSendingViewController: UIViewController, GaiaViewControllerProtocol {
    var viewModel: GaiaViewModelProtocol?

    @IBOutlet weak var feedbackTextView: UITextView?
    @IBOutlet weak var resultIconImageView: UIImageView?
    @IBOutlet weak var resultLabel: UILabel?
    @IBOutlet weak var resultActionButton: UIButton?

    override var title: String? {
        get {
            return viewModel?.title
        }
        set {}
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.hidesBackButton = true
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewModel?.activate()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        viewModel?.deactivate()
    }

    @IBAction func doneButtonTapped(_: Any) {
        navigationController?.popToRootViewController(animated: true)
    }

    @IBAction func resultActionButtonTapped(_: Any) {
        guard let vm = viewModel as? FeedbackSendingViewModel else {
            return
        }

        switch vm.state {
        case .fail(reason: _):
            UIPasteboard.general.string = vm.feedbackText.string
        case .success(issue: _, link: let link):
            UIPasteboard.general.string = link
        default:
            break
        }
    }
}

extension FeedbackSendingViewController {
    func update() {
        guard let vm = viewModel as? FeedbackSendingViewModel else {
            return
        }
        feedbackTextView?.attributedText = vm.feedbackText
        switch vm.state {
        case .uploading:
            resultActionButton?.isHidden = true
            resultLabel?.text = String(localized: "Uploading feedback.", comment: "Uploading Feedback...")
            resultIconImageView?.image = UIImage(systemName: "arrow.up.circle")
            resultIconImageView?.tintColor = Theming.regularButtonColor()
        case .fail(reason: let reason):
            addDoneButton()
            resultActionButton?.isHidden = false
            resultActionButton?.setTitle(String(localized: "COPY TO CLIPBOARD", comment: "COPY TO CLIPBOARD"), for: .normal)
            resultActionButton?.setTitle(String(localized: "COPY TO CLIPBOARD", comment: "COPY TO CLIPBOARD"), for: .selected)
            resultActionButton?.setTitle(String(localized: "COPY TO CLIPBOARD", comment: "COPY TO CLIPBOARD"), for: .highlighted)
            resultActionButton?.setTitle(String(localized: "COPY TO CLIPBOARD", comment: "COPY TO CLIPBOARD"), for: .disabled)

            resultLabel?.text = reason.count > 0 ? reason : String(localized: "Unable to send feedback.", comment: "Unable to Send Feedback")
            resultIconImageView?.image = UIImage(systemName: "xmark.circle")
            resultIconImageView?.tintColor = Theming.destructiveButtonColor()
        case .success(issue: let issue, link: _):
            addDoneButton()
            resultActionButton?.isHidden = false
            resultActionButton?.setTitle(String(localized: "COPY LINK", comment: "COPY LINK"), for: .normal)
            resultActionButton?.setTitle(String(localized: "COPY LINK", comment: "COPY LINK"), for: .selected)
            resultActionButton?.setTitle(String(localized: "COPY LINK", comment: "COPY LINK"), for: .highlighted)
            resultActionButton?.setTitle(String(localized: "COPY LINK", comment: "COPY LINK"), for: .disabled)

            resultLabel?.text = String(localized: "\(issue) created.", comment: "Feedback UI")
            resultIconImageView?.image = UIImage(systemName: "checkmark.circle")
            resultIconImageView?.tintColor = Theming.affirmativeButtonColor()
        default:
            break
        }
    }

    func addDoneButton() {
        let b = UIBarButtonItem(barButtonSystemItem: .done,
                                target: self,
                                action: #selector(doneButtonTapped(_:)))
        navigationItem.setRightBarButton(b, animated: false)
    }
}
