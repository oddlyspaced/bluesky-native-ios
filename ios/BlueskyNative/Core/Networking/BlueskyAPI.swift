import Foundation

/// Everything the ported screens need from the network.
///
/// View models depend on this protocol only; tests use `FakeBlueskyAPI`.
protocol BlueskyAPI: Sendable {
    /// DID of the signed-in account.
    var accountDid: String { get }

    func getTimeline(cursor: String?, limit: Int) async throws -> FeedPage
    func getAuthorFeed(actor: String, filter: AuthorFeedFilter, cursor: String?, limit: Int) async throws -> FeedPage
    /// `app.bsky.unspecced.getPostThreadV2`.
    func getPostThreadV2(_ request: PostThreadRequest) async throws -> PostThreadV2Response
    /// `app.bsky.unspecced.getPostThreadOtherV2`.
    func getPostThreadOtherV2(anchor: String) async throws -> PostThreadOtherV2Response
    func getProfile(actor: String) async throws -> ProfileViewDetailed
    func getPreferences() async throws -> ActorPreferences
    func listNotifications(limit: Int) async throws -> [NotificationView]

    /// Creates an `app.bsky.feed.like` record. Returns the like record URI.
    func like(_ subject: StrongRef, via: StrongRef?) async throws -> String
    func deleteLike(uri: String) async throws
    /// Creates an `app.bsky.feed.repost` record. Returns the repost record URI.
    func repost(_ subject: StrongRef, via: StrongRef?) async throws -> String
    func deleteRepost(uri: String) async throws
}

/// A live API bound to one signed-in session.
protocol SessionBoundAPI: BlueskyAPI {
    /// Stops all token refreshes and callbacks. Called on sign-out and account switch.
    func invalidate() async
    /// Revokes the session on the server (`com.atproto.server.deleteSession`).
    func deleteSession() async throws
}

/// Parameters of `getPostThreadV2`, as RN sends them (`usePostThread/index.ts:73-83`).
struct PostThreadRequest: Sendable, Hashable {
    var anchor: String
    /// Linear view: `LINEAR_VIEW_BELOW` = 10.
    var below: Int = 10
    /// Linear view: `LINEAR_VIEW_BF` = 1.
    var branchingFactor: Int = 1
    var sort: ThreadSort = .top
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
/// Token refresh follows RN's `PasswordSession` (`@atproto/lex-password-session`):
/// - A 401, or a 400 `ExpiredToken`, triggers one refresh and one retry.
/// - Refresh is single-flight: concurrent failures share one `refreshSession` call, and a
///   call whose token was already replaced retries with the new token without refreshing
///   again (review finding A3).
/// - `ExpiredToken`, `InvalidToken` or `AccountTakedown` from `refreshSession` ends the
///   session through `onAuthFailure`; other refresh failures keep it (review finding A4).
/// - After `invalidate()`, no refresh starts and no callback runs (review finding A1).
actor AuthenticatedBlueskyAPI: SessionBoundAPI {
    nonisolated let accountDid: String
    private let client: XRPCClient
    private var session: StoredSession
    private let callbacks: SessionCallbacks
    private var refreshTask: Task<StoredSession, any Error>?
    private var invalidated = false

    init(session: StoredSession, client: XRPCClient, callbacks: SessionCallbacks = .none) {
        self.accountDid = session.did
        self.session = session
        self.client = client
        self.callbacks = callbacks
    }

    func invalidate() {
        invalidated = true
        refreshTask?.cancel()
        refreshTask = nil
    }

    func deleteSession() async throws {
        // deleteSession authenticates with the refresh token.
        try await client.procedure("com.atproto.server.deleteSession", body: EmptyBody?.none,
                                   accessToken: session.refreshJwt)
    }

    func getTimeline(cursor: String?, limit: Int) async throws -> FeedPage {
        try await authorized { client, token in
            try await client.query("app.bsky.feed.getTimeline",
                                   Self.items(["limit": String(limit), "cursor": cursor]),
                                   accessToken: token)
        }
    }

    func getAuthorFeed(actor: String, filter: AuthorFeedFilter, cursor: String?, limit: Int) async throws -> FeedPage {
        try await authorized { client, token in
            try await client.query(
                "app.bsky.feed.getAuthorFeed",
                Self.items([
                    "actor": actor, "filter": filter.rawValue, "limit": String(limit), "cursor": cursor,
                    // RN turns pins on for the posts_and_author_threads filter (src/lib/api/feed/author.ts).
                    "includePins": filter == .postsAndAuthorThreads ? "true" : nil,
                ]),
                accessToken: token)
        }
    }

    func getPostThreadV2(_ request: PostThreadRequest) async throws -> PostThreadV2Response {
        try await authorized { client, token in
            try await client.query(
                "app.bsky.unspecced.getPostThreadV2",
                Self.items([
                    "anchor": request.anchor,
                    "branchingFactor": String(request.branchingFactor),
                    "below": String(request.below),
                    "sort": request.sort.rawValue,
                ]),
                accessToken: token)
        }
    }

    func getPostThreadOtherV2(anchor: String) async throws -> PostThreadOtherV2Response {
        try await authorized { client, token in
            try await client.query("app.bsky.unspecced.getPostThreadOtherV2", Self.items(["anchor": anchor]),
                                   accessToken: token)
        }
    }

    func getProfile(actor: String) async throws -> ProfileViewDetailed {
        try await authorized { client, token in
            try await client.query("app.bsky.actor.getProfile", Self.items(["actor": actor]), accessToken: token)
        }
    }

    func getPreferences() async throws -> ActorPreferences {
        try await authorized { client, token in
            try await client.query("app.bsky.actor.getPreferences", [], accessToken: token)
        }
    }

    func listNotifications(limit: Int) async throws -> [NotificationView] {
        let response: ListNotificationsResponse = try await authorized { client, token in
            try await client.query("app.bsky.notification.listNotifications",
                                   Self.items(["limit": String(limit)]), accessToken: token)
        }
        return response.notifications
    }

    func like(_ subject: StrongRef, via: StrongRef?) async throws -> String {
        try await createRecord(collection: "app.bsky.feed.like", subject: subject, via: via)
    }

    func deleteLike(uri: String) async throws {
        try await deleteRecord(uri: uri)
    }

    func repost(_ subject: StrongRef, via: StrongRef?) async throws -> String {
        try await createRecord(collection: "app.bsky.feed.repost", subject: subject, via: via)
    }

    func deleteRepost(uri: String) async throws {
        try await deleteRecord(uri: uri)
    }

    // MARK: - Records

    /// Like and repost record shape (`@bsky/sdk/dist/actions/records.js:28-34`).
    private struct SubjectRecord: Encodable {
        var type: String
        var subject: StrongRef
        var createdAt: String
        var via: StrongRef?

        enum CodingKeys: String, CodingKey {
            case type = "$type"
            case subject, createdAt, via
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

    private func createRecord(collection: String, subject: StrongRef, via: StrongRef?) async throws -> String {
        let body = CreateRecordBody(
            repo: accountDid,
            collection: collection,
            record: SubjectRecord(type: collection, subject: subject, createdAt: Self.now(), via: via)
        )
        let response: CreateRecordResponse = try await authorized { client, token in
            try await client.procedure("com.atproto.repo.createRecord", body: body, accessToken: token)
        }
        return response.uri
    }

    private func deleteRecord(uri: String) async throws {
        guard let at = ATURI(uri) else {
            throw XRPCError.invalidResponse("Invalid record URI: \(uri)")
        }
        let body = DeleteRecordBody(repo: accountDid, collection: at.collection, rkey: at.rkey)
        try await authorized { client, token in
            try await client.procedure("com.atproto.repo.deleteRecord", body: body, accessToken: token)
        }
    }

    // MARK: - Auth

    private func authorized<T: Sendable>(
        _ call: @Sendable (XRPCClient, String) async throws -> T
    ) async throws -> T {
        guard !invalidated else { throw XRPCError.sessionInvalidated }
        let token = session.accessJwt
        do {
            return try await call(client, token)
        } catch let error as XRPCError where error.needsTokenRefresh {
            let refreshed = try await refreshedSession(afterFailureWith: token, original: error)
            return try await call(client, refreshed.accessJwt)
        }
    }

    /// Returns a session whose access token differs from `failedToken`, refreshing at most once
    /// for all concurrent callers.
    private func refreshedSession(afterFailureWith failedToken: String, original: XRPCError) async throws -> StoredSession {
        guard !invalidated else { throw XRPCError.sessionInvalidated }
        // Another call already replaced the token while this one was in flight.
        if session.accessJwt != failedToken { return session }
        let task: Task<StoredSession, any Error>
        if let running = refreshTask {
            task = running
        } else {
            let client = self.client
            let current = session
            task = Task {
                let response: SessionResponse = try await client.procedure(
                    "com.atproto.server.refreshSession", body: EmptyBody?.none, accessToken: current.refreshJwt)
                var updated = current
                updated.accessJwt = response.accessJwt
                updated.refreshJwt = response.refreshJwt
                updated.handle = response.handle
                return updated
            }
            refreshTask = task
        }
        do {
            let updated = try await task.value
            if refreshTask == task { refreshTask = nil }
            guard !invalidated else { throw XRPCError.sessionInvalidated }
            if session.accessJwt == failedToken {
                session = updated
                callbacks.onTokensRefreshed(updated)
            }
            // RN returns the original response when the token did not change.
            guard session.accessJwt != failedToken else { throw original }
            return session
        } catch {
            if refreshTask == task { refreshTask = nil }
            if !invalidated, let xrpc = error as? XRPCError, xrpc.isTerminalAuthFailure {
                invalidated = true
                callbacks.onAuthFailure()
            }
            throw error
        }
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
