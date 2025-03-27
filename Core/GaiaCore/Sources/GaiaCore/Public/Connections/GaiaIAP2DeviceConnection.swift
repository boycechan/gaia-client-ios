//
//  © 2020 - 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation
import ExternalAccessory
import GaiaBase
import Packets
import GaiaLogger

/// This class encapsulates the behavior of a Gaia Device that is discovered/connected/etc using the iAP2 transport.
public class GaiaIAP2DeviceConnection: NSObject, GaiaDeviceConnectionProtocol {

    // MARK: Private ivars
    private var maxReadBufferSize: Int = IAP2Packet.maxPacketSizeNoExtension
    private var gaiaManagerObserverToken: ObserverToken?
    private let accessory: EAAccessory
    private var session: EASession?
    private let notificationCenter: NotificationCenter
    private var dataToProcess = Data()
    private let commandQueue = CommandQueue()

    // MARK: Public ivars
    public weak var delegate: GaiaDeviceConnectionDelegate?

    public private(set) var state: GaiaDeviceConnectionState = .disconnected {
        didSet {
            delegate?.stateChanged(connection: self)
        }
    }

    public var connectionID: String { Self.connectionID(accessory: accessory) }
    public var name: String { accessory.name }

    public var connected: Bool { accessory.isConnected }
    public let connectionKind = ConnectionKind.iap2
    public var rssi: Int = 0
    public var maxReceivePayloadSizeForGaia: Int { return maxReadBufferSize - IAP2Packet.GAIAHeaderSize - (isDataLengthExtensionSupported ? 5 : 4) }
    public var maxSendPayloadSizeForGaia: Int { return optimumWriteLength - IAP2Packet.GAIAHeaderSize - (isDataLengthExtensionSupported ? 5 : 4) }

    public private(set) var isDataLengthExtensionSupported: Bool = false
    public private(set) var maximumWriteLength: Int = IAP2Packet.maxPacketSizeNoExtension
    public private(set) var maximumWriteWithoutResponseLength: Int = IAP2Packet.maxPacketSizeNoExtension
    public private(set) var optimumWriteLength: Int = IAP2Packet.maxPacketSizeNoExtension

    public class func connectionID(accessory: EAAccessory) -> String {
        return Self.connectionID(accessory: accessory, serial: accessory.serialNumber)
    }

    private class func connectionID(accessory: EAAccessory, serial: String) -> String {
        return "IAP-\(accessory.modelNumber)-\(serial)"
    }

    // MARK: init/deinit
    public required init(accessory: EAAccessory, notificationCenter: NotificationCenter) {
        self.accessory = accessory
        self.notificationCenter = notificationCenter
        super.init()

        self.accessory.delegate = self
        commandQueue.delegate = self
        state = accessory.isConnected ? .uninitialised : .disconnected

        gaiaManagerObserverToken = notificationCenter.addObserver(forType: GaiaManagerNotification.self,
                                                                          object: nil,
                                                                          queue: OperationQueue.main,
                                                                          using: { [weak self] notification in self?.gaiaManagerNotificationHandler(notification) })
    }

    deinit {
        LOG(.high, "deinit of iAP2 Connection")
		closeStreams()
        commandQueue.reset()
        notificationCenter.removeObserver(gaiaManagerObserverToken!)
    }

    // MARK: Public Methods

    public func start() {
        if state == .uninitialised {
            state = .initialising
            initializeStreams()
        }
    }

    public func reset() {
        closeStreams()
        commandQueue.reset()
    }
    
    public func acknowledgementReceived() {
        commandQueue.acknowledgementReceived()
        writeToStreamFromQueue()
    }

    public func sendData(channel: GaiaDeviceConnectionChannel, payload: Data, acknowledgementExpected: Bool) {
        if connected && state == .ready {
            commandQueue.queueItem(CommandQueue.Command(data: payload, acknowledgementExpected: acknowledgementExpected))
            writeToStreamFromQueue()
        } else {
            LOG(.high, "Device not ready to write to!")
        }
    }

    public func transportParametersReceived(protocolVersion: Int, maxSendSize: Int, optimumSendSize: Int, maxReceiveSize: Int) {
        isDataLengthExtensionSupported = protocolVersion > 3 // Version 4 and above allows larger packets.
		maximumWriteLength = maxSendSize
        maximumWriteWithoutResponseLength = maxSendSize
        maxReadBufferSize = maxReceiveSize
        optimumWriteLength = optimumSendSize

        LOG(.medium, "IAP2: protocol: \(protocolVersion) maxSend: \(maxSendSize) optimumSend: \(optimumSendSize) maxRead: \(maxReceiveSize)")
    }

    public func equivalentConnectionIDsForReconnection(btAddresses: [String], serialNumbers: [String]) -> [String] {
        var ids = [String]()
        for entry in serialNumbers {
            ids.append(Self.connectionID(accessory: accessory, serial: entry))
        }
        return ids
    }
}

// MARK: - CommandQueueDelegate
extension GaiaIAP2DeviceConnection: CommandQueueDelegate {
    func commandQueueTimedOut(_ queue: CommandQueue) {
        if connected && state == .ready {
            delegate?.didSendData(channel: .command, error: .writeToDeviceTimedOut)
            writeToStreamFromQueue()
        }
    }
}

// MARK: - EAAccessoryDelegate
extension GaiaIAP2DeviceConnection: EAAccessoryDelegate {
}

// MARK: - StreamDelegate
extension GaiaIAP2DeviceConnection: StreamDelegate {
    public func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        switch eventCode {
        case .openCompleted:
            if aStream == session?.inputStream {
                LOG(.high, "Input Stream Opened")
            } else {
                LOG(.high, "Output Stream Opened")
            }
        case .errorOccurred:
            LOG(.high, "iAP2 Stream Error Occured")
            state = .initialisationFailed
            commandQueue.reset()
        case .hasBytesAvailable:
            handleBytesAvailable()
        case .hasSpaceAvailable:
            if state != .ready {
                state = .ready
            }
            writeToStreamFromQueue()
        case .endEncountered:
            guard aStream == session?.outputStream else {
                return
            }
            LOG(.high, "******8 iAP2 Stream unexpectedly torn-down on remote end. Re-creating. *******")
            commandQueue.reset()
            closeStreams()
            initializeStreams()
        default:
            break
        }
    }
}

// MARK: - Notification Handlers
extension GaiaIAP2DeviceConnection {
    func gaiaManagerNotificationHandler(_ notification: GaiaManagerNotification) {
        switch notification.payload {
        case .device(let device):
            if device.connectionID == connectionID {
                switch notification.reason {
                case .disconnect,
                     .poweredOff:
                    LOG(.high, "GaiaIAP2DeviceConnection - disconnect or connectFailed")
                    closeStreams()
                    commandQueue.reset()
                    state = .disconnected
                    break
                default:
                    break
                }
            }
        default:
            break
        }
    }
}

// MARK: - Private Methods
private extension GaiaIAP2DeviceConnection {
    func initializeStreams() {
        if session == nil {
            LOG(.high, "Creating new session for \(accessory.name)")
            session = EASession(accessory: accessory, forProtocol: Gaia.iap2ProtocolName)

            if let inputStream = session?.inputStream,
               let outputStream = session?.outputStream {
                inputStream.delegate = self
                inputStream.schedule(in: RunLoop.current, forMode: .common)
                inputStream.open()

                outputStream.delegate = self
                outputStream.schedule(in: RunLoop.current, forMode: .common)
                outputStream.open()

                LOG(.medium, "Transport session/streams set up for \(accessory.name)")
            } else {
                LOG(.high, "Streams not available")
                commandQueue.reset()
                state = .initialisationFailed
            }
        } else {
            LOG(.medium, "Session already exists for \(accessory.name)")
        }
    }

    func closeStreams() {
        if session != nil {
            LOG(.medium, "Tearing down session for \(accessory.name)")
            session?.inputStream?.close()
            session?.inputStream?.remove(from: RunLoop.current, forMode: .common)
            session?.inputStream?.delegate = nil
            session?.outputStream?.close()
            session?.outputStream?.remove(from: RunLoop.current, forMode: .common)
            session?.outputStream?.delegate = nil
            session = nil
            state = .uninitialised
        }
    }

    private func writeToStreamFromQueue() {
        guard
            connected,
            state == .ready,
            commandQueue.itemAvailable
        else {
			return
        }

        guard
            let sessionStream = session?.outputStream,
            sessionStream.hasSpaceAvailable
        else {
            LOG(.high, "Couldn't write to stream!!!")
            return
        }

        let item = commandQueue.removeItem()!

        if let dataToSend = IAP2Packet.data(payload: item.data, extensionSupported: isDataLengthExtensionSupported) {
            var writtenBytes: Int = -1
            dataToSend.withUnsafeBytes { ptr in
                guard let bytes = ptr.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                    return
                }
                writtenBytes = sessionStream.write(bytes, maxLength: dataToSend.count)
            }

            if writtenBytes > 0 {
                delegate?.didSendData(channel: .command, error: nil)
                LOG(.low, "Wrote \(writtenBytes) bytes")
            } else {
                if item.acknowledgementExpected {
                    commandQueue.acknowledgementReceived() // Otherwise it might be locked forever
                }
                LOG(.high, "Error writing to stream")
            }
        }
    }

    private func handleBytesAvailable() {
        guard let sessionStream = session?.inputStream else {
            return
        }

        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: maxReadBufferSize)
        defer {
            buffer.deallocate()
        }
        let bytesRead = sessionStream.read(buffer, maxLength: maxReadBufferSize)
        let bufferData = Data(bytes: buffer, count: bytesRead)

        LOG(.low, "Read \(bytesRead) bytes")

        dataToProcess.append(bufferData)

        var completed = dataToProcess.count == 0
        while !completed {
            if let packet = IAP2Packet(streamData: dataToProcess) {
                let gattPacketData = packet.payload
                delegate?.dataReceived(gattPacketData, channel: .response)
                dataToProcess = (dataToProcess.count > packet.totalLength) ? dataToProcess.advanced(by: packet.totalLength) : Data()
                completed = dataToProcess.count == 0
            } else {
                // Couldn't read packet
                if dataToProcess[0] != IAP2Packet.expectedSOF {
                    // First byte wasn't expected SOF - Skip to first 0xff we can find
                    if let byteIndex = dataToProcess.firstIndex(of: IAP2Packet.expectedSOF) {
                        // Start again at the next 0xff
                        dataToProcess = dataToProcess.advanced(by: byteIndex)
                    } else {
                        // There wasn't an 0xff in the stream - throw what we have and wait for more
                        dataToProcess = Data()
                        completed = true
                    }
                } else {
                    // The first byte is 0xff already - there aren't enough bytes - wait for more
					completed = true
                }
            }
        }
    }
}
