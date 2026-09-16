import Foundation
import Testing
@testable import NativeShowcase

/// Review finding F4: profile bios get facets from `detectFacets` (`@bsky/sdk`) with resolved
/// mentions, as `Profile.tsx:614-647` does.
@MainActor
@Suite("Rich text detection")
struct RichTextDetectionTests {
    private func summary(_ facets: [Facet]?) -> [String] {
        (facets ?? []).map { facet in
            let feature = facet.features.map { feature -> String in
                switch feature {
                case .mention(let did): "mention:\(did)"
                case .link(let uri): "link:\(uri)"
                case .tag(let tag): "tag:\(tag)"
                case .unknown: "unknown"
                }
            }.joined(separator: ",")
            return "\(facet.index.byteStart)-\(facet.index.byteEnd) \(feature)"
        }
    }

    /// Offsets follow the SDK: a link loses one trailing `.,;:!?` and an unmatched `)`; a tag
    /// loses trailing punctuation; a cashtag is upper-cased with a `$` prefix.
    @Test func detectsMentionsLinksTagsAndCashtags() {
        let text = "hi @bob.test see example.com/a, https://bsky.app/x) #swift! $aapl."
        #expect(summary(RichTextDetection.detect(text)) == [
            "3-12 mention:bob.test",
            "17-30 link:https://example.com/a",
            "32-50 link:https://bsky.app/x",
            "52-58 tag:swift",
            "60-65 tag:$AAPL",
        ])
    }

    @Test func rejectsUnknownDomainsAndDigitOnlyTags() {
        #expect(RichTextDetection.detect("@nohandle foo.notatld #123 @x.invalidtld") == nil)
        #expect(RichTextDetection.isValidDomain("bsky.social"))
        #expect(!RichTextDetection.isValidDomain("bsky.SOCIAL"))
    }

    /// Review finding A67: `.test` is not a top-level domain. Treating it as one was a capture
    /// accommodation sitting in shipping detection code, so Release linkified mentions that the
    /// SDK leaves as plain text. It is a build flag now.
    @Test func onlyTheE2EBuildLinkifiesTestHandles() {
        // Release behaviour: the SDK leaves it as plain text.
        #expect(RichTextDetection.detect("hi @bob.test", allowsTestTLD: false) == nil)
        // The capture build, which talks to the dev network.
        #expect(summary(RichTextDetection.detect("hi @bob.test", allowsTestTLD: true)) == ["3-12 mention:bob.test"])
        // A real top-level domain is a mention in either build.
        #expect(summary(RichTextDetection.detect("hi @bob.social", allowsTestTLD: false)) == ["3-14 mention:bob.social"])

        // The test target does not define `E2E`; only the app target's Debug configuration does
        // (`ios/project.yml`). The app module under test is therefore always the E2E build, so its
        // flag must be true here. The Release value is covered by the `allowsTestTLD: false` case
        // above and by the Release build, which compiles the other branch.
        #expect(AppConfig.treatsTestTLDAsValid)
    }

    @Test func byteOffsetsCountUTF8() {
        #expect(summary(RichTextDetection.detect("🦋 @bob.test")) == ["5-14 mention:bob.test"])
    }

    @Test func mentionsResolveOrBecomeEmpty() async {
        let resolved = await RichTextDetection.detectAndResolve("@bob.test and @nobody.test") { handle in
            guard handle == "bob.test" else { throw URLError(.badServerResponse) }
            return "did:plc:bob"
        }
        #expect(summary(resolved) == ["0-9 mention:did:plc:bob", "14-26 mention:"])
    }

    /// Review finding A68: handles resolved one after another, with no cache, so a bio with
    /// several mentions waited for one round trip after another and the profile stayed loading
    /// until the last returned.
    ///
    /// The gate proves the concurrency: it opens only after two resolutions have arrived, so a
    /// serial implementation never gets past `waitForArrivals(2)`.
    @Test func handlesResolveConcurrentlyAndOncePerHandle() async {
        let gate = Gate()
        let calls = Box<[String]>([])
        let resolving = Task {
            await RichTextDetection.detectAndResolve("@bob.test @carla.test @bob.test") { handle in
                calls.value.append(handle)
                await gate.pass()
                return "did:plc:\(handle)"
            }
        }

        await gate.waitForArrivals(2)
        gate.open()
        let resolved = await resolving.value

        // Three mentions, two distinct handles, so the repeated one costs no second request.
        #expect(calls.value.sorted() == ["bob.test", "carla.test"])
        #expect(summary(resolved) == [
            "0-9 mention:did:plc:bob.test",
            "10-21 mention:did:plc:carla.test",
            "22-31 mention:did:plc:bob.test",
        ])
    }

    @Test func profileBioGetsResolvedFacetsOnce() async throws {
        let api = FakeBlueskyAPI()
        var profile = try Fixtures.decode(ProfileViewDetailed.self, "getProfile")
        profile.description = "Hi @bob.test #tag"
        await api.setProfile(profile)
        await api.setHandles(["bob.test": "did:plc:bob"])
        let model = ProfileModel(api: api, actor: "did:plc:alice",
                                 posts: FeedModel(source: .following, api: api, preferences: PreferencesModel(api: api),
                                                  userDid: "did:plc:alice"))
        await model.loadProfile()
        #expect(model.status == .loaded)
        #expect(summary(model.descriptionFacets) == ["3-12 mention:did:plc:bob", "13-17 tag:tag"])

        await model.loadProfile()
        #expect(await api.calls.filter { $0.hasPrefix("resolveHandle") } == ["resolveHandle(bob.test)"])
    }
}
