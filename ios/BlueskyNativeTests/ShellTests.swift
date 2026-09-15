import Foundation
import Testing
@testable import NativeShowcase

/// Records opened URLs.
final class RecordingURLOpener: URLOpening, @unchecked Sendable {
    private let lock = NSLock()
    private var stored: [URL] = []
    var urls: [URL] { lock.withLock { stored } }

    @MainActor func open(_ url: URL) {
        lock.withLock { stored.append(url) }
    }
}

struct FakeActivity: AppActivity {
    var active: Bool
    @MainActor var isActive: Bool { active }
}

@MainActor
@Suite("Link router")
struct LinkRouterTests {
    let analytics = RecordingAnalytics()
    let shell = ShellState()
    let opener = RecordingURLOpener()

    private func router(_ preferences: MemoryPreferencesStore = MemoryPreferencesStore(),
                        profiles: Box<[String]> = Box([])) -> LinkRouter {
        LinkRouter(analytics: analytics, shell: shell, preferences: preferences, urlOpener: opener) { did in
            profiles.value.append(did)
        }
    }

    @Test func externalLinkLogsProxiesAndAsksForConsent() {
        let links = router()
        links.handleFacet(.link(uri: "https://example.com/a", displayText: "example.com/a"))
        #expect(analytics.events(named: "link:clicked").first?.props == [
            "domain": "example.com", "url": "https://example.com/a",
        ])
        #expect(shell.linkConsent?.uri == "https://go.bsky.app/redirect?u=https%3A%2F%2Fexample%2Ecom%2Fa")
        #expect(links.safariURL == nil)
        #expect(opener.urls.isEmpty)
    }

    @Test func consentAnswerIsStoredAndOpensTheLink() {
        let preferences = MemoryPreferencesStore()
        let links = router(preferences)
        let pending = PendingLink(uri: "https://go.bsky.app/redirect?u=x", displayText: "")
        links.answerConsent(true, for: pending)
        #expect(preferences.bool(forKey: LinkRouter.inAppBrowserKey) == true)
        #expect(links.safariURL?.url.absoluteString == "https://go.bsky.app/redirect?u=x")
        #expect(shell.linkConsent == nil)

        links.answerConsent(false, for: pending)
        #expect(preferences.bool(forKey: LinkRouter.inAppBrowserKey) == false)
        #expect(opener.urls.map(\.absoluteString) == ["https://go.bsky.app/redirect?u=x"])

        links.answerConsent(nil, for: pending)
        #expect(preferences.bool(forKey: LinkRouter.inAppBrowserKey) == false)
        #expect(opener.urls.count == 1)
    }

    @Test func storedPreferenceSkipsConsent() {
        let links = router(MemoryPreferencesStore([LinkRouter.inAppBrowserKey: false]))
        links.openLink("https://bsky.app/profile/alice.test")
        #expect(analytics.events(named: "link:clicked").isEmpty)
        #expect(opener.urls.map(\.absoluteString) == ["https://bsky.app/profile/alice.test"])
        #expect(shell.linkConsent == nil)
    }

    @Test func misleadingLinkShowsWarningFirst() {
        let links = router(MemoryPreferencesStore([LinkRouter.inAppBrowserKey: true]))
        links.handleFacet(.link(uri: "https://evil.example", displayText: "bsky.app"))
        #expect(shell.linkWarning == PendingLink(uri: "https://evil.example", displayText: "bsky.app"))
        #expect(links.safariURL == nil)
        links.confirmWarning(shell.linkWarning!)
        #expect(shell.linkWarning == nil)
        #expect(links.safariURL?.url.absoluteString.hasPrefix("https://go.bsky.app/redirect?u=") == true)
    }

    @Test func mentionsOpenProfilesAndTagsAreNotPorted() {
        let profiles = Box<[String]>([])
        let links = router(profiles: profiles)
        links.handleFacet(.mention(did: "did:plc:bob"))
        #expect(profiles.value == ["did:plc:bob"])
        links.handleFacet(.tag("swift"))
        #expect(shell.notInShowcase?.title == "Hashtag")
    }
}

@MainActor
@Suite("Unread polling")
struct UnreadPollingTests {
    /// Review finding A62: a stop while the first check runs also ends the poll loop.
    @Test func stopDuringFirstCheckEndsTheLoop() async {
        let api = FakeBlueskyAPI()
        let model = UnreadNotificationsModel(api: api)
        let waits = Box(0)
        let polling = Task {
            await model.startPolling(activity: FakeActivity(active: true)) { _ in
                waits.value += 1
                // Waits until the poll task is cancelled, without a timer.
                while !Task.isCancelled { await Task.yield() }
            }
        }
        while await api.calls.isEmpty { await Task.yield() }
        model.stopPolling()
        await polling.value
        #expect(waits.value <= 1)
        #expect(await api.calls == ["listNotifications"])
    }

    @Test func inactiveAppSkipsTheCheck() async {
        let api = FakeBlueskyAPI()
        let model = UnreadNotificationsModel(api: api)
        let polling = Task {
            await model.startPolling(activity: FakeActivity(active: false)) { _ in
                while !Task.isCancelled { await Task.yield() }
            }
        }
        for _ in 0..<50 { await Task.yield() }
        model.stopPolling()
        polling.cancel()
        await polling.value
        #expect(await api.calls.isEmpty)
    }
}
