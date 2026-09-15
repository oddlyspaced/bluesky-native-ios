import Foundation
import Testing
@testable import NativeShowcase

@MainActor
@Suite("Feed tuner")
struct FeedTunerTests {
    private func feedItem(_ post: PostView, reply: FeedViewPost.Reply? = nil,
                          reason: FeedViewPost.Reason? = nil) -> FeedViewPost {
        FeedViewPost(post: post, reply: reply, reason: reason)
    }

    @Test func groupsReplyWithParentAndDedupesRoot() throws {
        let page = try Fixtures.decode(FeedPage.self, "getTimeline")
        var tuner = FeedTuner(tuners: FeedTuner.following(userDid: "did:plc:alice", preferences: HomeFeedPreferences()))
        let slices = tuner.tune(page.feed)
        #expect(slices.count == 4)
        #expect(slices[0].items.map(\.post.record.text) == ["Thread root", "Thread reply"])
        #expect(slices.dropFirst().map { $0.items.count } == [1, 1, 1])

        let rows = FeedRow.rows(for: slices, firstRowHidesBorder: false)
        #expect(rows.count == 5)
        #expect(rows[0].isThreadParent && !rows[0].isThreadChild)
        #expect(rows[1].isThreadChild && rows[1].isThreadLastChild && rows[1].isFeedPost)
        #expect(rows.filter(\.isFeedPost).map(\.position) == [0, 1, 2, 3])
        #expect(rows.allSatisfy { !$0.hideTopBorder })
    }

    @Test func dropsSlicesSeenOnEarlierPages() throws {
        let page = try Fixtures.decode(FeedPage.self, "getTimeline")
        var tuner = FeedTuner()
        _ = tuner.tune(page.feed)
        #expect(tuner.tune(page.feed).isEmpty)
    }

    @Test func orphansAreRemoved() {
        let root = Make.post("root")
        let orphan = Make.post("orphan", by: "carla", reply: Make.replyRef(root: root, parent: root))
        var tuner = FeedTuner(tuners: [.removeOrphans])
        #expect(tuner.tune([feedItem(orphan)]).isEmpty)
    }

    @Test func followedRepliesOnly() {
        let root = Make.post("root", by: "stranger", following: false)
        let reply = Make.post("reply", by: "bob", reply: Make.replyRef(root: root, parent: root))
        let item = feedItem(reply, reply: FeedViewPost.Reply(root: .post(root), parent: .post(root)))
        var tuner = FeedTuner(tuners: [.followedRepliesOnly(userDid: "did:plc:alice")])
        #expect(tuner.tune([item]).isEmpty)

        let followedRoot = Make.post("root2", by: "carla")
        let followedReply = Make.post("reply2", by: "bob", reply: Make.replyRef(root: followedRoot, parent: followedRoot))
        var tuner2 = FeedTuner(tuners: [.followedRepliesOnly(userDid: "did:plc:alice")])
        #expect(tuner2.tune([feedItem(followedReply, reply: FeedViewPost.Reply(root: .post(followedRoot),
                                                                               parent: .post(followedRoot)))]).count == 1)
    }

    @Test func preferencesAddTuners() {
        let prefs = HomeFeedPreferences(hideReplies: true, hideReposts: true, hideQuotePosts: true)
        #expect(FeedTuner.following(userDid: "d", preferences: prefs) == [
            .removeOrphans, .removeReposts, .removeReplies, .removeQuotePosts, .dedupThreads, .removeMutedThreads,
        ])
        let post = Make.post("p")
        let repost = feedItem(post, reason: .repost(by: Make.author("carla"), uri: "at://r", cid: "c", indexedAt: "x"))
        var tuner = FeedTuner(tuners: [.removeReposts])
        #expect(tuner.tune([repost]).isEmpty)
    }

    @Test func mutedThreadsAreRemoved() {
        var post = Make.post("p")
        post.viewer?.threadMuted = true
        var tuner = FeedTuner(tuners: [.removeMutedThreads])
        #expect(tuner.tune([feedItem(post)]).isEmpty)
    }

    @Test func blockedParentMarksReplyRow() {
        let root = Make.post("root")
        let reply = Make.post("reply", reply: Make.replyRef(root: root, parent: root))
        let slice = FeedSlice(feedItem(reply, reply: FeedViewPost.Reply(root: .blocked(uri: root.uri),
                                                                        parent: .blocked(uri: root.uri))))
        #expect(slice.items.first?.isParentBlocked == true)
        #expect(slice.isOrphan)
    }
}

@MainActor
@Suite("Feed model")
struct FeedModelTests {
    let analytics = RecordingAnalytics()

    private func model(_ api: FakeBlueskyAPI, source: FeedModel.Source = .following,
                       faults: DebugFaults? = nil) -> FeedModel {
        FeedModel(source: source, api: api, preferences: PreferencesModel(api: api), analytics: analytics,
                  faults: faults, userDid: "did:plc:alice")
    }

    @Test func autoPaginatesThenShowsFallbackMarker() async throws {
        let api = FakeBlueskyAPI()
        let page = try Fixtures.decode(FeedPage.self, "getTimeline")
        await api.setTimeline(FeedPage(feed: page.feed, cursor: "next"))
        await api.setTimeline(FeedPage(feed: [], cursor: nil), cursor: "next")
        let feed = model(api)
        #expect(feed.status == .idle)
        await feed.loadIfNeeded()
        #expect(feed.status == .loaded)
        #expect(feed.slices.count == 4)
        #expect(!feed.hasMore)
        #expect(feed.showsFallbackMarker)
        #expect(await api.calls == ["getPreferences", "getTimeline(nil)", "getTimeline(next)"])
    }

    @Test func firstLoadErrorShowsCleanedMessageAndRetries() async throws {
        let api = FakeBlueskyAPI()
        let faults = DebugFaults()
        faults.arm(.feedFirstPage)
        let feed = model(api, faults: faults)
        await feed.loadIfNeeded()
        #expect(feed.status == .failed("Unable to connect. Please check your internet connection and try again."))
        let page = try Fixtures.decode(FeedPage.self, "getTimeline")
        await api.setTimeline(FeedPage(feed: page.feed, cursor: nil))
        await feed.reload()
        #expect(feed.status == .loaded)
    }

    @Test func loadMoreFailureKeepsPagingAndOffersRetry() async throws {
        let api = FakeBlueskyAPI()
        let page = try Fixtures.decode(FeedPage.self, "getTimeline")
        var many = page.feed
        // 30 posts on page one stop auto-pagination, so loadMore is needed.
        while many.count < 30 { many += page.feed.map { item in
            var copy = item
            copy.post.uri += "-\(many.count)"
            return copy
        } }
        await api.setTimeline(FeedPage(feed: many, cursor: "next"))
        await api.setTimeline(FeedPage(feed: [], cursor: nil), cursor: "next")
        let faults = DebugFaults()
        let feed = model(api, faults: faults)
        await feed.loadIfNeeded()
        #expect(feed.hasMore)

        faults.arm(.feedNextPage)
        feed.loadMore()
        while feed.isLoadingMore { await Task.yield() }
        #expect(feed.loadMoreError != nil)
        #expect(feed.hasMore)
        #expect(analytics.events(named: "feed:endReached").count == 1)

        await feed.retryAfterError()
        #expect(feed.loadMoreError == nil)
        #expect(!feed.hasMore)
        #expect(feed.showsFallbackMarker)
    }

    @Test func refreshFailureWithRowsShowsRetryRow() async throws {
        let api = FakeBlueskyAPI()
        let page = try Fixtures.decode(FeedPage.self, "getTimeline")
        await api.setTimeline(FeedPage(feed: page.feed, cursor: nil))
        let feed = model(api)
        await feed.loadIfNeeded()
        await api.setFailingPrefix("getTimeline")
        await feed.pullToRefresh()
        #expect(feed.status == .loaded)
        #expect(feed.slices.count == 4)
        #expect(feed.loadMoreError != nil)
        #expect(analytics.events(named: "feed:refresh").first?.props == [
            "feedType": "following", "feedUrl": "following", "reason": "pull-to-refresh",
        ])
    }

    @Test func refreshFaultWaitsForRowsThenShowsRetryRow() async throws {
        let api = FakeBlueskyAPI()
        let page = try Fixtures.decode(FeedPage.self, "getTimeline")
        await api.setTimeline(FeedPage(feed: page.feed, cursor: nil))
        let faults = DebugFaults()
        faults.arm(.feedFirstPage)
        faults.arm(.feedRefresh)
        let feed = model(api, faults: faults)
        await feed.loadIfNeeded()
        #expect(feed.status == .failed("Unable to connect. Please check your internet connection and try again."))
        // The retry has no rows yet, so the refresh fault stays armed.
        await feed.reload()
        #expect(feed.status == .loaded)
        #expect(feed.loadMoreError == nil)
        await feed.reload()
        #expect(feed.slices.count == 4)
        #expect(feed.loadMoreError != nil)
    }

    @Test func staleResultAfterNewerReloadIsDropped() async throws {
        let api = FakeBlueskyAPI()
        let page = try Fixtures.decode(FeedPage.self, "getTimeline")
        await api.setTimeline(FeedPage(feed: page.feed, cursor: nil))
        let feed = model(api)
        await feed.loadIfNeeded()
        await api.holdTimeline()
        let slow = Task { await feed.reload() }
        while await api.calls.filter({ $0 == "getTimeline(nil)" }).count < 2 { await Task.yield() }
        await api.setTimeline(FeedPage(feed: [], cursor: nil))
        await api.resumeTimeline()
        await feed.reload()
        await slow.value
        #expect(feed.slices.isEmpty)
    }

    @Test func emptyFollowingStillShowsFallbackAndEnd() async {
        let api = FakeBlueskyAPI()
        let feed = model(api)
        await feed.loadIfNeeded()
        #expect(feed.showsFallbackMarker)
        #expect(!feed.isEmpty)
        #expect(!feed.hasMore)
    }

    @Test func authorFeedUsesPostsAndAuthorThreads() async throws {
        let api = FakeBlueskyAPI(accountDid: "did:plc:alice")
        await api.setAuthorFeed(try Fixtures.decode(FeedPage.self, "getAuthorFeed"))
        let feed = model(api, source: .author(actor: "did:plc:alice", filter: .postsAndAuthorThreads))
        await feed.loadIfNeeded()
        #expect(feed.slices.count == 1)
        #expect(!feed.showsFallbackMarker)
        #expect(feed.feedDescriptor == "author|did:plc:alice|posts_and_author_threads")
        #expect(feed.rows.first?.hideTopBorder == true)
    }

    /// Review finding A54: a failed preferences load is not kept; the next load asks again and
    /// keeps the server value.
    @Test func failedPreferencesAreNotCached() async throws {
        let api = FakeBlueskyAPI()
        await api.setFailingPrefix("getPreferences", error: URLError(.timedOut))
        let prefs = PreferencesModel(api: api)
        await #expect(throws: URLError.self) { _ = try await prefs.load() }
        #expect(prefs.preferences == nil)
        #expect(try await prefs.loadOrDefaults() == ActorPreferences())

        await api.setFailingPrefix(nil)
        await api.setPreferences(ActorPreferences(homeFeed: HomeFeedPreferences(hideReplies: true)))
        #expect(try await prefs.load().homeFeed.hideReplies)
        _ = try await prefs.load()
        #expect(await api.calls.filter { $0 == "getPreferences" }.count == 3)
    }

    /// Review finding N6: the first screen of feed rows is reported in position order.
    @Test func feedViewsFollowIndexOrder() async throws {
        let gate = Gate()
        let api = FakeBlueskyAPI()
        let page = try Fixtures.decode(FeedPage.self, "getTimeline")
        await api.setTimeline(FeedPage(feed: page.feed, cursor: nil))
        let feed = FeedModel(source: .following, api: api, preferences: PreferencesModel(api: api), analytics: analytics,
                             userDid: "did:plc:alice", viewWaiter: { _ in await gate.pass() })
        await feed.loadIfNeeded()
        for row in feed.rows.reversed() { feed.rowAppeared(row) }
        await gate.waitForArrivals(1)
        gate.open()
        while analytics.events(named: "post:view").count < 4 { await Task.yield() }
        #expect(analytics.events(named: "post:view").map { $0.props["position"] } == [0, 1, 2, 3])
    }

    @Test func postViewIsRecordedOncePerURI() async throws {
        let api = FakeBlueskyAPI()
        let page = try Fixtures.decode(FeedPage.self, "getTimeline")
        await api.setTimeline(FeedPage(feed: page.feed, cursor: nil))
        let feed = model(api)
        await feed.loadIfNeeded()
        feed.recordView(of: feed.rows[0])
        feed.recordView(of: feed.rows[1])
        feed.recordView(of: feed.rows[1])
        let views = analytics.events(named: "post:view")
        #expect(views.count == 1)
        #expect(views.first?.props["position"] == 0)
        #expect(views.first?.props["isReply"] == true)
        #expect(views.first?.props["feedDescriptor"] == "following")
    }
}

@MainActor
@Suite("Profile and unread")
struct ProfileAndUnreadTests {
    @Test func profileLoadsAndLabelsPluralise() async throws {
        let api = FakeBlueskyAPI()
        await api.setProfile(try Fixtures.decode(ProfileViewDetailed.self, "getProfile"))
        let prefs = PreferencesModel(api: api)
        let model = ProfileModel(api: api, actor: "did:plc:alice",
                                 posts: FeedModel(source: .author(actor: "did:plc:alice", filter: .postsAndAuthorThreads),
                                                  api: api, preferences: prefs, userDid: "did:plc:alice"))
        await model.loadProfile()
        #expect(model.status == .loaded)
        #expect(model.profile?.handle == "alice.test")
        #expect(ProfileModel.postsLabel(1) == "post")
        #expect(ProfileModel.followersLabel(2) == "followers")
        #expect(ProfileModel.followersLabel(1) == "follower")
    }

    @Test func profileErrorScreen() async {
        let api = FakeBlueskyAPI()
        let faults = DebugFaults()
        faults.arm(.profile)
        let model = ProfileModel(api: api, actor: "did:plc:alice",
                                 posts: FeedModel(source: .following, api: api, preferences: PreferencesModel(api: api),
                                                  userDid: "did:plc:alice"),
                                 faults: faults)
        await model.loadProfile()
        #expect(model.status == .failed(title: "Not Found",
                                        message: "Unable to connect. Please check your internet connection and try again."))
    }

    @Test func unreadCountAndThrottle() async {
        let api = FakeBlueskyAPI()
        let author = Make.author("carla")
        await api.setNotifications([
            NotificationView(uri: "at://1", reason: "follow", isRead: false, indexedAt: "", author: author),
            NotificationView(uri: "at://2", reason: "follow", isRead: true, indexedAt: "", author: author),
        ])
        let model = UnreadNotificationsModel(api: api, random: { 0.9 })
        await model.check(isPoll: false)
        #expect(model.count == 1)
        #expect(model.displayText == "1")
        // A poll with a non-zero count skips when random() >= 0.5.
        await model.check(isPoll: true)
        #expect(await api.calls == ["listNotifications"])
        // Inactive app: no request.
        await model.check(isPoll: false, isActive: false)
        #expect(await api.calls == ["listNotifications"])
        let many = (0..<31).map {
            NotificationView(uri: "at://\($0)", reason: "like", isRead: false, indexedAt: "", author: author)
        }
        #expect(UnreadNotificationsModel.countUnread(many) == 31)
        #expect(BottomBar.unreadHint("1") == "1 unread item")
        #expect(BottomBar.unreadHint("30+") == "30+ unread items")
        #expect(BottomBar.unreadHint("") == "")
    }

    @Test func unreadFailureIsRecorded() async {
        let api = FakeBlueskyAPI()
        await api.setFailNextCall(true)
        let model = UnreadNotificationsModel(api: api)
        await model.check(isPoll: false)
        #expect(model.lastError != nil)
    }
}
