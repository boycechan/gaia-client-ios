//
//  © 2023 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import UIKit

class TagsEditViewController: UIViewController, GaiaViewControllerProtocol {
    var viewModel: GaiaViewModelProtocol?

    @IBOutlet weak var tableView: UITableView?

    override var title: String? {
        get {
            return viewModel?.title
        }
        set {}
    }

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewModel?.activate()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        viewModel?.deactivate()
    }
}

extension TagsEditViewController {
    func update() {
        tableView?.reloadData()
    }

    func updateRow(indexPath: IndexPath) {
        tableView?.reloadRows(at: [indexPath], with: .automatic)
    }
}

extension TagsEditViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard
            let cell = tableView.dequeueReusableCell(withIdentifier: "TagsEditTableViewCell") as? TagsEditTableViewCell,
            let vm = viewModel as? TagsEditViewModel
        else {
            return UITableViewCell()
        }

        let filters = vm.filters
        guard indexPath.row < filters.count  else {
            return UITableViewCell()
        }

        let filter = filters[indexPath.row]
        cell.fullTitleLabel?.text = filter.description
        cell.abbreviationLabel?.text = filter.id
        switch filter.state {
        case .required, .excluded:
            cell.checkmarkImageView?.isHidden = false
        case .none:
            cell.checkmarkImageView?.isHidden = true
        }

        return cell
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let vm = viewModel as? TagsEditViewModel else {
            return 0
        }
        return vm.filters.count
    }
}

extension TagsEditViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let vm = self.viewModel as? TagsEditViewModel else {
            return
        }
        vm.didToggleFilter(at: indexPath)
    }
}
