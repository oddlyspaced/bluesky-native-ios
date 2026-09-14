import Foundation
@testable import BlueskyNative

/// In-memory `BlueskyAPI` for view model tests.
actor FakeBlueskyAPI: BlueskyAPI {
    struct Failure: Error, Equatable {}

    nonisolated let accountDid: String

    var timelinePages: [String?: FeedPage] = [:]
    var authorPages: [String?: FeedPage] = [:]
    var thread: ThreadNode?
    var profile: ProfileViewDetailed?
    var notifications: [NotificationView] = []
    var failNextCall = false
    var likeCounter = 0

    private(set) var calls: [String] = []

    init(accountDid: String = "did:plc:alice") {
        self.accountDid = accountDid
    }

    func setTimeline(_ page: FeedPage, cursor: String? = nil) { timelinePages[cursor] = page }
    func setAuthorFeed(_ page: FeedPage, cursor: String? = nil) { authorPages[cursor] = page }
    func setThread(_ node: ThreadNode) { thread = node }
    func setFailNextCall(_ fail: Bool) { failNextCall = fail }

    private func record(_ call: String) throws {
        calls.append(call)
        if failNextCall {
            failNextCall = false
            throw Failure()
        }
    }

    func getTimeline(cursor: String?, limit: Int) async throws -> FeedPage {
        try record("getTimeline(\(cursor ?? "nil"))")
        return timelinePages[cursor] ?? FeedPage(feed: [], cursor: nil)
    }

    func getAuthorFeed(actor: String, filter: AuthorFeedFilter, cursor: String?, limit: Int) async throws -> FeedPage {
        try record("getAuthorFeed(\(actor),\(filter.rawValue))")
        return authorPages[cursor] ?? FeedPage(feed: [], cursor: nil)
    }

    func getPostThread(uri: String) async throws -> ThreadNode {
        try record("getPostThread(\(uri))")
        guard let thread else { throw XRPCError.http(status: 400, error: "NotFound", message: "Post not found") }
        return thread
    }

    func getProfile(actor: String) async throws -> ProfileViewDetailed {
        try record("getProfile(\(actor))")
        guard let profile else { throw Failure() }
        return profile
    }

    func listNotifications(limit: Int) async throws -> [NotificationView] {
        try record("listNotifications")
        return notifications
    }

    func like(_ subject: StrongRef) async throws -> String {
        try record("like(\(subject.uri))")
        likeCounter += 1
        return "at://\(accountDid)/app.bsky.feed.like/like\(likeCounter)"
    }

    func deleteLike(uri: String) async throws {
        try record("deleteLike(\(uri))")
    }

    func repost(_ subject: StrongRef) async throws -> String {
        try record("repost(\(subject.uri))")
        return "at://\(accountDid)/app.bsky.feed.repost/repost1"
    }

    func deleteRepost(uri: String) async throws {
        try record("deleteRepost(\(uri))")
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
    static func author(_ handle: String) -> ProfileViewBasic {
        ProfileViewBasic(did: "did:plc:\(handle)", handle: "\(handle).test", displayName: handle.capitalized)
    }

    static func post(_ id: String, by handle: String = "bob", text: String = "Post", likes: Int = 0,
                     like: String? = nil, reposts: Int = 0, repost: String? = nil,
                     reply: PostRecord.ReplyRef? = nil) -> PostView {
        PostView(uri: "at://did:plc:\(handle)/app.bsky.feed.post/\(id)", cid: "cid-\(id)", author: author(handle),
                 record: PostRecord(text: text, createdAt: "2026-09-14T19:30:21.210Z", reply: reply),
                 replyCount: 0, repostCount: reposts, likeCount: likes, quoteCount: 0,
                 indexedAt: "2026-09-14T19:30:21.210Z",
                 viewer: PostViewerState(like: like, repost: repost))
    }
}
