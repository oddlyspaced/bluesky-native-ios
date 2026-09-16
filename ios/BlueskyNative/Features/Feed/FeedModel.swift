import Foundation
import Observation
import os

/// Loads `app.bsky.actor.getPreferences` for the account (`src/state/queries/preferences`).
///
/// Only a successful load is kept (review finding A54). A failure is thrown to every caller of
/// that request, and the next `load()` asks the server again. Concurrent callers share one
/// request; a cancelled caller stops waiting without cancelling the request for the others.
@MainActor
@Observable
final class PreferencesModel {
    /// `STALE.SECONDS.FIFTEEN`, the preferences query's stale time (`preferences/index.ts:65`).
    static let staleTime: TimeInterval = 15

    private(set) var preferences: ActorPreferences?
    /// When `preferences` last arrived from the server.
    @ObservationIgnored private(set) var loadedAt: Date?
    @ObservationIgnored private let api: any BlueskyAPI
    @ObservationIgnored private let now: @MainActor () -> Date
    @ObservationIgnored private var task: Task<ActorPreferences, any Error>?
    @ObservationIgnored private let log = Logger(subsystem: "io.nativestarter.showcase.bluesky", category: "preferences")

    init(api: any BlueskyAPI, now: @escaping @MainActor () -> Date = { Date() }) {
        self.api = api
        self.now = now
    }

    /// True when no preferences are loaded or they are older than `staleTime`. A screen that
    /// mounts on stale data refetches it in the background, as a stale query does.
    var isStale: Bool {
        guard let loadedAt else { return true }
        return now().timeIntervalSince(loadedAt) > Self.staleTime
    }

    /// Returns the preferences, loading them when none are loaded yet.
    func load() async throws -> ActorPreferences {
        if let preferences { return preferences }
        return try await fetch()
    }

    /// Asks the server again, as a stale query refetch does. A failure keeps the loaded value.
    func refetch() async throws -> ActorPreferences {
        try await fetch()
    }

    private func fetch() async throws -> ActorPreferences {
        let running: Task<ActorPreferences, any Error>
        if let task {
            running = task
        } else {
            let api = self.api
            running = Task { try await api.getPreferences() }
            task = running
        }
        do {
            let loaded = try await running.value
            if task == running { task = nil }
            // Cancellation is checked before the commit, not after: a cancelled caller used to
            // publish the value and refresh `loadedAt`, then throw (review finding A86).
            try Task.checkCancellation()
            preferences = loaded
            loadedAt = now()
            return loaded
        } catch {
            if task == running { task = nil }
            if !RequestFailure.isCancellation(error) {
                log.error("getPreferences failed: \(String(describing: error), privacy: .public)")
            }
            throw error
        }
    }

    /// The feed's rule: RN's defaults (`DEFAULT_HOME_FEED_PREFS`) when the load fails, so the
    /// feed still loads. Cancellation is rethrown.
    func loadOrDefaults() async throws -> ActorPreferences {
        do {
            return try await load()
        } catch where RequestFailure.isCancellation(error) {
            throw error
        } catch {
            return ActorPreferences()
        }
    }
}

/// Loads and pages a feed. Port of RN `usePostFeedQuery` (`src/state/queries/post-feed.ts`)
/// for the two feeds in this slice: the Following timeline (`HomeFeedAPI`) and an author feed.
@MainActor
@Observable
final class FeedModel {
    enum Source: Sendable, Equatable {
        case following
        case author(actor: String, filter: AuthorFeedFilter)
    }

    enum Status: Equatable {
        case idle
        case loading
        case loaded
        /// First load failed with no rows; the text is `cleanError` output.
        case failed(String)
    }

    /// `MIN_POSTS`, used as the fetch limit, and `MAX_ATTEMPTS` of auto-pagination (`util.ts:29-94`).
    static let pageSize = 30
    static let maxAttempts = 5

    private(set) var slices: [FeedSlice] = []
    /// Rendered rows, rebuilt only when slices change (review finding A37).
    private(set) var rows: [FeedRow] = []
    private(set) var status: Status = .idle
    private(set) var isRefreshing = false
    private(set) var isLoadingMore = false
    /// True once the Following timeline is exhausted (RN `FALLBACK_MARKER_POST`).
    private(set) var showsFallbackMarker = false
    private(set) var hasMore = false
    /// A load that failed while rows were showing (RN `loadMoreError` row).
    private(set) var loadMoreError: String?

    /// RN feed descriptor: `following` or `author|<did>|<filter>`.
    let feedDescriptor: String
    var feedType: String { String(feedDescriptor.split(separator: "|").first ?? "") }

    @ObservationIgnored private let source: Source
    @ObservationIgnored private let api: any BlueskyAPI
    @ObservationIgnored private let preferences: PreferencesModel
    @ObservationIgnored private let analytics: any AnalyticsSink
    @ObservationIgnored private let faults: DebugFaults?
    @ObservationIgnored private let userDid: String
    @ObservationIgnored private var cursor: String?
    @ObservationIgnored private var tuner = FeedTuner()
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var loadMoreTask: Task<Void, Never>?
    @ObservationIgnored private var lastFailureWasRefresh = false
    /// URIs already reported with `post:view` (once per URI per feed instance).
    @ObservationIgnored private var viewedPosts = Set<String>()
    /// Row id to index in `rows`, for the viewability order.
    @ObservationIgnored private var rowIndex: [String: Int] = [:]
    @ObservationIgnored private var tracker: ViewabilityTracker<String>?

    init(source: Source, api: any BlueskyAPI, preferences: PreferencesModel, analytics: any AnalyticsSink = NoopAnalytics(),
         faults: DebugFaults? = nil, userDid: String, viewWaiter: ViewabilityTracker<String>.Waiter? = nil) {
        self.source = source
        self.api = api
        self.preferences = preferences
        self.analytics = analytics
        self.faults = faults
        self.userDid = userDid
        switch source {
        case .following: feedDescriptor = "following"
        case .author(let actor, let filter): feedDescriptor = "author|\(actor)|\(filter.rawValue)"
        }
        let onViewable: @MainActor ([String]) -> Void = { [weak self] ids in self?.reportViewable(ids) }
        tracker = viewWaiter.map { ViewabilityTracker(waiter: $0, onViewable: onViewable) }
            ?? ViewabilityTracker(onViewable: onViewable)
    }

    var isFollowing: Bool { source == .following }

    /// RN `isEmpty`: no slices; the fallback marker counts as a slice.
    var isEmpty: Bool { slices.isEmpty && !showsFallbackMarker }

    /// Rows RN counts in `feedItems.length` for `feed:endReached`: the composer prompt
    /// (Following only), post and "View full thread" rows, and the fallback marker.
    var metricItemCount: Int {
        (isFollowing && !isEmpty ? 1 : 0) + rows.count + (showsFallbackMarker ? 1 : 0)
    }

    func loadIfNeeded() async {
        guard status == .idle else { return }
        status = .loading
        await reload()
    }

    /// Pull to refresh (`PostFeed.tsx:748`).
    func pullToRefresh() async {
        analytics.metric("feed:refresh", ["feedType": .string(feedType), "feedUrl": .string(feedDescriptor),
                                          "reason": "pull-to-refresh"])
        await reload()
    }

    /// Reloads from the first page. Rows stay visible until the new page arrives. A running
    /// `loadMore` is cancelled and its result is dropped (review finding A7).
    func reload() async {
        generation += 1
        let generation = self.generation
        loadMoreTask?.cancel()
        loadMoreTask = nil
        isLoadingMore = false
        isRefreshing = true
        defer { if generation == self.generation { isRefreshing = false } }
        do {
            let prefs = try await preferences.loadOrDefaults()
            if faults?.consume(.feedFirstPage) == true { throw InjectedFault() }
            if !slices.isEmpty, faults?.consume(.feedRefresh) == true { throw InjectedFault() }
            var fresh = FeedTuner(tuners: tuners(prefs))
            let (feed, nextCursor) = try await fetchPages(from: nil)
            guard generation == self.generation else { return }
            let tuned = fresh.tune(feed)
            tuner = fresh
            slices = tuned
            cursor = nextCursor
            hasMore = nextCursor != nil
            showsFallbackMarker = isFollowing && nextCursor == nil
            loadMoreError = nil
            rebuildRows()
            status = .loaded
        } catch where RequestFailure.isCancellation(error) {
            if generation == self.generation, status == .loading { status = .idle }
        } catch {
            guard generation == self.generation else { return }
            if slices.isEmpty && !showsFallbackMarker {
                status = .failed(ErrorText.clean(error))
            } else {
                lastFailureWasRefresh = true
                loadMoreError = ErrorText.clean(error)
                status = .loaded
            }
        }
    }

    /// Loads the next page when the list nears its end (`PostFeed.tsx:776`).
    func loadMore() {
        guard status == .loaded, hasMore, !isLoadingMore, loadMoreError == nil else { return }
        analytics.metric("feed:endReached", ["feedType": .string(feedType), "feedUrl": .string(feedDescriptor),
                                             "itemCount": .int(metricItemCount)])
        startLoadMore()
    }

    /// The load-more error row's retry (`LoadMoreRetryBtn` calls `fetchNextPage`).
    func retryAfterError() async {
        loadMoreError = nil
        if lastFailureWasRefresh || !hasMore {
            lastFailureWasRefresh = false
            await reload()
        } else {
            startLoadMore()
            await loadMoreTask?.value
        }
    }

    /// A row was laid out on screen (`List.onItemSeen` viewability, review finding N6).
    func rowAppeared(_ row: FeedRow) {
        tracker?.appeared(row.id, index: rowIndex[row.id] ?? 0)
    }

    func rowDisappeared(_ row: FeedRow) {
        tracker?.disappeared(row.id)
    }

    private func reportViewable(_ ids: [String]) {
        for id in ids {
            guard let index = rowIndex[id], rows.indices.contains(index) else { continue }
            recordView(of: rows[index])
        }
    }

    /// Records a `post:view` for a feed post row seen for 500 ms (`PostFeed.tsx:1092`).
    func recordView(of row: FeedRow) {
        guard case .post(let item, _) = row.kind, row.isFeedPost, viewedPosts.insert(item.post.uri).inserted else { return }
        var props: [String: EventValue] = [
            "uri": .string(item.post.uri), "authorDid": .string(item.post.author.did),
            "isReply": .bool(item.post.record.reply != nil), "logContext": "FeedItem",
            "feedDescriptor": .string(feedDescriptor),
        ]
        if let position = row.position { props["position"] = .int(position) }
        analytics.metric("post:view", props)
    }

    private func startLoadMore() {
        isLoadingMore = true
        let generation = self.generation
        let startCursor = cursor
        loadMoreTask = Task { [weak self] in
            guard let self else { return }
            defer { if generation == self.generation { self.isLoadingMore = false } }
            do {
                if self.faults?.consume(.feedNextPage) == true { throw InjectedFault() }
                let (feed, nextCursor) = try await self.fetchPages(from: startCursor)
                guard generation == self.generation, !Task.isCancelled else { return }
                self.slices += self.tuner.tune(feed)
                self.cursor = nextCursor
                self.hasMore = nextCursor != nil
                if self.isFollowing && nextCursor == nil { self.showsFallbackMarker = true }
                self.rebuildRows()
            } catch where RequestFailure.isCancellation(error) {
                return
            } catch {
                guard generation == self.generation else { return }
                // RN keeps hasNextPage and shows the retry row instead of the end of the feed.
                self.lastFailureWasRefresh = false
                self.loadMoreError = ErrorText.clean(error)
            }
        }
    }

    /// Fetches pages until 30 posts arrive, the cursor ends or repeats, or 5 attempts pass.
    private func fetchPages(from start: String?) async throws -> ([FeedViewPost], String?) {
        var items: [FeedViewPost] = []
        var cursor = start
        var attempts = 0
        repeat {
            let page = try await fetch(cursor: cursor)
            attempts += 1
            items += page.feed
            if page.cursor == nil || page.cursor == cursor {
                return (items, nil)
            }
            cursor = page.cursor
        } while items.count < Self.pageSize && attempts < Self.maxAttempts
        return (items, cursor)
    }

    private func fetch(cursor: String?) async throws -> FeedPage {
        switch source {
        case .following:
            return try await api.getTimeline(cursor: cursor, limit: Self.pageSize)
        case .author(let actor, let filter):
            return try await api.getAuthorFeed(actor: actor, filter: filter, cursor: cursor, limit: Self.pageSize)
        }
    }

    private func tuners(_ prefs: ActorPreferences) -> [FeedTuner.Tuner] {
        switch source {
        case .following: FeedTuner.following(userDid: userDid, preferences: prefs.homeFeed)
        case .author: []
        }
    }

    private func rebuildRows() {
        rows = FeedRow.rows(for: slices, firstRowHidesBorder: !isFollowing)
        rowIndex = Dictionary(uniqueKeysWithValues: rows.enumerated().map { ($1.id, $0) })
    }
}

extension FeedModel: RouteScopedModel {
    /// Stops paging and the pending `post:view` reports when the feed's route leaves the stack
    /// (review finding A83).
    func cancel() {
        loadMoreTask?.cancel()
        loadMoreTask = nil
        tracker?.cancel()
    }
}

/// One rendered row of a slice, with the flags RN computes in `PostFeed.tsx:622-683, 872-893`.
struct FeedRow: Identifiable, Hashable {
    enum Kind: Hashable {
        case post(FeedSlice.Item, reason: FeedViewPost.Reason?)
        case viewFullThread(rootUri: String)
    }

    var id: String
    var kind: Kind
    var isThreadParent: Bool
    var isThreadChild: Bool
    var isThreadLastChild: Bool
    var showReplyTo: Bool
    var hideTopBorder: Bool
    /// The repost record, when the slice is a repost (`viaRepost`).
    var viaRepost: StrongRef?
    /// True for the row of the post the feed returned (`slice.feedPostUri`).
    var isFeedPost: Bool
    /// `post:view` position: earlier rows whose `indexInSlice` is 0.
    var position: Int?

    /// Expands slices into rows. `firstRowHidesBorder` is true when no row sits above the
    /// feed (the profile); Following has the composer prompt as row 0.
    static func rows(for slices: [FeedSlice], firstRowHidesBorder: Bool) -> [FeedRow] {
        var rows: [FeedRow] = []
        var firstRowsBefore = 0
        for (sliceIndex, slice) in slices.enumerated() {
            let items = slice.items
            let count = items.count
            var plan: [(index: Int, showReplyTo: Bool)] = items.indices.map { ($0, $0 == 0) }
            let collapses = slice.isIncompleteThread && count >= 3
            if collapses {
                let beforeLast = items[count - 2]
                plan = [(0, false),
                        (count - 2, beforeLast.parentAuthor?.did != beforeLast.post.author.did),
                        (count - 1, false)]
            }
            for (position, entry) in plan.enumerated() {
                let i = entry.index
                let isFeedPost = items[i].post.uri == slice.feedPostUri
                rows.append(FeedRow(
                    id: "\(slice.id)-\(i)",
                    kind: .post(items[i], reason: i == 0 ? slice.reason : nil),
                    isThreadParent: count > 1 && i < count - 1,
                    isThreadChild: count > 1 && i > 0,
                    isThreadLastChild: count > 1 && i == count - 1,
                    showReplyTo: entry.showReplyTo,
                    hideTopBorder: firstRowHidesBorder && sliceIndex == 0 && position == 0,
                    viaRepost: slice.reason?.viaRepost,
                    isFeedPost: isFeedPost,
                    // `getPostPosition` counts earlier `indexInSlice == 0` rows before the
                    // slice's first row, so it equals the number of earlier slices.
                    position: isFeedPost ? firstRowsBefore : nil
                ))
                if collapses && position == 0 {
                    rows.append(FeedRow(id: "\(slice.id)-full", kind: .viewFullThread(rootUri: items[0].post.uri),
                                        isThreadParent: true, isThreadChild: true, isThreadLastChild: false,
                                        showReplyTo: false, hideTopBorder: true, viaRepost: nil,
                                        isFeedPost: false, position: nil))
                }
            }
            firstRowsBefore += 1
        }
        return rows
    }
}
