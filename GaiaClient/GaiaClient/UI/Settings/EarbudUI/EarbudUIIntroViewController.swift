//
//  © 2021 - 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import UIKit

class EarbudUIIntroTableViewCell: UITableViewCell {

    @IBOutlet weak var titleLabel: UILabel?
    @IBOutlet weak var subtitleLabel: UILabel?
    @IBOutlet weak var gestureImageView: UIImageView?

}

class EarbudUIIntroViewController: UIViewController, GaiaViewControllerProtocol {
    var viewModel: GaiaViewModelProtocol?

    @IBOutlet weak var tableView: UITableView?
    @IBOutlet weak var overlayView: UIView?
    @IBOutlet weak var overlayViewLabel: UILabel?

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


    func update() {
        guard let vm = viewModel as? EarbudUIIntroViewModel else {
            overlayView?.isHidden = false
            overlayViewLabel?.text = String(localized: "No information", comment: "Overlay")
            return
        }

        let connected = vm.isDeviceConnected()

        let numberOfRows = vm.gestures.count

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

        overlayView?.isHidden = true
        tableView?.reloadData()
    }

    func showDenialAlert(title: String, message: String, completion: @escaping () -> ()) {
        let alert = UIAlertController(title: title,
                                      message: message,
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: String(localized: "OK", comment: "OK"),
                                      style: .default,
                                      handler: { _ in
                                        completion()
                                      }))
        present(alert, animated: true, completion: nil)
    }

    @IBAction func resetToDefault(_: UIButton) {
        guard let _ = viewModel as? EarbudUIIntroViewModel else {
            return
        }

        let alert = UIAlertController(title: String(localized: "Reset to Defaults", comment: "Warning Dialog"),
                                      message: String(localized: "Are you sure?", comment: "Warning Dialog"),
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: String(localized: "Cancel", comment: "Cancel"),
                                      style: .cancel,
                                      handler: nil))
        alert.addAction(UIAlertAction(title: String(localized: "Reset", comment: "Reset"),
                                      style: .destructive,
                                      handler: { [weak self] _ in
                                        guard let self = self,
                                              let vm = self.viewModel as? EarbudUIIntroViewModel else {
                                            return
                                        }
                                        vm.resetToDefaults()
                                      }))
        present(alert, animated: true, completion: nil)

    }
}

extension EarbudUIIntroViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        guard let _ = viewModel as? EarbudUIIntroViewModel else {
            return 0
        }
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard
            let vm = viewModel as? EarbudUIIntroViewModel,
            section == 0
        else {
            return 0
        }
        return vm.gestures.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard
            let cell = tableView.dequeueReusableCell(withIdentifier: "EarbudUIIntroTableViewCell") as? EarbudUIIntroTableViewCell,
            let vm = viewModel as? EarbudUIIntroViewModel,
            indexPath.row < vm.gestures.count
        else {
            return UITableViewCell()
        }

        cell.accessoryType = .disclosureIndicator
        let gesture = vm.gestures[indexPath.row]

        cell.titleLabel?.text = gesture.name
        cell.subtitleLabel?.text = gesture.subtitle
        cell.gestureImageView?.image = gesture.image?.withRenderingMode(.alwaysTemplate)
        cell.gestureImageView?.tintColor = UIColor(named: "color-btn-earbudui-selected")

        return cell
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
		return nil
    }

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return nil
    }
}

extension EarbudUIIntroViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return CGFloat.leastNormalMagnitude
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard
            let vm = viewModel as? EarbudUIIntroViewModel,
            indexPath.row < vm.gestures.count
        else {
            return
        }

        tableView.deselectRow(at: indexPath, animated: true)
        vm.selectedItem(indexPath: indexPath)
    }
}
