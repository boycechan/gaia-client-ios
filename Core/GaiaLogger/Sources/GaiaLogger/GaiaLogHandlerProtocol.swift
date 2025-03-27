//
//  © 2021 - 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation

public protocol GaiaLogHandlerProtocol {
    func log(level: GaiaLoggerLevel, message: String, file: String, line: Int, function: String)

    var supportsRetrieval: Bool { get }
    func previousEntries(limit: Int) async throws -> [String]
}
