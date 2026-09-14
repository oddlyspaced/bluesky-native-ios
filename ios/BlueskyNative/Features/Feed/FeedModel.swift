import Foundation
import Observation

/// Loads and pages a feed. Port of the RN `usePostFeedQuery` flow for the two feeds
/// in this slice: the Following timeline (`HomeFeedAPI`) and an author feed.
@MainActor
@Observable
final class FeedModel {
    enum Source {
        case following(any BlueskyAPI)
        case author(any BlueskyAPI, actor: String, filter: AuthorFeedFilter)
    }

    enum Status: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    /// RN requests 30 items per page (`PAGE_SIZE` in post-feed.ts).
    static let pageSize = 30

    private(set) var slices: [FeedSlice] = []
    private(set) var status: Status = .idle
    private(set) var isRefreshing = false
    private(set) var isLoadingMore = false
    /// True once the Following timeline is exhausted (RN `FALLBACK_MARKER_POST`).
    private(set) var showsFallbackMarker = false
    private(set) var hasMore = false

    private let source: Source
    private var cursor: String?
    private var tuner = FeedTuner()

    init(source: Source) {
        self.source = source
    }

    var isEmpty: Bool { slices.isEmpty }

    func loadIfNeeded() async {
        guard status == .idle else { return }
        status = .loading
        await refresh()
    }

    /// Reloads from the first page. Existing rows stay visible until the new page arrives.
    func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            let page = try await fetch(cursor: nil)
            tuner.reset()
            showsFallbackMarker = false
            apply(page, replacing: true)
            status = .loaded
        } catch is CancellationError {
            if status == .loading { status = .idle }
        } catch {
            status = slices.isEmpty ? .failed(Self.message(for: error)) : .loaded
        }
    }

    /// Loads the next page when the list reaches its end.
    func loadMore() async {
        guard status == .loaded, hasMore, !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let page = try await fetch(cursor: cursor)
            apply(page, replacing: false)
        } catch {
            // RN shows a "load more" error row; this slice keeps the rows and stops paging.
            hasMore = false
        }
    }

    private func apply(_ page: FeedPage, replacing: Bool) {
        let tuned = tuner.tune(page.feed, dedupThreads: isFollowing)
        slices = replacing ? tuned : slices + tuned
        cursor = page.cursor
        hasMore = page.cursor != nil
        if isFollowing && page.cursor == nil {
            // HomeFeedAPI appends the fallback marker, then reads Discover. RN skips the
            // Discover request in __DEV__ builds; this showcase does not port Discover.
            showsFallbackMarker = true
        }
    }

    private var isFollowing: Bool {
        if case .following = source { return true }
        return false
    }

    private func fetch(cursor: String?) async throws -> FeedPage {
        switch source {
        case .following(let api):
            return try await api.getTimeline(cursor: cursor, limit: Self.pageSize)
        case .author(let api, let actor, let filter):
            return try await api.getAuthorFeed(actor: actor, filter: filter, cursor: cursor, limit: Self.pageSize)
        }
    }

    static func message(for error: any Error) -> String {
        if case XRPCError.http(_, _, let message?) = error { return message }
        return "There was an issue fetching posts. Tap here to try again."
    }
}

/// One rendered row of a slice, with the thread-line flags RN computes in `PostFeed.tsx`.
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

    /// Expands slices into rows. `firstRowHidesBorder` is true when no row sits above the
    /// feed (the profile); home has the composer prompt as row 0.
    static func rows(for slices: [FeedSlice], firstRowHidesBorder: Bool) -> [FeedRow] {
        var rows: [FeedRow] = []
        for (sliceIndex, slice) in slices.enumerated() {
            let items = slice.items
            var indices = Array(items.indices)
            var insertFullThreadAfterRoot = false
            if slice.isIncompleteThread && items.count >= 3 {
                indices = [0, items.count - 2, items.count - 1]
                insertFullThreadAfterRoot = true
            }
            for (position, i) in indices.enumerated() {
                let count = items.count
                rows.append(FeedRow(
                    id: "\(slice.id)-\(i)",
                    kind: .post(items[i], reason: i == 0 ? slice.reason : nil),
                    isThreadParent: count > 1 && i < count - 1,
                    isThreadChild: count > 1 && i > 0,
                    isThreadLastChild: count > 1 && i == count - 1,
                    showReplyTo: i == 0,
                    hideTopBorder: firstRowHidesBorder && sliceIndex == 0 && position == 0
                ))
                if insertFullThreadAfterRoot && position == 0 {
                    rows.append(FeedRow(id: "\(slice.id)-full", kind: .viewFullThread(rootUri: items[0].post.uri),
                                        isThreadParent: true, isThreadChild: true, isThreadLastChild: false,
                                        showReplyTo: false, hideTopBorder: true))
                }
            }
        }
        return rows
    }
}
