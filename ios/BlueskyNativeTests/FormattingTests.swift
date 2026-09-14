import Foundation
import Testing
@testable import BlueskyNative

/// Cases ported from RN `src/lib/hooks/__tests__/useTimeAgo.test.ts`.
@Suite("Relative time, ported from useTimeAgo")
struct TimeAgoTests {
    let base = ATDate.parse("2024-06-17T00:00:00Z")!

    private func diff(seconds: Double) -> TimeAgo.Diff {
        TimeAgo.dateDiff(earlier: base.addingTimeInterval(-seconds), later: base)
    }

    static let cases: [(Double, Int, TimeAgo.Unit)] = [
        (0, 0, .now),
        (4, 0, .now),
        (5, 5, .second),
        (59, 59, .second),
        (60, 1, .minute),
        (119, 1, .minute),
        (3540, 59, .minute),
        (3600, 1, .hour),
        (7140, 1, .hour),
        (82800, 23, .hour),
        (86400, 1, .day),
        (169_200, 1, .day),
        (2_505_600, 29, .day),
        (2_592_000, 1, .month),
        (5_097_600, 1, .month),
        (5_270_400, 2, .month),
        (31_017_600, 11, .month),
        (31_104_000, 12, .month),
    ]

    @Test(arguments: cases)
    func dateDiff(seconds: Double, value: Int, unit: TimeAgo.Unit) {
        let result = diff(seconds: seconds)
        #expect(result.value == value)
        #expect(result.unit == unit)
    }

    @Test func futureDatesReturnNow() {
        let result = TimeAgo.dateDiff(earlier: base.addingTimeInterval(3 * 86400), later: base)
        #expect(result.unit == .now)
    }

    @Test func shortFormat() {
        let utc = TimeZone(identifier: "UTC")!
        let enUS = Locale(identifier: "en_US")
        func short(_ seconds: Double) -> String {
            TimeAgo.formatShort(diff(seconds: seconds), locale: enUS, timeZone: utc)
        }
        #expect(short(2) == "now")
        #expect(short(10) == "10s")
        #expect(short(5 * 60) == "5m")
        #expect(short(3 * 3600) == "3h")
        #expect(short(2 * 86400) == "2d")
        #expect(short(4 * 30 * 86400) == "4mo")
        // 12 months and over: locale short date of the earlier date, like Lingui i18n.date.
        #expect(short(400 * 86400) == "5/14/2023")
    }
}

@Suite("niceDate and count formatting")
struct NiceDateTests {
    @Test func dotSeparated() {
        let date = ATDate.parse("2026-09-14T19:25:21.210Z")!
        let text = NiceDate.dotSeparated(date, locale: Locale(identifier: "en_US"),
                                         timeZone: TimeZone(identifier: "Asia/Kolkata")!)
        // DateFormatter uses U+202F before AM/PM, as ICU-based Intl does.
        #expect(text.replacingOccurrences(of: "\u{202F}", with: " ") == "12:55 AM · Sep 15, 2026")
    }

    @Test(arguments: [
        (0, "0"), (999, "999"), (1000, "1K"), (1234, "1.2K"), (1299, "1.2K"),
        (9999, "9.9K"), (10_500, "10K"), (123_456, "123K"), (1_500_000, "1M"),
    ])
    func compactCounts(count: Int, expected: String) {
        #expect(CountFormat.format(count) == expected)
    }
}
