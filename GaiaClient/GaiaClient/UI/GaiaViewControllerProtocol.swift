//
//  © 2020 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import UIKit

/// Protocol which all view controllers in the app conform to.
protocol GaiaViewControllerProtocol where Self : UIViewController {
    /// The app has an MVVM UI design so all view controllers have a view model.
    var viewModel: GaiaViewModelProtocol? { get set }

    /// Causes the view controller to update the UI. Usually called from the view model.
    func update()
}

