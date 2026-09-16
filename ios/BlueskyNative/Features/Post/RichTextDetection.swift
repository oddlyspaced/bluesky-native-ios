import Foundation

/// Port of `detectFacets` from `@bsky/sdk` (`rich-text/detection.js` and the regexes in
/// `rich-text/util.js`), which `RichTextAPI.detectFacets` runs on text without stored facets, such
/// as a profile bio (`Profile.tsx:614-647`, review finding F4).
///
/// The JS regexes run on UTF-16. `NSRegularExpression` also reports UTF-16 ranges, so every offset
/// below is a UTF-16 offset until it becomes a UTF-8 byte offset for the facet index.
enum RichTextDetection {
    /// `MENTION_REGEX`, flags `g`.
    private static let mentionRegex = regex(#"(^|\s|\()(@)([a-zA-Z0-9.-]+)(\b)"#)
    /// `URL_REGEX`, flags `gim`.
    private static let urlRegex = regex(#"(^|\s|\()((https?:\/\/[\S]+)|((?<domain>[a-z][a-z0-9]*(\.[a-z0-9]+)+)[\S]*))"#,
                                        options: [.caseInsensitive, .anchorsMatchLines])
    /// `TAG_REGEX`, flags `gu`. JS `\d` with the `u` flag is ASCII only, so it is `0-9` here.
    private static let tagRegex = regex(
        #"(^|\s)[#＃]((?!\x{FE0F})[^\s\x{00AD}\x{2060}\x{200A}\x{200B}\x{200C}\x{200D}\x{20E2}]*[^0-9\s\p{P}\x{00AD}\x{2060}\x{200A}\x{200B}\x{200C}\x{200D}\x{20E2}]+[^\s\x{00AD}\x{2060}\x{200A}\x{200B}\x{200C}\x{200D}\x{20E2}]*)?"#)
    /// `CASHTAG_REGEX`, flags `gu`. JS `$` without the `m` flag is the end of the input (`\z`).
    private static let cashtagRegex = regex(#"(^|\s|\()\$([A-Za-z][A-Za-z0-9]{0,4})(?=\s|\z|[.,;:!?)"'\x{2019}])"#)

    private static func regex(_ pattern: String, options: NSRegularExpression.Options = []) -> NSRegularExpression {
        // The patterns are constants; a failure is a programming error found by the tests.
        // swiftlint:disable:next force_try
        try! NSRegularExpression(pattern: pattern, options: options)
    }

    /// Facets in `text`, mentions still unresolved (the handle is in `did`). nil when none, as the SDK.
    ///
    /// `allowsTestTLD` carries the capture accommodation (review finding A67). The dev network's
    /// handles end in `.test`, which is not a real top-level domain, so only the E2E build treats
    /// it as one. Release matches the SDK and leaves such mentions as plain text.
    static func detect(_ text: String, allowsTestTLD: Bool = AppConfig.treatsTestTLDAsValid) -> [Facet]? {
        let ns = text as NSString
        let whole = NSRange(location: 0, length: ns.length)
        var facets: [Facet] = []

        func facet(_ start: Int, _ end: Int, _ feature: Facet.Feature) -> Facet {
            Facet(index: .init(byteStart: utf8Offset(text, start), byteEnd: utf8Offset(text, end)),
                  features: [feature])
        }

        for match in mentionRegex.matches(in: text, range: whole) {
            let handle = ns.substring(with: match.range(at: 3))
            guard isValidDomain(handle) || (allowsTestTLD && handle.hasSuffix(".test")) else { continue }
            let start = match.range(at: 3).location - 1
            facets.append(facet(start, start + (handle as NSString).length + 1, .mention(did: handle)))
        }

        for match in urlRegex.matches(in: text, range: whole) {
            let matched = ns.substring(with: match.range(at: 2))
            var uri = matched
            if !uri.hasPrefix("http") {
                let domainRange = match.range(withName: "domain")
                guard domainRange.location != NSNotFound, isValidDomain(ns.substring(with: domainRange)) else { continue }
                uri = "https://\(uri)"
            }
            let start = match.range(at: 2).location
            var end = start + (matched as NSString).length
            if let last = uri.last, ".,;:!?".contains(last) {
                uri.removeLast()
                end -= 1
            }
            if uri.hasSuffix(")"), !uri.contains("(") {
                uri.removeLast()
                end -= 1
            }
            facets.append(facet(start, end, .link(uri: uri)))
        }

        for match in tagRegex.matches(in: text, range: whole) {
            let tagRange = match.range(at: 2)
            guard tagRange.location != NSNotFound else { continue }
            let tag = stripTrailingPunctuation(ns.substring(with: tagRange).trimmingCharacters(in: .whitespacesAndNewlines))
            let length = (tag as NSString).length
            if length == 0 || (length > 64 && tag.count > 64) { continue }
            let start = match.range.location + match.range(at: 1).length
            facets.append(facet(start, start + 1 + length, .tag(tag)))
        }

        for match in cashtagRegex.matches(in: text, range: whole) {
            let ticker = ns.substring(with: match.range(at: 2)).uppercased()
            let start = match.range.location + match.range(at: 1).length
            facets.append(facet(start, start + 1 + (ticker as NSString).length, .tag("$" + ticker)))
        }

        return facets.isEmpty ? nil : facets
    }

    /// `RichTextAPI.detectFacets(client)`: detection, then each mention handle resolved to a DID.
    /// An unresolved mention gets an empty DID, which `RichTextView` renders as plain text. Facets
    /// are sorted by `byteStart` (`facetSort`).
    /// Handles resolve concurrently, and each distinct handle resolves once however many times it
    /// appears, so a bio with several mentions no longer waits for one round trip after another
    /// (review finding A68). Cancelling the calling task cancels every resolution with it.
    static func detectAndResolve(_ text: String, allowsTestTLD: Bool = AppConfig.treatsTestTLDAsValid,
                                 resolveHandle: @Sendable @escaping (String) async throws -> String) async -> [Facet]? {
        guard var facets = detect(text, allowsTestTLD: allowsTestTLD) else { return nil }
        // One entry per distinct handle: the cache that makes a repeated mention free.
        let handles = Set(facets.flatMap { facet in
            facet.features.compactMap { feature -> String? in
                if case .mention(let handle) = feature { return handle }
                return nil
            }
        })
        var dids: [String: String] = [:]
        if !handles.isEmpty {
            dids = await withTaskGroup(of: (String, String).self) { group in
                for handle in handles {
                    // An unresolved mention gets an empty DID, as the SDK does.
                    group.addTask { (handle, (try? await resolveHandle(handle)) ?? "") }
                }
                var resolved: [String: String] = [:]
                for await (handle, did) in group { resolved[handle] = did }
                return resolved
            }
        }
        for index in facets.indices {
            for featureIndex in facets[index].features.indices {
                guard case .mention(let handle) = facets[index].features[featureIndex] else { continue }
                facets[index].features[featureIndex] = .mention(did: dids[handle] ?? "")
            }
        }
        // A stable sort, as JS `Array.prototype.sort`.
        return facets.enumerated()
            .sorted { ($0.element.index.byteStart, $0.offset) < ($1.element.index.byteStart, $1.offset) }
            .map(\.element)
    }

    /// `isValidDomain`: the text ends with "." and a known top-level domain (case-sensitive, as the SDK).
    static func isValidDomain(_ value: String) -> Bool {
        guard let dot = value.lastIndex(of: ".") else { return false }
        return TopLevelDomains.all.contains(String(value[value.index(after: dot)...]))
    }

    /// `TRAILING_PUNCTUATION_REGEX` (`/\p{P}+$/gu`).
    private static func stripTrailingPunctuation(_ value: String) -> String {
        var scalars = Array(value.unicodeScalars)
        while let last = scalars.last, isPunctuation(last) { scalars.removeLast() }
        return String(String.UnicodeScalarView(scalars))
    }

    private static func isPunctuation(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.properties.generalCategory {
        case .connectorPunctuation, .dashPunctuation, .openPunctuation, .closePunctuation,
             .initialPunctuation, .finalPunctuation, .otherPunctuation:
            true
        default:
            false
        }
    }

    /// `utf16IndexToUtf8Index`.
    private static func utf8Offset(_ text: String, _ utf16Offset: Int) -> Int {
        let index = String.Index(utf16Offset: utf16Offset, in: text)
        return text[..<index].utf8.count
    }
}
