import Foundation
import Testing
@testable import BlueskyNative

@MainActor
@Suite("Optimistic like and repost")
struct InteractionTests {
    let api = FakeBlueskyAPI()
    let shadows = PostShadowStore()

    private var interactions: PostInteractions { PostInteractions(api: api, shadows: shadows) }

    @Test func likeIsOptimisticThenStoresRecordURI() async {
        let post = Make.post("p1", likes: 3)
        let controller = interactions
        let task = controller.toggleLike(post)

        // Before the network call finishes the UI already shows the like.
        let optimistic = shadows.apply(to: post)
        #expect(optimistic.viewer?.like == PostShadowStore.pendingURI)
        #expect(optimistic.likeCount == 4)

        await task.value
        let settled = shadows.apply(to: post)
        #expect(settled.viewer?.like == "at://did:plc:alice/app.bsky.feed.like/like1")
        #expect(settled.likeCount == 4)
        #expect(await api.calls == ["like(\(post.uri))"])
    }

    @Test func failedLikeRollsBack() async {
        await api.setFailNextCall(true)
        let post = Make.post("p1", likes: 3)
        await interactions.toggleLike(post).value
        let settled = shadows.apply(to: post)
        #expect(settled.viewer?.like == nil)
        #expect(settled.likeCount == 3)
    }

    @Test func unlikeDeletesServerLike() async {
        let likeUri = "at://did:plc:alice/app.bsky.feed.like/existing"
        let post = Make.post("p1", likes: 1, like: likeUri)
        let controller = interactions
        let task = controller.toggleLike(post)
        #expect(shadows.apply(to: post).likeCount == 0)
        #expect(shadows.apply(to: post).viewer?.like == nil)
        await task.value
        #expect(await api.calls == ["deleteLike(\(likeUri))"])
    }

    @Test func failedUnlikeRestoresLike() async {
        await api.setFailNextCall(true)
        let likeUri = "at://did:plc:alice/app.bsky.feed.like/existing"
        let post = Make.post("p1", likes: 1, like: likeUri)
        await interactions.toggleLike(post).value
        #expect(shadows.apply(to: post).viewer?.like == likeUri)
        #expect(shadows.apply(to: post).likeCount == 1)
    }

    @Test func likeThenUnlikeQuicklyEndsUnliked() async {
        let post = Make.post("p1", likes: 0)
        let controller = interactions
        let first = controller.toggleLike(post)
        let second = controller.toggleLike(post)
        await first.value
        await second.value
        let settled = shadows.apply(to: post)
        #expect(settled.viewer?.like == nil)
        #expect(settled.likeCount == 0)
        // The created like is removed again so the server matches the UI.
        #expect(await api.calls == ["like(\(post.uri))", "deleteLike(at://did:plc:alice/app.bsky.feed.like/like1)"])
    }

    @Test func repostAndUndo() async {
        let post = Make.post("p1", reposts: 2)
        let controller = interactions
        await controller.toggleRepost(post).value
        #expect(shadows.apply(to: post).viewer?.repost == "at://did:plc:alice/app.bsky.feed.repost/repost1")
        #expect(shadows.apply(to: post).repostCount == 3)

        await controller.toggleRepost(post).value
        #expect(shadows.apply(to: post).viewer?.repost == nil)
        #expect(shadows.apply(to: post).repostCount == 2)
        #expect(await api.calls == ["repost(\(post.uri))",
                                    "deleteRepost(at://did:plc:alice/app.bsky.feed.repost/repost1)"])
    }

    @Test func shadowCountsNeverGoNegative() {
        let post = Make.post("p1", likes: 0, like: "at://x/app.bsky.feed.like/1")
        shadows.setLike(nil, for: post.uri)
        #expect(shadows.apply(to: post).likeCount == 0)
    }
}
