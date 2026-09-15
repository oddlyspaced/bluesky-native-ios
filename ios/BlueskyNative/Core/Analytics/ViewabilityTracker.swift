import Foundation

/// Port of RN's `ViewabilityHelper` as `List.onItemSeen` configures it
/// (`src/view/com/util/List.tsx:123-131`: `minimumViewTime: 500`), for `post:view` (review finding N6).
///
/// RN behaviour, from `node_modules/react-native/Libraries/Lists/ViewabilityHelper.js`:
/// - Each change of the viewable set starts one timer with a snapshot of the viewable indices.
/// - When the timer fires, the snapshot is filtered to the items still viewable, and the items not
///   viewable in the previous result are reported in ascending index order.
///
/// The port:
/// - Coalesces `appeared` and `disappeared` calls made in one main-actor turn into one change,
///   as one RN layout pass computes one viewable set.
/// - Processes changes one at a time, each at its own deadline (change time + 500 ms), so reports
///   keep the order of the changes.
/// - Treats a row that SwiftUI has laid out as viewable. RN also requires 40% of the row to be
///   visible; PARITY.md records that difference.
@MainActor
final class ViewabilityTracker<ID: Hashable> {
    /// Waits until a deadline. Tests inject a gate instead of the clock.
    typealias Waiter = @MainActor (ContinuousClock.Instant) async -> Void

    static var minimumViewTime: Duration { .milliseconds(500) }

    private struct Change {
        var ids: [ID]
        var deadline: ContinuousClock.Instant
    }

    private let waiter: Waiter
    private let onViewable: @MainActor ([ID]) -> Void
    private var visible: [ID: Int] = [:]
    private var viewable: Set<ID> = []
    private var changes: [Change] = []
    private var coalescing = false
    private var worker: Task<Void, Never>?

    init(waiter: @escaping Waiter = { deadline in try? await Task.sleep(until: deadline, clock: .continuous) },
         onViewable: @escaping @MainActor ([ID]) -> Void) {
        self.waiter = waiter
        self.onViewable = onViewable
    }

    func appeared(_ id: ID, index: Int) {
        visible[id] = index
        scheduleChange()
    }

    func disappeared(_ id: ID) {
        guard visible.removeValue(forKey: id) != nil else { return }
        scheduleChange()
    }

    /// Stops pending reports.
    func cancel() {
        worker?.cancel()
        worker = nil
        changes = []
    }

    private func scheduleChange() {
        guard !coalescing else { return }
        coalescing = true
        Task { @MainActor [weak self] in
            self?.recordChange()
        }
    }

    private func recordChange() {
        coalescing = false
        let snapshot = visible.sorted { $0.value < $1.value }.map(\.key)
        changes.append(Change(ids: snapshot, deadline: .now + Self.minimumViewTime))
        guard worker == nil else { return }
        worker = Task { [weak self] in
            await self?.drain()
        }
    }

    private func drain() async {
        while !changes.isEmpty, !Task.isCancelled {
            let change = changes.removeFirst()
            await waiter(change.deadline)
            guard !Task.isCancelled else { break }
            let still = change.ids.filter { visible[$0] != nil }
                .sorted { (visible[$0] ?? 0) < (visible[$1] ?? 0) }
            let next = Set(still)
            let newly = still.filter { !viewable.contains($0) }
            if next != viewable { viewable = next }
            if !newly.isEmpty { onViewable(newly) }
        }
        worker = nil
    }
}
