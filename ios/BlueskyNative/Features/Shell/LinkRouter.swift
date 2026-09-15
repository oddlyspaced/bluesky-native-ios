import Foundation
import Observation

/// Link and facet policy of the shell, out of the view so it is testable (review finding A59).
///
/// Ports `src/components/Link.tsx:146-248` (facet taps) and `src/lib/hooks/useOpenLink.ts`
/// (metric, proxy, then the in-app browser choice). The view only presents what this router
/// decides: `shell.linkWarning`, `shell.linkConsent` and `safariURL`.
@MainActor
@Observable
final class LinkRouter {
    /// RN's in-app browser preference key; unset until the consent dialog answers.
    static let inAppBrowserKey = "useInAppBrowser"

    /// The URL the in-app browser sheet shows.
    var safariURL: IdentifiedURL?

    @ObservationIgnored private let analytics: any AnalyticsSink
    @ObservationIgnored private let shell: ShellState
    @ObservationIgnored private let preferences: any PreferencesStore
    @ObservationIgnored private let urlOpener: any URLOpening
    @ObservationIgnored private let openProfile: @MainActor (String) -> Void

    init(analytics: any AnalyticsSink, shell: ShellState, preferences: any PreferencesStore,
         urlOpener: any URLOpening, openProfile: @escaping @MainActor (String) -> Void) {
        self.analytics = analytics
        self.shell = shell
        self.preferences = preferences
        self.urlOpener = urlOpener
        self.openProfile = openProfile
    }

    var inAppBrowserPreference: Bool? {
        preferences.bool(forKey: Self.inAppBrowserKey)
    }

    /// Tap on a `RichText` facet.
    func handleFacet(_ action: FacetAction) {
        switch action {
        case .mention(let did):
            openProfile(did)
        case .tag:
            shell.notInShowcase = NotInShowcaseItem(title: "Hashtag")
        case .link(let uri, let displayText):
            if RichTextRules.linkRequiresWarning(uri: uri, label: displayText) {
                shell.linkWarning = PendingLink(uri: uri, displayText: displayText)
            } else {
                openLink(uri)
            }
        case .shareLink(let uri, let displayText):
            // `handleLongPress` (`Link.tsx:258-274`): a mismatched link opens the warning in share
            // mode; any other link goes straight to the share sheet. No metric, no proxy.
            if RichTextRules.linkRequiresWarning(uri: uri, label: displayText) {
                shell.linkWarning = PendingLink(uri: uri, displayText: displayText, share: true)
            } else {
                share(uri)
            }
        }
    }

    /// "Visit site", or "Share link" for a long press, in the link warning dialog.
    func confirmWarning(_ link: PendingLink) {
        shell.linkWarning = nil
        if link.share {
            share(link.uri)
        } else {
            openLink(link.uri)
        }
    }

    /// `shareUrl` (`src/lib/sharing.ts`): the system share sheet with the URL.
    private func share(_ uri: String) {
        guard let url = URL(string: uri) else { return }
        shell.shareURL = IdentifiedURL(url: url)
    }

    /// The in-app browser consent answer; nil is Cancel.
    func answerConsent(_ choice: Bool?, for link: PendingLink) {
        shell.linkConsent = nil
        guard let choice else { return }
        preferences.setBool(choice, forKey: Self.inAppBrowserKey)
        open(link.uri, inApp: choice)
    }

    /// `useOpenLink`: metric, proxy, then the browser choice.
    func openLink(_ uri: String) {
        var url = uri
        if !Self.isBskyAppUrl(uri) {
            analytics.metric("link:clicked", ["domain": .string(RichTextRules.niceDomain(uri)), "url": .string(uri)])
            // Feed and thread text always proxy links.
            let encoded = uri.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? uri
            url = "https://go.bsky.app/redirect?u=\(encoded)"
        }
        if url.hasPrefix("mailto:") {
            open(url, inApp: false)
        } else if let preference = inAppBrowserPreference {
            open(url, inApp: preference)
        } else {
            shell.linkConsent = PendingLink(uri: url, displayText: url)
        }
    }

    private func open(_ uri: String, inApp: Bool) {
        guard let url = URL(string: uri) else { return }
        if inApp, url.scheme == "https" || url.scheme == "http" {
            safariURL = IdentifiedURL(url: url)
        } else {
            urlOpener.open(url)
        }
    }

    static func isBskyAppUrl(_ uri: String) -> Bool {
        uri.firstMatch(of: /^https?:\/\/(www\.)?bsky\.app/) != nil
    }
}

struct IdentifiedURL: Identifiable, Hashable {
    let url: URL
    var id: String { url.absoluteString }
}
