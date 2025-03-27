//
//  © 2020 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation
import GaiaLogger

protocol CommandQueueDelegate: AnyObject {
    func commandQueueTimedOut(_ queue: CommandQueue)
}

class CommandQueue {
    struct Command {
        let data: Data
        let acknowledgementExpected: Bool
    }
    var itemAvailable: Bool {
        let result = queue.count > 0 && !awaitingResponse
        return result
    }

    private var timer: DispatchSourceTimer?

    private var queue = [Command] ()
    private var awaitingResponse: Bool = false
    weak var delegate: CommandQueueDelegate?

    func removeItem() -> Command? {
        guard itemAvailable else {
            LOG(.low, "Cannot remove item")
            return nil
        }

        let item = queue.removeFirst()
        if item.acknowledgementExpected {
            awaitingResponse = true
            setupTimeoutTimer { [weak self] in
                guard let self = self else { return }
                LOG(.high, "Lock timed out")
                self.awaitingResponse = false
                self.timer = nil
                self.delegate?.commandQueueTimedOut(self)
            }
        } else {
            awaitingResponse = false
        }
		return item
    }

    func queueItem(_ item: Command) {
        if item.data.count > 0 {
            queue.append(item)
        }
    }

    func acknowledgementReceived() {
        if let _ = timer {
            timer?.cancel()
			timer = nil
        }
        awaitingResponse = false
    }

    func reset() {
        if let _ = timer {
            timer?.cancel()
            timer = nil
        }
        awaitingResponse = false
        queue.removeAll()
    }

    private func setupTimeoutTimer(handler: @escaping () -> Void) {
        if let _ = timer {
            timer?.cancel()
            timer = nil
        }

        timer = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
        timer?.setEventHandler(handler: handler)
        timer?.schedule(deadline: DispatchTime.now() + .milliseconds(5000))
        timer?.resume()
    }
}
