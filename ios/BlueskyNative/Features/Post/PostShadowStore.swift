import Foundation
import Observation
import os

/// Port of RN's post shadow cache (`src/state/cache/post-shadow.ts`).
///
/// RN keys shadows by `PostView` object identity (a `WeakMap`), so fresh query data (new
/// objects) never shows an old shadow. This port keys each shadow by URI and records the
/// server state it was made against (`base`). A post copy uses the shadow only while its own
/// server state equals `base`, or while a request for that URI is still running. Fresh
/// server state therefore always wins (review findings A8 and P21).
@MainActor
@Observable
final class PostShadowStore {
    /// An override of one viewer field. `.unset` means "use the server value".
    enum Override: Equatable, Sendable {
        case unset
        case value(String?)
    }

    /// The server fields a shadow overrides.
    struct ServerState: Equatable, Sendable {
        var like: String?
        var repost: String?
        var likeCount: Int?
        var repostCount: Int?

        init(_ post: PostView) {
            like = post.viewer?.like
            repost = post.viewer?.repost
            likeCount = post.likeCount
            repostCount = post.repostCount
        }
    }

    struct Shadow: Equatable, Sendable {
        var likeUri: Override = .unset
        var repostUri: Override = .unset
        var base: ServerState
    }

    /// RN writes this placeholder while the create request is in flight.
    static let pendingURI = "pending"
    /// Shadows kept at most; the oldest settled shadows are dropped first.
    static let capacity = 500

    private(set) var shadows: [String: Shadow] = [:]
    @ObservationIgnored private var pending: [String: Int] = [:]
    @ObservationIgnored private var order: [String] = []

    func shadow(for uri: String) -> Shadow? {
        shadows[uri]
    }

    func setLike(_ value: String?, for post: PostView) {
        update(post) { $0.likeUri = .value(value) }
    }

    func setRepost(_ value: String?, for post: PostView) {
        update(post) { $0.repostUri = .value(value) }
    }

    func beginRequest(_ uri: String) {
        pending[uri, default: 0] += 1
    }

    func endRequest(_ uri: String) {
        let count = (pending[uri] ?? 1) - 1
        pending[uri] = count > 0 ? count : nil
    }

    func hasPendingRequest(_ uri: String) -> Bool {
        pending[uri] != nil
    }

    /// Merges the shadow into a server post, adjusting counts by +-1 against that post's own
    /// viewer state, as `mergeShadow` does in RN (counts never go below 0).
    func apply(to post: PostView) -> PostView {
        guard let shadow = shadows[post.uri] else { return post }
        guard shadow.base == ServerState(post) || pending[post.uri] != nil else { return post }
        var merged = post
        var viewer = post.viewer ?? PostViewerState()
        if case .value(let likeUri) = shadow.likeUri {
            merged.likeCount = Self.adjust(post.likeCount, was: post.viewer?.like != nil, now: likeUri != nil)
            viewer.like = likeUri
        }
        if case .value(let repostUri) = shadow.repostUri {
            merged.repostCount = Self.adjust(post.repostCount, was: post.viewer?.repost != nil, now: repostUri != nil)
            viewer.repost = repostUri
        }
        merged.viewer = viewer
        return merged
    }

    private func update(_ post: PostView, _ change: (inout Shadow) -> Void) {
        var shadow = shadows[post.uri] ?? Shadow(base: ServerState(post))
        if shadows[post.uri] == nil { order.append(post.uri) }
        change(&shadow)
        shadows[post.uri] = shadow
        trim()
    }

    private func trim() {
        var index = 0
        while shadows.count > Self.capacity, index < order.count {
            let uri = order[index]
            if pending[uri] == nil {
                shadows[uri] = nil
                order.remove(at: index)
            } else {
                index += 1
            }
        }
    }

    private static func adjust(_ count: Int?, was: Bool, now: Bool) -> Int {
        let base = count ?? 0
        if was && !now { return max(0, base - 1) }
        if !was && now { return base + 1 }
        return base
    }
}

/// Where a post control was used, for analytics (`logContext`, `feedDescriptor`).
struct PostEventContext: Sendable, Hashable {
    /// RN `logContext`: `FeedItem` or `PostThreadItem`.
    var logContext: String
    /// RN `feedDescriptor`, for example `following`; nil where RN has no feed context.
    var feedDescriptor: String?

    static func feedItem(_ feedDescriptor: String?) -> PostEventContext {
        PostEventContext(logContext: "FeedItem", feedDescriptor: feedDescriptor)
    }

    static func threadItem(_ feedDescriptor: String?) -> PostEventContext {
        PostEventContext(logContext: "PostThreadItem", feedDescriptor: feedDescriptor)
    }

    /// `{uri, authorDid, logContext, feedDescriptor}`, the props most post events share.
    func props(for post: PostView) -> [String: EventValue] {
        var props: [String: EventValue] = [
            "uri": .string(post.uri), "authorDid": .string(post.author.did), "logContext": .string(logContext),
        ]
        if let feedDescriptor { props["feedDescriptor"] = .string(feedDescriptor) }
        return props
    }
}

/// Port of `useToggleMutationQueue` (`src/lib/hooks/useToggleMutationQueue.ts`).
///
/// - A new toggle replaces a queued one; a toggle equal to the one just run is skipped.
/// - Each mutation receives the state the previous mutation confirmed.
/// - When the queue drains, `onSettled` receives the last confirmed server state. A failed
///   mutation leaves the confirmed state unchanged, so the UI returns to the server truth.
@MainActor
final class ToggleMutationQueue {
    typealias Mutation = @MainActor (_ confirmed: String?, _ isOn: Bool) async throws -> String?

    private let run: Mutation
    private let onSettled: @MainActor (String?) -> Void
    private var active: Bool?
    private var queued: Bool?
    private var processing: Task<Void, Never>?
    private let log = Logger(subsystem: "io.nativestarter.showcase.bluesky", category: "post-mutation")

    var isIdle: Bool { processing == nil }

    init(run: @escaping Mutation, onSettled: @escaping @MainActor (String?) -> Void) {
        self.run = run
        self.onSettled = onSettled
    }

    /// Queues a toggle. `initial` is the confirmed state when the queue is idle.
    ///
    /// When the queue is idle the toggle becomes the active task at once, as RN's
    /// `processQueue` starts the first mutation synchronously; a toggle that arrives while it
    /// runs is queued behind it.
    func toggle(_ isOn: Bool, initial: String?) -> Task<Void, Never> {
        if let processing {
            queued = isOn
            return processing
        }
        active = isOn
        let task = Task { await self.process(initial: initial, first: isOn) }
        processing = task
        return task
    }

    private func process(initial: String?, first: Bool) async {
        var confirmed = initial
        do {
            confirmed = try await run(confirmed, first)
        } catch {
            log.error("Post mutation failed: \(String(describing: error), privacy: .public)")
        }
        while let next = queued {
            let previous = active
            active = next
            queued = nil
            if previous == next { continue }
            do {
                confirmed = try await run(confirmed, next)
            } catch {
                log.error("Post mutation failed: \(String(describing: error), privacy: .public)")
            }
        }
        active = nil
        queued = nil
        processing = nil
        onSettled(confirmed)
    }
}

/// Like and repost actions with optimistic updates.
///
/// Port of `usePostLikeMutationQueue` and `usePostRepostMutationQueue`
/// (`src/state/queries/post.ts`): the shadow changes first, a per-post toggle queue sends
/// the requests, and the settled server state is written back to the shadow.
@MainActor
final class PostInteractions {
    private let api: any BlueskyAPI
    let shadows: PostShadowStore
    private let analytics: any AnalyticsSink
    /// Followers of the signed-in account, from the profile cache (`likerClout`).
    private let ownFollowersCount: @MainActor () -> Int?
    private var likeQueues: [String: ToggleMutationQueue] = [:]
    private var repostQueues: [String: ToggleMutationQueue] = [:]

    init(api: any BlueskyAPI, shadows: PostShadowStore, analytics: any AnalyticsSink = NoopAnalytics(),
         ownFollowersCount: @escaping @MainActor () -> Int? = { nil }) {
        self.api = api
        self.shadows = shadows
        self.analytics = analytics
        self.ownFollowersCount = ownFollowersCount
    }

    /// Likes or unlikes the post, based on its current (shadowed) state.
    @discardableResult
    func toggleLike(_ serverPost: PostView, via: StrongRef? = nil,
                    context: PostEventContext = .feedItem(nil)) -> Task<Void, Never> {
        let post = shadows.apply(to: serverPost)
        let initial = post.viewer?.like
        let shouldLike = initial == nil
        shadows.setLike(shouldLike ? PostShadowStore.pendingURI : nil, for: serverPost)
        let uri = serverPost.uri
        let queue = likeQueues[uri] ?? makeQueue(uri: uri, isLike: true, post: post, via: via, context: context)
        likeQueues[uri] = queue
        if queue.isIdle { shadows.beginRequest(uri) }
        return queue.toggle(shouldLike, initial: initial)
    }

    /// Reposts or removes the repost, based on the current (shadowed) state.
    @discardableResult
    func toggleRepost(_ serverPost: PostView, via: StrongRef? = nil,
                      context: PostEventContext = .feedItem(nil)) -> Task<Void, Never> {
        let post = shadows.apply(to: serverPost)
        let initial = post.viewer?.repost
        let shouldRepost = initial == nil
        shadows.setRepost(shouldRepost ? PostShadowStore.pendingURI : nil, for: serverPost)
        let uri = serverPost.uri
        let queue = repostQueues[uri] ?? makeQueue(uri: uri, isLike: false, post: post, via: via, context: context)
        repostQueues[uri] = queue
        if queue.isIdle { shadows.beginRequest(uri) }
        return queue.toggle(shouldRepost, initial: initial)
    }

    private func makeQueue(uri: String, isLike: Bool, post: PostView, via: StrongRef?,
                           context: PostEventContext) -> ToggleMutationQueue {
        let api = self.api
        let analytics = self.analytics
        let subject = post.strongRef
        let run: ToggleMutationQueue.Mutation
        if isLike {
            let followers = ownFollowersCount
            run = { confirmed, isOn in
                if isOn {
                    analytics.metric("post:like", Self.likeProps(post: post, context: context,
                                                                 ownFollowers: followers()))
                    return try await api.like(subject, via: via)
                }
                if let confirmed {
                    analytics.metric("post:unlike", context.props(for: post))
                    try await api.deleteLike(uri: confirmed)
                }
                return nil
            }
        } else {
            run = { confirmed, isOn in
                if isOn {
                    analytics.metric("post:repost", context.props(for: post))
                    return try await api.repost(subject, via: via)
                }
                if let confirmed {
                    analytics.metric("post:unrepost", context.props(for: post))
                    try await api.deleteRepost(uri: confirmed)
                }
                return nil
            }
        }
        // The shadow store is captured strongly: the settled server state must land even if
        // the screen that started the toggle is gone, as RN's `onSuccess` does.
        let shadows = self.shadows
        return ToggleMutationQueue(run: run) { [weak self] final in
            // The shadow already holds the server base from the first optimistic update.
            if isLike {
                shadows.setLike(final, for: post)
                self?.likeQueues[uri] = nil
            } else {
                shadows.setRepost(final, for: post)
                self?.repostQueues[uri] = nil
            }
            shadows.endRequest(uri)
        }
    }

    /// `post:like` props (`src/state/queries/post.ts:201-221`).
    static func likeProps(post: PostView, context: PostEventContext, ownFollowers: Int?) -> [String: EventValue] {
        var props = context.props(for: post)
        if let viewer = post.author.viewer {
            props["doesPosterFollowLiker"] = .bool(viewer.followedBy != nil)
            props["doesLikerFollowPoster"] = .bool(viewer.following != nil)
        }
        if let clout = toClout(ownFollowers) { props["likerClout"] = .int(clout) }
        if let likes = post.likeCount, let reposts = post.repostCount, let replies = post.replyCount,
           let clout = toClout(likes + reposts + replies) {
            props["postClout"] = .int(clout)
        }
        return props
    }

    /// `toClout` (`src/analytics/metrics/utils.ts`): `max(0, round(ln(n)))`, undefined for nil.
    static func toClout(_ value: Int?) -> Int? {
        guard let value else { return nil }
        guard value > 0 else { return 0 }
        return max(0, Int(log(Double(value)).rounded()))
    }
}
