import Foundation

/// Ports of RN's display-name and handle helpers, and the fallbacks each RN call site uses
/// (review finding A13: one implementation instead of four).
enum Names {
    /// `sanitizeDisplayName` (`src/lib/strings/display-names.ts:12-27`), without moderation
    /// (this slice has no moderation, so `moderation.blur` is never set).
    static func sanitizeDisplayName(_ value: String) -> String {
        var text = value
        text = text.replacing(/[\u{2705}\u{2713}\u{2714}\u{2611}]/, with: "")
        text = text.replacing(/[\u{0000}-\u{001F}\u{007F}-\u{009F}\u{061C}\u{200E}\u{200F}\u{202A}-\u{202E}\u{2066}-\u{2069}]/, with: "")
        text = text.replacing(/\s[\s\u{200B}]+/, with: " ")
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// `sanitizeHandle(handle, prefix, forceLeftToRight = true)` (`src/lib/strings/handles.ts:31-42`).
    /// On native, `forceLTR` wraps the text in U+202A ... U+202C.
    static func sanitizeHandle(_ handle: String, prefix: String = "", forceLeftToRight: Bool = true) -> String {
        if handle == "handle.invalid" { return "\u{26A0}Invalid Handle" }
        let text = prefix + handle.lowercased()
        return forceLeftToRight ? "\u{202A}\(text)\u{202C}" : text
    }

    /// `PostMeta.tsx:44`: `sanitizeDisplayName(displayName || handle)`; the handle is raw.
    static func postMetaName(displayName: String?, handle: String) -> String {
        sanitizeDisplayName(nonEmpty(displayName) ?? handle)
    }

    /// `ThreadItemAnchor.tsx:357-361`, `PostRepliedTo.tsx` and the profile header:
    /// `sanitizeDisplayName(displayName || sanitizeHandle(handle))`.
    static func displayNameOrHandle(displayName: String?, handle: String) -> String {
        sanitizeDisplayName(nonEmpty(displayName) ?? sanitizeHandle(handle))
    }

    /// `createSanitizedDisplayName(profile, false)` in `PostFeedReason.tsx`: a non-empty display
    /// name is sanitized; otherwise `@handle`.
    static func reasonName(displayName: String?, handle: String) -> String {
        if let name = nonEmpty(displayName) { return sanitizeDisplayName(name) }
        return sanitizeHandle(handle, prefix: "@")
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        return value
    }
}

/// English plural forms used by the slice's Lingui messages.
enum Plural {
    static func count(_ n: Int, one: String, other: String) -> String {
        "\(n) \(n == 1 ? one : other)"
    }

    static func word(_ n: Int, one: String, other: String) -> String {
        n == 1 ? one : other
    }
}
