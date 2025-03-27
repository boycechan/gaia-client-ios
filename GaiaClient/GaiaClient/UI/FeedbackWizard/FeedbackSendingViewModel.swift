//
//  © 2023 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import UIKit
import GaiaCore

class FeedbackSendingViewModel: GaiaDeviceViewModelProtocol {
    public enum UploadState {
        case none
        case uploading
        case fail(reason: String)
        case success(issue: String, link: String)
    }
    
    private weak var viewController: GaiaViewControllerProtocol?
    private let coordinator: AppCoordinator
    private let gaiaManager: GaiaManager
    private let notificationCenter: NotificationCenter

    private(set) var title: String
    private(set) var state: UploadState = .none
    public var feedbackText: NSAttributedString {
        guard let feedbackInfo = feedbackInfo else {
            return NSAttributedString()
        }

        let titleAttributes: [NSAttributedString.Key: Any] = [.font : UIFont.boldSystemFont(ofSize: 14)]
        let bodyAttributes: [NSAttributedString.Key: Any] = [.font : UIFont.systemFont(ofSize: 12)]

        let text = NSMutableAttributedString(string: String(localized: "Title", comment: "Title"), attributes: titleAttributes)
        text.append(NSAttributedString(string: "\n\n"))
        text.append(NSMutableAttributedString(string: feedbackInfo.title, attributes: bodyAttributes))
        text.append(NSAttributedString(string: "\n\n"))

        text.append(NSMutableAttributedString(string: String(localized: "Description", comment: "Description"), attributes: titleAttributes))
        text.append(NSAttributedString(string: "\n\n"))
        text.append(NSMutableAttributedString(string: feedbackInfo.description, attributes: bodyAttributes))
        text.append(NSAttributedString(string: "\n\n"))

        text.append(NSMutableAttributedString(string: String(localized: "Reporter", comment: "Reporter"), attributes: titleAttributes))
        text.append(NSAttributedString(string: "\n\n"))
        text.append(NSMutableAttributedString(string: feedbackInfo.reporter ?? String(localized: "(Empty)", comment: "Empty"), attributes: bodyAttributes))
        text.append(NSAttributedString(string: "\n\n"))

        text.append(NSMutableAttributedString(string: String(localized: "Hardware Build ID", comment: "Hardware Build ID"), attributes: titleAttributes))
        text.append(NSAttributedString(string: "\n\n"))
        text.append(NSMutableAttributedString(string: feedbackInfo.device.hardwareVersion ?? String(localized: "(Empty)", comment: "Empty"), attributes: bodyAttributes))
        text.append(NSAttributedString(string: "\n\n"))

        text.append(NSMutableAttributedString(string: String(localized: "Client", comment: "Client"), attributes: titleAttributes))
        text.append(NSAttributedString(string: "\n\n"))
        text.append(NSMutableAttributedString(string: String(localized: "\(feedbackInfo.client.name) version: \(feedbackInfo.client.appVersion)", comment: "Feedback Report"),
                                              attributes: bodyAttributes))
        text.append(NSAttributedString(string: "\n"))
        text.append(NSMutableAttributedString(string: String(localized: "Handset: \(feedbackInfo.client.device) - \(feedbackInfo.client.system) \(feedbackInfo.client.systemVersion)", comment: "Feedback Report"),
                                              attributes: bodyAttributes))
        text.append(NSAttributedString(string: "\n\n"))

        text.append(NSMutableAttributedString(string: String(localized: "Audio Device", comment: "Audio Device"), attributes: titleAttributes))
        text.append(NSAttributedString(string: "\n\n"))
        text.append(NSMutableAttributedString(string: String(localized: "Application version: \(feedbackInfo.device.applicationVersion)", comment: "Feedback Report"),
                                              attributes: bodyAttributes))
        text.append(NSAttributedString(string: "\n"))
        let buildID = feedbackInfo.device.applicationBuildId ?? String(localized: "(Empty)", comment: "Empty")
        text.append(NSMutableAttributedString(string: String(localized: "Application Build ID: \(buildID)", comment: "Feedback Report"),
                                              attributes: bodyAttributes))
        text.append(NSAttributedString(string: "\n\n"))

        return text
    }

    private var device: GaiaDeviceProtocol?
    private var feedbackInfo: FeedbackInfo?

    required init(viewController: GaiaViewControllerProtocol,
                  coordinator: AppCoordinator,
                  gaiaManager: GaiaManager,
                  notificationCenter: NotificationCenter) {
        self.viewController = viewController
        self.coordinator = coordinator
        self.gaiaManager = gaiaManager
        self.notificationCenter = notificationCenter

        self.title = String(localized: "Feedback", comment: "Settings Screen Title")
    }

    func injectDevice(device: GaiaDeviceProtocol?) {
        self.device = device
    }

    func injectFeedbackInfo(feedbackInfo: FeedbackInfo) {
        self.feedbackInfo = feedbackInfo
    }

    func isDeviceConnected() -> Bool {
        if let device = device {
            return device.state != .disconnected
        } else {
            return false
        }
    }

    func activate() {
        state = .uploading
        refresh()
        if let feedbackInfo {
            Task {
                do {
                    let response = try await FeedbackServer.shared.sendFeedback(feedbackInfo)
                    state = .success(issue: response.issue.id, link: response.issue.link)
                } catch let error as RemoteServerError {
                    switch error {
                    case .configuration:
                        state = .fail(reason: String(localized: "", comment: "Updates Fetch Error"))
                    case .connectivity:
                        state = .fail(reason: String(localized: "Cannot reach server.", comment: "Updates Fetch Error"))
                    case .errorResponse(let errorResponse):
                        state = .fail(reason: errorResponse.userVisibleDescriptionConcise())
                    case .aborted:
                        state = .fail(reason: String(localized: "Cancelled.", comment: "Updates Fetch Error"))
                    case .format:
                        state = .fail(reason: String(localized: "Unexpected Response.", comment: "Updates Fetch Error"))
                    }
                } catch {
                    state = .fail(reason: "")
                }
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.refresh()
                }
            }
        }
    }

    func deactivate() {
    }

    func refresh() {
        viewController?.update()
    }
}
