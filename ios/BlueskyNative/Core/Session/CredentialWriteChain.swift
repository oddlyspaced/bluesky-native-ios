import Foundation

/// The one ordered chain of credential writes, owned by `SessionStore` (review finding A46).
///
/// Rules:
/// - `enqueue` is synchronous and appends the operation after every operation enqueued before
///   it, so writes land in the order they were requested, from any thread (review finding A48).
/// - `generation` changes on every session transition. An operation that must only apply to one
///   session checks `isCurrent(_:)` inside the chain, just before it writes.
/// - A transition bumps the generation before it enqueues its own write, so every stale write
///   either ran before that write or is dropped when it reaches the head of the chain.
final class CredentialWriteChain: @unchecked Sendable {
    private let lock = NSLock()
    private var tail: Task<Void, Never>?
    private var generationValue = 0
    private var enqueued = 0

    var generation: Int { lock.withLock { generationValue } }

    /// Number of operations enqueued so far. Tests use it to wait for an enqueue.
    var enqueuedCount: Int { lock.withLock { enqueued } }

    /// Starts a new generation and returns it.
    func bumpGeneration() -> Int {
        lock.withLock {
            generationValue += 1
            return generationValue
        }
    }

    func isCurrent(_ generation: Int) -> Bool {
        lock.withLock { generationValue == generation }
    }

    /// Appends `operation` to the chain and returns its task.
    @discardableResult
    func enqueue<T: Sendable>(_ operation: @escaping @Sendable () async -> T) -> Task<T, Never> {
        lock.withLock {
            let previous = tail
            let task = Task<T, Never> {
                await previous?.value
                return await operation()
            }
            tail = Task { _ = await task.value }
            enqueued += 1
            return task
        }
    }

    /// Returns when every operation enqueued before and during the wait has finished.
    func waitUntilIdle() async {
        while true {
            let current = lock.withLock { tail }
            await current?.value
            if lock.withLock({ tail == current }) { return }
        }
    }
}
