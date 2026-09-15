import Foundation
import Testing
@testable import NativeShowcase

/// Decodes JSON captured with curl from the local dev PDS and AppView.
@Suite("XRPC decoding of captured responses")
struct DecodingTests {
    @Test func createSession() throws {
        let session = try Fixtures.decode(SessionResponse.self, "createSession")
        #expect(session.handle == "alice.test")
        #expect(session.did.hasPrefix("did:plc:"))
    }

    @Test func timelineHasReplyContextAndCursor() throws {
        let page = try Fixtures.decode(FeedPage.self, "getTimeline")
        #expect(page.feed.count == 5)
        #expect(page.cursor != nil)
        #expect(page.feed.map(\.post.record.text) == ["Thread reply", "Thread root", "Post", "Post", "Post"])
        let reply = try #require(page.feed.first?.reply)
        #expect(reply.parent.post?.author.handle == "bob.test")
        #expect(reply.root.post?.record.text == "Thread root")
        #expect(page.feed[1].post.indexedDate != nil)
    }

    @Test func postThreadV2() throws {
        let response = try Fixtures.decode(PostThreadV2Response.self, "getPostThreadV2")
        #expect(response.thread.map(\.depth) == [0, 1])
        #expect(!response.hasOtherReplies)
        guard case .post(let anchor) = response.thread[0].value else {
            Issue.record("expected threadItemPost")
            return
        }
        #expect(anchor.post.record.text == "Thread root")
        #expect(anchor.opThread)
    }

    @Test func threadItemUnion() throws {
        let json = Data("""
        {"thread":[{"uri":"at://a","depth":0,"value":{"$type":"app.bsky.unspecced.defs#threadItemNotFound"}},
        {"uri":"at://b","depth":1,"value":{"$type":"app.bsky.unspecced.defs#threadItemBlocked","author":{"did":"did:x"}}},
        {"uri":"at://c","depth":-1,"value":{"$type":"app.bsky.unspecced.defs#threadItemNoUnauthenticated"}}]}
        """.utf8)
        let response = try JSONDecoder().decode(PostThreadV2Response.self, from: json)
        #expect(response.thread.map(\.value) == [.notFound, .blocked, .noUnauthenticated])
    }

    @Test func preferences() throws {
        let json = Data("""
        {"preferences":[{"$type":"app.bsky.actor.defs#feedViewPref","feed":"home","hideReplies":true,"hideQuotePosts":true},
        {"$type":"app.bsky.actor.defs#threadViewPref","sort":"oldest"},{"$type":"app.bsky.actor.defs#savedFeedsPrefV2","items":[]}]}
        """.utf8)
        let prefs = try JSONDecoder().decode(ActorPreferences.self, from: json)
        #expect(prefs.homeFeed == HomeFeedPreferences(hideReplies: true, hideReposts: false, hideQuotePosts: true))
        #expect(prefs.threadSort == "oldest")
        _ = try Fixtures.decode(ActorPreferences.self, "getPreferences")
    }

    @Test func profileCounts() throws {
        let profile = try Fixtures.decode(ProfileViewDetailed.self, "getProfile")
        #expect(profile.displayName == "Alice")
        #expect(profile.followersCount == 2)
        #expect(profile.postsCount == 1)
    }

    @Test func unionMembersAndRepostReason() throws {
        let json = Data("""
        {"feed":[{"post":{"uri":"at://a/app.bsky.feed.post/1","cid":"c","author":{"did":"did:a","handle":"a.test"},
        "record":{"text":"hi @b","createdAt":"2026-01-01T00:00:00Z","facets":[{"index":{"byteStart":3,"byteEnd":5},
        "features":[{"$type":"app.bsky.richtext.facet#mention","did":"did:b"}]}]},"indexedAt":"2026-01-01T00:00:00Z",
        "embed":{"$type":"app.bsky.embed.record#view"}},
        "reason":{"$type":"app.bsky.feed.defs#reasonRepost","by":{"did":"did:b","handle":"b.test"},"uri":"at://r","cid":"rc","indexedAt":"x"},
        "reply":{"root":{"$type":"app.bsky.feed.defs#notFoundPost","uri":"at://x","notFound":true},
        "parent":{"$type":"app.bsky.feed.defs#blockedPost","uri":"at://y","blocked":true,"author":{"did":"did:c"}}}}]}
        """.utf8)
        let page = try JSONDecoder().decode(FeedPage.self, from: json)
        let item = try #require(page.feed.first)
        #expect(item.reason?.viaRepost == StrongRef(uri: "at://r", cid: "rc"))
        #expect(item.reply?.root == .notFound(uri: "at://x"))
        #expect(item.reply?.parent == .blocked(uri: "at://y"))
        #expect(item.post.record.facets?.first?.features == [.mention(did: "did:b")])
        #expect(item.post.embed?.isQuote == true)
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
