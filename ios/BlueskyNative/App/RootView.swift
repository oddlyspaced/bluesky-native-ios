import SwiftUI

/// Switches between the signed-out screen and the signed-in shell.
struct RootView: View {
    @Environment(SessionStore.self) private var session

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                switch session.state {
                case .restoring:
                    Theme.background.ignoresSafeArea()
                case .signedOut:
                    SignedOutView()
                case .signedIn(let did, let handle):
                    if let api = session.api {
                        SignedInRoot(api: api, did: did, handle: handle)
                            .id(did)
                    }
                }
            }
            #if E2E
            E2ETestControls()
            #endif
        }
        .task { session.restore() }
    }
}

/// Owns per-account objects for the signed-in shell.
private struct SignedInRoot: View {
    let api: any BlueskyAPI
    let did: String
    let handle: String

    @State private var shadows = PostShadowStore()

    var body: some View {
        TabShell(
            context: AppContext(api: api, accountDid: did, accountHandle: handle,
                                interactions: PostInteractions(api: api, shadows: shadows))
        )
        .environment(shadows)
    }
}

/// Dependencies shared by the signed-in screens.
@MainActor
struct AppContext {
    let api: any BlueskyAPI
    let accountDid: String
    let accountHandle: String
    let interactions: PostInteractions
}

/// Signed-out screen.
///
/// The RN splash uses a commissioned illustration and the Bluesky logotype, which are
/// not licensed for redistribution (ASSETS.md sections 1 and 3). This showcase keeps the
/// layout (mark at top, "Create account" and "Sign in" at the bottom) without that art.
struct SignedOutView: View {
    @State private var showsNotInShowcase = false

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                ShowcaseMark(width: 76)
                Text("Bluesky native showcase")
                    .textStyle(size: FontSize._2xl, weight: FontWeight.bold, leading: Leading.tight)
                    .foregroundStyle(Palette.primary500)
            }
            .padding(.top, 46)
            Spacer()
            VStack(spacing: 12) {
                Button { showsNotInShowcase = true } label: {
                    Text("Create account")
                        .textStyle(size: FontSize.md, weight: FontWeight.medium, leading: Leading.tight)
                        .foregroundStyle(Theme.textContrastMedium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Theme.bgContrast50, in: Capsule())
                }
                .accessibilityIdentifier("createAccountButton")
                Button { showsNotInShowcase = true } label: {
                    Text("Sign in")
                        .textStyle(size: FontSize.md, weight: FontWeight.medium, leading: Leading.tight)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Palette.primary500, in: Capsule())
                }
                .accessibilityIdentifier("signInButton")
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
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
/// RN renders twelve controls. The ones this slice needs work; the rest keep their
/// slot so the column looks the same but do nothing.
struct E2ETestControls: View {
    @Environment(SessionStore.self) private var session

    var body: some View {
        VStack(spacing: 0) {
            control("e2eSignInAlice") { signIn("alice.test") }
            control("e2eSignInBob") { signIn("bob.test") }
            control("e2eSignOut") { session.signOut() }
            ForEach(0..<9, id: \.self) { _ in
                Color.red.frame(width: 1, height: 1)
            }
        }
        .padding(.top, 100)
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
        }
    }
}
#endif
