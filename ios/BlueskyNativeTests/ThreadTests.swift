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

    @Test func statsRowRule() {
        var post = Make.post("p")
        #expect(!ThreadAnchorView.showsStats(post))
        post.likeCount = 1
        #expect(ThreadAnchorView.showsStats(post))
        post.likeCount = nil
        #expect(ThreadAnchorView.showsStats(post))
    }
}
