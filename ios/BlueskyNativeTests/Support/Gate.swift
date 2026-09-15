import Foundation

/// A test gate: code under test calls `pass()` and waits until the test calls `open()`.
///
/// Tests order concurrent work with gates instead of sleeps (review finding A51):
/// `waitForArrivals(n)` returns once `n` callers reached the gate.
final class Gate: @unchecked Sendable {
    private let lock = NSLock()
    private var isOpen = false
    private var blocked: [CheckedContinuation<Void, Never>] = []
    private var arrivals = 0
    private var arrivalWaiters: [(count: Int, continuation: CheckedContinuation<Void, Never>)] = []

    init(open: Bool = false) {
        isOpen = open
    }

    /// Number of callers that reached the gate so far.
    var arrivalCount: Int { lock.withLock { arrivals } }

    /// Called by the code under test. Returns at once when the gate is open.
    func pass() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let (resumeNow, ready) = lock.withLock { () -> (Bool, [CheckedContinuation<Void, Never>]) in
                arrivals += 1
                let ready = arrivalWaiters.filter { $0.count <= arrivals }.map(\.continuation)
                arrivalWaiters.removeAll { $0.count <= arrivals }
                if isOpen { return (true, ready) }
                blocked.append(continuation)
                return (false, ready)
            }
            ready.forEach { $0.resume() }
            if resumeNow { continuation.resume() }
        }
    }

    /// Returns once `count` callers reached the gate (open or not).
    func waitForArrivals(_ count: Int = 1) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let resumeNow = lock.withLock { () -> Bool in
                if arrivals >= count { return true }
                arrivalWaiters.append((count, continuation))
                return false
            }
            if resumeNow { continuation.resume() }
        }
    }

    /// Opens the gate: blocked callers continue, later callers pass at once.
    func open() {
        let waiting = lock.withLock { () -> [CheckedContinuation<Void, Never>] in
            isOpen = true
            defer { blocked = [] }
            return blocked
        }
        waiting.forEach { $0.resume() }
    }

    /// Closes the gate for later callers.
    func close() {
        lock.withLock { isOpen = false }
    }
}
