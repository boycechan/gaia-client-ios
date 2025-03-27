//
//  © 2021 - 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation

protocol GaiaRWCPHandlerDelegate: AnyObject {
    /// The final packet was successful
    func didCompleteDataSend()

    /// Some bytes have been successfully transferred.
    /// - Parameter progress: The number of payload bytes additionally sent. Note this is not the total of bytes that have been sent.
    func didSend(bytes: Double)
}

