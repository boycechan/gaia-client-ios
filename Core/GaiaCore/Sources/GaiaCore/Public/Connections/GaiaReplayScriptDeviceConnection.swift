//
//  © 2020 - 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation
import GaiaBase
import GaiaLogger

enum ReplayFileCommand: String {
    case connect = "O"
    case disconnect = "X"
    case from = "<"
    case to = ">"
    case error = "E"
    case timeout = "T"
    case unknown = "!"

    static func decodeFileString(fileString: String) -> (command: ReplayFileCommand, remainder: String) {
        if let firstCharacter = fileString.first {
            var testStr = String(firstCharacter)
            if let testResult = ReplayFileCommand(rawValue: testStr) {
                return (testResult, String(fileString.dropFirst()))
            } else if fileString.count > 1 {
                testStr = String(fileString.prefix(2))
                if let testResult = ReplayFileCommand(rawValue: testStr) {
                    return (testResult, String(fileString.dropFirst(2)))
                }
            }
        }
        return (Self.unknown, fileString)
    }

    func string(value: String) -> String {
        return self.rawValue + value
    }
}

// MARK: -

public class GaiaReplayScriptDeviceConnection: NSObject, GaiaDeviceConnectionProtocol {

    // MARK: Private ivars
    internal weak var scriptDelegate: ScriptConnectionDelegate?

    private let fileContents: [String]
    private var fileContentsIndex = -1
    private let commandQueue = CommandQueue()
    private var currentSendingCommand: String?

    // MARK: Public ivars
    public let connectionKind: ConnectionKind
    public weak var delegate: GaiaDeviceConnectionDelegate?
    public var connectionID: String = UUID().uuidString
    public private(set) var name: String = "Replay Script Device"
    public private(set) var connected: Bool = false
    public private(set) var rssi: Int = 0
    public private(set) var isDataLengthExtensionSupported: Bool = true
    public var maximumWriteLength: Int {
        connectionKind == .ble ? 64 : 0xfffe
    }
    public var maximumWriteWithoutResponseLength: Int {
        connectionKind == .ble ? 64 : 0xfffe
    }
    public var optimumWriteLength: Int {
        maximumWriteLength
    }
    public var maxReceivePayloadSizeForGaia: Int {
        return optimumWriteLength - 4 - (connectionKind == .iap2 ? 5 : 3)
    }

    public var maxSendPayloadSizeForGaia: Int {
        return optimumWriteLength - 4 - (connectionKind == .iap2 ? 5 : 3)
    }

    public private(set) var state: GaiaDeviceConnectionState = .disconnected {
        didSet {
            delegate?.stateChanged(connection: self)
        }
    }

    // MARK: init/deinit
    public init(path: URL, mockedKind: ConnectionKind) {
        connectionKind = mockedKind
        var str = ""
        do {
            str = try String(contentsOf: path)
        } catch (let e) {
            LOG(.high, "Couldn't read replay file: \(path)\nError: \(e)")
        }
        fileContents = str.components(separatedBy: .newlines)

        super.init()
        state = .uninitialised
        
        commandQueue.delegate = self
    }

    // MARK: Public Methods
    public func start() {
        state = .initialising
        state = .ready
        queueNextLine()
    }
    public func acknowledgementReceived() {
        commandQueue.acknowledgementReceived()
        writeFromQueue()
     }

    public func sendData(channel: GaiaDeviceConnectionChannel, payload: Data, acknowledgementExpected: Bool) {
        if connected && state == .ready {
            commandQueue.queueItem(CommandQueue.Command(data: payload, acknowledgementExpected: acknowledgementExpected))
            writeFromQueue()
        }
    }

    public func transportParametersReceived(protocolVersion: Int, maxSendSize: Int, optimumSendSize: Int, maxReceiveSize: Int) {
		// Replay file ignores.
    }

    public func equivalentConnectionIDsForReconnection(btAddresses: [String], serialNumbers: [String]) -> [String] {
        return [connectionID]
    }
}

// MARK: - CommandQueueDelegate
extension GaiaReplayScriptDeviceConnection: CommandQueueDelegate {
    func commandQueueTimedOut(_ queue: CommandQueue) {
        writeFromQueue()
    }
}

// MARK: - Private Methods
extension GaiaReplayScriptDeviceConnection {
    func writeFromQueue() {
        if commandQueue.itemAvailable && connected && state == .ready {
            let item = commandQueue.removeItem()!
            sendData(item.data)
        }
    }

    func connect() {
        assert(!connected)
        queueNextLine()
    }

    func disconnect() {
        commandQueue.reset()
        fileContentsIndex = -1
        state = .disconnected
        scriptDelegate?.scriptDisconnected()
    }

    func sendData(_ data: Data) {
        guard fileContentsIndex < fileContents.count else {
            return
        }

        let hex = data.hexString()
        currentSendingCommand = ReplayFileCommand.to.rawValue + hex

        let line = fileContents[fileContentsIndex].trimmingCharacters(in: .whitespacesAndNewlines)
        let decoded = ReplayFileCommand.decodeFileString(fileString: line)

        if decoded.command == .to {
			// We are currently waiting for a send - what good luck.
            processLineFromReplay()
        }
    }

    func queueNextLine() {
        fileContentsIndex = fileContentsIndex + 1
        processLineFromReplay()
    }

    func processLineFromReplay() {
        guard fileContentsIndex < fileContents.count else {
            return
        }

        let line = fileContents[fileContentsIndex].trimmingCharacters(in: .whitespacesAndNewlines)
        let decoded = ReplayFileCommand.decodeFileString(fileString: line)

        switch decoded.command {
        case .connect:
            connected = true
            state = .uninitialised
            scriptDelegate?.scriptConnected()
        case .disconnect:
            disconnect()
        case .from:
            if let data = decoded.remainder.fromHex() {
                DispatchQueue.main.async { [weak self] in
                    self?.delegate?.dataReceived(data, channel: .command)
                }
            }
            queueNextLine()
        case .to:
            if let firstWaiting = currentSendingCommand {
                // We need to wait for the incoming message from the app so we do nothing here
                if firstWaiting != line {
                    LOG(.high, "Unexpected Send!\nExpected: \(line)\nGot: \(firstWaiting)")
                    commandQueue.acknowledgementReceived() // Unlock the queue
                }
                currentSendingCommand = nil
                queueNextLine()
            } // else we need to wait for the incoming message from the app so we do nothing here
        case .unknown,
             .error:
            queueNextLine()
        case .timeout:
            if let delay = Double(decoded.remainder) {
                DispatchQueue.main.asyncAfter(deadline:.now() + delay) { [weak self] in
                    self?.queueNextLine()
                }
            } else {
                LOG(.low, "No timeout value - skipping")
                queueNextLine()
            }
        }
    }
}

// MARK: -

extension Data {
    func hexString() -> String {
        return self.reduce("", { $0 + String(format: "%02x", $1) } )
    }
}

extension String {
    func fromHex() -> Data? {
        if count % 2 != 0 {
            return nil
        }

        let hexChars = ["0", "1", "2", "3", "4", "5", "6", "7",
                         "8","9", "A", "B", "C", "D", "E", "F"]
        let uppercaseArray = Array(self.uppercased())
        let bytesStrArray = stride(from: 0, to: uppercaseArray.count, by: 2).map { String(uppercaseArray[$0..<$0+2]) }
        var resultBytes = [UInt8] ()
        bytesStrArray.forEach { pair in
            let firstCharIndex = hexChars.firstIndex(of: String(pair.first!)) ?? 0
            let secondCharIndex = hexChars.firstIndex(of: String(pair.last!)) ?? 0
            resultBytes.append(UInt8((firstCharIndex * 16) + secondCharIndex))
        }
		return Data(resultBytes)
    }
}
