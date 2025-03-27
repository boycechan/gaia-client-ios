//
//  © 2023 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation

struct ErrorResponse: Decodable {
    let status: String
    let id: String
    let message: String

    func userVisibleDescription() -> String {
        if let knownID = ErrorResponseID(rawValue: id) {
            return knownID.userVisibleDescription()
        } else {
            return message
        }
    }

    func userVisibleDescriptionConcise() -> String {
        if let knownID = ErrorResponseID(rawValue: id) {
            return knownID.userVisibleDescriptionConcise()
        } else {
            return ""
        }
    }
}

enum ErrorResponseID: String {
    case noToken = "NO_TOKEN"
    case noID = "NO_ID"
    case noFeedback = "NO_FEEDBACK"
    case unableToResolveID = "UNABLE_TO_RESOLVE_ID"
    case invalidToken = "INVALID_TOKEN"
    case serverError = "SERVER_ERROR"
    case serviceNotAvailable = "SERVICE_NOT_AVAILABLE"
    case trackingSystemUnavailable = "TRACKING_SYSTEM_UNAVAILABLE"
    case fileNotFound = "FILE_NOT_FOUND"

    func userVisibleDescription() -> String {
        switch self {
        case .noToken:
            return String(localized: "No token was provided therefore the server is unable to process the request.",
                                     comment: "No token was provided therefore the server is unable to process the request.")
        case .noID:
            return String(localized: "No chip family could be identified. Please ensure you have entered a Hardware ID.",
                                     comment: "No chip family could be identified. Please ensure you have entered a Hardware ID.")
        case .noFeedback:
            return String(localized: "A title and feedback text are required to create a feedback report.",
                                     comment: "A title and feedback text are required to create a feedback report.")
        case .unableToResolveID:
            return String(localized: "No chip family could be identified for the supplied id, applicationVersion and hardwareVersion.",
                                     comment: "No chip family could be identified for the supplied id, applicationVersion and hardwareVersion.")
        case .invalidToken:
            return String(localized: "The token provided was invalid therefore the server is unable to process the request.",
                                     comment: "The token provided was invalid therefore the server is unable to process the request.")
        case .serverError:
            return String(localized: "The server encountered a problem and is unable to process the request.",
                                     comment: "The server encountered a problem and is unable to process the request.")
        case .serviceNotAvailable:
            return String(localized: "The service is currently unavailable and is unable to process the request. Please try again later.",
                                     comment: "The service is currently unavailable and is unable to process the request. Please try again later.")
        case .trackingSystemUnavailable:
            return String(localized: "The bug tracking system currently unavailable and the server is unable to process the request. Please try again later.",
                                     comment: "The bug tracking system currently unavailable and the server is unable to process the request. Please try again later.")
        case .fileNotFound:
            return String(localized: "The requested file could not be found.",
                                     comment: "The requested file could not be found.")
        }
    }

    func userVisibleDescriptionConcise() -> String {
        switch self {
        case .noToken:
            return String(localized: "No token was provided.",
                                     comment: "No token was provided.")
        case .noID:
            return String(localized: "No chip family could be identified.",
                                     comment: "No chip family could be identified.")
        case .noFeedback:
            return String(localized: "A title and feedback text are required.",
                                     comment: "A title and feedback text are required.")
        case .unableToResolveID:
            return String(localized: "No chip family could be identified.",
                                     comment: "No chip family could be identified .")
        case .invalidToken:
            return String(localized: "The token provided was invalid.",
                                     comment: "The token provided was invalid.")
        case .serverError:
            return String(localized: "The server encountered a problem.",
                                     comment: "The server encountered a problem.")
        case .serviceNotAvailable:
            return String(localized: "The service is currently unavailable.",
                                     comment: "The service is currently unavailable.")
        case .trackingSystemUnavailable:
            return String(localized: "The bug tracking system currently unavailable.",
                                     comment: "The bug tracking system currently unavailable.")
        case .fileNotFound:
            return String(localized: "The requested file could not be found.",
                                     comment: "The requested file could not be found.")
        }
    }
}
