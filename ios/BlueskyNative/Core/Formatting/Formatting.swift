import Foundation
import os

/// Locale for dates and numbers.
///
/// RN formats through Lingui with the app language (for example "en"), not the device
/// region, so an English device in India still shows "Sep 15, 2026".
enum AppLocale {
    static var formatting: Locale {
        Locale(identifier: Locale.current.language.languageCode?.identifier ?? "en")
    }
}

/// Thread-safe cache of `DateFormatter`s keyed by locale, time zone and pattern.
///
/// Formatters are expensive to create (review finding A14). Each formatter is used only
/// inside the lock, so no formatter crosses threads and no `nonisolated(unsafe)` is needed.
final class DateFormatterCache: Sendable {
    enum Pattern: Hashable, Sendable {
        case styles(date: DateFormatter.Style, time: DateFormatter.Style)
        case template(String)
    }

    private struct Key: Hashable {
        var locale: String
        var timeZone: String
        var pattern: Pattern
    }

    static let shared = DateFormatterCache()

    private let formatters = OSAllocatedUnfairLock<[Key: DateFormatter]>(uncheckedState: [:])

    func string(from date: Date, locale: Locale, timeZone: TimeZone, pattern: Pattern) -> String {
        let key = Key(locale: locale.identifier, timeZone: timeZone.identifier, pattern: pattern)
        return formatters.withLockUnchecked { cache in
            let formatter: DateFormatter
            if let existing = cache[key] {
                formatter = existing
            } else {
                formatter = DateFormatter()
                formatter.locale = locale
                formatter.timeZone = timeZone
                switch pattern {
                case .styles(let dateStyle, let timeStyle):
                    formatter.dateStyle = dateStyle
                    formatter.timeStyle = timeStyle
                case .template(let template):
                    formatter.setLocalizedDateFormatFromTemplate(template)
                }
                cache[key] = formatter
            }
            return formatter.string(from: date)
        }
    }
}

/// Parses AT Protocol datetime strings with value-type `ISO8601FormatStyle` (Sendable).
enum ATDate {
    private static let fractional = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
    private static let plain = Date.ISO8601FormatStyle()

    /// Parses an AT Protocol datetime string. Returns nil for malformed values.
    static func parse(_ string: String) -> Date? {
        (try? fractional.parse(string)) ?? (try? plain.parse(string))
    }
}

/// Port of `niceDate` (`src/lib/strings/time.ts`).
enum NiceDate {
    /// `'dot separated'`: short time, " · ", medium date. Example: "12:55 AM · Sep 15, 2026".
    static func dotSeparated(_ date: Date, locale: Locale = AppLocale.formatting,
                             timeZone: TimeZone = .current) -> String {
        let cache = DateFormatterCache.shared
        let time = cache.string(from: date, locale: locale, timeZone: timeZone, pattern: .styles(date: .none, time: .short))
        let day = cache.string(from: date, locale: locale, timeZone: timeZone, pattern: .styles(date: .medium, time: .none))
        return "\(time) · \(day)"
    }

    /// Default style: long date and short time, used for accessibility labels.
    static func long(_ date: Date, locale: Locale = AppLocale.formatting, timeZone: TimeZone = .current) -> String {
        DateFormatterCache.shared.string(from: date, locale: locale, timeZone: timeZone,
                                         pattern: .styles(date: .long, time: .short))
    }
}

/// Port of `formatCount` (`src/view/com/util/numeric/format.ts`): compact notation,
/// one decimal below 10k, truncated rather than rounded. The decimal separator follows
/// the app language, as RN's `Intl.NumberFormat(i18n.locale)` does (review finding P39).
enum CountFormat {
    static func format(_ count: Int, locale: Locale = AppLocale.formatting) -> String {
        if count < 1000 { return String(count) }
        let units: [(Double, String)] = [(1e9, "B"), (1e6, "M"), (1e3, "K")]
        for (size, suffix) in units where Double(count) >= size {
            let value = Double(count) / size
            let truncated: Double
            if count < 10_000 {
                truncated = (value * 10).rounded(.down) / 10
            } else {
                truncated = value.rounded(.down)
            }
            let text = truncated.truncatingRemainder(dividingBy: 1) == 0
                ? String(Int(truncated))
                : truncated.formatted(.number.locale(locale).precision(.fractionLength(1)).grouping(.never))
            return text + suffix
        }
        return String(count)
    }
}
