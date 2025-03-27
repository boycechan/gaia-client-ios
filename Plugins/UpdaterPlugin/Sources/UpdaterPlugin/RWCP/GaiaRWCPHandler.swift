//
//  © 2021 - 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation
import GaiaBase
import GaiaLogger

class GaiaRWCPHandler: GaiaRWCPHandlerProtocol {
/// Delegate class for callbacks.
    private weak var delegate:  GaiaRWCPHandlerDelegate?

    private var connection: GaiaDeviceConnectionProtocol?
    private var state = RWCPHandlerState()
    private var timer: Timer?

    required init(connection: GaiaDeviceConnectionProtocol, delegate: GaiaRWCPHandlerDelegate?) {
        self.connection = connection
        self.delegate = delegate
    }

    func prepareForUpdate(initialCongestionWindowSize: Int,
                          maximumCongestionWindowSize: Int) {
        state.initialCongestionWindowSize = initialCongestionWindowSize
        state.maximumCongestionWindowSize = maximumCongestionWindowSize
    }

    func didReceive(data: Data) {
        guard data.count >= RWCPConstants.RWCP_HEADER_SIZE else {
            return
        }

        if let segment = RWCPSegment(data: data) {
            switch (segment.opCode) {
            case RWCPConstants.RWCP_HEADER_OPCODE_SYN_ACK:
                receiveSynAck(segment: segment)
            case RWCPConstants.RWCP_HEADER_OPCODE_DATA_ACK:
                receiveDataAck(segment: segment)
            case RWCPConstants.RWCP_HEADER_OPCODE_RST:
                receiveRST(segment: segment)
            case RWCPConstants.RWCP_HEADER_OPCODE_GAP:
                receiveGAP(segment: segment)
            default:
                break
            }
        }
    }

    func setPayload(data: Data, lastPacket: Bool) {
        state.pendingData.append(data)
        state.isMoreToSend = !lastPacket
    }

    func startTransfer() {
        switch state.connectionState {
        case .listen:
            startSession()
        case .established:
            sendDataSegment()
        default:
            break
        }
    }

    func teardown() {
        reset(complete: true)
    }

    func powerOff() {
        state = RWCPHandlerState()
    }

    func abort() {
        LOG(.medium, "RWCP Abort");
        guard state.connectionState != .listen else {
            LOG(.medium, "State is listen so not aborting...")
            return
        }

        reset(complete: true)
        sendRSTSegment()
        terminateSession()
    }
}

// Lifecycle
private extension GaiaRWCPHandler {
    @discardableResult
    func startSession() -> Bool {
        LOG(.medium, "startSession")

        guard state.connectionState == .listen else {
            LOG(.medium, "Start RWCP session failed: already an ongoing session.")
            return false
        }

        if sendRSTSegment() {
            return true
        } else {
            LOG(.medium, "Start RWCP session failed: sending of RST segment failed.")
            terminateSession()
            return false
        }
    }

    func terminateSession() {
        LOG(.medium, "terminateSession")
        reset(complete: true)
    }
}


// Receive functions
private extension GaiaRWCPHandler {
    func receiveSynAck(segment: RWCPSegment) {
        switch state.connectionState {
        case .synSent:
            cancelTimeout()

            let validated = validateAckSequence(opCode: RWCPConstants.RWCP_HEADER_OPCODE_SYN, sequence:segment.sequence)

            if validated >= 0 {
                state.connectionState = .established;
                if state.pendingData.count > 0 {
                    sendDataSegment()
                }
            } else {
                LOG(.medium, "Receive SYN_ACK with unexpected sequence number: \(segment.sequence)")
                terminateSession()
                sendRSTSegment()
            }
        case .established:
            cancelTimeout()

            if state.unacknowledgedSegments.count > 0 {
                resendDataSegment()
            }
        case .listen,
             .closing:
            LOG(.medium, "Received unexpected SYN_ACK segment with header while in state \(state.connectionState.userVisibleName())")
        }
    }

    func receiveDataAck(segment: RWCPSegment) {
        switch state.connectionState {
        case .established:
            cancelTimeout()

            let validated = validateAckSequence(opCode: RWCPConstants.RWCP_HEADER_OPCODE_DATA, sequence:segment.sequence)

            if validated >= 0 {
                if state.credits > 0 && state.pendingData.count > 0 {
                    sendDataSegment()
                } else if state.pendingData.count == 0 && state.unacknowledgedSegments.count == 0 {
                    sendRSTSegment()
                } else if (state.pendingData.count == 0 && state.unacknowledgedSegments.count > 0) ||
                            (state.credits == 0 && state.pendingData.count > 0) {
                    startTimer(timeoutInMs: state.dataTimeout)
                }
            }
        case .closing:
            LOG(.medium, "Received DATA_ACK(\(segment.sequence)) segment while in state CLOSING: segment discarded.")
        case .synSent,
             .listen:
            LOG(.medium, "Received unexpected DATA_ACK segment with sequence \(segment.sequence) while in state \(state.connectionState.userVisibleName())")
        }
    }

    func receiveRST(segment: RWCPSegment) {
        LOG(.low, "Receive RST or RST_ACK for sequence \(segment.sequence)")
        switch state.connectionState {
        case .synSent:
            LOG(.medium, "Received in SynSent state, ignoring segment")
        case .established:
            LOG(.medium, "Received RST (sequence \(segment.sequence) in ESTABLISHED state, terminating session, transfer failed.")
            terminateSession()
        case .closing:
            cancelTimeout()
            validateAckSequence(opCode: RWCPConstants.RWCP_HEADER_OPCODE_RST, sequence:segment.sequence)
            reset(complete: false)

            if state.pendingData.count > 0 {
                if !sendSYNSegment() {
                    LOG(.high, "Start session of RWCP data transfer failed: sending of SYN failed.")
                    terminateSession()
                }
            } else {
                delegate?.didCompleteDataSend()
            }
        case .listen:
            LOG(.medium, "Received unexpected RST segment with sequence=\(segment.sequence) while in state \(state.connectionState.userVisibleName())")
        }
    }

    func receiveGAP(segment: RWCPSegment) {
        LOG(.low, "Receive GAP for sequence \(segment.sequence)");

        switch state.connectionState {
        case .established:
            let discard = shouldDiscardGAP(sequence: segment.sequence, last: state.lastAckSequence, window: state.window)
            if discard {
                LOG(.medium, "Ignoring GAP (\(segment.sequence) as last ack sequence is \(state.lastAckSequence).")
                return
            }

            decreaseWindow()

            validateAckSequence(opCode: RWCPConstants.RWCP_HEADER_OPCODE_GAP, sequence:segment.sequence)

            cancelTimeout()
            resendDataSegment()
        case .closing:
            LOG(.medium, "Received GAP(\(segment.sequence) segment while in state CLOSING: segment discarded.")
        case .listen,
             .synSent:
            LOG(.medium, "Received unexpected GAP segment with header while in state \(state.connectionState.userVisibleName())")
        }
    }

    func shouldDiscardGAP(sequence:UInt8, last: Int, window: Int) -> Bool {
        let seqInt = Int(sequence)
        let difference: Int = ((last > seqInt) ? RWCPConstants.RWCP_MAX_SEQUENCE : 0) + seqInt - last
        return difference > 0 && difference <= window
    }

    @discardableResult
    func validateAckSequence(opCode: UInt8, sequence: UInt8) -> Int {
        let notValidated = -1

        if sequence > RWCPConstants.RWCP_MAX_SEQUENCE {
            LOG(.medium, "Received ACK sequence \(sequence) is bigger than its maximum value \(RWCPConstants.RWCP_MAX_SEQUENCE)")
            return notValidated
        }
        if state.lastAckSequence < state.nextSequence && (sequence < state.lastAckSequence || sequence > state.nextSequence) {
            LOG(.medium, "Received ACK sequence \(sequence) is out of interval: last received is \(state.lastAckSequence) and next will be \(state.nextSequence)")
            return notValidated
        }
        if state.lastAckSequence > state.nextSequence && sequence < state.lastAckSequence && sequence > state.nextSequence {
            LOG(.medium, "Received ACK sequence \(sequence) is out of interval: last received is \(state.lastAckSequence) and next will be \(state.nextSequence)")
            return notValidated;
        }

        var acknowledged = 0;
        var nextAckSequence = state.lastAckSequence;

        while (nextAckSequence != sequence) {
            nextAckSequence = increaseSequenceNumber(nextAckSequence)

            if removeSegmentFromQueue(opCode: opCode, sequence: UInt8(nextAckSequence), success: true) {
                state.lastAckSequence = nextAckSequence

                if state.credits < state.window {
                    state.credits = state.credits + 1
                }

                acknowledged = acknowledged + 1
            } else {
                LOG(.medium, "Error validating sequence \(nextAckSequence): no corresponding segment in pending segments.")
            }
        }

        // increase the window size if qualified.
        increaseWindow(acknowledged: acknowledged)

        return acknowledged
    }

}


// Sending
private extension GaiaRWCPHandler {
    @discardableResult
    func sendRSTSegment() -> Bool {
        guard state.connectionState != .closing else {
            return true
        }

        reset(complete: false)
        state.connectionState = .closing

        let segment = RWCPSegment(opCode: RWCPConstants.RWCP_HEADER_OPCODE_RST, sequence: UInt8(state.nextSequence))
        let done = sendSegment(segment, delay: RWCPConstants.RWCP_RST_TIMEOUT_MS)
        if (done) {
            state.unacknowledgedSegments.append(segment)
            state.nextSequence = increaseSequenceNumber(state.nextSequence)
            state.credits = state.credits - 1
            LOG(.low, "send RST segment")
        }

        return done
    }

    func sendSYNSegment() -> Bool  {
        state.connectionState = .synSent

        let segment = RWCPSegment(opCode: RWCPConstants.RWCP_HEADER_OPCODE_SYN, sequence: UInt8(state.nextSequence))
        let done = sendSegment(segment, delay: RWCPConstants.RWCP_SYN_TIMEOUT_MS)
        if (done) {
            state.unacknowledgedSegments.append(segment)
            state.nextSequence = increaseSequenceNumber(state.nextSequence)
            state.credits = state.credits - 1
            LOG(.low, "send SYN segment")
        }

        return done
    }

    func sendDataSegment() {
        while state.credits > 0 &&
                state.pendingData.count > 0 &&
                !state.isResendingSegments &&
                state.connectionState == .established {

            if let data = state.pendingData.first {
                let segment = RWCPSegment(opCode: RWCPConstants.RWCP_HEADER_OPCODE_DATA,
                                          sequence: UInt8(state.nextSequence),
                                          payload: data)

                state.pendingData.remove(at: 0)
                if sendSegment(segment, delay: state.dataTimeout) {
                    state.unacknowledgedSegments.append(segment)
                    state.nextSequence = increaseSequenceNumber(state.nextSequence)
                    state.credits = state.credits - 1
                }
            }
        }
    }

    func sendSegment(_ segment: RWCPSegment, delay: Int) -> Bool {
        connection?.sendData(channel: .data, payload: segment.data, acknowledgementExpected: false)
        startTimer(timeoutInMs: delay)
        return true
    }

    func resendSegment() {
        guard state.connectionState != .established else {
            LOG(.medium, "Trying to resend non data segment while in ESTABLISHED state.")
            return
        }

        state.isResendingSegments = true
        state.credits = state.window

        for segment in state.unacknowledgedSegments {
            var delay = state.dataTimeout
            switch segment.opCode {
            case RWCPConstants.RWCP_HEADER_OPCODE_SYN:
                delay = RWCPConstants.RWCP_SYN_TIMEOUT_MS
            case RWCPConstants.RWCP_HEADER_OPCODE_RST:
                delay = RWCPConstants.RWCP_RST_TIMEOUT_MS
            default:
                break
            }
            if sendSegment(segment, delay: delay) {
            	state.credits = state.credits - 1
            }
        }

        LOG(.medium, "Resend segments");
        state.isResendingSegments = false
    }

    func resendDataSegment() {
        guard state.connectionState == .established else {
            LOG(.medium, "Trying to resend non data segment while not in ESTABLISHED state.")
            return
        }

        state.isResendingSegments = true
        state.credits = state.window

        var moved = 0

        while state.unacknowledgedSegments.count > state.credits {
            if let segment = state.unacknowledgedSegments.last {
                if segment.opCode == RWCPConstants.RWCP_HEADER_OPCODE_DATA {
                    removeSegmentFromQueue(opCode: segment.opCode, sequence: segment.sequence, success: false)
                    state.pendingData.insert(segment.payload, at: 0)
                    moved = moved + 1
                } else {
                    break
                }
            }
        }

        state.nextSequence = decreaseSequenceNumber(state.nextSequence, decrease:moved)

        for segment in state.unacknowledgedSegments {
            LOG(.low, "Resend \(segment.sequence)")
            if sendSegment(segment, delay: state.dataTimeout) {
                state.credits = state.credits - 1
            }
        }

        state.isResendingSegments = false;

        if state.credits > 0 {
            LOG(.medium, "Resend DATA segments")
            sendDataSegment();
        }
    }
}

// Timer
private extension GaiaRWCPHandler {
    func didTimeOut() {
        guard state.connectionState == .established else {
			return
        }

        LOG(.high, "TIME OUT > re sending segments")
        cancelTimeout()
        state.isResendingSegments = false
        state.acknowledgedSegments = 0

        if (state.connectionState == .established) {
            state.dataTimeout = min(state.dataTimeout * 2, RWCPConstants.RWCP_DATA_TIMEOUT_MS_MAX)

            resendDataSegment()
        } else {
            resendSegment()
        }
    }

    func cancelTimeout() {
        if timer != nil {
            timer?.invalidate()
            timer = nil
        }
    }

    func startTimer(timeoutInMs: Int) {
        cancelTimeout()
        timer = Timer.scheduledTimer(withTimeInterval: Double(timeoutInMs) * 0.001,
                                     repeats: false,
                                     block: { [weak self] _ in
                                        guard let self = self else {
                                            return
                                        }
                                        self.didTimeOut()
                                     })
    }
}

private extension GaiaRWCPHandler {
    func reset(complete: Bool) {
        let oldInitialCongestionWindowSize = state.initialCongestionWindowSize
        let oldMaximumCongestionWindowSize = state.maximumCongestionWindowSize
        let pending = complete ? [Data]() : state.pendingData
        let oldIsResendingSegments = state.isResendingSegments
        let oldIsMoreToSend = state.isMoreToSend

		state = RWCPHandlerState()

        state.initialCongestionWindowSize = oldInitialCongestionWindowSize
        state.maximumCongestionWindowSize = oldMaximumCongestionWindowSize
        state.window = oldMaximumCongestionWindowSize
        state.credits = oldMaximumCongestionWindowSize
        state.pendingData = pending
        state.isResendingSegments = oldIsResendingSegments
        state.isMoreToSend = oldIsMoreToSend
    }

    func increaseSequenceNumber(_ lastSequence: Int) -> Int {
        return (lastSequence + 1) % RWCPConstants.RWCP_SEQUENCE_SPACE_SIZE;
    }

    func decreaseSequenceNumber(_ lastSequence: Int, decrease: Int) -> Int {
        return (lastSequence - decrease + RWCPConstants.RWCP_SEQUENCE_SPACE_SIZE) % RWCPConstants.RWCP_SEQUENCE_SPACE_SIZE;
    }

    func increaseWindow(acknowledged: Int) {
        state.acknowledgedSegments = state.acknowledgedSegments + acknowledged

        if state.acknowledgedSegments > state.window &&
            state.window < state.maximumCongestionWindowSize {
            state.acknowledgedSegments = 0
            state.window = state.window + 1
            state.credits = state.credits + 1
            LOG(.low, "Increase window to \(state.window)")
        }
    }

    func decreaseWindow() {
        state.window = ((state.window - 1) / 2) + 1;

        if state.window > state.maximumCongestionWindowSize || state.window < 1 {
            state.window = 1
        }

        state.acknowledgedSegments = 0
        state.credits = state.window

        LOG(.low, "Decrease window to \(state.window)")
    }

    @discardableResult
    func removeSegmentFromQueue(opCode: UInt8, sequence: UInt8, success: Bool) -> Bool {
        if let index = state.unacknowledgedSegments.firstIndex(where: { $0.opCode == opCode && $0.sequence == sequence }) {
            let segment = state.unacknowledgedSegments[index]
            if success && opCode == RWCPConstants.RWCP_HEADER_OPCODE_DATA {
                delegate?.didSend(bytes: Double(segment.payload.count))
            }
            state.unacknowledgedSegments.remove(at: index)
            return true
        }

        LOG(.medium, "Pending segments does not contain acknowledged segment: code=\(opCode)\tsequence=\(sequence)")
        return false
    }
}
