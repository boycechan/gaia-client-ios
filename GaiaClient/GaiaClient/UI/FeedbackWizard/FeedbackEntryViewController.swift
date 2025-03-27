//
//  © 2023 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import UIKit
import GaiaLogger

class FeedbackEntryViewController: UIViewController, GaiaViewControllerProtocol {
    var viewModel: GaiaViewModelProtocol?
    private weak var sendBarButton: UIBarButtonItem?

    @IBOutlet weak var titleTextField: UITextField?
    @IBOutlet weak var descriptionTextView: UITextView?
    @IBOutlet weak var descriptionPlaceholderTextView: UITextView?
    @IBOutlet weak var reporterTextField: UITextField?
    @IBOutlet weak var hardwareBuildIDTextField: UITextField?

    @IBOutlet weak var scrollView: UIScrollView?

    var descriptionPlaceholderText: String?


    override var title: String? {
        get {
            return viewModel?.title
        }
        set {}
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let b = UIBarButtonItem(image: UIImage(systemName: "paperplane.fill"),
                                style: .plain,
                                target: self,
                                action: #selector(sendFeedback(_:)))
        navigationItem.setRightBarButton(b, animated: false)
        sendBarButton = b

        let flexButtonItem = UIBarButtonItem(barButtonSystemItem: .flexibleSpace,
                                             target: nil,
                                             action: nil)

        let doneButtonItem = UIBarButtonItem(barButtonSystemItem: .done,
                                            target: self,
                                            action: #selector(doneButton(_:)))

        let doneButtonItemToolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        doneButtonItemToolbar.items = [flexButtonItem, doneButtonItem]
        doneButtonItemToolbar.sizeToFit()

        let previousButtonItem = UIBarButtonItem(image: UIImage(systemName: "chevron.up"),
                                             style: .plain,
                                            target: self,
                                            action: #selector(previousButton(_:)))

        let nextButtonItem = UIBarButtonItem(image: UIImage(systemName: "chevron.down"),
                                             style: .plain,
                                            target: self,
                                            action: #selector(nextButton(_:)))

        let nextButtonItemToolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        nextButtonItemToolbar.items = [previousButtonItem, nextButtonItem, flexButtonItem, doneButtonItem]
        nextButtonItemToolbar.sizeToFit()

        titleTextField?.inputAccessoryView = nextButtonItemToolbar
        descriptionTextView?.inputAccessoryView = nextButtonItemToolbar
        reporterTextField?.inputAccessoryView = nextButtonItemToolbar
        hardwareBuildIDTextField?.inputAccessoryView = nextButtonItemToolbar

        if let titleTextField {
            let titlePaddingView = UIView(frame: CGRectMake(0, 0, 5, titleTextField.frame.height))
            titleTextField.leftView = titlePaddingView
            titleTextField.leftViewMode = .always
        }

        if let reporterTextField {
            let reporterPaddingView = UIView(frame: CGRectMake(0, 0, 5, reporterTextField.frame.height))
            reporterTextField.leftView = reporterPaddingView
            reporterTextField.leftViewMode = .always
        }

        if let hardwareBuildIDTextField {
            let buildIDPaddingView = UIView(frame: CGRectMake(0, 0, 5, hardwareBuildIDTextField.frame.height))
            hardwareBuildIDTextField.leftView = buildIDPaddingView
            hardwareBuildIDTextField.leftViewMode = .always
        }

        descriptionPlaceholderText = String(localized: "Required.", comment: "Placeholder Text")
        descriptionPlaceholderTextView?.text = descriptionPlaceholderText
        descriptionPlaceholderTextView?.delegate = self
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        NotificationCenter.default.addObserver(self, selector: #selector(adjustScrollViewForKeyboard), name: UIResponder.keyboardWillHideNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(adjustScrollViewForKeyboard), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)

        viewModel?.activate()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        NotificationCenter.default.removeObserver(self)
        viewModel?.deactivate()
    }

    @objc func doneButton(_: Any) {
        view.endEditing(true)
        update()
    }

    @objc func nextButton(_: Any) {
        update()
        if titleTextField?.isFirstResponder ?? false {
            descriptionTextView?.becomeFirstResponder()
        } else if descriptionTextView?.isFirstResponder ?? false {
            reporterTextField?.becomeFirstResponder()
        } else if reporterTextField?.isFirstResponder ?? false {
            hardwareBuildIDTextField?.becomeFirstResponder()
        } else {
            titleTextField?.becomeFirstResponder()
        }
        update()
    }

    @objc func previousButton(_: Any) {
        update()
        if titleTextField?.isFirstResponder ?? false {
            hardwareBuildIDTextField?.becomeFirstResponder()
        } else if descriptionTextView?.isFirstResponder ?? false {
            titleTextField?.becomeFirstResponder()
        } else if reporterTextField?.isFirstResponder ?? false {
            descriptionTextView?.becomeFirstResponder()
        } else {
            reporterTextField?.becomeFirstResponder()
        }
        update()
    }

    @IBAction func didFinishEditingField(sender: UITextField) {
        update()
    }

    @objc func sendFeedback(_: Any) {
        view.endEditing(true)
        
        guard let viewModel = viewModel as? FeedbackEntryViewModel else {
            return
        }

        viewModel.sendFeedback(title: titleTextField?.text ?? "",
                               description: descriptionTextView?.text ?? "",
                               reporter: reporterTextField?.text,
                               hardwareBuildID: hardwareBuildIDTextField?.text)
    }

    @objc func adjustScrollViewForKeyboard(note: Notification) {
        guard
            let scrollView = scrollView,
            let keyboardValue = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue
        else {
            return
        }

        let keyboardScreenFrame = keyboardValue.cgRectValue
        let keyboardViewFrame = view.convert(keyboardScreenFrame, from: view.window)

        if note.name == UIResponder.keyboardWillHideNotification {
            scrollView.contentInset = .zero
        } else {
            scrollView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: keyboardViewFrame.height - view.safeAreaInsets.bottom, right: 0)
        }

        scrollView.scrollIndicatorInsets = scrollView.contentInset
    }
}

extension FeedbackEntryViewController {
    func update() {
        guard let viewModel = viewModel as? FeedbackEntryViewModel else {
            return
        }

        sendBarButton?.isEnabled = viewModel.feedbackValid(title: titleTextField?.text ?? "",
                                                           description: descriptionTextView?.text ?? "",
                                                           reporter: reporterTextField?.text,
                                                           hardwareBuildID: hardwareBuildIDTextField?.text)
    }
}

extension FeedbackEntryViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        guard textView == descriptionTextView else {
            return
        }

        if descriptionTextView?.text.isEmpty ?? false {
            descriptionPlaceholderTextView?.text = descriptionPlaceholderText
        } else {
            descriptionPlaceholderTextView?.text = ""
        }
    }
}
