//
//  © 2021 - 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import UIKit

class VoiceProcessingSettingsViewController: BaseTableViewController {
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        guard section == 0 else {
            return
        }
        let headerView = view as! UITableViewHeaderFooterView

        // Trademark Requires the label to be lower case.
        headerView.textLabel?.text = String(localized: "QUALCOMM® cVc™ 3-MIC", comment: "cVc")
    }
}
