//
//  © 2020 - 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation
import GaiaBase

public protocol GaiaDeviceVendorExtensionProtocol {
    static var vendorID: UInt16 { get }
    var vendorID: UInt16 { get }

    init(device: GaiaDeviceProtocol,
         connection: GaiaDeviceConnectionProtocol,
         notificationCenter: NotificationCenter)
    
    /**
    This method is sent after the GAIA version has been determined and the initial state requested.
    */
    func start()

    /**
    This method is sent when a device is being torn down, for example after disconnection.
    */
    func stop()

    /**
    This method is used to support third party extensions that do not necessarily use the GAIA v3 format.

    For this method, the data passed to the method is what would normally be the V3 GAIA GATT packet including the VendorID, PDU etc. For BLE
    transports, this is the complete data read from the characteristic. For RFCOMM or IAP2 transports this is the data unwrapped of those transports' additional
    data i.e. the data sent to this method is transport agnostic.

    - parameter data: The data received as described in the description above.
    - returns: a boolean denoting if the data was a response or an error (not a notification) and the command that was originally sent expected an acknowledgement
               (see sending a command).
    */
    func dataReceived(_ data: Data) -> Bool

    /**
    If when sending to a Gaia device an error occurs, this method is called on all registered vendor extensions.

    - parameter error: The error for the write failure
    */
    func didError(_ error: GaiaError)
}

public extension GaiaDeviceVendorExtensionProtocol {
    var vendorID: UInt16 {
        get {
            return Self.vendorID
        }
    }
}
