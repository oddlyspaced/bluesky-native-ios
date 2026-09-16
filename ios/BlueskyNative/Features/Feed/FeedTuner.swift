import Foundation

/// One row group in a feed: a post, optionally preceded by its parent and root.
/// Port of `FeedViewPostsSlice` (`src/lib/api/feed-manip.ts:89-219`).
struct FeedSlice: Identifiable, Hashable, Sendable {
    struct Item: Hashable, Sendable {
        var post: PostView
        /// Author of the post this item replies to, for the "Replied to" row.
        var parentAuthor: ProfileViewBasic?
        var isParentBlocked = false
        var isParentNotFound = false
    }

    /// RN `_reactKey`: `slice-<feed post uri>-<reason.indexedAt ?? post.indexedAt>`.
    var id: String
    var items: [Item]
    var reason: FeedViewPost.Reason?
    var isIncompleteThread = false
    var isOrphan = false
    /// The post the feed returned (the last item before tuning).
    let feedPost: PostView
    let replyContext: FeedViewPost.Reply?

    var feedPostUri: String { feedPost.uri }
    var isReply: Bool { feedPost.record.reply != nil }
    var isRepost: Bool {
        if case .repost = reason { return true }
        return false
    }
    var isQuotePost: Bool { feedPost.embed?.isQuote ?? false }

    /// RN `rootUri` (`feed-manip.ts:79-110`): `reply.root.uri` when the root is a post view,
    /// else the feed post's URI.
    var rootUri: String {
        replyContext?.root.post?.uri ?? feedPost.uri
    }

    init(_ item: FeedViewPost) {
        let post = item.post
        feedPost = post
        replyContext = item.reply
        reason = item.reason
        id = "slice-\(post.uri)-\(item.reason?.indexedAt ?? post.indexedAt)"
        items = [Item(post: post,
                      parentAuthor: item.reply?.parent.post?.author,
                      isParentBlocked: item.reply?.parent.isBlocked ?? false,
                      isParentNotFound: item.reply?.parent.isNotFound ?? false)]

        guard let reply = item.reply else {
            if post.record.reply != nil {
                isOrphan = true
                items[0].isParentNotFound = true
            }
            return
        }
        if item.reason != nil { return }
        guard let parent = reply.parent.post else {
            isOrphan = true
            return
        }
        let rootRefUri: String? = switch reply.root {
        case .post(let root): root.uri
        case .notFound(let uri), .blocked(let uri): uri
        case .unknown: nil
        }
        let grandparentIsRoot = parent.record.reply?.parent.uri != nil && parent.record.reply?.parent.uri == rootRefUri
        var parentItem = Item(post: parent, parentAuthor: reply.grandparentAuthor)
        if grandparentIsRoot {
            parentItem.isParentBlocked = reply.root.isBlocked
            parentItem.isParentNotFound = reply.root.isNotFound
            if reply.root.isBlocked { isOrphan = true }
        }
        items.insert(parentItem, at: 0)

        guard let root = reply.root.post else {
            isOrphan = true
            return
        }
        if root.uri == parent.uri { return }
        items.insert(Item(post: root), at: 0)
        if parent.record.reply?.parent.uri != root.uri {
            isIncompleteThread = true
        }
    }
}

/// Port of `FeedTuner` (`src/lib/api/feed-manip.ts`) and the tuner lists in
/// `src/state/preferences/feed-tuners.tsx`.
struct FeedTuner {
    enum Tuner: Sendable, Hashable {
        case removeOrphans
        case removeReposts
        case removeReplies
        case followedRepliesOnly(userDid: String)
        case removeQuotePosts
        case dedupThreads
        case removeMutedThreads
    }

    private(set) var tuners: [Tuner]
    private var seenKeys = Set<String>()
    private var seenUris = Set<String>()
    private var seenRootUris = Set<String>()

    init(tuners: [Tuner] = []) {
        self.tuners = tuners
    }

    /// The Following feed's tuners, in RN order (`feed-tuners.tsx:27-48`).
    static func following(userDid: String, preferences: HomeFeedPreferences) -> [Tuner] {
        var list: [Tuner] = [.removeOrphans]
        if preferences.hideReposts { list.append(.removeReposts) }
        list.append(preferences.hideReplies ? .removeReplies : .followedRepliesOnly(userDid: userDid))
        if preferences.hideQuotePosts { list.append(.removeQuotePosts) }
        list.append(.dedupThreads)
        list.append(.removeMutedThreads)
        return list
    }

    mutating func reset() {
        seenKeys = []
        seenUris = []
        seenRootUris = []
    }

    /// Turns a page of feed items into slices, removing posts already shown on earlier pages
    /// or earlier in this page.
    mutating func tune(_ page: [FeedViewPost]) -> [FeedSlice] {
        var slices = page.map(FeedSlice.init)
        for tuner in tuners {
            slices = apply(tuner, to: slices)
        }

        var result: [FeedSlice] = []
        for var slice in slices {
            guard !seenKeys.contains(slice.id) else { continue }
            var dropped = false
            var index = 0
            while index < slice.items.count {
                let uri = slice.items[index].post.uri
                if seenUris.contains(uri) {
                    if index == 0 {
                        slice.items.remove(at: 0)
                        index -= 1
                    }
                    if index == slice.items.count - 1 {
                        dropped = true
                        break
                    }
                } else if !(slice.isReply && slice.isRepost) {
                    seenUris.insert(uri)
                }
                index += 1
            }
            if dropped { continue }
            seenKeys.insert(slice.id)
            result.append(slice)
        }
        return result
    }

    private mutating func apply(_ tuner: Tuner, to slices: [FeedSlice]) -> [FeedSlice] {
        switch tuner {
        case .removeOrphans:
            return slices.filter { !$0.isOrphan }
        case .removeReposts:
            return slices.filter { !$0.isRepost }
        case .removeQuotePosts:
            return slices.filter { !$0.isQuotePost }
        case .removeMutedThreads:
            return slices.filter { $0.feedPost.viewer?.threadMuted != true }
        case .removeReplies:
            return slices.filter { !($0.isReply && !$0.isRepost && !Self.areSameAuthor($0)) }
        case .dedupThreads:
            // `feed-manip.ts:448-465`: a repost is never removed, but its root is still recorded, so a
            // later slice of the same thread is removed. Found by the api parity capture (a reposted
            // reply above its own thread, review finding F9).
            var kept: [FeedSlice] = []
            for slice in slices {
                if !slice.isRepost && seenRootUris.contains(slice.rootUri) { continue }
                seenRootUris.insert(slice.rootUri)
                kept.append(slice)
            }
            return kept
        case .followedRepliesOnly(let userDid):
            return slices.filter { !($0.isReply && !$0.isRepost && !Self.shouldDisplayReply($0, userDid: userDid)) }
        }
    }

    /// Parent, grandparent and root authors, where present, are the feed post's author.
    static func areSameAuthor(_ slice: FeedSlice) -> Bool {
        let author = slice.feedPost.author.did
        let others = [slice.replyContext?.parent.post?.author.did,
                      slice.replyContext?.grandparentAuthor?.did,
                      slice.replyContext?.root.post?.author.did]
        return others.allSatisfy { $0 == nil || $0 == author }
    }

    /// `shouldDisplayReplyInFollowing` (`feed-manip.ts:542-589`).
    static func shouldDisplayReply(_ slice: FeedSlice, userDid: String) -> Bool {
        let author = slice.feedPost.author
        guard isSelfOrFollowing(author, userDid: userDid) else { return false }
        let others = [slice.replyContext?.parent.post?.author,
                      slice.replyContext?.grandparentAuthor,
                      slice.replyContext?.root.post?.author]
        if others.allSatisfy({ $0 == nil || $0?.did == author.did }) { return true }
        return others.contains { other in
            guard let other, other.did != author.did else { return false }
            return isSelfOrFollowing(other, userDid: userDid)
        }
    }

    static func isSelfOrFollowing(_ profile: ProfileViewBasic, userDid: String) -> Bool {
        profile.did == userDid || profile.viewer?.following != nil
    }
}
