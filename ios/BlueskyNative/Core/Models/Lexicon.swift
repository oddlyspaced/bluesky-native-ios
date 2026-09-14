import Foundation

// Swift mirrors of the AT Protocol lexicon shapes this slice reads.
// Only the fields the ported screens use are decoded; unknown fields are ignored.

struct ActorViewerState: Codable, Sendable, Hashable {
    var muted: Bool?
    var blockedBy: Bool?
    var following: String?
    var followedBy: String?
}

/// `app.bsky.actor.defs#profileViewBasic`
struct ProfileViewBasic: Codable, Sendable, Hashable, Identifiable {
    var did: String
    var handle: String
    var displayName: String?
    var avatar: URL?
    var viewer: ActorViewerState?

    var id: String { did }
}

/// `app.bsky.actor.defs#profileViewDetailed`
struct ProfileViewDetailed: Codable, Sendable, Hashable {
    var did: String
    var handle: String
    var displayName: String?
    var description: String?
    var avatar: URL?
    var banner: URL?
    var followersCount: Int?
    var followsCount: Int?
    var postsCount: Int?
    var viewer: ActorViewerState?
}

/// `com.atproto.repo.strongRef`
struct StrongRef: Codable, Sendable, Hashable {
    var uri: String
    var cid: String
}

/// `app.bsky.feed.post` record, reduced to the fields this slice renders.
struct PostRecord: Codable, Sendable, Hashable {
    struct ReplyRef: Codable, Sendable, Hashable {
        var root: StrongRef
        var parent: StrongRef
    }

    var text: String
    var createdAt: String
    var reply: ReplyRef?
}

struct PostViewerState: Codable, Sendable, Hashable {
    var like: String?
    var repost: String?
    var bookmarked: Bool?
    var threadMuted: Bool?
    var replyDisabled: Bool?
}

/// `app.bsky.feed.defs#postView`
struct PostView: Codable, Sendable, Hashable, Identifiable {
    var uri: String
    var cid: String
    var author: ProfileViewBasic
    var record: PostRecord
    var replyCount: Int?
    var repostCount: Int?
    var likeCount: Int?
    var quoteCount: Int?
    var bookmarkCount: Int?
    var indexedAt: String
    var viewer: PostViewerState?

    var id: String { uri }
    var strongRef: StrongRef { StrongRef(uri: uri, cid: cid) }
}

/// Union used by `app.bsky.feed.defs#replyRef` root and parent.
enum ReplyRefPost: Codable, Sendable, Hashable {
    case post(PostView)
    case notFound(uri: String)
    case blocked(uri: String)
    case unknown

    private enum CodingKeys: String, CodingKey {
        case type = "$type"
        case uri
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decodeIfPresent(String.self, forKey: .type)
        switch type {
        case "app.bsky.feed.defs#notFoundPost":
            self = .notFound(uri: try container.decode(String.self, forKey: .uri))
        case "app.bsky.feed.defs#blockedPost":
            self = .blocked(uri: try container.decode(String.self, forKey: .uri))
        case "app.bsky.feed.defs#postView", nil:
            self = .post(try PostView(from: decoder))
        default:
            self = .unknown
        }
    }

    func encode(to encoder: any Encoder) throws {
        if case .post(let post) = self { try post.encode(to: encoder) }
    }

    var post: PostView? {
        if case .post(let post) = self { return post }
        return nil
    }
}

/// `app.bsky.feed.defs#feedViewPost`
struct FeedViewPost: Codable, Sendable, Hashable {
    struct Reply: Codable, Sendable, Hashable {
        var root: ReplyRefPost
        var parent: ReplyRefPost
        var grandparentAuthor: ProfileViewBasic?
    }

    enum Reason: Codable, Sendable, Hashable {
        case repost(by: ProfileViewBasic)
        case pin
        case unknown

        private enum CodingKeys: String, CodingKey {
            case type = "$type"
            case by
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            switch try container.decodeIfPresent(String.self, forKey: .type) {
            case "app.bsky.feed.defs#reasonRepost":
                self = .repost(by: try container.decode(ProfileViewBasic.self, forKey: .by))
            case "app.bsky.feed.defs#reasonPin":
                self = .pin
            default:
                self = .unknown
            }
        }

        func encode(to encoder: any Encoder) throws {}
    }

    var post: PostView
    var reply: Reply?
    var reason: Reason?
}

/// Response of `app.bsky.feed.getTimeline` and `app.bsky.feed.getAuthorFeed`.
struct FeedPage: Codable, Sendable, Hashable {
    var feed: [FeedViewPost]
    var cursor: String?
}

/// Union returned by `app.bsky.feed.getPostThread`.
indirect enum ThreadNode: Decodable, Sendable, Hashable {
    case post(PostView, parent: ThreadNode?, replies: [ThreadNode])
    case notFound(uri: String)
    case blocked(uri: String)
    case unknown

    private enum CodingKeys: String, CodingKey {
        case type = "$type"
        case uri, post, parent, replies
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decodeIfPresent(String.self, forKey: .type)
        switch type {
        case "app.bsky.feed.defs#notFoundPost":
            self = .notFound(uri: try container.decode(String.self, forKey: .uri))
        case "app.bsky.feed.defs#blockedPost":
            self = .blocked(uri: try container.decode(String.self, forKey: .uri))
        case "app.bsky.feed.defs#threadViewPost", nil:
            guard container.contains(.post) else {
                self = .unknown
                return
            }
            self = .post(
                try container.decode(PostView.self, forKey: .post),
                parent: try container.decodeIfPresent(ThreadNode.self, forKey: .parent),
                replies: try container.decodeIfPresent([ThreadNode].self, forKey: .replies) ?? []
            )
        default:
            self = .unknown
        }
    }
}

struct PostThreadResponse: Decodable, Sendable {
    var thread: ThreadNode
}

/// Response of `com.atproto.server.createSession` and `refreshSession`.
struct SessionResponse: Codable, Sendable, Hashable {
    var accessJwt: String
    var refreshJwt: String
    var did: String
    var handle: String
    var email: String?
    var active: Bool?
}

/// Response of `com.atproto.repo.createRecord`.
struct CreateRecordResponse: Codable, Sendable, Hashable {
    var uri: String
    var cid: String
}

struct UnreadCountResponse: Codable, Sendable, Hashable {
    var count: Int
}

/// An AT URI: `at://<did>/<collection>/<rkey>`.
struct ATURI: Sendable, Hashable {
    var host: String
    var collection: String
    var rkey: String

    init?(_ string: String) {
        guard string.hasPrefix("at://") else { return nil }
        let parts = string.dropFirst(5).split(separator: "/", omittingEmptySubsequences: false)
        guard parts.count == 3 else { return nil }
        host = String(parts[0])
        collection = String(parts[1])
        rkey = String(parts[2])
    }
}

enum ATDate {
    nonisolated(unsafe) private static let fractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    nonisolated(unsafe) private static let plain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static let lock = NSLock()

    /// Parses an AT Protocol datetime string. Returns nil for malformed values.
    static func parse(_ string: String) -> Date? {
        lock.lock()
        defer { lock.unlock() }
        return fractional.date(from: string) ?? plain.date(from: string)
    }
}
