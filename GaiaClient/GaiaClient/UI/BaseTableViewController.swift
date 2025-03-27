//
//  © 2020 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import UIKit

class BaseTableViewController: UIViewController, GaiaViewControllerProtocol {
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

    override func viewDidLoad() {
        super.viewDidLoad()
        update()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        viewModel?.deactivate()
    }


    func update() {
        guard let vm = viewModel as? GaiaTableViewModelProtocol else {
            overlayView?.isHidden = false
            overlayViewLabel?.text = String(localized: "No information", comment: "Overlay")
            return
        }

        tableView?.reloadData()

        let connected = vm.isDeviceConnected()

        let numberOfRows = vm.sections.first?.rows.count ?? 0

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
    }
}

extension BaseTableViewController: UITableViewDataSource {
    func rowForIndexPath(_ ip: IndexPath) -> SettingRow? {
        guard let vm = viewModel as? GaiaTableViewModelProtocol else {
            return nil
        }

        let sections = vm.sections
        guard
            ip.section < sections.count,
            ip.row < sections[ip.section].rows.count
        else {
            return nil
        }
        return sections[ip.section].rows[ip.row]
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        guard let vm = viewModel as? GaiaTableViewModelProtocol else {
            return 0
        }
        return vm.sections.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard
            let vm = viewModel as? GaiaTableViewModelProtocol,
            section < vm.sections.count
        else {
            return 0
        }
        return vm.sections[section].rows.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard
            let cell = tableView.dequeueReusableCell(withIdentifier: "SettingsTableViewCell") as? SettingsTableViewCell,
            let vm = viewModel as? GaiaTableViewModelProtocol,
            let row = rowForIndexPath(indexPath)
        else {
            return UITableViewCell()
        }

        cell.accessoryType = .none

        switch row {
        case .title(let title, let tapable):
            cell.titleLabel?.text = title
            cell.viewOption = .titleOnly
            if let checkmarkIndexPath = vm.checkmarkIndexPath {
				cell.accessoryType = indexPath == checkmarkIndexPath ? .checkmark : .none
            } else {
                cell.accessoryType = tapable ? .disclosureIndicator : .none
            }
        case .titleAndSubtitle(let title, let subtitle, let tapable):
            cell.titleLabel?.text = title
            cell.subtitleLabel?.text = subtitle
            cell.viewOption = .titleAndSubtitle
            if let checkmarkIndexPath = vm.checkmarkIndexPath {
                cell.accessoryType = indexPath == checkmarkIndexPath ? .checkmark : .none
            } else {
                cell.accessoryType = tapable ? .disclosureIndicator : .none
            }
        case .titleAndSwitch(let title, let switchOn):
            cell.onOffSwitch?.setOn(switchOn, animated: false)
            cell.titleLabel?.text = title
            cell.viewOption = .titleAndSwitch
            cell.onOffSwitch?.tapHandler = { [weak self] _ in
                guard
                    let self = self,
                    let ncViewModel = self.viewModel as? GaiaTableViewModelProtocol,
                    let ip = self.tableView?.indexPath(for: cell) else {
                        return
                }
                ncViewModel.toggledSwitch(indexPath: ip)
            }
        case .titleSubtitleAndSlider(let title, let subtitle, let value, let min, let max):
            cell.titleLabel?.text = title
            cell.subtitleLabel?.text = subtitle
            cell.viewOption = .titleSubtitleAndSlider
            cell.slider?.maximumValue = Float(max)
            cell.slider?.minimumValue = Float(min)
            cell.slider?.value = Float(value)
            cell.slider?.valueChangedHandler = { [weak self] slider in
                guard
                    let self = self,
                    let ncViewModel = self.viewModel as? GaiaTableViewModelProtocol,
                    let ip = self.tableView?.indexPath(for: cell) else {
                        return
                }
                ncViewModel.valueChanged(indexPath: ip, newValue: Int(slider.value))
            }
        }

        return cell
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard
            let vm = viewModel as? GaiaTableViewModelProtocol,
            section < vm.sections.count
        else {
            return nil
        }

        let section = vm.sections[section]
        return section.title
    }

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return nil
    }
}

extension BaseTableViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        guard
            let vm = viewModel as? GaiaTableViewModelProtocol,
            section < vm.sections.count
        else {
            return CGFloat.leastNormalMagnitude
        }

        let section = vm.sections[section]
        return section.title == nil ? CGFloat.leastNormalMagnitude : UITableView.automaticDimension
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        guard
            let vm = viewModel as? GaiaTableViewModelProtocol,
        	indexPath != vm.checkmarkIndexPath
        else {
            return
        }

        vm.selectedItem(indexPath: indexPath)
    }

    func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        guard
        	let row = rowForIndexPath(indexPath)
        else {
            return nil
        }

        switch row {
        case .title(_, let tapable):
            return tapable ? indexPath : nil
        case .titleAndSubtitle(_ , _, let tapable):
            return tapable ? indexPath : nil
        default:
            return nil
        }
    }
}
