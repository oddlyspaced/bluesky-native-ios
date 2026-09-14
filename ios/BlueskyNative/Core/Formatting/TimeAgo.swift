import Foundation

/// Port of `dateDiff` and `formatDateDiff` from RN `src/lib/hooks/useTimeAgo.ts`.
///
/// Rules carried over from RN:
/// - Every month is exactly 30 days.
/// - A future `earlier` date, or a difference under 5 seconds, is "now".
/// - Values round down (the RN default).
/// - 12 or more months formats as the locale short date, as Lingui `i18n.date` does.
enum TimeAgo {
    enum Unit: Equatable, Sendable {
        case now, second, minute, hour, day, month
    }

    struct Diff: Equatable, Sendable {
        var value: Int
        var unit: Unit
        var earlier: Date
        var later: Date
    }

    private static let nowThreshold = 5
    private static let minute = 60
    private static let hour = minute * 60
    private static let day = hour * 24
    private static let month30 = day * 30

    static func dateDiff(earlier: Date, later: Date) -> Diff {
        // date-fns differenceInSeconds truncates toward zero.
        let seconds = Int(later.timeIntervalSince(earlier).rounded(.towardZero))
        let (value, unit): (Int, Unit)
        switch seconds {
        case ..<nowThreshold: (value, unit) = (0, .now)
        case ..<minute: (value, unit) = (seconds, .second)
        case ..<hour: (value, unit) = (seconds / minute, .minute)
        case ..<day: (value, unit) = (seconds / hour, .hour)
        case ..<month30: (value, unit) = (seconds / day, .day)
        default: (value, unit) = (seconds / month30, .month)
        }
        return Diff(value: value, unit: unit, earlier: earlier, later: later)
    }

    /// The "short" format RN uses in post meta rows: `now`, `10s`, `5m`, `3h`, `2d`, `4mo`.
    static func formatShort(_ diff: Diff, locale: Locale = AppLocale.formatting,
                            timeZone: TimeZone = .current) -> String {
        switch diff.unit {
        case .now: return "now"
        case .second: return "\(diff.value)s"
        case .minute: return "\(diff.value)m"
        case .hour: return "\(diff.value)h"
        case .day: return "\(diff.value)d"
        case .month:
            if diff.value < 12 { return "\(diff.value)mo" }
            let formatter = DateFormatter()
            formatter.locale = locale
            formatter.timeZone = timeZone
            formatter.setLocalizedDateFormatFromTemplate("yMd")
            return formatter.string(from: diff.earlier)
        }
    }

    static func short(from earlier: Date, to later: Date = Date(), locale: Locale = AppLocale.formatting,
                      timeZone: TimeZone = .current) -> String {
        formatShort(dateDiff(earlier: earlier, later: later), locale: locale, timeZone: timeZone)
    }
}
