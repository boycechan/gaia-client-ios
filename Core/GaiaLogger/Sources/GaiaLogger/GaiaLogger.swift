//
//  © 2021 - 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation

public enum GaiaLoggerLevel: Int {
    case low = 0
    case medium = 1
    case high = 2
}

public func LOG(_ level: GaiaLoggerLevel, _ message: String, file: String = #file, line: Int = #line, function: String = #function) {
    GaiaLogger.shared.log(level, message, file: file, line: line, function: function)
}

public class GaiaLogger {
    public static let shared = GaiaLogger()
    public var logLevel = GaiaLoggerLevel.medium

    private var handlers = [GaiaLogHandlerProtocol]()

    private let formatter = DateFormatter()

    init() {
        formatter.dateFormat = "HH:mm:ss.SSSS"
    }

    public func registerHandler(_ handler: GaiaLogHandlerProtocol) {
        handlers.append(handler)
    }

    public func logRetrievalProvider() -> GaiaLogHandlerProtocol? {
        return handlers.first(where: {$0.supportsRetrieval})
    }

    internal func log(_ level: GaiaLoggerLevel, _ message: String, file: String = #file, line: Int = #line, function: String = #function) {
        guard level.rawValue >= logLevel.rawValue else {
			return
        }

        if handlers.count > 0 {
            handlers.forEach {
                $0.log(level: level, message: message, file: file, line: line, function: function)
            }
        } else {
            print("\(formatter.string(from: Date())) \(URL(fileURLWithPath: file).lastPathComponent):\(line) \(function): \(message)")
        }
    }
}
