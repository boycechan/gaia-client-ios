//
//  © 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation
import Network

class Reachability {
    static let shared = Reachability()

    private(set) var isReachable: Bool = false
    private var monitor = NWPathMonitor()
    private var started = false

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            self.handleChangedPath(path)
        }
    }

    deinit {
        monitor.cancel()
    }

    func start() {
        guard !started else { return }
        started = true
        monitor.start(queue: DispatchQueue.global(qos: .background))
    }

    func handleChangedPath(_ path: NWPath) {
        isReachable = path.status == .satisfied
    }
}
