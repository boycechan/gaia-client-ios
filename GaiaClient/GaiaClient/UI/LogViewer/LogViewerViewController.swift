//
//  © 2023 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import UIKit
import LinkPresentation
import UniformTypeIdentifiers

class LogViewerViewController: UIViewController, GaiaViewControllerProtocol {
    var viewModel: GaiaViewModelProtocol?

    @IBOutlet weak var textView: UITextView?

    override func viewDidLoad() {
        super.viewDidLoad()
        let b = UIBarButtonItem(barButtonSystemItem: .action,
                                target: self,
                                action: #selector(shareSelectedText(_:)))
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

    override var title: String? {
        get {
            return viewModel?.title
        }
        set {}
    }
    
    func update() {
        guard let vm = viewModel as? LogViewerViewModel else {
			return
        }

        let evenAttributes: [NSAttributedString.Key: Any] = [.foregroundColor : UIColor.label]
        let oddAttributes: [NSAttributedString.Key: Any] = [.foregroundColor : UIColor.secondaryLabel]

        let text = NSMutableAttributedString(string: "", attributes: evenAttributes)
        for i in 0 ..< vm.logLines.count {
            let line = vm.logLines[i] + "\n"
            text.append(NSAttributedString(string: line, attributes: i % 2 == 0 ? evenAttributes : oddAttributes))
        }
        textView?.attributedText = text
    }

    @objc func shareSelectedText(_: Any) {
        var selectedText = textView?.text ?? ""

        // If the user has selected some then use that instead
        if let textRange = textView?.selectedTextRange, !textRange.isEmpty {
            selectedText = textView?.text(in: textRange) ?? ""
        }

        // So that we get sensible descriptions in the UI, we need to save to temporary file

        guard
            let infoDictionary = Bundle.main.infoDictionary,
            let appName = infoDictionary["CFBundleName"] as? String,
            selectedText.count > 0,
            let data = selectedText.data(using: .utf8)
        else {
            return
        }

        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = .current
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
		formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        let dateStr = formatter.string(from: Date())

        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let path = documentsDirectory.appendingPathComponent(appName + "-" + dateStr + ".log", isDirectory: false)

        do {
            try data.write(to: path)
        } catch let error {
            print(error.localizedDescription)
        }

        let activityViewController = UIActivityViewController(activityItems: [path as Any], applicationActivities: nil)
        activityViewController.popoverPresentationController?.sourceView = view
        activityViewController.excludedActivityTypes = [.postToFacebook, .postToFlickr, .postToTwitter, .postToTencentWeibo, .postToWeibo]
        activityViewController.completionWithItemsHandler = { (activity, success, items, error) in
            if success {
                try? FileManager.default.removeItem(at: path)
            }
        }

        // present the view controller
        self.present(activityViewController, animated: true)
    }
}
