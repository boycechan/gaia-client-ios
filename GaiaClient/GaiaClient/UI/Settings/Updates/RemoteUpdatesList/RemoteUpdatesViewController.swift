//
//  © 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import UIKit

extension UpdateEntry {
    func containsSearchText(_ searchText: String) -> Bool {
        let titleMatch = title.range(of: searchText, options: NSString.CompareOptions.caseInsensitive)
        let descriptionMatch = description.range(of: searchText, options: NSString.CompareOptions.caseInsensitive)
        let idMatch = id.range(of: searchText, options: NSString.CompareOptions.caseInsensitive)
 //       let dateMatch = date.range(of: searchText, options: NSString.CompareOptions.caseInsensitive)
        let chipMatch = chipname.range(of: searchText, options: NSString.CompareOptions.caseInsensitive)
        return titleMatch != nil || descriptionMatch != nil || idMatch != nil || /*dateMatch != nil ||*/ chipMatch != nil
    }
}

class RemoteUpdatesViewController: UIViewController, GaiaViewControllerProtocol {
    var viewModel: GaiaViewModelProtocol?

    @IBOutlet weak var tableView: UITableView?

    @IBOutlet weak var overlayView: UIView?
    @IBOutlet weak var overlayViewLabel: UILabel?

    @IBOutlet weak var noFilesOverlayView: UIView?

    @IBOutlet weak var errorOverlayView: UIView?
    @IBOutlet weak var errorOverlayViewLabel: UILabel?

    var searchController: UISearchController?
    var filteredUpdates = [UpdateEntry]()
    var dateFormatter = DateFormatter()

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
        searchController = UISearchController(searchResultsController: nil)
        searchController?.searchResultsUpdater = self
        searchController?.obscuresBackgroundDuringPresentation = false
        searchController?.hidesNavigationBarDuringPresentation = false

        tableView?.tableHeaderView = searchController?.searchBar

        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .medium
    }
}

extension RemoteUpdatesViewController {
    @objc private func forceRefresh(_ sender: Any) {
        guard let updatesVM = viewModel as? RemoteUpdatesViewModel else {
            return
        }
        updatesVM.fetchUpdates()
    }

    func update() {
        guard let updatesVM = viewModel as? RemoteUpdatesViewModel else {
            return
        }

        if !updatesVM.isDeviceConnected() {
            overlayView?.isHidden = false
            noFilesOverlayView?.isHidden = true
            errorOverlayView?.isHidden = true
            overlayViewLabel?.text = String(localized: "Device disconnected", comment: "Updates Overlay")
            return
        }

        switch updatesVM.overlay {
        case .hidden:
            overlayView?.isHidden = true
            noFilesOverlayView?.isHidden = true
            errorOverlayView?.isHidden = true
        case .fetching:
            overlayView?.isHidden = false
            noFilesOverlayView?.isHidden = true
            errorOverlayView?.isHidden = true
            overlayViewLabel?.text = String(localized: "Fetching Updates", comment: "Updates Fetch Error")
        case .noUpdates:
            overlayView?.isHidden = true
            noFilesOverlayView?.isHidden = false
            errorOverlayView?.isHidden = true
        case .error(message: let message):
            overlayView?.isHidden = true
            noFilesOverlayView?.isHidden = true
            errorOverlayView?.isHidden = false
            errorOverlayViewLabel?.text = message
        }

        tableView?.reloadData()
    }
}

extension RemoteUpdatesViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        guard let updatesVM = viewModel as? RemoteUpdatesViewModel else {
            return
        }

        if let searchText = searchController.searchBar.text {
            if searchText.isEmpty {
                filteredUpdates = updatesVM.updates
            } else {
                filteredUpdates = updatesVM.updates.filter({ $0.containsSearchText(searchText) })
            }
            update()  // replace current table view with search results table view
        }
    }
}

extension RemoteUpdatesViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let updatesVM = viewModel as? RemoteUpdatesViewModel else {
            return 0
        }

        if searchController?.isActive ?? false {
            return filteredUpdates.count
        } else {
            return updatesVM.updates.count
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard
            let cell = tableView.dequeueReusableCell(withIdentifier: "RemoteUpdatesTableViewCell") as? RemoteUpdatesTableViewCell,
            let updatesVM = viewModel as? RemoteUpdatesViewModel
        else {
            return UITableViewCell()
        }

        let updates = searchController?.isActive ?? false ? filteredUpdates : updatesVM.updates
        guard indexPath.row < updates.count  else {
            return UITableViewCell()
        }

        let update = updates[indexPath.row]
        cell.titleLabel?.text = update.title
        cell.descriptionLabel?.text = update.description
        cell.filterLabel?.text = update.filters.joined(separator: ", ")
        cell.dateLabel?.text = dateFormatter.string(from: update.date)


        return cell
    }
}

extension RemoteUpdatesViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return CGFloat.leastNormalMagnitude
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        guard
            let updatesVM = viewModel as? RemoteUpdatesViewModel
        else {
            return
        }

        let updates = searchController?.isActive ?? false ? filteredUpdates : updatesVM.updates
        guard indexPath.row < updates.count  else {
            return
        }

        updatesVM.didSelect(info: updates[indexPath.row])
    }
}
