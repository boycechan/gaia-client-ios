//
//  © 2023 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation

internal enum RemoteServerError: Error {
    case configuration
    case connectivity
    case errorResponse(ErrorResponse)
    case aborted
    case format
}

extension RemoteServerError: Equatable {
    public static func ==(lhs: RemoteServerError, rhs: RemoteServerError) -> Bool {
        switch lhs {
        case .configuration:
            switch rhs {
            case .configuration:
                return true
            default:
                return false
            }
        case .connectivity:
            switch rhs {
            case .connectivity:
                return true
            default:
                return false
            }
        case .errorResponse(let leftResponse):
            switch rhs {
            case .errorResponse(let rightResponse):
                return leftResponse.id == rightResponse.id && leftResponse.status == rightResponse.status
            default:
                return false
            }
        case .aborted:
            switch rhs {
            case .aborted:
                return true
            default:
                return false

            }
        case .format:
            switch rhs {
            case .format:
                return true
            default:
                return false

            }
        }
    }
}
