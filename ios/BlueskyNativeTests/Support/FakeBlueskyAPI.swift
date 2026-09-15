import Foundation
@testable import NativeShowcase

/// In-memory `BlueskyAPI` for view model tests.
actor FakeBlueskyAPI: SessionBoundAPI {
    struct Failure: Error, Equatable {}

    nonisolated let accountDid: String

    var timelinePages: [String?: FeedPage] = [:]
    var authorPages: [String?: FeedPage] = [:]
    var threadResponse: PostThreadV2Response?
    var otherRepliesResponse = PostThreadOtherV2Response(thread: [])
    var threadError: XRPCError?
    var profile: ProfileViewDetailed?
    var preferences = ActorPreferences()
    var notifications: [NotificationView] = []
    var failNextCall = false
    /// Fails every call whose name starts with this prefix, with `failure`.
    var failingPrefix: String?
    /// The error a failing call throws. Tests set realistic transport or XRPC errors, so error
    /// paths go through the real error mapping (review finding A53).
    var failure: any Error = Failure()
    /// When set, `getPostThreadV2` waits at this gate before it answers.
    nonisolated let threadGate: Gate?
    var likeCounter = 0
    var invalidated = false
    /// When set, `getTimeline` waits for `resumeTimeline()` before answering.
    private var timelineGate: CheckedContinuation<Void, Never>?
    private var gateTimeline = false

    private(set) var calls: [String] = []
    private(set) var lastThreadRequest: PostThreadRequest?
    private(set) var vias: [StrongRef?] = []

    init(accountDid: String = "did:plc:alice", threadGate: Gate? = nil) {
        self.accountDid = accountDid
        self.threadGate = threadGate
    }

    func setTimeline(_ page: FeedPage, cursor: String? = nil) { timelinePages[cursor] = page }
    func setAuthorFeed(_ page: FeedPage, cursor: String? = nil) { authorPages[cursor] = page }
    func setThread(_ response: PostThreadV2Response) { threadResponse = response }
    func setThreadError(_ error: XRPCError?) { threadError = error }
    func setFailNextCall(_ fail: Bool) { failNextCall = fail }
    func setFailingPrefix(_ prefix: String?, error: any Error = Failure()) {
        failingPrefix = prefix
        failure = error
    }
    func setPreferences(_ value: ActorPreferences) { preferences = value }
    func setProfile(_ value: ProfileViewDetailed) { profile = value }
    func setNotifications(_ value: [NotificationView]) { notifications = value }
    func setOtherReplies(_ value: PostThreadOtherV2Response) { otherRepliesResponse = value }

    func holdTimeline() { gateTimeline = true }

    func resumeTimeline() {
        gateTimeline = false
        timelineGate?.resume()
        timelineGate = nil
    }

    private func record(_ call: String) throws {
        calls.append(call)
        if let failingPrefix, call.hasPrefix(failingPrefix) { throw failure }
        if failNextCall {
            failNextCall = false
            throw failure
        }
    }

    func invalidate() { invalidated = true }

    func deleteSession() async throws {
        try record("deleteSession")
    }

    func getTimeline(cursor: String?, limit: Int) async throws -> FeedPage {
        try record("getTimeline(\(cursor ?? "nil"))")
        if gateTimeline {
            await withCheckedContinuation { timelineGate = $0 }
        }
        return timelinePages[cursor] ?? FeedPage(feed: [], cursor: nil)
    }

    func getAuthorFeed(actor: String, filter: AuthorFeedFilter, cursor: String?, limit: Int) async throws -> FeedPage {
        try record("getAuthorFeed(\(actor),\(filter.rawValue))")
        return authorPages[cursor] ?? FeedPage(feed: [], cursor: nil)
    }

    func getPostThreadV2(_ request: PostThreadRequest) async throws -> PostThreadV2Response {
        try record("getPostThreadV2(\(request.anchor))")
        lastThreadRequest = request
        if let threadGate { await threadGate.pass() }
        if let threadError { throw threadError }
        guard let threadResponse else {
            return PostThreadV2Response(thread: [ThreadItem(uri: request.anchor, depth: 0, value: .notFound)])
        }
        return threadResponse
    }

    func getPostThreadOtherV2(anchor: String) async throws -> PostThreadOtherV2Response {
        try record("getPostThreadOtherV2(\(anchor))")
        return otherRepliesResponse
    }

    func getProfile(actor: String) async throws -> ProfileViewDetailed {
        try record("getProfile(\(actor))")
        guard let profile else { throw Failure() }
        return profile
    }

    func getPreferences() async throws -> ActorPreferences {
        try record("getPreferences")
        return preferences
    }

    func listNotifications(limit: Int) async throws -> [NotificationView] {
        try record("listNotifications")
        return notifications
    }

    func like(_ subject: StrongRef, via: StrongRef?) async throws -> String {
        try record("like(\(subject.uri))")
        vias.append(via)
        likeCounter += 1
        return "at://\(accountDid)/app.bsky.feed.like/like\(likeCounter)"
    }

    func deleteLike(uri: String) async throws {
        try record("deleteLike(\(uri))")
    }

    func repost(_ subject: StrongRef, via: StrongRef?) async throws -> String {
        try record("repost(\(subject.uri))")
        vias.append(via)
        return "at://\(accountDid)/app.bsky.feed.repost/repost1"
    }

    func deleteRepost(uri: String) async throws {
        try record("deleteRepost(\(uri))")
    }
}

/// Records analytics events in memory.
final class RecordingAnalytics: AnalyticsSink, @unchecked Sendable {
    private let lock = NSLock()
    private var stored: [AnalyticsEvent] = []

    var events: [AnalyticsEvent] { lock.withLock { stored } }
    var names: [String] { events.map(\.name) }

    func record(_ event: AnalyticsEvent) {
        lock.withLock { stored.append(event) }
    }

    func events(named name: String) -> [AnalyticsEvent] {
        events.filter { $0.name == name }
    }
}

/// Loads JSON captured from the local dev PDS (see ios/README.md).
enum Fixtures {
    private final class Token {}

    static func data(_ name: String) throws -> Data {
        let bundle = Bundle(for: Token.self)
        guard let url = bundle.url(forResource: name, withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try Data(contentsOf: url)
    }

    static func decode<T: Decodable>(_ type: T.Type, _ name: String) throws -> T {
        try JSONDecoder().decode(T.self, from: data(name))
    }
}

/// Builds small posts for tests.
enum Make {
    static func author(_ handle: String, following: Bool = true) -> ProfileViewBasic {
        ProfileViewBasic(did: "did:plc:\(handle)", handle: "\(handle).test", displayName: handle.capitalized,
                         viewer: ActorViewerState(following: following ? "at://follow/\(handle)" : nil))
    }

    static func post(_ id: String, by handle: String = "bob", text: String = "Post", likes: Int = 0,
                     like: String? = nil, reposts: Int = 0, repost: String? = nil, replies: Int = 0,
                     reply: PostRecord.ReplyRef? = nil, following: Bool = true) -> PostView {
        PostView(uri: uri(id, by: handle), cid: "cid-\(id)", author: author(handle, following: following),
                 record: PostRecord(text: text, createdAt: "2026-09-14T19:30:21.210Z", reply: reply),
                 replyCount: replies, repostCount: reposts, likeCount: likes, quoteCount: 0, bookmarkCount: 0,
                 indexedAt: "2026-09-14T19:30:21.210Z",
                 viewer: PostViewerState(like: like, repost: repost))
    }

    static func uri(_ id: String, by handle: String = "bob") -> String {
        "at://did:plc:\(handle)/app.bsky.feed.post/\(id)"
    }

    static func replyRef(root: PostView, parent: PostView) -> PostRecord.ReplyRef {
        PostRecord.ReplyRef(root: root.strongRef, parent: parent.strongRef)
    }

    static func threadPost(_ post: PostView, depth: Int, moreReplies: Int = 0, moreParents: Bool = false,
                           hidden: Bool = false) -> ThreadItem {
        ThreadItem(uri: post.uri, depth: depth,
                   value: .post(ThreadItemValue.Post(post: post, moreParents: moreParents, moreReplies: moreReplies,
                                                     hiddenByThreadgate: hidden)))
    }
}
