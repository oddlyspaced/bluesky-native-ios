import Foundation
import Testing
@testable import BlueskyNative

@MainActor
@Suite("Feed, thread and profile view models")
struct ViewModelTests {
    @Test func tunerGroupsReplyWithParentAndDedupesRoot() throws {
        let page = try Fixtures.decode(FeedPage.self, "getTimeline")
        var tuner = FeedTuner()
        let slices = tuner.tune(page.feed)
        // Same order the RN app renders: root + reply, then the three standalone posts.
        #expect(slices.count == 4)
        #expect(slices[0].items.map(\.post.record.text) == ["Thread root", "Thread reply"])
        #expect(slices.dropFirst().map { $0.items.count } == [1, 1, 1])

        let rows = FeedRow.rows(for: slices, firstRowHidesBorder: false)
        #expect(rows.count == 5)
        #expect(rows[0].isThreadParent && !rows[0].isThreadChild)
        #expect(rows[1].isThreadChild && rows[1].isThreadLastChild)
        #expect(!rows[2].isThreadParent && !rows[2].isThreadChild)
        #expect(rows.allSatisfy { !$0.hideTopBorder })
    }

    @Test func tunerDropsSlicesSeenOnEarlierPages() throws {
        let page = try Fixtures.decode(FeedPage.self, "getTimeline")
        var tuner = FeedTuner()
        _ = tuner.tune(page.feed)
        #expect(tuner.tune(page.feed).isEmpty)
    }

    @Test func followingFeedLoadsPagesThenShowsFallbackMarker() async throws {
        let api = FakeBlueskyAPI()
        let page = try Fixtures.decode(FeedPage.self, "getTimeline")
        await api.setTimeline(FeedPage(feed: page.feed, cursor: "next"))
        await api.setTimeline(FeedPage(feed: [], cursor: nil), cursor: "next")
        let model = FeedModel(source: .following(api))

        #expect(model.status == .idle)
        await model.loadIfNeeded()
        #expect(model.status == .loaded)
        #expect(model.slices.count == 4)
        #expect(model.hasMore)
        #expect(!model.showsFallbackMarker)

        await model.loadMore()
        #expect(!model.hasMore)
        #expect(model.showsFallbackMarker)
        #expect(await api.calls == ["getTimeline(nil)", "getTimeline(next)"])
    }

    @Test func feedErrorStateAndRetry() async throws {
        let api = FakeBlueskyAPI()
        await api.setFailNextCall(true)
        let model = FeedModel(source: .following(api))
        await model.loadIfNeeded()
        guard case .failed = model.status else {
            Issue.record("expected failed, got \(model.status)")
            return
        }
        let page = try Fixtures.decode(FeedPage.self, "getTimeline")
        await api.setTimeline(FeedPage(feed: page.feed, cursor: nil))
        await model.refresh()
        #expect(model.status == .loaded)
        #expect(model.showsFallbackMarker)
    }

    @Test func refreshKeepsRowsWhenItFails() async throws {
        let api = FakeBlueskyAPI()
        let page = try Fixtures.decode(FeedPage.self, "getTimeline")
        await api.setTimeline(page)
        let model = FeedModel(source: .following(api))
        await model.loadIfNeeded()
        await api.setFailNextCall(true)
        await model.refresh()
        #expect(model.status == .loaded)
        #expect(model.slices.count == 4)
    }

    @Test func authorFeedUsesPostsAndAuthorThreads() async throws {
        let api = FakeBlueskyAPI(accountDid: "did:plc:alice")
        await api.setAuthorFeed(try Fixtures.decode(FeedPage.self, "getAuthorFeed"))
        let model = ProfileModel(api: api, actor: "did:plc:alice")
        await model.posts.loadIfNeeded()
        #expect(model.posts.slices.count == 1)
        #expect(!model.posts.showsFallbackMarker)
        #expect(await api.calls == ["getAuthorFeed(did:plc:alice,posts_and_author_threads)"])
        let rows = FeedRow.rows(for: model.posts.slices, firstRowHidesBorder: true)
        #expect(rows.first?.hideTopBorder == true)
    }

    @Test func profileLoadsAndLabelsPluralise() async throws {
        let api = FakeBlueskyAPI()
        await api.setProfile(try Fixtures.decode(ProfileViewDetailed.self, "getProfile"))
        let model = ProfileModel(api: api, actor: "did:plc:alice")
        await model.loadProfile()
        #expect(model.status == .loaded)
        #expect(model.profile?.handle == "alice.test")
        #expect(ProfileModel.metricLabel(1, one: "post", other: "posts") == "post")
        #expect(ProfileModel.metricLabel(2, one: "follower", other: "followers") == "followers")
    }

    @Test func threadFlattensAnchorAndReplies() async throws {
        let api = FakeBlueskyAPI()
        await api.setThread(try Fixtures.decode(PostThreadResponse.self, "getPostThread").thread)
        let model = ThreadModel(api: api, uri: "at://root")
        await model.load()
        #expect(model.status == .loaded)
        #expect(model.rows.map(\.kind) == [.anchor, .reply])
        #expect(model.rows.map(\.post.record.text) == ["Thread root", "Thread reply"])
        #expect(model.anchor?.author.handle == "bob.test")
        #expect(model.rows.allSatisfy { !$0.showsParentLine && !$0.showsChildLine })
    }

    @Test func threadWithAncestorsAndReplyChain() {
        let root = Make.post("root", by: "bob")
        let middle = Make.post("middle", by: "carla")
        let anchor = Make.post("anchor", by: "alice")
        let reply = Make.post("reply", by: "bob")
        let nested = Make.post("nested", by: "carla")
        let node = ThreadNode.post(
            anchor,
            parent: .post(middle, parent: .post(root, parent: nil, replies: []), replies: []),
            replies: [.post(reply, parent: nil, replies: [.post(nested, parent: nil, replies: [])])]
        )
        let rows = ThreadModel.flatten(node)
        #expect(rows.map(\.post.uri) == [root, middle, anchor, reply, nested].map(\.uri))
        #expect(rows.map(\.kind) == [.parent, .parent, .anchor, .reply, .reply])
        #expect(rows.map(\.showsParentLine) == [false, true, true, false, true])
        #expect(rows.map(\.showsChildLine) == [true, true, false, true, false])
    }

    @Test func threadNotFound() async {
        let model = ThreadModel(api: FakeBlueskyAPI(), uri: "at://missing")
        await model.load()
        #expect(model.status == .notFound)
    }

    @Test func unreadCountMatchesRN() async {
        let api = FakeBlueskyAPI()
        let author = Make.author("carla")
        await api.setNotifications([
            NotificationView(uri: "at://1", reason: "follow", isRead: false, indexedAt: "", author: author),
            NotificationView(uri: "at://2", reason: "follow", isRead: true, indexedAt: "", author: author),
        ])
        let model = UnreadNotificationsModel(api: api)
        await model.load()
        #expect(model.count == 1)
        #expect(model.displayText == "1")
        let many = (0..<31).map {
            NotificationView(uri: "at://\($0)", reason: "like", isRead: false, indexedAt: "", author: author)
        }
        #expect(UnreadNotificationsModel.countUnread(many) == 31)
    }
}

extension FakeBlueskyAPI {
    func setProfile(_ value: ProfileViewDetailed) { profile = value }
    func setNotifications(_ value: [NotificationView]) { notifications = value }
}
