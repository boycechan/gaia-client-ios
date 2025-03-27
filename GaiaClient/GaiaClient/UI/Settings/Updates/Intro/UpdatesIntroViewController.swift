//
//  © 2020 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import UIKit

class UpdatesIntroViewController: BaseTableViewController {
    @IBOutlet weak var remoteUpdatesButton: UIButton?

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        remoteUpdatesButton?.isHidden = !RemoteDFUServer.shared.supported
    }

    @IBAction func showFiles(_: Any) {
        guard let uiViewModel = viewModel as? UpdatesIntroViewModel else {
            return
        }

        uiViewModel.showFiles()
    }

    @IBAction func showRemoteUpdates(_: Any) {
        guard let uiViewModel = viewModel as? UpdatesIntroViewModel else {
            return
        }

        uiViewModel.showRemoteUpdates()
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
