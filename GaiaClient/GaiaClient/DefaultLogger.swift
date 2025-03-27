//
//  © 2023 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation
import GaiaLogger
import OSLog

class DefaultLogger: GaiaLogHandlerProtocol {
    private let formatter = DateFormatter()
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "")

    init() {
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = .current
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
    }

    func log(level: GaiaLoggerLevel, message: String, file: String, line: Int, function: String) {
        let logString = "\(URL(fileURLWithPath: file).lastPathComponent):\(line) \(function): \(message)"
        switch level {
        case .high:
            // OSLog doesn't allow direct logging of a string.
            logger.notice("\(logString, privacy: .public)")
        case .medium:
            logger.info("\(logString, privacy: .public)")
        case .low:
            logger.debug("\(logString, privacy: .public)")
        }
    }

    // Log retrieval

    let supportsRetrieval = true

    func previousEntries(limit: Int) async throws -> [String] {
        let store = try OSLogStore(scope: .currentProcessIdentifier)
        let last24Hrs = Date.now.addingTimeInterval(-24 * 3600)
        let position = store.position(date: last24Hrs)
        let entries = try store
                        .getEntries(at: position)
                        .compactMap { $0 as? OSLogEntryLog }
                        .filter { $0.subsystem == Bundle.main.bundleIdentifier! }
                        .map { "\(formatter.string(from: $0.date)) \($0.composedMessage)" }
        return entries.suffix(limit)
    }
}
