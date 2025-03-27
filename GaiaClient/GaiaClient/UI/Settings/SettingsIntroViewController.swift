//
//  © 2020 - 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import UIKit
import GaiaLogger

class SettingsIntroViewController: BaseTableViewController {
    @IBOutlet weak var versionLabel: UILabel?
    @IBOutlet weak var appNameLabel: UILabel?
    @IBOutlet weak var featuresTitleLabel: UILabel?
    @IBOutlet weak var featuresListLabel: UILabel?
    @IBOutlet weak var feedbackButtonContainer: UIView?
    @IBOutlet weak var featuresContainer: UIView?
    @IBOutlet weak var viewLogsButton: UIButton?

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        guard let infoDictionary = Bundle.main.infoDictionary,
            let name = infoDictionary["CFBundleName"] as? String,
            let version = infoDictionary["CFBundleShortVersionString"] as? String,
            let build = infoDictionary["CFBundleVersion"] as? String
        else {
            versionLabel?.text = ""
            return
        }
        appNameLabel?.text = name
        versionLabel?.text = String(localized: "Version \(version) (build \(build))", comment: "Intro View App version")

        feedbackButtonContainer?.isHidden = !FeedbackServer.shared.supported
        viewLogsButton?.isHidden = GaiaLogger.shared.logRetrievalProvider() == nil
    }

    override func update() {
        super.update()

        featuresContainer?.isHidden = true

        if let vm = viewModel as? SettingsIntroViewModel {
            let list = vm.userFeatures
            if list.count > 0 {
                featuresContainer?.isHidden = false

                let features = list.count < 16 ? list.joined(separator: "\n") : list.joined(separator: ", ")
                featuresListLabel?.text = features
            }
        }
    }

    @IBAction func startFeedback() {
        if let vm = viewModel as? SettingsIntroViewModel {
            vm.startFeedback()
        }
    }

    @IBAction func startLogViewer() {
        if let vm = viewModel as? SettingsIntroViewModel {
            vm.startLogViewer()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        guard let tableView,
              let footerView = tableView.tableFooterView else {
            return
        }

        let size = footerView.systemLayoutSizeFitting(CGSize(width: tableView.bounds.size.width, height: UIView.layoutFittingCompressedSize.height))
        if footerView.frame.size.height != size.height {
            footerView.frame.size.height = size.height
        }
    }
}
