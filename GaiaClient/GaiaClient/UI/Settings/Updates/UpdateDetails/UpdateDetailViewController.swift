//
//  © 2023 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import UIKit

class UpdateDetailViewController: UIViewController, GaiaViewControllerProtocol {
    var viewModel: GaiaViewModelProtocol?
    
    @IBOutlet weak var overlayView: UIView?
    @IBOutlet weak var overlayViewLabel: UILabel?

    @IBOutlet weak var downloadContainerView: UIView?
    @IBOutlet weak var upgradeContainerView: UIView?

    @IBOutlet weak var titleLabel: UILabel?
    @IBOutlet weak var chipLabel: UILabel?
    @IBOutlet weak var descriptionLabel: UILabel?
    @IBOutlet weak var filterLabel: UILabel?
    @IBOutlet weak var dateLabel: UILabel?
    @IBOutlet weak var idLabel: UILabel?

    @IBOutlet weak var actionButton: UIButton?

    var dateFormatter = DateFormatter()

    var downloadViewController: DownloadProgressViewController? {
        return children.compactMap({ $0 as? DownloadProgressViewController}).first
    }

    var upgradeViewController: UpdateProgressViewController? {
        return children.compactMap({ $0 as? UpdateProgressViewController}).first
    }
    
    override var title: String? {
        get {
            return viewModel?.title
        }
        set {}
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .medium

        let b = UIBarButtonItem(image: UIImage(systemName: "slider.horizontal.3"),
                                style: .plain,
                                target: self,
                                action: #selector(showUpgradeSettings(_:)))
        navigationItem.setRightBarButton(b, animated: false)
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
        updateForNewState()
    }

    @IBAction func performAction(_: Any) {
        guard let vm = viewModel as? UpdateDetailViewModel else {
            return
        }

        switch vm.state {
        case .showDetailsForRemote(id: _, info: _):
            vm.startDownload()
        case .showDetailsForLocal(data: _, info: _):
            vm.startDFUForLocal()
        default:
            break
        }
    }

    @objc func showUpgradeSettings(_: Any) {
        guard
            let vm = viewModel as? UpdateDetailViewModel,
            let vc = vm.viewControllerForUpgradeSettings()
        else {
            return
        }

        let navContainer = UINavigationController(rootViewController: vc)
        navContainer.modalPresentationStyle = .pageSheet
        if let pc = navContainer.sheetPresentationController {
            pc.detents = [.medium()]
            present(navContainer, animated: true, completion:nil)
        }
    }

    @objc func closeViewController(_: Any) {
        navigationController?.popToRootViewController(animated: true)
    }
}

extension UpdateDetailViewController {
    func updateForNewState() {
        guard let vm = viewModel as? UpdateDetailViewModel else {
			return
        }

        switch vm.state {
        case .none:
            downloadContainerView?.isHidden = true
            upgradeContainerView?.isHidden = true
            actionButton?.isHidden = true
        case .showDetailsForRemote(id: _, info: let info):
            downloadContainerView?.isHidden = true
            upgradeContainerView?.isHidden = true
            actionButton?.isHidden = false
            actionButton?.setTitle("Download", for: .normal)
            actionButton?.setTitle("Download", for: .highlighted)
            actionButton?.setTitle("Download", for: .selected)
            updateTextFields(info: info)
        case .showDetailsForLocal(data: _, info: let info):
            downloadContainerView?.isHidden = true
            upgradeContainerView?.isHidden = true
            actionButton?.isHidden = false
            actionButton?.setTitle("Update", for: .normal)
            actionButton?.setTitle("Update", for: .highlighted)
            actionButton?.setTitle("Update", for: .selected)
            updateTextFields(info: info)
        case .download(id: _, info: _):
            downloadContainerView?.isHidden = false
            upgradeContainerView?.isHidden = true
            actionButton?.isHidden = true
        case .update(data: _, info: let info):
            downloadContainerView?.isHidden = true
            upgradeContainerView?.isHidden = false
            actionButton?.isHidden = true

            updateTextFields(info: info)

            // Remove the preceeding view controllers so that going back from here goes right back to start.
            if let vcs = navigationController?.viewControllers.filter({ $0 is SettingsIntroViewController || $0 is UpdateDetailViewController }) {
                navigationController?.setViewControllers(vcs, animated: false)
            }

            navigationItem.setRightBarButton(nil, animated: true)
        case .done(info: _):
            break
        case .failed(message: _, info: _):
            break
        }
    }

    func updateTextFields(info: UpdateDetailViewModel.UpdateExtendedInfo) {
        titleLabel?.text = info.entryInfo.title
        descriptionLabel?.text = info.entryInfo.description
        if info.source == .remote {
            chipLabel?.isHidden = info.entryInfo.chipname.isEmpty
            chipLabel?.text = info.entryInfo.chipname

            filterLabel?.isHidden = info.entryInfo.filters.isEmpty
            filterLabel?.text = info.entryInfo.filters.joined(separator: ", ")

            dateLabel?.text = dateFormatter.string(from: info.entryInfo.date)
            idLabel?.text = info.entryInfo.id
        } else {
            chipLabel?.isHidden = true
            filterLabel?.isHidden = true
            dateLabel?.isHidden = true
            idLabel?.isHidden = true
        }
    }
}
