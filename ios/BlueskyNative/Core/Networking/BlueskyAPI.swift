import Foundation

/// Everything the ported screens need from the network.
///
/// View models depend on this protocol only; tests use `FakeBlueskyAPI`.
protocol BlueskyAPI: Sendable {
    /// DID of the signed-in account.
    var accountDid: String { get }

    func getTimeline(cursor: String?, limit: Int) async throws -> FeedPage
    func getAuthorFeed(actor: String, filter: AuthorFeedFilter, cursor: String?, limit: Int) async throws -> FeedPage
    func getPostThread(uri: String) async throws -> ThreadNode
    func getProfile(actor: String) async throws -> ProfileViewDetailed
    func listNotifications(limit: Int) async throws -> [NotificationView]

    /// Creates an `app.bsky.feed.like` record. Returns the like record URI.
    func like(_ subject: StrongRef) async throws -> String
    func deleteLike(uri: String) async throws
    /// Creates an `app.bsky.feed.repost` record. Returns the repost record URI.
    func repost(_ subject: StrongRef) async throws -> String
    func deleteRepost(uri: String) async throws
}

/// `filter` values of `app.bsky.feed.getAuthorFeed`.
enum AuthorFeedFilter: String, Sendable {
    case postsWithReplies = "posts_with_replies"
    case postsNoReplies = "posts_no_replies"
    case postsWithMedia = "posts_with_media"
    case postsAndAuthorThreads = "posts_and_author_threads"
    case postsWithVideo = "posts_with_video"
}

/// `app.bsky.notification.listNotifications#notification`, reduced.
struct NotificationView: Codable, Sendable, Hashable {
    var uri: String
    var reason: String
    var reasonSubject: String?
    var isRead: Bool
    var indexedAt: String
    var author: ProfileViewBasic
}

struct ListNotificationsResponse: Codable, Sendable {
    var notifications: [NotificationView]
    var cursor: String?
}

/// Stored credentials for one account.
struct StoredSession: Codable, Sendable, Hashable {
    var service: URL
    var did: String
    var handle: String
    var accessJwt: String
    var refreshJwt: String
}

/// The live `BlueskyAPI`: an XRPC client plus the account's tokens.
///
/// It refreshes the access token once when the server answers `ExpiredToken`,
/// like the RN agent does, and reports new tokens through `onSessionUpdate`.
actor AuthenticatedBlueskyAPI: BlueskyAPI {
    nonisolated let accountDid: String
    private let client: XRPCClient
    private var session: StoredSession
    private let onSessionUpdate: @Sendable (StoredSession) -> Void

    init(session: StoredSession, client: XRPCClient,
         onSessionUpdate: @escaping @Sendable (StoredSession) -> Void = { _ in }) {
        self.accountDid = session.did
        self.session = session
        self.client = client
        self.onSessionUpdate = onSessionUpdate
    }

    func getTimeline(cursor: String?, limit: Int) async throws -> FeedPage {
        try await authorized { token in
            try await self.client.query("app.bsky.feed.getTimeline",
                                        Self.items(["limit": String(limit), "cursor": cursor]),
                                        accessToken: token)
        }
    }

    func getAuthorFeed(actor: String, filter: AuthorFeedFilter, cursor: String?, limit: Int) async throws -> FeedPage {
        try await authorized { token in
            try await self.client.query(
                "app.bsky.feed.getAuthorFeed",
                Self.items([
                    "actor": actor, "filter": filter.rawValue, "limit": String(limit), "cursor": cursor,
                    // RN turns pins on for the posts_and_author_threads filter (src/lib/api/feed/author.ts).
                    "includePins": filter == .postsAndAuthorThreads ? "true" : nil,
                ]),
                accessToken: token)
        }
    }

    func getPostThread(uri: String) async throws -> ThreadNode {
        let response: PostThreadResponse = try await authorized { token in
            try await self.client.query("app.bsky.feed.getPostThread",
                                        Self.items(["uri": uri, "depth": "10", "parentHeight": "10"]),
                                        accessToken: token)
        }
        return response.thread
    }

    func getProfile(actor: String) async throws -> ProfileViewDetailed {
        try await authorized { token in
            try await self.client.query("app.bsky.actor.getProfile", Self.items(["actor": actor]),
                                        accessToken: token)
        }
    }

    func listNotifications(limit: Int) async throws -> [NotificationView] {
        let response: ListNotificationsResponse = try await authorized { token in
            try await self.client.query("app.bsky.notification.listNotifications",
                                        Self.items(["limit": String(limit)]), accessToken: token)
        }
        return response.notifications
    }

    func like(_ subject: StrongRef) async throws -> String {
        try await createRecord(collection: "app.bsky.feed.like", subject: subject)
    }

    func deleteLike(uri: String) async throws {
        try await deleteRecord(uri: uri)
    }

    func repost(_ subject: StrongRef) async throws -> String {
        try await createRecord(collection: "app.bsky.feed.repost", subject: subject)
    }

    func deleteRepost(uri: String) async throws {
        try await deleteRecord(uri: uri)
    }

    // MARK: - Records

    private struct SubjectRecord: Encodable {
        var type: String
        var subject: StrongRef
        var createdAt: String

        enum CodingKeys: String, CodingKey {
            case type = "$type"
            case subject, createdAt
        }
    }

    private struct CreateRecordBody: Encodable {
        var repo: String
        var collection: String
        var record: SubjectRecord
    }

    private struct DeleteRecordBody: Encodable {
        var repo: String
        var collection: String
        var rkey: String
    }

    private func createRecord(collection: String, subject: StrongRef) async throws -> String {
        let body = CreateRecordBody(
            repo: accountDid,
            collection: collection,
            record: SubjectRecord(type: collection, subject: subject, createdAt: Self.now())
        )
        let response: CreateRecordResponse = try await authorized { token in
            try await self.client.procedure("com.atproto.repo.createRecord", body: body, accessToken: token)
        }
        return response.uri
    }

    private func deleteRecord(uri: String) async throws {
        guard let at = ATURI(uri) else {
            throw XRPCError.invalidResponse("Invalid record URI: \(uri)")
        }
        let body = DeleteRecordBody(repo: accountDid, collection: at.collection, rkey: at.rkey)
        try await authorized { token in
            try await self.client.procedure("com.atproto.repo.deleteRecord", body: body, accessToken: token)
        }
    }

    // MARK: - Auth

    private func authorized<T: Sendable>(_ call: @Sendable (String) async throws -> T) async throws -> T {
        do {
            return try await call(session.accessJwt)
        } catch let error as XRPCError where error.isExpiredToken {
            try await refresh()
            return try await call(session.accessJwt)
        }
    }

    private func refresh() async throws {
        // refreshSession authenticates with the refresh token, not the access token.
        let response: SessionResponse = try await client.procedure(
            "com.atproto.server.refreshSession", body: EmptyBody(), accessToken: session.refreshJwt)
        session.accessJwt = response.accessJwt
        session.refreshJwt = response.refreshJwt
        onSessionUpdate(session)
    }

    private static func items(_ values: KeyValuePairs<String, String?>) -> [URLQueryItem] {
        values.compactMap { key, value in value.map { URLQueryItem(name: key, value: $0) } }
    }

    private static func now() -> String {
        Date().formatted(.iso8601.year().month().day().time(includingFractionalSeconds: true)
            .dateSeparator(.dash).timeSeparator(.colon).timeZone(separator: .omitted))
    }
}

struct EmptyBody: Codable, Sendable {}
