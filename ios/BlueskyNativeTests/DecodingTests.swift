import Foundation
import Testing
@testable import BlueskyNative

/// Decodes JSON captured with curl from the local dev PDS and AppView.
@Suite("XRPC decoding of captured responses")
struct DecodingTests {
    @Test func createSession() throws {
        let session = try Fixtures.decode(SessionResponse.self, "createSession")
        #expect(session.handle == "alice.test")
        #expect(session.did.hasPrefix("did:plc:"))
        #expect(!session.accessJwt.isEmpty)
    }

    @Test func timelineHasReplyContextAndCursor() throws {
        let page = try Fixtures.decode(FeedPage.self, "getTimeline")
        #expect(page.feed.count == 5)
        #expect(page.cursor != nil)
        #expect(page.feed.map(\.post.record.text) == ["Thread reply", "Thread root", "Post", "Post", "Post"])

        let reply = try #require(page.feed.first?.reply)
        #expect(reply.parent.post?.author.handle == "bob.test")
        #expect(reply.root.post?.record.text == "Thread root")
        #expect(page.feed[0].post.author.viewer?.following != nil)
        #expect(page.feed[1].post.replyCount == 1)
    }

    @Test func postThreadDecodesRecursiveReplies() throws {
        let response = try Fixtures.decode(PostThreadResponse.self, "getPostThread")
        guard case .post(let anchor, let parent, let replies) = response.thread else {
            Issue.record("expected threadViewPost")
            return
        }
        #expect(anchor.record.text == "Thread root")
        #expect(parent == nil)
        #expect(replies.count == 1)
        if case .post(let reply, _, _) = replies.first {
            #expect(reply.author.handle == "carla.test")
            #expect(reply.record.reply?.parent.uri == anchor.uri)
        } else {
            Issue.record("expected reply post")
        }
    }

    @Test func profileCounts() throws {
        let profile = try Fixtures.decode(ProfileViewDetailed.self, "getProfile")
        #expect(profile.displayName == "Alice")
        #expect(profile.description == "Test user 1")
        #expect(profile.followersCount == 2)
        #expect(profile.followsCount == 2)
        #expect(profile.postsCount == 1)
        #expect(profile.avatar == nil)
        #expect(profile.banner == nil)
    }

    @Test func authorFeed() throws {
        let page = try Fixtures.decode(FeedPage.self, "getAuthorFeed")
        #expect(page.feed.count == 1)
        #expect(page.feed.first?.post.author.handle == "alice.test")
    }

    @Test func unionMembersDecode() throws {
        let json = Data("""
        {"feed":[{"post":{"uri":"at://a/app.bsky.feed.post/1","cid":"c","author":{"did":"did:a","handle":"a.test"},
        "record":{"text":"hi","createdAt":"2026-01-01T00:00:00Z"},"indexedAt":"2026-01-01T00:00:00Z"},
        "reason":{"$type":"app.bsky.feed.defs#reasonRepost","by":{"did":"did:b","handle":"b.test"},"indexedAt":"x"},
        "reply":{"root":{"$type":"app.bsky.feed.defs#notFoundPost","uri":"at://x","notFound":true},
        "parent":{"$type":"app.bsky.feed.defs#blockedPost","uri":"at://y","blocked":true,"author":{"did":"did:c"}}}}]}
        """.utf8)
        let page = try JSONDecoder().decode(FeedPage.self, from: json)
        let item = try #require(page.feed.first)
        #expect(item.reason == .repost(by: ProfileViewBasic(did: "did:b", handle: "b.test")))
        #expect(item.reply?.root == .notFound(uri: "at://x"))
        #expect(item.reply?.parent == .blocked(uri: "at://y"))
    }

    @Test func atDateParsesFractionalAndPlain() {
        #expect(ATDate.parse("2026-09-14T19:30:21.215Z") != nil)
        #expect(ATDate.parse("2026-09-14T19:30:21Z") != nil)
        #expect(ATDate.parse("yesterday") == nil)
    }

    @Test func atURIParts() throws {
        let uri = try #require(ATURI("at://did:plc:abc/app.bsky.feed.like/3mvi"))
        #expect(uri.host == "did:plc:abc")
        #expect(uri.collection == "app.bsky.feed.like")
        #expect(uri.rkey == "3mvi")
        #expect(ATURI("https://example.com") == nil)
    }
}
