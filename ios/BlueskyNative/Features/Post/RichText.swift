import SwiftUI

/// What a tap on a facet asks the app to do. The shell decides (see `FacetRouter`).
enum FacetAction: Hashable, Sendable {
    case mention(did: String)
    /// `uri` is the facet's target; `displayText` is the shortened text shown in the post.
    case link(uri: String, displayText: String)
    /// Long press on a link (`Link.tsx:258-281`, `shareOnLongPress`, review finding F13).
    case shareLink(uri: String, displayText: String)
    case tag(String)
}

struct FacetHandler: Sendable {
    var handle: @MainActor @Sendable (FacetAction) -> Void

    static let none = FacetHandler { _ in }
}

extension EnvironmentValues {
    @Entry var facetHandler: FacetHandler = .none
}

/// One run of post text: plain, or covered by a facet.
struct RichTextSegment: Hashable, Sendable {
    var text: String
    var features: [Facet.Feature]

    var mentionDid: String? {
        for case .mention(let did) in features { return did }
        return nil
    }

    var linkURI: String? {
        for case .link(let uri) in features { return uri }
        return nil
    }

    var tag: String? {
        for case .tag(let tag) in features { return tag }
        return nil
    }
}

/// Port of `RichText.segments()` (`@bsky/sdk/richtext`): facets index UTF-8 byte ranges.
enum RichTextSegmenter {
    static func segments(text: String, facets: [Facet]?) -> [RichTextSegment] {
        guard let facets, !facets.isEmpty else { return [RichTextSegment(text: text, features: [])] }
        let bytes = Array(text.utf8)
        var result: [RichTextSegment] = []
        var cursor = 0
        for facet in facets.sorted(by: { $0.index.byteStart < $1.index.byteStart }) {
            let start = facet.index.byteStart
            let end = min(facet.index.byteEnd, bytes.count)
            // Overlapping or empty ranges are skipped, as the SDK does.
            guard start >= cursor, start < end else { continue }
            if cursor < start {
                result.append(RichTextSegment(text: String(decoding: bytes[cursor..<start], as: UTF8.self), features: []))
            }
            result.append(RichTextSegment(text: String(decoding: bytes[start..<end], as: UTF8.self),
                                          features: facet.features))
            cursor = end
        }
        if cursor < bytes.count {
            result.append(RichTextSegment(text: String(decoding: bytes[cursor...], as: UTF8.self), features: []))
        }
        return result
    }
}

/// Link and text helpers from `src/lib/strings/url-helpers.ts`, `helpers.ts` and `RichText.tsx`.
enum RichTextRules {
    /// `MAX_POST_LINES` (`src/lib/constants.ts:140`).
    static let maxPostLines = 25

    /// `countLines`: the number of newline characters (`src/lib/strings/helpers.ts:45-48`).
    static func countLines(_ text: String) -> Int {
        text.reduce(0) { $1 == "\n" ? $0 + 1 : $0 }
    }

    /// `URL_REGEX` from `RichText.tsx:19-20`, tested against the link facet's URI.
    static func isValidLinkURI(_ uri: String) -> Bool {
        uri.firstMatch(of: /(?i)(^|\s|\()((https?:\/\/\S+)|(([a-z][a-z0-9]*(\.[a-z0-9]+)+)\S*))/) != nil
    }

    /// `isOnlyEmoji` (`src/alf/typography.tsx:118-122`): at most 15 UTF-16 units, emoji only.
    static func isOnlyEmoji(_ text: String) -> Bool {
        guard !text.isEmpty, text.utf16.count <= 15 else { return false }
        // Swift exposes no Extended_Pictographic property; emoji scalars outside Latin-1 cover
        // the same pictographs (digits and '#' are Emoji but not pictographic, so they are excluded).
        return text.unicodeScalars.allSatisfy { scalar in
            scalar.properties.isEmojiPresentation || (scalar.properties.isEmoji && scalar.value > 0xFF)
                || scalar.value == 0xFE0F || scalar.value == 0x200D
        }
    }

    /// `toShortUrl` (`url-helpers.ts:74-89`).
    static func toShortUrl(_ value: String) -> String {
        guard let components = URLComponents(string: value),
              let scheme = components.scheme?.lowercased(), scheme == "http" || scheme == "https",
              let host = components.host else { return value }
        let hostWithPort = components.port.map { "\(host):\($0)" } ?? host
        var path = components.percentEncodedPath == "/" ? "" : components.percentEncodedPath
        if let query = components.percentEncodedQuery { path += "?\(query)" }
        if let fragment = components.percentEncodedFragment { path += "#\(fragment)" }
        if path.count > 15 {
            return hostWithPort + String(path.prefix(13)) + "..."
        }
        return hostWithPort + path
    }

    /// `linkRequiresWarning(uri, label)` (`url-helpers.ts:310-356`).
    static func linkRequiresWarning(uri: String, label: String) -> Bool {
        if uri.hasPrefix("/") || uri.hasPrefix("#") { return false }
        let labelDomain = labelToDomain(label)
        let host = URLComponents(string: uri)?.host?.lowercased()
        let trusted = uri.firstMatch(
            of: /^(https?:\/\/([\w-]+\.)?(bsky\.app|bsky\.social|blueskyweb\.xyz|blueskyweb\.zendesk\.com)|\/|#)/) != nil
        if trusted {
            guard let labelDomain else { return false }
            return labelDomain != host && isPossiblyAUrl(labelDomain)
        }
        guard let labelDomain else { return true }
        return labelDomain != host
    }

    /// `toNiceDomain`: the URL's host, or the input when it has none.
    static func niceDomain(_ url: String) -> String {
        URLComponents(string: url)?.host ?? url
    }

    private static func labelToDomain(_ label: String) -> String? {
        if label.contains(where: \.isWhitespace) { return nil }
        if let host = URLComponents(string: label)?.host, !host.isEmpty { return host.lowercased() }
        if let host = URLComponents(string: "https://\(label)")?.host, !host.isEmpty { return host.lowercased() }
        return nil
    }

    private static func isPossiblyAUrl(_ value: String) -> Bool {
        let text = value.trimmingCharacters(in: .whitespaces)
        if text.hasPrefix("http://") || text.hasPrefix("https://") { return true }
        let firstWord = text.split(whereSeparator: { $0.isWhitespace || $0 == "/" }).first.map(String.init) ?? ""
        return firstWord.firstMatch(of: /\.[A-Za-z0-9]+$/) != nil
    }
}

/// Port of `RichText` (`src/components/RichText.tsx`): mentions, links and tags in `text_link`
/// colour with the post's weight, no underline on native. Taps go to `facetHandler`.
struct RichTextView: View {
    var text: String
    var facets: [Facet]?
    var size: CGFloat = FontSize.md
    var lineLimit: Int?
    var enableTags = true
    var testID: String?
    var lineBoxAdjustment: RNLineBox.Adjustment = RNLineBox.richText

    @Environment(\.theme) private var theme
    @Environment(\.facetHandler) private var facetHandler

    private static let scheme = "showcase-facet"

    var body: some View {
        let emojiOnly = (facets?.isEmpty ?? true) && RichTextRules.isOnlyEmoji(text)
        Text(attributed)
            .textStyle(size: emojiOnly ? size * 1.85 : size, leading: Leading.snug, adjustment: lineBoxAdjustment)
            .foregroundStyle(theme.text)
            .tint(theme.textLink)
            .lineLimit(emojiOnly ? nil : lineLimit)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .environment(\.openURL, OpenURLAction { url in
                if let action = Self.action(from: url) {
                    facetHandler.handle(action)
                    return .handled
                }
                return .discarded
            })
            .modifier(LinkShareMenu(links: shareableLinks, handler: facetHandler))
            .accessibilityIdentifier(testID ?? "")
    }

    /// Links a long press can share: RN renders valid link facets as `InlineLinkText` with
    /// `shareOnLongPress` (`RichText.tsx:160-180`). SwiftUI `Text` has no per-run long press, so the
    /// text gets one context menu with a "Share link" item per link (review finding F13).
    var shareableLinks: [PendingLink] {
        RichTextSegmenter.segments(text: text, facets: facets).compactMap { segment in
            guard let uri = segment.linkURI, RichTextRules.isValidLinkURI(uri) else { return nil }
            return PendingLink(uri: uri, displayText: RichTextRules.toShortUrl(segment.text))
        }
    }

    private var attributed: AttributedString {
        var result = AttributedString()
        for segment in RichTextSegmenter.segments(text: text, facets: facets) {
            var run: AttributedString
            if let did = segment.mentionDid, did.hasPrefix("did:") {
                run = AttributedString(segment.text)
                run.link = Self.url("mention", ["did": did])
                run.foregroundColor = theme.textLink
            } else if let uri = segment.linkURI {
                let display = RichTextRules.toShortUrl(segment.text)
                run = AttributedString(display)
                if RichTextRules.isValidLinkURI(uri) {
                    run.link = Self.url("link", ["u": uri, "d": display])
                    run.foregroundColor = theme.textLink
                }
            } else if enableTags, let tag = segment.tag {
                run = AttributedString(segment.text)
                run.link = Self.url("tag", ["t": tag])
                run.foregroundColor = theme.textLink
            } else {
                run = AttributedString(segment.text)
            }
            result += run
        }
        return result
    }

    private static func url(_ host: String, _ items: [String: String]) -> URL? {
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.queryItems = items.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        return components.url
    }

    nonisolated static func action(from url: URL) -> FacetAction? {
        guard url.scheme == scheme, let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }
        let items = Dictionary((components.queryItems ?? []).map { ($0.name, $0.value ?? "") },
                               uniquingKeysWith: { first, _ in first })
        switch components.host {
        case "mention": return items["did"].map { .mention(did: $0) }
        case "link": return items["u"].map { .link(uri: $0, displayText: items["d"] ?? $0) }
        case "tag": return items["t"].map { .tag($0) }
        default: return nil
        }
    }
}

/// The long-press menu of `RichTextView`. Text without links gets no menu.
private struct LinkShareMenu: ViewModifier {
    var links: [PendingLink]
    var handler: FacetHandler

    func body(content: Content) -> some View {
        if links.isEmpty {
            content
        } else {
            content.contextMenu {
                ForEach(links) { link in
                    Button(links.count == 1 ? "Share link" : "Share \(link.displayText)") {
                        handler.handle(.shareLink(uri: link.uri, displayText: link.displayText))
                    }
                }
            }
        }
    }
}
