import Testing
@testable import NativeShowcase

/// Review findings A64 and A71: the five RN screen ids need an automated check.
///
/// **What a unit test cannot do here, and why it was not guessed at.** A unit test cannot read
/// SwiftUI's accessibility tree. SwiftUI answers accessibility for an out-of-process client
/// (XCUITest, and `maestro hierarchy` through it); it does not fill in
/// `UIView.accessibilityElements`, nor the `accessibilityElementCount()` and
/// `accessibilityElement(at:)` pair, in process. That was measured, not assumed: a
/// `UIHostingController` holding `HomeScreen` and `ProfileScreen`, in a scene-backed `UIWindow`,
/// laid out and flushed through `CATransaction`, renders its `HostingScrollView` but reports zero
/// accessibility children and zero identifiers. `ios/PARITY.md` records the limit and what would
/// close it.
///
/// What is checked here instead:
/// - the shell takes the home stack's id from `ScreenRegistry`, so no shell edit can drop it and
///   no tab is named in the shell (review finding A71);
/// - the five ids have one definition, shared by the screens and `parity/flows/capture.yml`.
///
/// The check that fails when a screen stops exposing an id is `assertVisible` in
/// `parity/flows/capture.yml`. It needs a capture run.
@MainActor
@Suite("Screen identifiers")
struct ScreenIdentifierTests {
    @Test func theShellTakesTheHomeStackIdFromTheRegistry() {
        let registry = ScreenRegistry.slice()
        #expect(registry.rootIdentifier(for: .home) == ScreenID.homeStack)
        // The profile tab's id sits inside the screen, not on its hosting stack.
        #expect(registry.rootIdentifier(for: .profile) == nil)
        #expect(registry.rootIdentifier(for: .search) == nil)
    }

    /// The shell's branch is driven by registration, not by a tab name: a root registered without
    /// an id leaves its stack unlabelled.
    @Test func onlyARegisteredIdentifierLabelsAStack() {
        let registry = ScreenRegistry()
        registry.registerRoot(.home) { _ in NotInShowcaseView(title: "Home") }
        #expect(registry.rootIdentifier(for: .home) == nil)

        registry.registerRoot(.home, identifier: ScreenID.homeStack) { _ in NotInShowcaseView(title: "Home") }
        #expect(registry.rootIdentifier(for: .home) == "HomeScreen")
    }

    /// RN's own id values. A rename in the port breaks this before it reaches a capture.
    @Test func theScreenIdsAreTheRNValues() {
        #expect(ScreenID.assertedInCaptureFlow == [
            "HomeScreen", "homeScreen", "followingFeedPage", "profileScreen", "postsFeed",
        ])
    }
}
