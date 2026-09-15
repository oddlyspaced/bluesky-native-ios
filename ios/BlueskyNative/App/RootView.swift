import QuartzCore
import SwiftUI

/// Switches between the signed-out screen and the signed-in shell, and reports app-level
/// analytics: `router:navigate` and `init` on ready, `state:foreground` and `state:background`.
struct RootView: View {
    var launchTime: CFTimeInterval

    @Environment(SessionStore.self) private var session
    @Environment(\.analytics) private var analytics
    @Environment(\.theme) private var theme
    @State private var lastActive: CFTimeInterval?
    /// RN registers its AppState listener after launch, when the app is already active, so the
    /// launch activation sends no `state:foreground` (`PassiveAnalytics.tsx:19-21`); only a return
    /// from inactive or background does (review finding N24).
    @State private var hasResignedActive = false
    @State private var reportedReady = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                switch session.state {
                case .restoring:
                    theme.bg.ignoresSafeArea()
                case .signedOut:
                    SignedOutView()
                case .signedIn(let did, let handle):
                    if let api = session.api {
                        SignedInRoot(api: api, did: did, handle: handle, launchTime: launchTime)
                            .id(did)
                    }
                }
            }
            #if E2E
            E2ETestControls()
            #endif
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .task { await session.restore() }
        .onAppear {
            guard !reportedReady else { return }
            reportedReady = true
            // Before sign-in RN's navigator is ready on the Home route behind the logged-out view.
            analytics.metric("router:navigate")
            analytics.metric("init", ["initMs": .int(Self.elapsedMs(since: launchTime))])
        }
        // The app hosts SwiftUI in a UIKit scene, where `scenePhase` is not updated, so the
        // port listens to the same UIApplication state changes RN's AppState reports.
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            reportActive()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            reportInactive()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            reportInactive()
        }
    }

    /// `PassiveAnalytics.tsx:19-21`: `state:foreground` on `active`.
    private func reportActive() {
        guard hasResignedActive else {
            lastActive = CACurrentMediaTime()
            return
        }
        analytics.metric("state:foreground")
        lastActive = CACurrentMediaTime()
    }

    /// RN fires `state:background` on every change away from `active` without resetting the
    /// start time, so iOS reports it for both inactive and background.
    private func reportInactive() {
        hasResignedActive = true
        guard let lastActive else { return }
        analytics.metric("state:background",
                         ["secondsActive": .int(Int((CACurrentMediaTime() - lastActive).rounded()))])
    }

    static func elapsedMs(since start: CFTimeInterval) -> Int {
        Int(((CACurrentMediaTime() - start) * 1000).rounded())
    }
}

/// Owns the account container for the signed-in shell. `.id(did)` in `RootView` recreates it
/// on an account switch, as RN remounts the shell with `key={currentAccount.did}`.
private struct SignedInRoot: View {
    let api: any BlueskyAPI
    let did: String
    let handle: String
    let launchTime: CFTimeInterval

    @Environment(\.analytics) private var analytics
    @Environment(\.platform) private var platform
    @Environment(DebugFaults.self) private var faults
    @State private var container: AccountContainer?

    @Environment(\.theme) private var theme

    var body: some View {
        ZStack {
            // A real view is needed: an empty Group never appears, so onAppear would not run.
            theme.bg.ignoresSafeArea()
            if let container {
                TabShell()
                    .environment(container)
                    .environment(container.ticker)
            }
        }
        .onAppear {
            guard container == nil else { return }
            let created = AccountContainer(api: api, accountDid: did, accountHandle: handle, analytics: analytics,
                                           faults: faults, platform: platform)
            container = created
            // The remounted navigator is ready again (`Navigation.tsx:955`).
            created.router.reportReady(initMs: RootView.elapsedMs(since: launchTime))
        }
    }
}

/// Signed-out screen.
///
/// The RN splash uses a commissioned illustration and the Bluesky logotype, which are
/// not licensed for redistribution (ASSETS.md sections 1 and 3). This showcase keeps the
/// layout (mark at top, "Create account" and "Sign in" at the bottom) without that art.
/// Release builds have no sign-in form; they are smoke builds, not for store submission.
struct SignedOutView: View {
    @State private var showsNotInShowcase = false
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                ShowcaseMark(width: 76)
                Text("Native showcase")
                    .textStyle(size: FontSize._2xl, weight: FontWeight.bold, leading: Leading.tight)
                    .foregroundStyle(theme.palette.primary500)
            }
            .padding(.top, 46)
            Spacer()
            VStack(spacing: Space.md) {
                DSButton(title: "Create account", color: .secondary, size: .large, fullWidth: true) {
                    showsNotInShowcase = true
                }
                .accessibilityIdentifier("createAccountButton")
                DSButton(title: "Sign in", color: .primary, size: .large, fullWidth: true) {
                    showsNotInShowcase = true
                }
                .accessibilityIdentifier("signInButton")
            }
            .padding(.horizontal, Space._5xl)
            .padding(.bottom, Space.sm)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.bg)
        .accessibilityIdentifier("noSessionView")
        .sheet(isPresented: $showsNotInShowcase) {
            NotInShowcaseView(title: "Sign in")
                .presentationDetents([.medium])
        }
    }
}

#if E2E
/// Port of RN `TestCtrls.e2e.tsx`: 1x1pt red buttons stacked at top 100, right 0.
///
/// RN renders twelve controls; the ones this slice needs work and the rest keep their slot.
/// Four native-only controls sit in a second column at top 100, left 0. They arm one injected
/// network failure so Maestro can capture error states; RN has no equivalent control. The left
/// edge is used because a control below RN's twelve lies over the "Feeds" pager tab when signed in.
struct E2ETestControls: View {
    @Environment(SessionStore.self) private var session
    @Environment(DebugFaults.self) private var faults
    @Environment(\.analytics) private var analytics

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(spacing: 0) {
                control("e2eFailNextFeedLoad") { faults.arm(.feedFirstPage) }
                control("e2eFailNextLoadMore") { faults.arm(.feedNextPage) }
                control("e2eFailNextRefresh") { faults.arm(.feedRefresh) }
                control("e2eFailNextThread") { faults.arm(.thread) }
                control("e2eFailNextProfile") { faults.arm(.profile) }
            }
            Spacer(minLength: 0)
            VStack(spacing: 0) {
                control("e2eSignInAlice") { signIn("alice.test") }
                control("e2eSignInBob") { signIn("bob.test") }
                control("e2eSignOut") {
                    analytics.metric("account:loggedOut", ["logContext": "Settings", "scope": "every"])
                    session.signOut()
                }
                ForEach(0..<9, id: \.self) { _ in
                    Color.red.frame(width: 1, height: 1)
                }
            }
        }
        .padding(.top, 100)
        .frame(maxWidth: .infinity, alignment: .top)
        .ignoresSafeArea()
    }

    private func control(_ id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Color.red.frame(width: 1, height: 1)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
    }

    private func signIn(_ handle: String) {
        Task {
            await session.signIn(service: AppConfig.e2eService, identifier: handle, password: "hunter2")
            if case .signedIn = session.state {
                analytics.metric("account:loggedIn", ["logContext": "LoginForm", "withPassword": true])
            }
        }
    }
}
#endif
