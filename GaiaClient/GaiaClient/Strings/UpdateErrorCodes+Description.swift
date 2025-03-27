//
//  © 2023 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation
import PluginBase

extension UpdateErrorCodes {
    public func userVisibleDescription() -> String {
        switch self {
        case .success:
            return String(localized: "Everything is fine", comment: "Update Error Response")
        case .errorUnknownId:
            return String(localized: "Bad file - unrecognized header (upgrade/partition/footer)", comment: "Update Error Response")
        case .errorBadLength:
            return String(localized: "Bad length", comment: "Update Error Response")
        case .errorWrongVariant:
            return String(localized: "Wrong variant", comment: "Update Error Response")
        case .errorWrongPartitionNumber:
            return String(localized: "Wrong partition number", comment: "Update Error Response")
        case .errorPartitionSizeMismatch:
            return String(localized: "Partition size mismatch", comment: "Update Error Response")
        case .errorPartitionTypeNotFound:
            return String(localized: "Partition type not found", comment: "Update Error Response")
        case .errorPartitionOpenFailed:
            return String(localized: "Partition open failed", comment: "Update Error Response")
        case .errorPartitionWriteFailed:
            return String(localized: "Partition write failed", comment: "Update Error Response")
        case .errorPartitionCloseFailed:
            return String(localized: "Partition close failed", comment: "Update Error Response")
        case .errorSFSValidationFailed:
            return String(localized: "SFS validation failed:", comment: "Update Error Response")
        case .errorOEMValidationFailed:
            return String(localized: "OEM validation failed", comment: "Update Error Response")
        case .errorUpdateFailed:
            return String(localized: "Update failed", comment: "Update Error Response")
        case .errorAppNotReady:
            return String(localized: "App not ready on earbud/headset", comment: "Update Error Response")
        case .errorLoaderError:
            return String(localized: "Loader error", comment: "Update Error Response")
        case .errorUnexpectedLoaderMessage:
            return String(localized: "Unexpected loader", comment: "Update Error Response")
        case .errorMissingLoaderMessage:
            return String(localized: "Missing loader", comment: "Update Error Response")
        case .errorBatteryLow:
            return String(localized: "Battery low", comment: "Update Error Response")
        case .errorInvalidSyncId:
            return String(localized: "Invalid sync ID", comment: "Update Error Response")
        case .errorInErrorState:
            return String(localized: "In error state", comment: "Update Error Response")
        case .errorNoMemory:
            return String(localized: "No memory", comment: "Update Error Response")
        case .errorHandoverDFUAbort:
            return String(localized: "Handover DFU Abort", comment: "Update Error Response")
        case .errorBadLengthPartitionParse:
            return String(localized: "Bad length - partition parse", comment: "Update Error Response")
        case .errorBadLengthTooShort:
            return String(localized: "Bad length - too short", comment: "Update Error Response")
        case .errorBadLengthUpgradeHeader:
            return String(localized: "Bad length - Upgrade header", comment: "Update Error Response")
        case .errorBadLengthPartitionHeader:
            return String(localized: "Bad length - Partition header", comment: "Update Error Response")
        case .errorBadLengthSignature:
            return String(localized: "Bad length - Signature", comment: "Update Error Response")
        case .errorBadLengthDataHeaderResume:
            return String(localized: "Bad length - Data header resume", comment: "Update Error Response")
        case .errorOEMValidationFailedHeader:
            return String(localized: "OEM validation failed - Header", comment: "Update Error Response")
        case .errorOEMValidationFailedUpgradeHeader:
            return String(localized: "OEM validation failed - Upgrade header", comment: "Update Error Response")
        case .errorOEMValidationFailedPartitionHeader:
            return String(localized: "OEM validation failed - Partition header", comment: "Update Error Response")
        case .errorOEMValidationFailedPartitionHeader2:
            return String(localized: "OEM validation failed - Partition header 2", comment: "Update Error Response")
        case .errorOEMValidationFailedPartitionData:
            return String(localized: "OEM validation failed - Partition data", comment: "Update Error Response")
        case .errorOEMValidationFailedFooter:
            return String(localized: "OEM validation failed - Footer", comment: "Update Error Response")
        case .errorOEMValidationFailedMemory:
            return String(localized: "OEM validation failed - Memory", comment: "Update Error Response")
        case .errorPartitionCloseFailed2:
            return String(localized: "Partition close failed 2", comment: "Update Error Response")
        case .errorPartitionCloseFailedHeader:
            return String(localized: "Partition close failed - Header", comment: "Update Error Response")
        case .errorPartitionCloseFailedPSSpace:
            return String(localized: "Partition close failed - PS space", comment: "Update Error Response")
        case .errorPartitionTypeNotMatching:
            return String(localized: "Partition type - Not matching", comment: "Update Error Response")
        case .errorPartitionTypeTwoDFU:
            return String(localized: "Partition type - Two DFU", comment: "Update Error Response")
        case .errorPartitionWriteFailedHeader:
            return String(localized: "Partition write - Failed header", comment: "Update Error Response")
        case .errorPartitionWriteFailedData:
            return String(localized: "Partition write - Failed data", comment: "Update Error Response")
        case .errorFileTooSmall:
            return String(localized: "File too small", comment: "Update Error Response")
        case .errorFileTooBig:
            return String(localized: "File too big", comment: "Update Error Response")
        case .errorInternalError1:
            return String(localized: "Internal error 1", comment: "Update Error Response")
        case .errorInternalError2:
            return String(localized: "Internal error 2", comment: "Update Error Response")
        case .errorInternalError3:
            return String(localized: "Internal error 3", comment: "Update Error Response")
        case .errorInternalError4:
            return String(localized: "Internal error 4", comment: "Update Error Response")
        case .errorInternalError5:
            return String(localized: "Internal error 5", comment: "Update Error Response")
        case .errorInternalError6:
            return String(localized: "Internal error 6", comment: "Update Error Response")
        case .errorInternalError7:
            return String(localized: "Internal error 7", comment: "Update Error Response")
        case .errorSilentCommitNotSupported:
            return String(localized: "Delayed reboot/silent commit not supported", comment: "Update Error Response")
        case .errorTimeout:
            return String(localized: "The update timed out waiting for action.", comment: "Update Error Response")
        case .warnAppConfigVersionIncompatible:
            return String(localized: "App config version incompatible", comment: "Update Error Response")
        case .warnSyncIdIsDifferent:
            return String(localized: "Sync ID is different", comment: "Update Error Response")
        case .warnSyncIdIsZero:
            return String(localized: "Sync ID is zero", comment: "Update Error Response")
        case .errorRequestedVersionMismatch:
            return String(localized: "The requested earbud version does not match", comment: "Update Error Response")
        }
    }
}
