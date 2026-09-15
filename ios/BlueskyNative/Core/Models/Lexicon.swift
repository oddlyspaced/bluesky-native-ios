import Foundation

// Swift mirrors of the AT Protocol lexicon shapes this slice reads.
// Only the fields the ported screens use are decoded; unknown fields are ignored.

struct ActorViewerState: Codable, Sendable, Hashable {
    var muted: Bool?
    var blockedBy: Bool?
    /// URI of the viewer's block record, when the viewer blocks this actor.
    var blocking: String?
    /// Present when a list the viewer subscribes to blocks this actor.
    var blockingByList: ListViewBasicRef?
    var following: String?
    var followedBy: String?

    struct ListViewBasicRef: Codable, Sendable, Hashable {
        var uri: String
    }
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

/// `app.bsky.richtext.facet`: a UTF-8 byte range and its features.
struct Facet: Codable, Sendable, Hashable {
    struct ByteSlice: Codable, Sendable, Hashable {
        var byteStart: Int
        var byteEnd: Int
    }

    enum Feature: Codable, Sendable, Hashable {
        case mention(did: String)
        case link(uri: String)
        case tag(String)
        case unknown

        private enum CodingKeys: String, CodingKey {
            case type = "$type"
            case did, uri, tag
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            switch try container.decodeIfPresent(String.self, forKey: .type) {
            case "app.bsky.richtext.facet#mention":
                self = .mention(did: try container.decode(String.self, forKey: .did))
            case "app.bsky.richtext.facet#link":
                self = .link(uri: try container.decode(String.self, forKey: .uri))
            case "app.bsky.richtext.facet#tag":
                self = .tag(try container.decode(String.self, forKey: .tag))
            default:
                self = .unknown
            }
        }

        func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .mention(let did):
                try container.encode("app.bsky.richtext.facet#mention", forKey: .type)
                try container.encode(did, forKey: .did)
            case .link(let uri):
                try container.encode("app.bsky.richtext.facet#link", forKey: .type)
                try container.encode(uri, forKey: .uri)
            case .tag(let tag):
                try container.encode("app.bsky.richtext.facet#tag", forKey: .type)
                try container.encode(tag, forKey: .tag)
            case .unknown:
                break
            }
        }
    }

    var index: ByteSlice
    var features: [Feature]
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
    var facets: [Facet]?

    init(text: String, createdAt: String, reply: ReplyRef? = nil, facets: [Facet]? = nil) {
        self.text = text
        self.createdAt = createdAt
        self.reply = reply
        self.facets = facets
    }
}

struct PostViewerState: Codable, Sendable, Hashable {
    var like: String?
    var repost: String?
    var bookmarked: Bool?
    var threadMuted: Bool?
    var replyDisabled: Bool?
    var embeddingDisabled: Bool?

    init(like: String? = nil, repost: String? = nil, bookmarked: Bool? = nil, threadMuted: Bool? = nil,
         replyDisabled: Bool? = nil, embeddingDisabled: Bool? = nil) {
        self.like = like
        self.repost = repost
        self.bookmarked = bookmarked
        self.threadMuted = threadMuted
        self.replyDisabled = replyDisabled
        self.embeddingDisabled = embeddingDisabled
    }
}

/// The `$type` of a post's embed view. Embeds are not rendered in this slice
/// (proposed out of scope); the type is read for the quote-post feed tuner.
struct EmbedViewType: Codable, Sendable, Hashable {
    var type: String

    private enum CodingKeys: String, CodingKey {
        case type = "$type"
    }

    var isQuote: Bool {
        type == "app.bsky.embed.record#view" || type == "app.bsky.embed.recordWithMedia#view"
    }
}

/// `app.bsky.feed.defs#threadgateView`, reduced to the `allow` rules of its record.
struct ThreadgateView: Codable, Sendable, Hashable {
    struct Record: Codable, Sendable, Hashable {
        struct Rule: Codable, Sendable, Hashable {
            var type: String?

            private enum CodingKeys: String, CodingKey {
                case type = "$type"
            }
        }

        var allow: [Rule]?
    }

    var record: Record?
}

/// `app.bsky.feed.defs#postView`
struct PostView: Codable, Sendable, Hashable, Identifiable {
    var uri: String
    var cid: String
    var author: ProfileViewBasic
    var record: PostRecord
    var embed: EmbedViewType?
    var replyCount: Int?
    var repostCount: Int?
    var likeCount: Int?
    var quoteCount: Int?
    var bookmarkCount: Int?
    var indexedAt: String {
        didSet { indexedDate = ATDate.parse(indexedAt) }
    }
    var viewer: PostViewerState?
    var threadgate: ThreadgateView?

    /// `indexedAt`, parsed once at decode time (review finding A14).
    private(set) var indexedDate: Date?

    var id: String { uri }
    var strongRef: StrongRef { StrongRef(uri: uri, cid: cid) }

    private enum CodingKeys: String, CodingKey {
        case uri, cid, author, record, embed, replyCount, repostCount, likeCount, quoteCount, bookmarkCount
        case indexedAt, viewer, threadgate
    }

    init(uri: String, cid: String, author: ProfileViewBasic, record: PostRecord, embed: EmbedViewType? = nil,
         replyCount: Int? = nil, repostCount: Int? = nil, likeCount: Int? = nil, quoteCount: Int? = nil,
         bookmarkCount: Int? = nil, indexedAt: String, viewer: PostViewerState? = nil,
         threadgate: ThreadgateView? = nil) {
        self.uri = uri
        self.cid = cid
        self.author = author
        self.record = record
        self.embed = embed
        self.replyCount = replyCount
        self.repostCount = repostCount
        self.likeCount = likeCount
        self.quoteCount = quoteCount
        self.bookmarkCount = bookmarkCount
        self.indexedAt = indexedAt
        self.viewer = viewer
        self.threadgate = threadgate
        self.indexedDate = ATDate.parse(indexedAt)
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            uri: try c.decode(String.self, forKey: .uri),
            cid: try c.decode(String.self, forKey: .cid),
            author: try c.decode(ProfileViewBasic.self, forKey: .author),
            record: try c.decode(PostRecord.self, forKey: .record),
            embed: try? c.decodeIfPresent(EmbedViewType.self, forKey: .embed),
            replyCount: try c.decodeIfPresent(Int.self, forKey: .replyCount),
            repostCount: try c.decodeIfPresent(Int.self, forKey: .repostCount),
            likeCount: try c.decodeIfPresent(Int.self, forKey: .likeCount),
            quoteCount: try c.decodeIfPresent(Int.self, forKey: .quoteCount),
            bookmarkCount: try c.decodeIfPresent(Int.self, forKey: .bookmarkCount),
            indexedAt: try c.decode(String.self, forKey: .indexedAt),
            viewer: try c.decodeIfPresent(PostViewerState.self, forKey: .viewer),
            threadgate: try? c.decodeIfPresent(ThreadgateView.self, forKey: .threadgate)
        )
    }

    func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(uri, forKey: .uri)
        try c.encode(cid, forKey: .cid)
        try c.encode(author, forKey: .author)
        try c.encode(record, forKey: .record)
        try c.encodeIfPresent(embed, forKey: .embed)
        try c.encodeIfPresent(replyCount, forKey: .replyCount)
        try c.encodeIfPresent(repostCount, forKey: .repostCount)
        try c.encodeIfPresent(likeCount, forKey: .likeCount)
        try c.encodeIfPresent(quoteCount, forKey: .quoteCount)
        try c.encodeIfPresent(bookmarkCount, forKey: .bookmarkCount)
        try c.encode(indexedAt, forKey: .indexedAt)
        try c.encodeIfPresent(viewer, forKey: .viewer)
        try c.encodeIfPresent(threadgate, forKey: .threadgate)
    }
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

    var isBlocked: Bool {
        if case .blocked = self { return true }
        return false
    }

    var isNotFound: Bool {
        if case .notFound = self { return true }
        return false
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
        /// `reasonRepost`. `uri` and `cid` identify the repost record (used as `via`).
        case repost(by: ProfileViewBasic, uri: String?, cid: String?, indexedAt: String?)
        case pin
        case unknown

        private enum CodingKeys: String, CodingKey {
            case type = "$type"
            case by, uri, cid, indexedAt
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            switch try container.decodeIfPresent(String.self, forKey: .type) {
            case "app.bsky.feed.defs#reasonRepost":
                self = .repost(by: try container.decode(ProfileViewBasic.self, forKey: .by),
                               uri: try container.decodeIfPresent(String.self, forKey: .uri),
                               cid: try container.decodeIfPresent(String.self, forKey: .cid),
                               indexedAt: try container.decodeIfPresent(String.self, forKey: .indexedAt))
            case "app.bsky.feed.defs#reasonPin":
                self = .pin
            default:
                self = .unknown
            }
        }

        func encode(to encoder: any Encoder) throws {}

        /// The repost record, when the reason carries one (`PostFeedItem.tsx:306-317`).
        var viaRepost: StrongRef? {
            if case .repost(_, let uri?, let cid?, _) = self { return StrongRef(uri: uri, cid: cid) }
            return nil
        }

        var indexedAt: String? {
            if case .repost(_, _, _, let indexedAt) = self { return indexedAt }
            return nil
        }
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

// MARK: - Thread V2

/// `app.bsky.unspecced.defs#threadItem*` value union.
enum ThreadItemValue: Decodable, Sendable, Hashable {
    struct Post: Decodable, Sendable, Hashable {
        var post: PostView
        var moreParents: Bool
        var moreReplies: Int
        var opThread: Bool
        var hiddenByThreadgate: Bool
        var mutedByViewer: Bool

        init(post: PostView, moreParents: Bool = false, moreReplies: Int = 0, opThread: Bool = false,
             hiddenByThreadgate: Bool = false, mutedByViewer: Bool = false) {
            self.post = post
            self.moreParents = moreParents
            self.moreReplies = moreReplies
            self.opThread = opThread
            self.hiddenByThreadgate = hiddenByThreadgate
            self.mutedByViewer = mutedByViewer
        }

        private enum CodingKeys: String, CodingKey {
            case post, moreParents, moreReplies, opThread, hiddenByThreadgate, mutedByViewer
        }

        init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            post = try c.decode(PostView.self, forKey: .post)
            moreParents = try c.decodeIfPresent(Bool.self, forKey: .moreParents) ?? false
            moreReplies = try c.decodeIfPresent(Int.self, forKey: .moreReplies) ?? 0
            opThread = try c.decodeIfPresent(Bool.self, forKey: .opThread) ?? false
            hiddenByThreadgate = try c.decodeIfPresent(Bool.self, forKey: .hiddenByThreadgate) ?? false
            mutedByViewer = try c.decodeIfPresent(Bool.self, forKey: .mutedByViewer) ?? false
        }
    }

    case post(Post)
    case noUnauthenticated
    case notFound
    case blocked
    case unknown

    private enum CodingKeys: String, CodingKey {
        case type = "$type"
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decodeIfPresent(String.self, forKey: .type) {
        case "app.bsky.unspecced.defs#threadItemPost":
            self = .post(try Post(from: decoder))
        case "app.bsky.unspecced.defs#threadItemNoUnauthenticated":
            self = .noUnauthenticated
        case "app.bsky.unspecced.defs#threadItemNotFound":
            self = .notFound
        case "app.bsky.unspecced.defs#threadItemBlocked":
            self = .blocked
        default:
            self = .unknown
        }
    }
}

/// `app.bsky.unspecced.getPostThreadV2#threadItem`
struct ThreadItem: Decodable, Sendable, Hashable {
    var uri: String
    /// 0 is the anchor, negative values are parents, positive values are replies.
    var depth: Int
    var value: ThreadItemValue
}

struct PostThreadV2Response: Decodable, Sendable, Hashable {
    var thread: [ThreadItem]
    var hasOtherReplies: Bool

    init(thread: [ThreadItem], hasOtherReplies: Bool = false) {
        self.thread = thread
        self.hasOtherReplies = hasOtherReplies
    }

    private enum CodingKeys: String, CodingKey {
        case thread, hasOtherReplies
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        thread = try c.decode([ThreadItem].self, forKey: .thread)
        hasOtherReplies = try c.decodeIfPresent(Bool.self, forKey: .hasOtherReplies) ?? false
    }
}

struct PostThreadOtherV2Response: Decodable, Sendable, Hashable {
    var thread: [ThreadItem]
}

/// Reply sort values of `getPostThreadV2`.
enum ThreadSort: String, Sendable {
    case top, oldest, newest

    /// `normalizeSort` (`useThreadPreferences.ts:145-154`): anything else becomes `top`.
    static func normalize(_ value: String?) -> ThreadSort {
        switch value {
        case "oldest": .oldest
        case "newest": .newest
        default: .top
        }
    }
}

// MARK: - Preferences

/// `app.bsky.actor.defs#feedViewPref` for the "home" feed, with RN's defaults
/// (`DEFAULT_HOME_FEED_PREFS`, `src/state/queries/preferences/const.ts:20-28`).
struct HomeFeedPreferences: Sendable, Hashable {
    var hideReplies = false
    var hideReposts = false
    var hideQuotePosts = false
}

/// The preferences this slice reads from `app.bsky.actor.getPreferences`.
struct ActorPreferences: Decodable, Sendable, Hashable {
    var homeFeed = HomeFeedPreferences()
    /// `app.bsky.actor.defs#threadViewPref.sort`, raw.
    var threadSort: String?

    init(homeFeed: HomeFeedPreferences = HomeFeedPreferences(), threadSort: String? = nil) {
        self.homeFeed = homeFeed
        self.threadSort = threadSort
    }

    private enum CodingKeys: String, CodingKey {
        case preferences
    }

    private struct RawPreference: Decodable {
        var type: String?
        var feed: String?
        var hideReplies: Bool?
        var hideReposts: Bool?
        var hideQuotePosts: Bool?
        var sort: String?

        private enum CodingKeys: String, CodingKey {
            case type = "$type"
            case feed, hideReplies, hideReposts, hideQuotePosts, sort
        }
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let raw = try c.decodeIfPresent([RawPreference].self, forKey: .preferences) ?? []
        for pref in raw {
            switch pref.type {
            case "app.bsky.actor.defs#feedViewPref" where pref.feed == "home":
                homeFeed.hideReplies = pref.hideReplies ?? false
                homeFeed.hideReposts = pref.hideReposts ?? false
                homeFeed.hideQuotePosts = pref.hideQuotePosts ?? false
            case "app.bsky.actor.defs#threadViewPref":
                threadSort = pref.sort
            default:
                break
            }
        }
    }
}

// MARK: - Sessions and records

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
