//
//  © 2020 - 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation
import GaiaCore
import GaiaBase

extension Notification.Name {
    static let VendorExtensionNotification = Notification.Name("VendorExtensionNotification")
}

struct VendorExtensionNotification: GaiaNotification {
    enum Reason {
    }

    var sender: GaiaNotificationSender
    var payload: GaiaDeviceIdentifierProtocol
    var reason: Reason

    static var name: Notification.Name = .VendorExtensionNotification
}

class ExampleVendorExtension: GaiaDeviceVendorExtensionProtocol, GaiaNotificationSender {

    static let vendorID: UInt16 = 0x0080 // Your Vendor ID here.
    private let notificationCenter: NotificationCenter
    private let connection: GaiaDeviceConnectionProtocol
    private weak var device: GaiaDeviceProtocol!
    
    required init(device: GaiaDeviceProtocol,
                  connection: GaiaDeviceConnectionProtocol,
                  notificationCenter: NotificationCenter) {
        self.device = device
        self.connection = connection
        self.notificationCenter = notificationCenter
    }

    /**
     This method is sent after the GAIA version has been determined and the initial state requested.
     */
    func start() {
        /* If GAIA V3 formatted messages are to  be sent to the device the following example shows how:

         let message = GaiaV3GATTPacket(vendorID: vendorID, // vendor specific vendor ID
         								featureID: 0,	// vendor specific vendor ID.
         								commandID: 0,	// vendor specific command ID.
         								payload: Data())
         connection.sendData(channel: .command, payload: message.data, acknowledgementExpected: true)
         */
    }

    /**
     This method is sent when a device is being torn down, for example after disconnection.
     */
    func stop() {
    }

    /**
     This method is used to support third party extensions that do not necessarily use the GAIA v3 format.

     For this method, the data passed to the method is what would normally be the V3 GAIA GATT packet including the VendorID, PDU etc. For BLE
     transports, this is the complete data read from the characteristic. For RFCOMM or IAP2 transports this is the data unwrapped of those transports' additional
     data i.e. the data sent to this method is transport agnostic.

     - parameter data: The data received as described in the description above.
     - returns: a boolean denoting if the data was a response or an error (not a notification) and the command that was originally sent expected an acknowledgement
     			(see sending a command).
     */
    func dataReceived(_ data: Data) -> Bool {
        /* Here if the data is a GAIA V3 packet you could use the following:
		if let message = GaiaV3GATTPacket(data: data),
         	message.vendorID == vendorID {
         	// Here you can inspect the command ID, PDU values inc feature ID which will be
         	// returned as .vendor(let id) where id is a UInt8

            switch message.messageDescription {
            case .notification(let notificationID, let payload):
                // Handle notification
                return false
            case .error(let commandID , let errorCode, let payload):
                // Handle error
                return true
            case .response(let command, let payload):
         		// Handle response
                return true
         	default:
         		break
         	}
        }
		*/
        return true
    }

    /**
    If when sending to a Gaia device an error occurs, this method is called on all registered vendor extensions.

    - parameter error: The error for the write failure
    */
    func didError(_ error: GaiaError) {
    }
}
