import Foundation

/// Locale for dates and numbers.
///
/// RN formats through Lingui with the app language (for example "en"), not the device
/// region, so an English device in India still shows "Sep 15, 2026".
enum AppLocale {
    static var formatting: Locale {
        Locale(identifier: Locale.current.language.languageCode?.identifier ?? "en")
    }
}

/// Port of `niceDate` (`src/lib/strings/time.ts`).
enum NiceDate {
    /// `'dot separated'`: short time, " · ", medium date. Example: "12:55 AM · Sep 15, 2026".
    static func dotSeparated(_ date: Date, locale: Locale = AppLocale.formatting,
                             timeZone: TimeZone = .current) -> String {
        let time = DateFormatter()
        time.locale = locale
        time.timeZone = timeZone
        time.dateStyle = .none
        time.timeStyle = .short
        let day = DateFormatter()
        day.locale = locale
        day.timeZone = timeZone
        day.dateStyle = .medium
        day.timeStyle = .none
        return "\(time.string(from: date)) · \(day.string(from: date))"
    }

    /// Default style: long date and short time, used for accessibility labels.
    static func long(_ date: Date, locale: Locale = AppLocale.formatting, timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

/// Port of `formatCount` (`src/view/com/util/numeric/format.ts`): compact notation,
/// one decimal below 10k, truncated rather than rounded.
enum CountFormat {
    static func format(_ count: Int, locale: Locale = Locale(identifier: "en_US")) -> String {
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
                ? String(Int(truncated)) : String(format: "%.1f", locale: locale, truncated)
            return text + suffix
        }
        return String(count)
    }
}
