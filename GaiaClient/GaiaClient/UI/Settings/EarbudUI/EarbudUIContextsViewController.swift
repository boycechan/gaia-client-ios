//
//  © 2021 - 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import UIKit

class EarbudUIActionsTableViewCell: UITableViewCell {
    @IBOutlet weak var titleLabel: UILabel?
    @IBOutlet weak var leftButton: ClosureButton?
    @IBOutlet weak var rightButton: ClosureButton?
    @IBOutlet weak var checkmarkImageView: UIImageView?

    override func prepareForReuse() {
        super.prepareForReuse()
        leftButton?.tapHandler = nil
        rightButton?.tapHandler = nil
    }
}

class EarbudUIContextsViewController: UIViewController, GaiaViewControllerProtocol {

    let selectedColor = UIColor(named: "color-btn-earbudui-selected")
	let unselectedColor = UIColor(named: "color-btn-earbudui-unselected")

    var viewModel: GaiaViewModelProtocol?

    @IBOutlet weak var tableView: UITableView?
    @IBOutlet weak var overlayView: UIView?
    @IBOutlet weak var overlayViewLabel: UILabel?
    @IBOutlet weak var pageSegmentedControl: UISegmentedControl?

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
        guard
            let vm = viewModel as? EarbudUIContextsViewModel,
            let pageSegmentedControl = pageSegmentedControl
        else {
            overlayView?.isHidden = false
            overlayViewLabel?.text = String(localized: "No information", comment: "Overlay")
            return
        }

        let connected = vm.isDeviceConnected()

        let showOverlay = vm.tableViewStructure.count == 0 || !connected
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
        // Load Segmented View
        if pageSegmentedControl.numberOfSegments != vm.pageTitles.count {
            pageSegmentedControl.removeAllSegments()
            for title in vm.pageTitles {
                pageSegmentedControl.insertSegment(withTitle: title, at: pageSegmentedControl.numberOfSegments, animated: false)
            }
            if pageSegmentedControl.numberOfSegments > 0 {
            	pageSegmentedControl.selectedSegmentIndex = 0
            }
        }

        tableView?.reloadData()
    }

    func reloadSection(_ section: Int) {
        tableView?.reloadSections(IndexSet(integer: section), with: .none)
    }

    @IBAction func didTapSegmentedControl(_ control: UISegmentedControl) {
        guard
            let vm = viewModel as? EarbudUIContextsViewModel
        else {
            return
        }
        vm.selectNewPage(index: control.selectedSegmentIndex)
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

    func showWarningAlert(title: String, message: String, completion: @escaping (Bool) -> ()) {
        let alert = UIAlertController(title: title,
                                      message: message,
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: String(localized: "Cancel", comment: "Cancel"),
                                      style: .default,
                                      handler: { _ in
                                        completion(false)
                                      }))
        alert.addAction(UIAlertAction(title: String(localized: "Proceed", comment: "Proceed"),
                                      style: .destructive,
                                      handler: { _ in
                                        completion(true)
                                      }))
        present(alert, animated: true, completion: nil)
    }
}

extension EarbudUIContextsViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard
            let vm = viewModel as? EarbudUIContextsViewModel,
            section < vm.tableViewStructure.count,
            vm.tableViewStructure.count > 1
        else {
            return nil
        }

        return vm.tableViewStructure[section].title
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        guard
            let vm = viewModel as? EarbudUIContextsViewModel
        else {
            return 0
        }
        return vm.tableViewStructure.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard
            let vm = viewModel as? EarbudUIContextsViewModel,
            section < vm.tableViewStructure.count
        else {
            return 0
        }
        return vm.tableViewStructure[section].rows.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard
            let vm = viewModel as? EarbudUIContextsViewModel,
            indexPath.section < vm.tableViewStructure.count,
            indexPath.row < vm.tableViewStructure[indexPath.section].rows.count
        else {
            return UITableViewCell()
        }

        let info = vm.tableViewStructure[indexPath.section].rows[indexPath.row]
        switch info.type {
        case .toggle(let enabled, let isOn):
            if let cell = tableView.dequeueReusableCell(withIdentifier: "SettingsTableViewCell") as? SettingsTableViewCell {
                cell.viewOption = .titleAndSwitch
                cell.titleLabel?.text = info.title
                cell.onOffSwitch?.isEnabled = enabled
                cell.onOffSwitch?.setOn(isOn, animated: false)
                cell.onOffSwitch?.tapHandler = { [weak self] sw in
                    guard
                        let self = self,
                        let vm = self.viewModel as? EarbudUIContextsViewModel,
                        let ip = self.tableView?.indexPath(for: cell) else {
                            return
                    }
                    vm.didToggleShowLeftRight(newState: sw.isOn, section: ip.section)
                }
                return cell
            }
        case .action(let touchpadInfo):
            if let cell = tableView.dequeueReusableCell(withIdentifier: "EarbudUIActionsTableViewCell") as? EarbudUIActionsTableViewCell {

                let showLeftRight = vm.tableViewStructure[indexPath.section].showLeftRight
                cell.leftButton?.isHidden = !showLeftRight
                cell.rightButton?.isHidden = !showLeftRight
                cell.checkmarkImageView?.isHidden = showLeftRight || touchpadInfo == .none

                cell.leftButton?.tintColor = unselectedColor
                cell.leftButton?.accessibilityIdentifier = String(localized: "\(info.title): Left Inactive", comment: "Earbud UI Button State")
                cell.leftButton?.accessibilityLabel = String(localized: "\(info.title): Left Inactive", comment: "Earbud UI Button State")

                cell.rightButton?.tintColor = unselectedColor
                cell.rightButton?.accessibilityIdentifier = String(localized: "\(info.title): Right Inactive", comment: "Earbud UI Button State")
                cell.rightButton?.accessibilityLabel = String(localized: "\(info.title): Right Inactive", comment: "Earbud UI Button State")

                cell.checkmarkImageView?.tintColor = unselectedColor
                cell.checkmarkImageView?.accessibilityIdentifier = String(localized: "\(info.title): Inactive", comment: "Earbud UI Button State")
                cell.checkmarkImageView?.accessibilityLabel = String(localized: "\(info.title): Inactive", comment: "Earbud UI Button State")

                cell.titleLabel?.text = info.title

                switch touchpadInfo {
                case .none:
                    break
                case .single:
                    cell.checkmarkImageView?.tintColor = selectedColor
                    cell.checkmarkImageView?.accessibilityIdentifier = String(localized: "\(info.title): Active", comment: "Earbud UI Button State")
                    cell.checkmarkImageView?.accessibilityLabel = String(localized: "\(info.title): Active", comment: "Earbud UI Button State")
                case .right:
                    cell.rightButton?.tintColor = selectedColor
                    cell.rightButton?.accessibilityIdentifier = String(localized: "\(info.title): Right Active", comment: "Earbud UI Button State")
                    cell.rightButton?.accessibilityLabel = String(localized: "\(info.title): Right Active", comment: "Earbud UI Button State")
                case .left:
                    cell.leftButton?.tintColor = selectedColor
                    cell.leftButton?.accessibilityIdentifier = String(localized: "\(info.title): Left Active", comment: "Earbud UI Button State")
                    cell.leftButton?.accessibilityLabel = String(localized: "\(info.title): Left Active", comment: "Earbud UI Button State")
                case .both:
                    cell.leftButton?.tintColor = selectedColor
                    cell.leftButton?.accessibilityIdentifier = String(localized: "\(info.title): Left Active", comment: "Earbud UI Button State")
                    cell.leftButton?.accessibilityLabel = String(localized: "\(info.title): Left Active", comment: "Earbud UI Button State")

                    cell.rightButton?.tintColor = selectedColor
                    cell.rightButton?.accessibilityIdentifier = String(localized: "\(info.title): Right Active", comment: "Earbud UI Button State")
                    cell.rightButton?.accessibilityLabel = String(localized: "\(info.title): Right Active", comment: "Earbud UI Button State")
                }

                cell.leftButton?.tapHandler = { [weak self] _ in
                    guard
                        let self = self,
                        let vm = self.viewModel as? EarbudUIContextsViewModel,
                        let ip = self.tableView?.indexPath(for: cell) else {
                            return
                    }
                    vm.didSelectTouchpad(touchpad: .left, indexPath: ip)
                }

                cell.rightButton?.tapHandler = { [weak self] _ in
                    guard
                        let self = self,
                        let vm = self.viewModel as? EarbudUIContextsViewModel,
                        let ip = self.tableView?.indexPath(for: cell) else {
                            return
                    }
                    vm.didSelectTouchpad(touchpad: .right, indexPath: ip)
                }
                return cell
            }
        }
        return UITableViewCell()
    }

    func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        guard
            let vm = viewModel as? EarbudUIContextsViewModel,
            indexPath.section < vm.tableViewStructure.count,
            indexPath.row < vm.tableViewStructure[indexPath.section].rows.count
        else {
            return nil
        }


        let info = vm.tableViewStructure[indexPath.section].rows[indexPath.row]
        switch info.type {
        case .toggle(_, _):
            return nil
        case .action(_):
            let showLeftRight = vm.tableViewStructure[indexPath.section].showLeftRight
            return showLeftRight ? nil : indexPath
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard
            let vm = viewModel as? EarbudUIContextsViewModel,
            indexPath.section < vm.tableViewStructure.count,
            indexPath.row < vm.tableViewStructure[indexPath.section].rows.count
        else {
            return
        }

        tableView.deselectRow(at: indexPath, animated: true)

        let showLeftRight = vm.tableViewStructure[indexPath.section].showLeftRight
        if !showLeftRight {
            // Should it be both or single?
            if let toggleRow = vm.tableViewStructure[indexPath.section].rows.first {
                switch toggleRow.type {
                case .toggle(_, _):
                    vm.didSelectTouchpad(touchpad: .both, indexPath: indexPath)
                case .action(_):
                    vm.didSelectTouchpad(touchpad: .single, indexPath: indexPath)
                }
            }
        }
    }
}
