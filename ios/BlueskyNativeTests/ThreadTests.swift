import Foundation
import Testing
@testable import NativeShowcase

@MainActor
@Suite("Thread V2")
struct ThreadTests {
    let analytics = RecordingAnalytics()

    private func model(_ api: FakeBlueskyAPI, uri: String = "at://root", faults: DebugFaults? = nil) -> ThreadModel {
        ThreadModel(api: api, anchor: uri, feedDescriptor: "following", preferences: PreferencesModel(api: api),
                    analytics: analytics, faults: faults, userDid: "did:plc:alice")
    }

    @Test func loadsCapturedThreadWithRNParameters() async throws {
        let api = FakeBlueskyAPI()
        let response = try Fixtures.decode(PostThreadV2Response.self, "getPostThreadV2")
        await api.setThread(response)
        let thread = model(api)
        await thread.loadIfNeeded()
        #expect(thread.status == .loaded)
        #expect(thread.items.compactMap(\.postValue).map(\.post.record.text) == ["Thread root", "Thread reply"])
        #expect(thread.anchor?.author.handle == "bob.test")
        #expect(await api.lastThreadRequest == PostThreadRequest(anchor: "at://root", below: 10, branchingFactor: 1,
                                                                 sort: .top))
        #expect(analytics.events(named: "thread:preferences:load").first?.props == ["sort": "hotness", "view": "linear"])
        #expect(analytics.events(named: "post:view").first?.props == [
            "uri": .string(response.thread[0].uri), "authorDid": .string(thread.anchor?.author.did ?? ""),
            "isReply": false, "logContext": "Post", "feedDescriptor": "following",
        ])
    }

    @Test func serverSortPreferenceIsNormalised() async {
        let api = FakeBlueskyAPI()
        await api.setPreferences(ActorPreferences(threadSort: "newest"))
        await model(api).loadIfNeeded()
        #expect(await api.lastThreadRequest?.sort == .newest)
        #expect(ThreadSort.normalize("hotness") == .top)
    }

    @Test func parentsRepliesAndLines() {
        let root = Make.post("root", by: "bob")
        let middle = Make.post("middle", by: "carla", reply: Make.replyRef(root: root, parent: root))
        let anchor = Make.post("anchor", by: "alice", replies: 1, reply: Make.replyRef(root: root, parent: middle))
        let reply = Make.post("reply", by: "bob", replies: 1, reply: Make.replyRef(root: root, parent: anchor))
        let nested = Make.post("nested", by: "carla", reply: Make.replyRef(root: root, parent: reply))
        let result = ThreadTraversal.sortAndAnnotate([
            Make.threadPost(root, depth: -2), Make.threadPost(middle, depth: -1), Make.threadPost(anchor, depth: 0),
            Make.threadPost(reply, depth: 1), Make.threadPost(nested, depth: 2),
        ], userDid: "did:plc:alice")
        let posts = result.items.compactMap { item -> (String, ThreadPostUI)? in
            if case .post(_, _, let value, _, let ui) = item { return (value.post.record.text, ui) }
            return nil
        }
        #expect(posts.map(\.0) == ["Post", "Post", "Post", "Post", "Post"])
        #expect(result.items.map(\.depth) == [-2, -1, 0, 1, 2])
        #expect(posts.map(\.1.showParentReplyLine) == [false, true, true, false, true])
        #expect(posts.map(\.1.showChildReplyLine) == [true, true, false, true, false])
    }

    @Test func tombstonesStopTheParentWalkAndSkipReplyBranches() {
        let anchor = Make.post("anchor", replies: 2)
        let visible = Make.post("visible", by: "carla")
        let result = ThreadTraversal.sortAndAnnotate([
            Make.threadPost(Make.post("grand"), depth: -2),
            ThreadItem(uri: "at://blocked", depth: -1, value: .blocked),
            Make.threadPost(anchor, depth: 0),
            ThreadItem(uri: "at://gone", depth: 1, value: .notFound),
            Make.threadPost(Make.post("under-gone", by: "carla"), depth: 2),
            Make.threadPost(visible, depth: 1),
        ], userDid: "did:plc:alice")
        #expect(result.items.map(\.id) == ["blocked:at://blocked", anchor.uri, visible.uri])
    }

    @Test func notFoundAnchorRendersTombstone() async {
        let api = FakeBlueskyAPI()
        let thread = model(api, uri: "at://missing")
        await thread.loadIfNeeded()
        #expect(thread.status == .loaded)
        #expect(thread.items.map(\.id) == ["notFound:at://missing"])
    }

    @Test func hiddenRepliesGoToTheOtherBucket() async {
        let api = FakeBlueskyAPI()
        let anchor = Make.post("anchor", replies: 2)
        let shown = Make.post("shown", by: "carla", reply: Make.replyRef(root: anchor, parent: anchor))
        let hidden = Make.post("hidden", by: "bob", reply: Make.replyRef(root: anchor, parent: anchor))
        await api.setThread(PostThreadV2Response(thread: [
            Make.threadPost(anchor, depth: 0), Make.threadPost(shown, depth: 1),
            Make.threadPost(hidden, depth: 1, hidden: true),
        ], hasOtherReplies: true))
        let other = Make.post("server-other", by: "carla", reply: Make.replyRef(root: anchor, parent: anchor))
        await api.setOtherReplies(PostThreadOtherV2Response(thread: [Make.threadPost(other, depth: 1)]))
        let thread = model(api)
        await thread.loadIfNeeded()
        #expect(thread.items.map(\.id) == [anchor.uri, shown.uri, "showOtherReplies"])

        await thread.showOtherReplies()
        #expect(thread.items.map(\.id) == [anchor.uri, shown.uri, hidden.uri, other.uri])
        #expect(analytics.names.contains("thread:click:showOtherReplies"))
        #expect(await api.calls.contains("getPostThreadOtherV2(at://root)"))
    }

    @Test func readMoreFollowsTheLastChild() {
        let anchor = Make.post("anchor", replies: 1)
        let reply = Make.post("reply", by: "carla", replies: 3, reply: Make.replyRef(root: anchor, parent: anchor))
        let result = ThreadTraversal.sortAndAnnotate([
            Make.threadPost(anchor, depth: 0), Make.threadPost(reply, depth: 1, moreReplies: 3),
        ], userDid: "did:plc:alice")
        #expect(result.items.map(\.id) == [anchor.uri, reply.uri, "readMore:\(reply.uri)"])
    }

    @Test func errorCopyFollowsThreadError() {
        #expect(ThreadModel.failure(for: XRPCError.http(status: 400, error: "NotFound", message: "Post not found: x"))
            == .failed(title: "Post not found", message: "Post not found: x"))
        #expect(ThreadModel.failure(for: URLError(.notConnectedToInternet))
            == .failed(title: "Error loading post", message: "Something went wrong. Please try again in a moment."))
    }

    @Test func failureThenRetry() async throws {
        let api = FakeBlueskyAPI()
        let faults = DebugFaults()
        faults.arm(.thread)
        await api.setThread(try Fixtures.decode(PostThreadV2Response.self, "getPostThreadV2"))
        let thread = model(api, faults: faults)
        await thread.loadIfNeeded()
        #expect(thread.status == .failed(title: "Error loading post",
                                         message: "Something went wrong. Please try again in a moment."))
        await thread.retry()
        #expect(thread.status == .loaded)
    }

    @Test func placeholderShowsAnchorAndReplySkeletons() {
        let api = FakeBlueskyAPI()
        let thread = model(api)
        thread.setPlaceholder(Make.post("root", replies: 2))
        #expect(thread.items.map(\.id) == [Make.uri("root"), "anchor-skeleton-reply-0", "anchor-skeleton-reply-1"])
        let empty = model(api)
        #expect(empty.items.count == 5)
    }

    /// Review finding N22: no `thread:preferences:load` and no thread request while preferences
    /// fail; the retry loads them, sends the metric once and loads the thread.
    @Test func preferencesMetricWaitsForServerPreferences() async throws {
        let api = FakeBlueskyAPI()
        await api.setThread(try Fixtures.decode(PostThreadV2Response.self, "getPostThreadV2"))
        await api.setFailingPrefix("getPreferences", error: URLError(.notConnectedToInternet))
        let thread = model(api)
        await thread.loadIfNeeded()
        #expect(analytics.events(named: "thread:preferences:load").isEmpty)
        #expect(!(await api.calls).contains { $0.hasPrefix("getPostThreadV2") })
        #expect(thread.status == .failed(title: "Error loading post",
                                         message: "Something went wrong. Please try again in a moment."))

        await api.setFailingPrefix(nil)
        await thread.retry()
        #expect(thread.status == .loaded)
        #expect(analytics.events(named: "thread:preferences:load").count == 1)
        #expect(await api.calls.filter { $0 == "getPreferences" }.count == 2)
    }

    /// Review finding N5: the logged view is the server's `lab_treeViewEnabled`; the port still
    /// renders the linear view (the tree view is proposed out of scope).
    @Test func preferencesMetricLogsTheServerView() async throws {
        let api = FakeBlueskyAPI()
        await api.setPreferences(ActorPreferences(threadSort: "newest", threadTreeViewEnabled: true))
        await model(api).loadIfNeeded()
        #expect(analytics.events(named: "thread:preferences:load").first?.props == ["sort": "newest", "view": "tree"])
        let decoded = try JSONDecoder().decode(ActorPreferences.self, from: Data(#"""
            {"preferences":[{"$type":"app.bsky.actor.defs#threadViewPref","sort":"top","lab_treeViewEnabled":true}]}
            """#.utf8))
        #expect(decoded.threadTreeViewEnabled)
        #expect(decoded.threadSort == "top")
    }

    /// Review finding N23: with a cached anchor, the anchor `post:view` fires before the network
    /// answers, and only once.
    @Test func anchorViewFiresOnThePlaceholder() async throws {
        let gate = Gate()
        let api = FakeBlueskyAPI(threadGate: gate)
        let response = try Fixtures.decode(PostThreadV2Response.self, "getPostThreadV2")
        await api.setThread(response)
        guard case .post(let anchorValue) = response.thread[0].value else {
            Issue.record("fixture anchor is not a post")
            return
        }
        let thread = model(api, uri: response.thread[0].uri)
        thread.setPlaceholder(anchorValue.post)
        let load = Task { await thread.loadIfNeeded() }
        await gate.waitForArrivals(1)
        // Preferences were not loaded yet, so RN's placeholder effect runs before the metric.
        #expect(analytics.names == ["post:view", "thread:preferences:load"])
        #expect(analytics.events(named: "post:view").map { $0.props["logContext"] } == ["Post"])
        gate.open()
        await load.value
        #expect(analytics.events(named: "post:view").count == 1)
    }

    /// Review finding N1: only the anchor's avatar logs `post:clickthroughAuthor`.
    @Test func onlyTheAnchorAvatarLogsClickthroughAuthor() {
        let post = Make.post("p")
        let context = PostEventContext.threadItem("following")
        #expect(ThreadModel.authorTapEvent(for: post, isAnchor: false, context: context) == nil)
        let event = ThreadModel.authorTapEvent(for: post, isAnchor: true, context: context)
        #expect(event?.name == "post:clickthroughAuthor")
        #expect(event?.props == ["uri": .string(post.uri), "authorDid": "did:plc:bob",
                                 "logContext": "PostThreadItem", "feedDescriptor": "following"])
    }

    /// Review finding N2: `canReply` follows the anchor's `viewer.replyDisabled`, including the
    /// placeholder, and is true while no anchor is known.
    @Test func canReplyFollowsTheAnchor() async {
        let api = FakeBlueskyAPI()
        var disabled = Make.post("root")
        disabled.viewer?.replyDisabled = true
        let thread = model(api, uri: disabled.uri)
        #expect(thread.canReply)
        thread.setPlaceholder(disabled)
        #expect(!thread.canReply)
        await api.setThread(PostThreadV2Response(thread: [Make.threadPost(disabled, depth: 0)]))
        await thread.loadIfNeeded()
        #expect(!thread.canReply)

        let open = model(api, uri: "at://open")
        await api.setThread(PostThreadV2Response(thread: [Make.threadPost(Make.post("open"), depth: 0)]))
        await open.loadIfNeeded()
        #expect(open.canReply)
    }

    /// Review finding N6: rows seen together are reported in index order, whatever order they
    /// appeared in, and a row that left before the delay is not reported.
    @Test func replyViewsFollowIndexOrder() async {
        let gate = Gate()
        let api = FakeBlueskyAPI()
        let anchor = Make.post("anchor", replies: 3)
        let replies = (0..<3).map { Make.post("r\($0)", by: "carla", reply: Make.replyRef(root: anchor, parent: anchor)) }
        await api.setThread(PostThreadV2Response(thread: [Make.threadPost(anchor, depth: 0)]
            + replies.map { Make.threadPost($0, depth: 1) }))
        let thread = ThreadModel(api: api, anchor: anchor.uri, feedDescriptor: nil, preferences: PreferencesModel(api: api),
                                 analytics: analytics, userDid: "did:plc:alice", viewWaiter: { _ in await gate.pass() })
        await thread.loadIfNeeded()
        let items = thread.items
        thread.itemAppeared(items[3])
        thread.itemAppeared(items[1])
        thread.itemAppeared(items[2])
        thread.itemAppeared(items[0])
        await gate.waitForArrivals(1)
        gate.open()
        while analytics.events(named: "post:view").count < 4 { await Task.yield() }
        #expect(analytics.events(named: "post:view").map { $0.props["uri"] } == [
            .string(anchor.uri), .string(replies[0].uri), .string(replies[1].uri), .string(replies[2].uri),
        ])
    }

    @Test func statsRowRule() {
        var post = Make.post("p")
        #expect(!ThreadAnchorView.showsStats(post))
        post.likeCount = 1
        #expect(ThreadAnchorView.showsStats(post))
        post.likeCount = nil
        #expect(ThreadAnchorView.showsStats(post))
    }
}
