//
//  © 2021 - 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import UIKit

class StatisticsCategoriesTableViewCell: UITableViewCell {

    @IBOutlet weak var titleLabel: UILabel?
    @IBOutlet weak var recordingImageView: UIImageView?
}

class StatisticsCategoriesViewController: UIViewController, GaiaViewControllerProtocol {
    var viewModel: GaiaViewModelProtocol?

    @IBOutlet weak var tableView: UITableView?
    @IBOutlet weak var overlayView: UIView?
    @IBOutlet weak var overlayViewLabel: UILabel?

    @IBOutlet private weak var stopAllRecordingsButton: UIButton?

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

    override func viewDidLoad() {
        super.viewDidLoad()
        update()
    }

    func update() {
        guard let vm = viewModel as? StatisticsCategoriesViewModel else {
            overlayView?.isHidden = false
            overlayViewLabel?.text = String(localized: "No information", comment: "Overlay")
            return
        }

        let connected = vm.isDeviceConnected()

        let numberOfRows = vm.rows.count

        let showOverlay = numberOfRows == 0 || !connected
        if showOverlay {
            overlayView?.isHidden = false
            if !connected {
                overlayViewLabel?.text = String(localized: "Device disconnected", comment: "Overlay")
            } else {
                // No rows
                overlayViewLabel?.text = String(localized: "No information", comment: "Overlay")
            }
            return
        }

        stopAllRecordingsButton?.isHidden = !vm.isRecording
        overlayView?.isHidden = true
        tableView?.reloadData()
    }

    @IBAction func stopAllRecordingsButtonTapped(_ btn: UIButton) {
        guard let vm = viewModel as? StatisticsCategoriesViewModel else {
            return
        }

        vm.stopAllRecording()
    }
}

extension StatisticsCategoriesViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        guard let _ = viewModel as? StatisticsCategoriesViewModel else {
            return 0
        }
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard
            let vm = viewModel as? StatisticsCategoriesViewModel,
            section == 0
        else {
            return 0
        }
        return vm.rows.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard
            let cell = tableView.dequeueReusableCell(withIdentifier: "StatisticsCategoriesTableViewCell") as? StatisticsCategoriesTableViewCell,
            let vm = viewModel as? StatisticsCategoriesViewModel,
            indexPath.row < vm.rows.count
        else {
            return UITableViewCell()
        }

        cell.accessoryType = .disclosureIndicator
        let row = vm.rows[indexPath.row]

        cell.titleLabel?.text = row.title
        cell.recordingImageView?.isHidden = !row.recording

        return cell
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return nil
    }

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return nil
    }
}

extension StatisticsCategoriesViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return CGFloat.leastNormalMagnitude
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard
            let vm = viewModel as? StatisticsCategoriesViewModel,
            indexPath.row < vm.rows.count
        else {
            return
        }

        tableView.deselectRow(at: indexPath, animated: true)
        vm.selectedItem(indexPath: indexPath)
    }
}
