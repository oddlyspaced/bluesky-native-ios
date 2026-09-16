import Foundation
import Observation
import os

/// Port of the unread notifications provider (`src/state/queries/notifications/unread.tsx`).
///
/// - Checks once when the shell appears, then every 30 seconds (`UPDATE_INTERVAL`).
/// - Each check does nothing while the app is not active (RN checks `AppState.currentState`).
/// - A poll that already has a non-zero count skips when the count is 30 or more, or with
///   probability 0.5 (RN's load-shedding rule, lines 147-152).
/// - One check runs at a time.
@MainActor
@Observable
final class UnreadNotificationsModel {
    static let updateInterval: Duration = .seconds(30)

    private(set) var count = 0

    @ObservationIgnored private let api: any BlueskyAPI
    @ObservationIgnored private let random: @Sendable () -> Double
    @ObservationIgnored private var isFetching = false
    @ObservationIgnored private var pollTask: Task<Void, Never>?
    @ObservationIgnored private let log = Logger(subsystem: "io.nativestarter.showcase.bluesky", category: "unread")

    init(api: any BlueskyAPI, random: @escaping @Sendable () -> Double = { Double.random(in: 0..<1) }) {
        self.api = api
        self.random = random
    }

    /// "" for zero, "30+" from 30, otherwise the number.
    var displayText: String {
        count >= 30 ? "30+" : count == 0 ? "" : String(count)
    }

    /// Runs the initial check and the 30 s poll until `stopPolling()` or cancellation.
    ///
    /// The task is stored before the first check runs, so a `stopPolling()` during that check
    /// also ends the loop (review finding A62).
    func startPolling(activity: any AppActivity, interval: Duration = UnreadNotificationsModel.updateInterval,
                      wait: @escaping @Sendable (Duration) async -> Void = { try? await Task.sleep(for: $0) }) async {
        pollTask?.cancel()
        let task = Task { [weak self] in
            await self?.check(isPoll: false, isActive: activity.isActive)
            while !Task.isCancelled {
                await wait(interval)
                guard let self, !Task.isCancelled else { return }
                await self.check(isPoll: true, isActive: activity.isActive)
            }
        }
        pollTask = task
        await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            task.cancel()
        }
    }

    func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    func check(isPoll: Bool, isActive: Bool = true) async {
        guard isActive, !isFetching else { return }
        if isPoll && count != 0 {
            if count >= 30 || random() >= 0.5 { return }
        }
        isFetching = true
        defer { isFetching = false }
        do {
            let notifications = try await api.listNotifications(limit: 40)
            count = Self.countUnread(notifications)
        } catch where RequestFailure.isCancellation(error) {
            return
        } catch {
            // Logged, not kept as state: no view ever read it, and a failed check keeps the count
            // already on screen (review finding A82).
            log.error("Unread check failed: \(String(describing: error), privacy: .public)")
        }
    }

    /// Grouping does not change the count: RN adds grouped notifications back in.
    nonisolated static func countUnread(_ notifications: [NotificationView]) -> Int {
        notifications.filter { !$0.isRead }.count
    }
}
