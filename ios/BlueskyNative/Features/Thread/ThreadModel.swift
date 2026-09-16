import Foundation
import Observation

/// UI flags of a thread post row (`getThreadPostUI`, `usePostThread/utils.ts:114-147`).
struct ThreadPostUI: Hashable, Sendable {
    var isAnchor = false
    var showParentReplyLine = false
    var showChildReplyLine = false
    var indent = 0
    var isLastChild = false
    var precedesChildReadMore = false
}

/// One item of the linear thread list (`usePostThread/types.ts:36-116`).
enum ThreadListItem: Identifiable, Hashable, Sendable {
    case post(uri: String, depth: Int, value: ThreadItemValue.Post, isBlurred: Bool, ui: ThreadPostUI)
    case noUnauthenticated(uri: String, depth: Int, ui: ThreadPostUI)
    case notFound(uri: String, depth: Int)
    case blocked(uri: String, depth: Int)
    case readMore(uri: String, depth: Int, moreReplies: Int)
    case readMoreUp(uri: String)
    case showOtherReplies
    case anchorSkeleton
    case replySkeleton(index: Int)

    var id: String {
        switch self {
        case .post(let uri, _, _, _, _): uri
        case .noUnauthenticated(let uri, _, _): "noUnauthenticated:\(uri)"
        case .notFound(let uri, _): "notFound:\(uri)"
        case .blocked(let uri, _): "blocked:\(uri)"
        case .readMore(let uri, _, _): "readMore:\(uri)"
        case .readMoreUp(let uri): "readMoreUp:\(uri)"
        case .showOtherReplies: "showOtherReplies"
        case .anchorSkeleton: "anchor-skeleton"
        case .replySkeleton(let index): "anchor-skeleton-reply-\(index)"
        }
    }

    var depth: Int? {
        switch self {
        case .post(_, let depth, _, _, _), .noUnauthenticated(_, let depth, _), .notFound(_, let depth),
             .blocked(_, let depth), .readMore(_, let depth, _):
            depth
        default:
            nil
        }
    }

    var postValue: ThreadItemValue.Post? {
        if case .post(_, _, let value, _, _) = self { return value }
        return nil
    }

    var isTombstone: Bool {
        switch self {
        case .notFound, .blocked: true
        default: false
        }
    }
}

/// Port of RN's thread traversal (`src/state/queries/usePostThread/traversal.ts`) for the
/// linear view. Moderation is not ported; `isBlurred` uses the server's `hiddenByThreadgate`
/// and `mutedByViewer` flags and the author's muted state, and never blurs your own posts.
enum ThreadTraversal {
    private struct Meta {
        var depth: Int
        var parentUri: String?
        var repliesCount: Int
        var repliesUnhydrated: Int
        var repliesSeenCounter = 0
        var replyIndex = 0
        var prevItemDepth: Int?
        var nextItemDepth: Int?
        var followsReadMoreUp = false
        var precedesChildReadMore = false
    }

    struct Result: Equatable {
        var items: [ThreadListItem]
        var otherItems: [ThreadListItem]
    }

    static func isBlurred(_ value: ThreadItemValue.Post, userDid: String) -> Bool {
        let hidden = value.hiddenByThreadgate || value.mutedByViewer || value.post.author.viewer?.muted == true
        return hidden && value.post.author.did != userDid
    }

    static func sortAndAnnotate(_ thread: [ThreadItem], userDid: String, skipModeration: Bool = false) -> Result {
        var metadata: [String: Meta] = [:]
        var items: [ThreadListItem] = []
        var other: [ThreadListItem] = []

        var i = 0
        while i < thread.count {
            let item = thread[i]
            if case .post(let value) = item.value {
                metadata[item.uri] = Meta(depth: item.depth, parentUri: value.post.record.reply?.parent.uri,
                                          repliesCount: value.post.replyCount ?? 0,
                                          repliesUnhydrated: value.moreReplies)
            }
            if item.depth < 0 {
                i += 1
                continue
            }
            if item.depth == 0 {
                items.append(view(for: item, userDid: userDid, skipModeration: skipModeration))
                if case .post = item.value {
                    parents: for pi in stride(from: i - 1, through: 0, by: -1) {
                        let parent = thread[pi]
                        switch parent.value {
                        case .noUnauthenticated:
                            items.insert(.noUnauthenticated(uri: parent.uri, depth: parent.depth,
                                                            ui: ThreadPostUI(showParentReplyLine: false,
                                                                             showChildReplyLine: parent.depth < 0)),
                                         at: 0)
                            break parents
                        case .notFound:
                            items.insert(.notFound(uri: parent.uri, depth: parent.depth), at: 0)
                            break parents
                        case .blocked:
                            items.insert(.blocked(uri: parent.uri, depth: parent.depth), at: 0)
                            break parents
                        case .post:
                            items.insert(view(for: parent, userDid: userDid, skipModeration: true), at: 0)
                        case .unknown:
                            continue
                        }
                    }
                }
                i += 1
                continue
            }

            // depth > 0
            guard case .post(let value) = item.value else {
                i = branchEnd(thread, from: i)
                continue
            }
            if let parentUri = metadata[item.uri]?.parentUri, var parentMeta = metadata[parentUri] {
                metadata[item.uri]?.replyIndex = parentMeta.repliesSeenCounter
                let blurred = !skipModeration && isBlurred(value, userDid: userDid)
                if !blurred {
                    items.append(view(for: item, userDid: userDid, skipModeration: skipModeration))
                    parentMeta.repliesSeenCounter += 1
                    metadata[parentUri] = parentMeta
                    i += 1
                    continue
                }
                let end = branchEnd(thread, from: i)
                if item.depth == 1 {
                    other.append(view(for: item, userDid: userDid, skipModeration: true))
                    var k = i + 1
                    while k < end {
                        let child = thread[k]
                        guard case .post(let childValue) = child.value else { break }
                        if case .post = child.value, let childMeta = metadata[child.uri] ?? Optional(
                            Meta(depth: child.depth, parentUri: childValue.post.record.reply?.parent.uri,
                                 repliesCount: childValue.post.replyCount ?? 0,
                                 repliesUnhydrated: childValue.moreReplies)) {
                            metadata[child.uri] = childMeta
                        }
                        if isBlurred(childValue, userDid: userDid) {
                            k = branchEnd(thread, from: k)
                            continue
                        }
                        other.append(view(for: child, userDid: userDid, skipModeration: true))
                        k += 1
                    }
                }
                i = end
            } else {
                items.append(view(for: item, userDid: userDid, skipModeration: skipModeration))
                i += 1
            }
        }

        return Result(items: annotate(items, metadata: &metadata),
                      otherItems: annotate(other, metadata: &metadata))
    }

    /// Index after the sub-branch that starts at `index`.
    private static func branchEnd(_ thread: [ThreadItem], from index: Int) -> Int {
        let depth = thread[index].depth
        var j = index + 1
        while j < thread.count, thread[j].depth > depth { j += 1 }
        return j
    }

    private static func view(for item: ThreadItem, userDid: String, skipModeration: Bool) -> ThreadListItem {
        switch item.value {
        case .post(let value):
            let blurred = !skipModeration && isBlurred(value, userDid: userDid)
            return .post(uri: item.uri, depth: item.depth, value: value, isBlurred: blurred,
                         ui: ThreadPostUI(isAnchor: item.depth == 0, indent: item.depth))
        case .noUnauthenticated:
            return .noUnauthenticated(uri: item.uri, depth: item.depth, ui: ThreadPostUI())
        case .notFound, .unknown:
            return .notFound(uri: item.uri, depth: item.depth)
        case .blocked:
            return .blocked(uri: item.uri, depth: item.depth)
        }
    }

    /// The second pass (`traversal.ts:280-454`) for the linear view.
    private static func annotate(_ list: [ThreadListItem], metadata: inout [String: Meta]) -> [ThreadListItem] {
        var output: [ThreadListItem] = []
        for (index, item) in list.enumerated() {
            guard case .post(let uri, let depth, let value, let blurred, _) = item, var meta = metadata[uri] else {
                output.append(item)
                continue
            }
            meta.prevItemDepth = index > 0 ? (list[index - 1].postValue != nil ? list[index - 1].depth : nil) : nil
            meta.nextItemDepth = index + 1 < list.count ? (list[index + 1].postValue != nil ? list[index + 1].depth : nil) : nil
            let isLastChild = meta.nextItemDepth == nil || meta.nextItemDepth! <= depth
            var trailing: ThreadListItem?
            if meta.repliesUnhydrated > 0 && isLastChild {
                meta.precedesChildReadMore = true
                trailing = .readMore(uri: uri, depth: depth, moreReplies: meta.repliesUnhydrated)
            }
            if value.moreParents {
                meta.followsReadMoreUp = true
                output.append(.readMoreUp(uri: uri))
            }
            metadata[uri] = meta
            output.append(.post(uri: uri, depth: depth, value: value, isBlurred: blurred,
                                ui: ui(for: meta, isLastChild: isLastChild)))
            if let trailing { output.append(trailing) }
        }
        return output
    }

    private static func ui(for meta: Meta, isLastChild: Bool) -> ThreadPostUI {
        let depth = meta.depth
        let isReplyAndHasReplies = depth > 0 && meta.repliesCount > 0
            && (meta.repliesCount - meta.repliesUnhydrated == meta.repliesSeenCounter || meta.repliesSeenCounter > 0)
        // JS `!!prevItemDepth`: 0 is falsy.
        let prev = meta.prevItemDepth
        let showParent = meta.followsReadMoreUp || (prev != nil && prev != 0 && prev! < depth)
        return ThreadPostUI(isAnchor: depth == 0, showParentReplyLine: showParent,
                            showChildReplyLine: depth < 0 || isReplyAndHasReplies, indent: depth,
                            isLastChild: isLastChild, precedesChildReadMore: meta.precedesChildReadMore)
    }
}

/// `preferences.threadViewPrefs`: the only part of the preferences that `useThreadPreferences`
/// compares (`useThreadPreferences.ts:33-52`, review finding F10).
struct ThreadViewPreferences: Hashable, Sendable {
    var sort: String?
    var treeViewEnabled: Bool
}

extension ActorPreferences {
    var threadViewPreferences: ThreadViewPreferences {
        ThreadViewPreferences(sort: threadSort, treeViewEnabled: threadTreeViewEnabled)
    }
}

/// Loads a post thread. Port of `usePostThread` (`src/state/queries/usePostThread/index.ts`)
/// in the linear view.
@MainActor
@Observable
final class ThreadModel {
    enum Status: Equatable {
        case loading
        case loaded
        /// `ThreadError` copy.
        case failed(title: String, message: String)
    }

    private(set) var status: Status = .loading { didSet { rebuildItems() } }
    private(set) var result = ThreadTraversal.Result(items: [], otherItems: []) { didSet { rebuildItems() } }
    private(set) var hasOtherReplies = false { didSet { rebuildItems() } }
    private(set) var otherItemsVisible = false { didSet { rebuildItems() } }
    private(set) var serverOtherItems: [ThreadListItem] = [] { didSet { rebuildItems() } }
    private(set) var isLoadingOther = false { didSet { rebuildItems() } }
    /// The anchor from another screen's data, shown while the thread loads.
    private(set) var placeholder: PostView? { didSet { rebuildItems() } }
    /// The list RN renders (`buildThread`, `traversal.ts:462-565`), rebuilt only when its inputs
    /// change, so rows never recompute it (review finding A61).
    private(set) var items: [ThreadListItem] = []

    let anchorUri: String
    let feedDescriptor: String?

    @ObservationIgnored private let api: any BlueskyAPI
    @ObservationIgnored private let preferences: PreferencesModel
    @ObservationIgnored private let analytics: any AnalyticsSink
    @ObservationIgnored private let faults: DebugFaults?
    @ObservationIgnored private let userDid: String
    @ObservationIgnored private var reportedPreferences = false
    /// The thread view preferences this screen saw when it appeared (RN `useState(serverPrefs)`,
    /// where `serverPrefs` is `preferences.threadViewPrefs`, review finding F10).
    @ObservationIgnored private var threadPrefsAtAppear: ThreadViewPreferences?
    /// The background refetch started when the cached preferences were stale.
    @ObservationIgnored private(set) var preferencesRefresh: Task<Void, Never>?
    @ObservationIgnored private var reportedAnchorUri: String?
    @ObservationIgnored private var viewedPosts = Set<String>()
    /// Item id to index in `items`, for the viewability order. A linear scan of `items` for every
    /// row event is O(n squared) over a long thread; `FeedModel` already solved it this way
    /// (review finding A70).
    @ObservationIgnored private var itemIndex: [String: Int] = [:]
    @ObservationIgnored private var loadTask: Task<Void, Never>?
    @ObservationIgnored private var tracker: ViewabilityTracker<String>?

    init(api: any BlueskyAPI, anchor: String, feedDescriptor: String?, preferences: PreferencesModel,
         analytics: any AnalyticsSink = NoopAnalytics(), faults: DebugFaults? = nil, userDid: String,
         placeholder: PostView? = nil, viewWaiter: ViewabilityTracker<String>.Waiter? = nil) {
        self.api = api
        self.anchorUri = anchor
        self.feedDescriptor = feedDescriptor
        self.preferences = preferences
        self.analytics = analytics
        self.faults = faults
        self.userDid = userDid
        self.placeholder = placeholder
        threadPrefsAtAppear = preferences.preferences?.threadViewPreferences
        let onViewable: @MainActor ([String]) -> Void = { [weak self] ids in self?.reportViewable(ids) }
        tracker = viewWaiter.map { ViewabilityTracker(waiter: $0, onViewable: onViewable) }
            ?? ViewabilityTracker(onViewable: onViewable)
        rebuildItems()
    }

    func setPlaceholder(_ post: PostView?) {
        if status == .loading, placeholder == nil { placeholder = post }
    }

    var anchor: PostView? {
        for item in result.items {
            if case .post(_, 0, let value, _, _) = item { return value.post }
        }
        return nil
    }

    var hasParents: Bool {
        result.items.contains { ($0.depth ?? 0) < 0 }
    }

    /// `canReply` (`PostThread/index.tsx:158`): false only when the anchor RN has (loaded or the
    /// placeholder) says replies are disabled. The mobile prompt shows only when this is true
    /// (`index.tsx:647-649`, review finding N2).
    var canReply: Bool {
        let current = anchor ?? (status == .loading ? placeholder : nil)
        return current?.viewer?.replyDisabled != true
    }

    /// The event a tap on a thread row's avatar logs. RN logs `post:clickthroughAuthor` only on the
    /// anchor (`ThreadItemAnchor.tsx:280-286`); reply and parent avatars log nothing
    /// (`ThreadItemPost.tsx:280-286`, review finding N1).
    static func authorTapEvent(for post: PostView, isAnchor: Bool, context: PostEventContext) -> AnalyticsEvent? {
        guard isAnchor else { return nil }
        return AnalyticsEvent(name: "post:clickthroughAuthor", props: context.props(for: post))
    }

    /// Loads once; later calls do nothing unless the last load failed.
    func loadIfNeeded() async {
        if case .loaded = status { return }
        if let loadTask { return await loadTask.value }
        let task = Task { await self.load() }
        loadTask = task
        await task.value
        loadTask = nil
    }

    /// The `ThreadError` retry (`query.refetch`).
    func retry() async {
        status = .loading
        await loadIfNeeded()
    }

    /// Events of the thread screen's first render: the anchor `post:view` effect runs on the
    /// placeholder anchor from the query cache, before the network answers
    /// (`PostThread/index.tsx:95-112`, review finding N23). Idempotent.
    func reportRenderEvents() {
        if let placeholder { reportAnchorView(placeholder) }
    }

    private func load() async {
        reportRenderEvents()
        let prefs: ActorPreferences
        if let cached = preferences.preferences {
            // RN reads the cached preferences query and refetches it in the background when it is
            // older than the 15 s stale time (`preferences/index.ts:65-66`, review finding F10).
            prefs = cached
            if preferences.isStale, preferencesRefresh == nil {
                preferencesRefresh = Task { await self.refreshPreferences() }
            }
        } else {
            do {
                prefs = try await preferences.load()
            } catch where RequestFailure.isCancellation(error) {
                return
            } catch {
                // RN enables the thread query only after preferences load (`usePostThread/index.ts:74`)
                // and shows its placeholder data meanwhile: the cached anchor and reply skeletons
                // (`index.ts:141-151`). A failed load sends no metric (`useThreadPreferences.ts:50-70`)
                // and is not retried (`react-query.tsx:134`). The status stays `.loading`, so the
                // screen keeps the placeholder, and the next load asks again (review finding F3).
                return
            }
        }
        preferencesArrived(prefs)
        do {
            if faults?.consume(.thread) == true { throw InjectedFault() }
            let response = try await api.getPostThreadV2(
                PostThreadRequest(anchor: anchorUri, below: 10, branchingFactor: 1,
                                  sort: ThreadSort.normalize(prefs.threadSort)))
            result = ThreadTraversal.sortAndAnnotate(response.thread, userDid: userDid)
            // `hasOtherReplies` stays true once any response set it (`index.ts:111-120`).
            hasOtherReplies = hasOtherReplies || response.hasOtherReplies
            status = .loaded
            if let anchor { reportAnchorView(anchor) }
        } catch where RequestFailure.isCancellation(error) {
            return
        } catch {
            status = Self.failure(for: error)
        }
    }

    /// `thread:preferences:load` (`useThreadPreferences.ts:50-71`). RN starts `prevServerPrefs` as
    /// the preferences cached when the screen mounts and sends the metric, once, only when server
    /// preferences arrive or change after that. Preferences already cached on appear (Home loaded
    /// them) send nothing; a failed load sends nothing.
    private func preferencesArrived(_ prefs: ActorPreferences) {
        let threadPrefs = prefs.threadViewPreferences
        guard threadPrefs != threadPrefsAtAppear else { return }
        threadPrefsAtAppear = threadPrefs
        reportPreferences(prefs)
    }

    /// The stale-time refetch. Changed thread view preferences send the metric (once, as a server
    /// update does in RN). A changed sort is a new RN query key, so the thread loads again.
    private func refreshPreferences() async {
        let before = threadPrefsAtAppear
        guard let fresh = try? await preferences.refetch() else { return }
        preferencesArrived(fresh)
        guard status == .loaded, ThreadSort.normalize(fresh.threadSort) != ThreadSort.normalize(before?.sort) else {
            return
        }
        status = .loading
        await loadIfNeeded()
    }

    /// The metric with the merged server values: `sort` raw with the `hotness` default, `view` from
    /// `lab_treeViewEnabled` (`useThreadPreferences.ts:65-70`).
    private func reportPreferences(_ prefs: ActorPreferences) {
        guard !reportedPreferences else { return }
        reportedPreferences = true
        analytics.metric("thread:preferences:load", [
            "sort": .string(prefs.threadSort ?? "hotness"),
            "view": .string(prefs.threadTreeViewEnabled ? "tree" : "linear"),
        ])
    }

    /// `ThreadError.tsx:26-38`: only errors whose message starts with "Post not found" get the
    /// not-found copy; everything else is generic.
    static func failure(for error: any Error) -> Status {
        if case XRPCError.http(_, _, let message?) = error, message.hasPrefix("Post not found") {
            return .failed(title: "Post not found", message: ErrorText.clean(error))
        }
        return .failed(title: "Error loading post", message: "Something went wrong. Please try again in a moment.")
    }

    /// "Show more replies" (`ThreadItemShowOtherReplies.tsx`, `index.ts:187-240`).
    func showOtherReplies() async {
        analytics.metric("thread:click:showOtherReplies")
        otherItemsVisible = true
        guard hasOtherReplies else { return }
        isLoadingOther = true
        defer { isLoadingOther = false }
        do {
            let response = try await api.getPostThreadOtherV2(anchor: anchorUri)
            serverOtherItems = ThreadTraversal.sortAndAnnotate(response.thread, userDid: userDid,
                                                               skipModeration: true).items
        } catch {
            // RN shows nothing when this request fails.
            serverOtherItems = []
        }
    }

    /// Anchor `post:view` (`PostThread/index.tsx:96-112`), once per anchor URI.
    private func reportAnchorView(_ anchor: PostView) {
        guard reportedAnchorUri != anchor.uri else { return }
        reportedAnchorUri = anchor.uri
        var props: [String: EventValue] = [
            "uri": .string(anchor.uri), "authorDid": .string(anchor.author.did),
            "isReply": .bool(anchor.record.reply != nil), "logContext": "Post",
        ]
        if let feedDescriptor { props["feedDescriptor"] = .string(feedDescriptor) }
        analytics.metric("post:view", props)
    }

    /// A row was laid out on screen (`List.onItemSeen`, review finding N6).
    func itemAppeared(_ item: ThreadListItem) {
        guard let index = itemIndex[item.id] else { return }
        tracker?.appeared(item.id, index: index)
    }

    func itemDisappeared(_ item: ThreadListItem) {
        tracker?.disappeared(item.id)
    }

    private func reportViewable(_ ids: [String]) {
        for id in ids {
            guard let index = itemIndex[id], items.indices.contains(index) else { continue }
            recordView(of: items[index])
        }
    }

    /// Non-anchor `post:view` (`index.tsx:595-600`, `usePostViewTracking.ts:21-29`), once per URI.
    func recordView(of item: ThreadListItem) {
        guard case .post(let uri, let depth, let value, _, _) = item, depth != 0,
              viewedPosts.insert(uri).inserted else { return }
        analytics.metric("post:view", [
            "uri": .string(uri), "authorDid": .string(value.post.author.did),
            "isReply": .bool(value.post.record.reply != nil), "logContext": "PostThreadItem",
        ])
    }

    private func rebuildItems() {
        items = computeItems()
        // Rebuilt with the list, so every row event is a dictionary lookup (review finding A70).
        // A duplicate id keeps the last position rather than trapping.
        itemIndex = items.enumerated().reduce(into: [:]) { map, pair in map[pair.element.id] = pair.offset }
    }

    private func computeItems() -> [ThreadListItem] {
        switch status {
        case .loading:
            if let placeholder {
                let anchor = ThreadListItem.post(uri: placeholder.uri, depth: 0,
                                                 value: ThreadItemValue.Post(post: placeholder), isBlurred: false,
                                                 ui: ThreadPostUI(isAnchor: true))
                return [anchor] + (0..<(placeholder.replyCount ?? 4)).map { ThreadListItem.replySkeleton(index: $0) }
            }
            return [.anchorSkeleton] + (0..<4).map { ThreadListItem.replySkeleton(index: $0) }
        case .failed:
            return []
        case .loaded:
            var list = result.items
            if !result.otherItems.isEmpty || hasOtherReplies {
                if otherItemsVisible {
                    list += result.otherItems
                    list += isLoadingOther ? [.replySkeleton(index: 1000), .replySkeleton(index: 1001)] : serverOtherItems
                } else {
                    list.append(.showOtherReplies)
                }
            }
            return list
        }
    }
}

extension ThreadModel: RouteScopedModel {
    /// Stops the load, the stale-preferences refetch and the pending `post:view` reports when the
    /// thread's route leaves the stack (review finding A83).
    func cancel() {
        loadTask?.cancel()
        loadTask = nil
        preferencesRefresh?.cancel()
        preferencesRefresh = nil
        tracker?.cancel()
    }
}
