import Foundation
import Testing
@testable import NativeShowcase

/// Cases ported from RN `src/lib/hooks/__tests__/useTimeAgo.test.ts`.
@Suite("Relative time, ported from useTimeAgo")
struct TimeAgoTests {
    let base = ATDate.parse("2024-06-17T00:00:00Z")!

    private func diff(seconds: Double) -> TimeAgo.Diff {
        TimeAgo.dateDiff(earlier: base.addingTimeInterval(-seconds), later: base)
    }

    static let cases: [(Double, Int, TimeAgo.Unit)] = [
        (0, 0, .now), (4, 0, .now), (5, 5, .second), (59, 59, .second), (60, 1, .minute), (119, 1, .minute),
        (3540, 59, .minute), (3600, 1, .hour), (7140, 1, .hour), (82800, 23, .hour), (86400, 1, .day),
        (169_200, 1, .day), (2_505_600, 29, .day), (2_592_000, 1, .month), (5_097_600, 1, .month),
        (5_270_400, 2, .month), (31_017_600, 11, .month), (31_104_000, 12, .month),
    ]

    @Test(arguments: cases)
    func dateDiff(seconds: Double, value: Int, unit: TimeAgo.Unit) {
        let result = diff(seconds: seconds)
        #expect(result.value == value)
        #expect(result.unit == unit)
    }

    @Test func futureDatesReturnNow() {
        #expect(TimeAgo.dateDiff(earlier: base.addingTimeInterval(3 * 86400), later: base).unit == .now)
    }

    @Test func shortFormatAtBoundaries() {
        let utc = TimeZone(identifier: "UTC")!
        let enUS = Locale(identifier: "en_US")
        func short(_ seconds: Double) -> String {
            TimeAgo.formatShort(diff(seconds: seconds), locale: enUS, timeZone: utc)
        }
        #expect(short(4.9) == "now")
        #expect(short(10) == "10s")
        #expect(short(59.9) == "59s")
        #expect(short(60) == "1m")
        #expect(short(3599) == "59m")
        #expect(short(3600) == "1h")
        #expect(short(2 * 86400) == "2d")
        #expect(short(4 * 30 * 86400) == "4mo")
        #expect(short(400 * 86400) == "5/14/2023")
    }

    @MainActor
    @Test func tickerStartsAtMountTime() {
        let fixed = Date(timeIntervalSince1970: 1_000_000)
        let ticker = MinuteTicker(clock: { fixed })
        #expect(ticker.now == fixed)
    }
}

@Suite("niceDate, counts, names and errors")
struct FormattingTests {
    @Test func dotSeparated() {
        let date = ATDate.parse("2026-09-14T19:25:21.210Z")!
        let text = NiceDate.dotSeparated(date, locale: Locale(identifier: "en_US"),
                                         timeZone: TimeZone(identifier: "Asia/Kolkata")!)
        #expect(text.replacingOccurrences(of: "\u{202F}", with: " ") == "12:55 AM · Sep 15, 2026")
    }

    @Test(arguments: [
        (0, "0"), (999, "999"), (1000, "1K"), (1234, "1.2K"), (1299, "1.2K"),
        (9999, "9.9K"), (10_500, "10K"), (123_456, "123K"), (1_500_000, "1M"),
    ])
    func compactCounts(count: Int, expected: String) {
        #expect(CountFormat.format(count, locale: Locale(identifier: "en")) == expected)
    }

    @Test func countsFollowTheAppLanguage() {
        #expect(CountFormat.format(1234, locale: Locale(identifier: "de")) == "1,2K")
    }

    @Test func displayNames() {
        #expect(Names.sanitizeDisplayName("  Alice \u{2705}  ") == "Alice")
        #expect(Names.sanitizeDisplayName("A\u{200E}l  ice") == "Al ice")
        #expect(Names.sanitizeHandle("Alice.Test", prefix: "@") == "\u{202A}@alice.test\u{202C}")
        #expect(Names.sanitizeHandle("handle.invalid") == "\u{26A0}Invalid Handle")
        #expect(Names.postMetaName(displayName: "", handle: "bob.test") == "bob.test")
        #expect(Names.displayNameOrHandle(displayName: nil, handle: "Bob.test") == "bob.test")
        #expect(Names.reasonName(displayName: nil, handle: "bob.test") == "\u{202A}@bob.test\u{202C}")
    }

    @Test func cleanError() {
        #expect(ErrorText.cleanString("TypeError: Network request failed")
            == "Unable to connect. Please check your internet connection and try again.")
        #expect(ErrorText.cleanString("UpstreamFailure")
            == "The server appears to be experiencing issues. Please try again in a few moments.")
        #expect(ErrorText.cleanString("Error: Boom") == "Boom")
        #expect(ErrorText.clean(XRPCError.http(status: 400, error: "InvalidRequest", message: "Bad cursor")) == "Bad cursor")
        #expect(ErrorText.clean(URLError(.timedOut))
            == "Unable to connect. Please check your internet connection and try again.")
    }

    @Test func fontScaleTableMatchesRN() {
        #expect(FontScale.multiplier(for: .large) == 1)
        #expect(FontScale.multiplier(for: .xxxLarge) == 1.353)
        #expect(FontScale.multiplier(for: .accessibility5, cap: 1.5) == 1.5)
        #expect(FontScale.multiplier(for: .small, cap: 1.5) == 0.882)
        #expect(RNLineBox.verticalInset(natural: 18.15, lineHeight: 17, pixelLength: 1.0 / 3) == -1.0 / 3 * 2)
    }
}

@Suite("Rich text")
struct RichTextTests {
    private func facet(_ start: Int, _ end: Int, _ feature: Facet.Feature) -> Facet {
        Facet(index: Facet.ByteSlice(byteStart: start, byteEnd: end), features: [feature])
    }

    @Test func segmentsByUTF8Bytes() {
        let text = "héllo @bob.test #tag"
        let mentionStart = Array("héllo ".utf8).count
        let mentionEnd = mentionStart + Array("@bob.test".utf8).count
        let tagStart = mentionEnd + 1
        let segments = RichTextSegmenter.segments(text: text, facets: [
            facet(tagStart, tagStart + 4, .tag("tag")),
            facet(mentionStart, mentionEnd, .mention(did: "did:plc:bob")),
        ])
        #expect(segments.map(\.text) == ["héllo ", "@bob.test", " ", "#tag"])
        #expect(segments[1].mentionDid == "did:plc:bob")
        #expect(segments[3].tag == "tag")
    }

    @Test func overlappingAndOutOfRangeFacetsAreSkipped() {
        let segments = RichTextSegmenter.segments(text: "abcdef", facets: [
            facet(0, 4, .tag("a")), facet(2, 5, .tag("b")), facet(10, 12, .tag("c")),
        ])
        #expect(segments.map(\.text) == ["abcd", "ef"])
    }

    @Test func shortUrls() {
        #expect(RichTextRules.toShortUrl("https://example.com/") == "example.com")
        // Path "/a/very/long/path" is 17 characters: RN keeps the first 13 and appends "...".
        #expect(RichTextRules.toShortUrl("https://example.com/a/very/long/path") == "example.com/a/very/long/...")
        #expect(RichTextRules.toShortUrl("https://example.com/short") == "example.com/short")
        #expect(RichTextRules.toShortUrl("ftp://x") == "ftp://x")
    }

    @Test func linkWarnings() {
        #expect(!RichTextRules.linkRequiresWarning(uri: "https://example.com/x", label: "example.com/x"))
        #expect(RichTextRules.linkRequiresWarning(uri: "https://evil.com", label: "example.com"))
        #expect(RichTextRules.linkRequiresWarning(uri: "https://example.com", label: "click here"))
        #expect(!RichTextRules.linkRequiresWarning(uri: "https://bsky.app/profile/x", label: "my profile"))
        #expect(!RichTextRules.linkRequiresWarning(uri: "/profile/x", label: "anything"))
    }

    @Test func emojiAndLines() {
        #expect(RichTextRules.isOnlyEmoji("🎉🎉"))
        #expect(!RichTextRules.isOnlyEmoji("hi 🎉"))
        #expect(RichTextRules.countLines("a\nb\nc") == 2)
        #expect(RichTextRules.isValidLinkURI("https://example.com"))
        #expect(!RichTextRules.isValidLinkURI("javascript"))
    }

    @Test func facetURLsRoundTrip() {
        #expect(RichTextView.action(from: URL(string: "showcase-facet://mention?did=did:plc:bob")!) == .mention(did: "did:plc:bob"))
        #expect(RichTextView.action(from: URL(string: "https://example.com")!) == nil)
    }
}

@Suite("Analytics log")
struct AnalyticsLogTests {
    @Test func writesOneJSONObjectPerLine() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "events-\(UUID().uuidString).jsonl")
        let log = JSONLinesEventLog(fileURL: url)
        log.metric("post:like", ["uri": "at://x", "clout": 2, "follows": true])
        log.metric("composerPrompt:press")
        log.flush()
        let lines = try String(contentsOf: url, encoding: .utf8).split(separator: "\n")
        #expect(lines == [
            #"{"name":"post:like","props":{"clout":2,"follows":true,"uri":"at://x"}}"#,
            #"{"name":"composerPrompt:press","props":{}}"#,
        ])
        try? FileManager.default.removeItem(at: url)
    }
}
