//
//  © 2020 - 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation
import GaiaBase

enum UpdateControlOperations: UInt8 {
    case UPGRADE_START_REQ                     = 0x01
    case UPGRADE_START_CFM                     = 0x02
    case UPGRADE_DATA_BYTES_REQ                = 0x03
    case UPGRADE_DATA                          = 0x04
    case UPGRADE_ABORT_REQ                     = 0x07
    case UPGRADE_ABORT_CFM                     = 0x08
    case UPGRADE_TRANSFER_COMPLETE_IND         = 0x0B
    case UPGRADE_TRANSFER_COMPLETE_RES         = 0x0C
    case UPGRADE_PROCEED_TO_COMMIT             = 0x0E
    case UPGRADE_COMMIT_REQ                    = 0x0F
    case UPGRADE_COMMIT_CFM                    = 0x10
    case UPGRADE_ERROR_IND                     = 0x11
    case UPGRADE_COMPLETE_IND                  = 0x12
    case UPGRADE_SYNC_REQ                      = 0x13
    case UPGRADE_SYNC_CFM                      = 0x14
    case UPGRADE_START_DATA_REQ                = 0x15
    case UPGRADE_IS_VALIDATION_DONE_REQ        = 0x16
    case UPGRADE_IS_VALIDATION_DONE_CFM        = 0x17
    case UPGRADE_ERROR_RES                     = 0x1F
    case UPGRADE_SILENT_COMMIT_SUPPORTED_REQ   = 0x20
    case UPGRADE_SILENT_COMMIT_SUPPORTED_CFM   = 0x21
    case UPGRADE_SILENT_COMMIT_COMPLETE_CFM    = 0x22
    case UPGRADE_PUT_EARBUDS_IN_CASE_REQ	   = 0x23
    case UPGRADE_PUT_EARBUDS_IN_CASE_CFM       = 0x24
    case UPGRADE_COMPLETE_IND_WITH_STATUS	   = 0x25 // TBC
}

enum UpdateCompleteIndStatusCode: UInt8 {
    case UNDEFINED								    = 0x00
    case COMMIT_SUCCESS_SECURITY_UPDATE_FAILED      = 0x01
    case COMMIT_AND_SECURITY_UPDATE_SUCCESS         = 0x02
};

enum UpdateDataAction: UInt8 {
    case noAbort                      = 0x00
    case abort                         = 0x01
}
