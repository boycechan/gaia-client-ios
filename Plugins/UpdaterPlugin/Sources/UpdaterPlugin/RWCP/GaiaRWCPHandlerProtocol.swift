//
//  © 2021 - 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation
import GaiaBase

protocol GaiaRWCPHandlerProtocol {
    init(connection: GaiaDeviceConnectionProtocol, delegate: GaiaRWCPHandlerDelegate?)

    func prepareForUpdate(initialCongestionWindowSize: Int,
                          maximumCongestionWindowSize: Int)
    func didReceive(data: Data)
    func setPayload(data: Data, lastPacket: Bool)
    func startTransfer()
    func teardown()
    func powerOff()
    func abort()
}
