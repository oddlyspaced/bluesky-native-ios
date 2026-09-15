import Foundation
import Testing
@testable import NativeShowcase

@MainActor
@Suite("Optimistic like and repost")
struct InteractionTests {
    let api = FakeBlueskyAPI()
    let shadows = PostShadowStore()
    let analytics = RecordingAnalytics()

    private func makeInteractions(followers: Int? = 2) -> PostInteractions {
        PostInteractions(api: api, shadows: shadows, analytics: analytics, ownFollowersCount: { followers })
    }

    @Test func likeIsOptimisticThenStoresRecordURI() async {
        let post = Make.post("p1", likes: 3)
        let task = makeInteractions().toggleLike(post)
        let optimistic = shadows.apply(to: post)
        #expect(optimistic.viewer?.like == PostShadowStore.pendingURI)
        #expect(optimistic.likeCount == 4)

        await task.value
        let settled = shadows.apply(to: post)
        #expect(settled.viewer?.like == "at://did:plc:alice/app.bsky.feed.like/like1")
        #expect(settled.likeCount == 4)
        #expect(await api.calls == ["like(\(post.uri))"])
    }

    @Test func failedLikeRollsBackToServerState() async {
        await api.setFailNextCall(true)
        let post = Make.post("p1", likes: 3)
        await makeInteractions().toggleLike(post).value
        let settled = shadows.apply(to: post)
        #expect(settled.viewer?.like == nil)
        #expect(settled.likeCount == 3)
    }

    @Test func failedUnlikeKeepsTheServerLike() async {
        await api.setFailNextCall(true)
        let likeUri = "at://did:plc:alice/app.bsky.feed.like/existing"
        let post = Make.post("p1", likes: 1, like: likeUri)
        await makeInteractions().toggleLike(post).value
        #expect(shadows.apply(to: post).viewer?.like == likeUri)
        #expect(shadows.apply(to: post).likeCount == 1)
    }

    @Test func likeThenUnlikeWhileRunningCompensates() async {
        let post = Make.post("p1", likes: 0)
        let controller = makeInteractions()
        let first = controller.toggleLike(post)
        let second = controller.toggleLike(post)
        await first.value
        await second.value
        let settled = shadows.apply(to: post)
        #expect(settled.viewer?.like == nil)
        #expect(settled.likeCount == 0)
        #expect(await api.calls == ["like(\(post.uri))", "deleteLike(at://did:plc:alice/app.bsky.feed.like/like1)"])
    }

    @Test func likeUnlikeLikeCollapsesQueuedToggles() async {
        let post = Make.post("p1", likes: 0)
        let controller = makeInteractions()
        let first = controller.toggleLike(post)
        _ = controller.toggleLike(post)
        let third = controller.toggleLike(post)
        await first.value
        await third.value
        // The queued unlike is replaced by the like, which equals the running toggle, so it is skipped.
        #expect(await api.calls == ["like(\(post.uri))"])
        #expect(shadows.apply(to: post).viewer?.like == "at://did:plc:alice/app.bsky.feed.like/like1")
    }

    @Test func repostAndUndoCarryVia() async {
        let post = Make.post("p1", reposts: 2)
        let via = StrongRef(uri: "at://did:plc:carla/app.bsky.feed.repost/r", cid: "c")
        let controller = makeInteractions()
        await controller.toggleRepost(post, via: via).value
        #expect(shadows.apply(to: post).repostCount == 3)
        await controller.toggleRepost(post, via: via).value
        #expect(shadows.apply(to: post).viewer?.repost == nil)
        #expect(shadows.apply(to: post).repostCount == 2)
        #expect(await api.calls == ["repost(\(post.uri))", "deleteRepost(at://did:plc:alice/app.bsky.feed.repost/repost1)"])
        #expect(await api.vias == [via])
    }

    @Test func failedRepostRollsBack() async {
        await api.setFailNextCall(true)
        let post = Make.post("p1", reposts: 2)
        await makeInteractions().toggleRepost(post).value
        #expect(shadows.apply(to: post).viewer?.repost == nil)
        #expect(shadows.apply(to: post).repostCount == 2)
    }

    @Test func freshServerStateWinsOverASettledShadow() async {
        let post = Make.post("p1", likes: 0)
        await makeInteractions().toggleLike(post).value
        #expect(shadows.apply(to: post).likeCount == 1)
        // A refresh returns the server's view, in which someone else also unliked.
        let fresh = Make.post("p1", likes: 5, like: nil)
        #expect(shadows.apply(to: fresh).likeCount == 5)
        #expect(shadows.apply(to: fresh).viewer?.like == nil)
    }

    @Test func pendingRequestKeepsShadowOnFreshData() {
        let post = Make.post("p1", likes: 0)
        _ = makeInteractions().toggleLike(post)
        let fresh = Make.post("p1", likes: 7)
        #expect(shadows.apply(to: fresh).viewer?.like == PostShadowStore.pendingURI)
        #expect(shadows.apply(to: fresh).likeCount == 8)
    }

    @Test func likeEventsMatchRN() async {
        let post = Make.post("p1", likes: 2, reposts: 1, replies: 1)
        let controller = makeInteractions(followers: 20)
        let context = PostEventContext.feedItem("following")
        await controller.toggleLike(post, context: context).value
        await controller.toggleLike(post, context: context).value
        let likes = analytics.events(named: "post:like")
        #expect(likes.count == 1)
        #expect(likes.first?.props == [
            "uri": .string(post.uri), "authorDid": "did:plc:bob", "logContext": "FeedItem",
            "feedDescriptor": "following", "doesPosterFollowLiker": false, "doesLikerFollowPoster": true,
            "likerClout": 3, "postClout": 1,
        ])
        #expect(analytics.events(named: "post:unlike").first?.props == [
            "uri": .string(post.uri), "authorDid": "did:plc:bob", "logContext": "FeedItem", "feedDescriptor": "following",
        ])
    }

    @Test func toClout() {
        #expect(PostInteractions.toClout(nil) == nil)
        #expect(PostInteractions.toClout(0) == 0)
        #expect(PostInteractions.toClout(1) == 0)
        #expect(PostInteractions.toClout(3) == 1)
        #expect(PostInteractions.toClout(1000) == 7)
    }

    @Test func shadowCountsNeverGoNegative() {
        let post = Make.post("p1", likes: 0, like: "at://x/app.bsky.feed.like/1")
        shadows.setLike(nil, for: post)
        #expect(shadows.apply(to: post).likeCount == 0)
    }

    @Test func countWheelRollRules() {
        #expect(CountWheel.shouldRoll(count: 0, isOn: false))
        #expect(!CountWheel.shouldRoll(count: 1, isOn: true))
        #expect(CountWheel.shouldRoll(count: 2, isOn: true))
        #expect(CountWheel.shouldRoll(count: 1000, isOn: true))
        #expect(!CountWheel.shouldRoll(count: 1001, isOn: true))
        #expect(CountWheel.shouldRoll(count: 1099, isOn: false))
    }
}
