//
//  © 2021 - 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import UIKit

class AudioCurationIntroViewController: BaseTableViewController {

    @IBOutlet private weak var demoModeButton: UIButton?

    override func update() {
        super.update()
        guard let vm = viewModel as? AudioCurationIntroViewModel else {
            return
        }

        demoModeButton?.isHidden = !vm.isDemoModePermitted
    }

    @IBAction func demoModeButtonTapped(_ btn: UIButton) {
        guard let vm = viewModel as? AudioCurationIntroViewModel else {
            return
        }

        vm.enterDemoMode()
    }
}
