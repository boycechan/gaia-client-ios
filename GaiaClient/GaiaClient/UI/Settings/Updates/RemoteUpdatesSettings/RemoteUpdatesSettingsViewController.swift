//
//  © 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import UIKit

class RemoteUpdatesDateFilterView: UIView {
    @IBOutlet weak var label: UILabel?
    @IBOutlet weak var picker: UIDatePicker?
}

class RemoteUpdatesSettingsViewController: UIViewController, GaiaViewControllerProtocol {
    var viewModel: GaiaViewModelProtocol?

    @IBOutlet weak var overlayView: UIView?
    @IBOutlet weak var overlayViewLabel: UILabel?

    @IBOutlet weak var serverTextField: UITextField?

    @IBOutlet weak var hardwareIdTextField: UITextField?
    @IBOutlet weak var hardwareIdContainer: UIView?

    @IBOutlet weak var requiredTagsLabel: UILabel?
    @IBOutlet weak var excludeTagsLabel: UILabel?

    @IBOutlet weak var dateFilterContainer: RemoteUpdatesDateFilterView?

    @IBOutlet weak var continueButton: UIButton?



    override var title: String? {
        get {
            return viewModel?.title
        }
        set {}
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        dateFilterContainer?.isHidden = true
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewModel?.activate()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        viewModel?.deactivate()
    }

    @IBAction func didFinishEditingField(sender: UITextField) {
        sender.resignFirstResponder()

        guard let vm = viewModel as? RemoteUpdatesSettingsViewModel else {
            return
        }
        vm.server = serverTextField?.text ?? ""
        vm.hardwareId = hardwareIdTextField?.text ?? ""
        update()
    }

    @IBAction func didTapEditRequiredTags(_: Any) {
        showTagEditor(tagType: .required)
    }

    @IBAction func didTapEditExcludedTags(_: Any) {
        showTagEditor(tagType: .excluded)
    }

    func showTagEditor(tagType: TagsEditViewModel.TagType) {
        guard let vm = viewModel as? RemoteUpdatesSettingsViewModel else {
            return
        }
        let vc = vm.viewControllerForTagEdit(tagType: tagType)
        let navContainer = UINavigationController(rootViewController: vc)
        navContainer.modalPresentationStyle = .pageSheet
        if let pc = navContainer.sheetPresentationController {
            pc.detents = [.medium()]
            pc.delegate = self
            present(navContainer, animated: true, completion:nil)
        }
    }
}

extension RemoteUpdatesSettingsViewController: UISheetPresentationControllerDelegate {
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        update()
    }
}

extension RemoteUpdatesSettingsViewController {
    func update() {
        var connected = false
        if let vm = viewModel as? RemoteUpdatesSettingsViewModel{
            connected = vm.isDeviceConnected()
        }

        if !connected {
            overlayView?.isHidden = false
            overlayViewLabel?.text = String(localized: "Device disconnected", comment: "Updates Overlay")
        } else {
            overlayView?.isHidden = true
        }

        if let vm = viewModel as? RemoteUpdatesSettingsViewModel {

            serverTextField?.text = vm.server
            hardwareIdTextField?.text = vm.hardwareId

            let serverIsValid = URL(string: vm.server) != nil

            switch vm.hardwareIDRequired {
            case .notRequired:
                hardwareIdContainer?.isHidden = true
                continueButton?.isEnabled = serverIsValid
                vm.hardwareId = ""
            case .optional:
                hardwareIdTextField?.placeholder = String(localized: "Optional.", comment: "Optional")
                hardwareIdContainer?.isHidden = false
                continueButton?.isEnabled = serverIsValid && vm.hardwareId.allSatisfy({$0.isNumber})
            case .mandatory:
                hardwareIdTextField?.placeholder = String(localized: "Required.", comment: "Required")
                hardwareIdContainer?.isHidden = false
                continueButton?.isEnabled = serverIsValid && vm.hardwareId.count > 0 && vm.hardwareId.allSatisfy({$0.isNumber})
            }

            var requiredTags = [String]()
            var excludeTags = [String]()
            var dateFilter: RemoteDFUServer.DateFilter?
            vm.filters.forEach({
                switch $0 {
                case .property(let pf):
                    if pf.state == .required {
                        requiredTags.append(pf.id)
                    }
                    if pf.state == .excluded {
                        excludeTags.append(pf.id)
                    }
                case .date(let df):
                    dateFilter = df
                }
            })

            requiredTagsLabel?.text = requiredTags.isEmpty ? String(localized: "(None)", comment: "(None)") : requiredTags.joined(separator: ", ")
            excludeTagsLabel?.text = excludeTags.isEmpty ? String(localized: "(None)", comment: "(None)") : excludeTags.joined(separator: ", ")

            if let dateFilter = dateFilter {
                dateFilterContainer?.isHidden = false
                dateFilterContainer?.label?.text = dateFilter.description
                dateFilterContainer?.picker?.date = dateFilter.date
            } else {
                dateFilterContainer?.isHidden = true
            }
        }

    }

    @IBAction func datePickerChanged(_ picker: UIDatePicker) {
        guard let vm = viewModel as? RemoteUpdatesSettingsViewModel else {
            return
        }

        let newFilters = vm.filters.map({
            switch $0 {
            case .date(let dateFilter):
                let newDateFilter = RemoteDFUServer.DateFilter(id: dateFilter.id,
                                                               description: dateFilter.description,
                                                               date: picker.date)
                let newWrapper = RemoteDFUServer.Filter.date(newDateFilter)
                return newWrapper
            default:
                return $0
            }
        })
        vm.filters = newFilters
    }

    @IBAction func continueTapped(_ button: UIButton) {
        view.endEditing(true) // Text field may still be editing.

        guard let vm = viewModel as? RemoteUpdatesSettingsViewModel else {
            return
        }

        vm.server = serverTextField?.text ?? ""
        vm.hardwareId = hardwareIdTextField?.text ?? ""

        vm.continueSelected()
    }
}
