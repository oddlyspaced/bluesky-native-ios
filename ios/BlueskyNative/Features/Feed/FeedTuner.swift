import Foundation

/// One row group in a feed: a post, optionally preceded by its parent and root.
/// Port of `FeedViewPostsSlice` (`src/lib/api/feed-manip.ts`).
struct FeedSlice: Identifiable, Hashable, Sendable {
    struct Item: Hashable, Sendable {
        var post: PostView
        /// Author of the post this item replies to, for the "Replied to" row.
        var parentAuthor: ProfileViewBasic?
    }

    var id: String
    var items: [Item]
    var reason: FeedViewPost.Reason?
    var isIncompleteThread: Bool
    var rootUri: String

    var isReply: Bool { items.last?.post.record.reply != nil }
    var isRepost: Bool {
        if case .repost = reason { return true }
        return false
    }

    init(_ item: FeedViewPost) {
        let post = item.post
        var items = [Item(post: post, parentAuthor: item.reply?.parent.post?.author)]
        var incomplete = false
        var rootUri = post.uri
        reason = item.reason
        id = "slice-\(post.uri)-\(item.reason.map { String(describing: $0).hashValue } ?? 0)"

        if let reply = item.reply, item.reason == nil,
           let parent = reply.parent.post {
            let grandparentAuthor = reply.grandparentAuthor
            items.insert(Item(post: parent, parentAuthor: grandparentAuthor), at: 0)
            if let root = reply.root.post {
                rootUri = root.uri
                if root.uri != parent.uri {
                    items.insert(Item(post: root, parentAuthor: nil), at: 0)
                    if parent.record.reply?.parent.uri != root.uri {
                        incomplete = true
                    }
                }
            }
        } else if let reply = item.reply, let root = reply.root.post {
            rootUri = root.uri
        }
        self.items = items
        self.isIncompleteThread = incomplete
        self.rootUri = rootUri
    }
}

/// Port of the Following-feed tuning in RN (`FeedTuner.tune` with `dedupThreads`).
struct FeedTuner {
    private var seenKeys = Set<String>()
    private var seenUris = Set<String>()
    private var seenRootUris = Set<String>()

    mutating func reset() {
        self = FeedTuner()
    }

    /// Turns a page of feed items into slices, removing posts already shown
    /// on earlier pages or earlier in this page.
    mutating func tune(_ page: [FeedViewPost], dedupThreads: Bool = true) -> [FeedSlice] {
        var result: [FeedSlice] = []
        for item in page {
            var slice = FeedSlice(item)
            guard seenKeys.insert(slice.id).inserted else { continue }

            // dedupThreads: a non-repost slice whose thread root was already shown is dropped.
            if dedupThreads && !slice.isRepost {
                if seenRootUris.contains(slice.rootUri) { continue }
                seenRootUris.insert(slice.rootUri)
            }

            // Leading items already shown are removed; a slice whose last item was shown is dropped.
            if let last = slice.items.last, seenUris.contains(last.post.uri) { continue }
            while slice.items.count > 1, let first = slice.items.first, seenUris.contains(first.post.uri) {
                slice.items.removeFirst()
            }
            if !(slice.isReply && slice.isRepost) {
                for entry in slice.items { seenUris.insert(entry.post.uri) }
            }
            result.append(slice)
        }
        return result
    }
}
