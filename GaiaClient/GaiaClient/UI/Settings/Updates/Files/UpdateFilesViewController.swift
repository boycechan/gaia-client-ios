//
//  © 2020 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import UIKit

class UpdateFilesViewController: BaseTableViewController {
    override func viewDidLoad() {
        let filesButton = UIBarButtonItem(image: UIImage(systemName: "folder"),
                                          style: .plain,
                                          target: self,
                                          action: #selector(filesButtonTapped(_:)))
        navigationItem.rightBarButtonItems = [filesButton]
    }

    @objc func filesButtonTapped(_: Any) {
        guard let vm = viewModel as? UpdateFilesViewModel else {
            return
        }

        vm.showFileBrowser()
    }
}
