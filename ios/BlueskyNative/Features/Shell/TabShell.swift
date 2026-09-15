import SafariServices
import SwiftUI

/// Port of the RN bottom-tab shell (`src/view/shell`), with Home and Profile ported.
///
/// Tabs are a `ZStack` of per-tab `NavigationStack`s under the custom `BottomBar`, not a
/// `TabView` with its bar hidden. Reason (review finding A16): `TabView` on iOS 26 reserves
/// the system tab bar's safe area and draws its own background under the hidden bar, which
/// moved the feed and the bar by several pixels against the RN captures. Per-tab routers and
/// a screen factory (`AccountContainer.threadModel(for:)`) give the structure the review
/// asked for. Like RN's lazy tabs, a tab mounts on first visit and stays mounted.
struct TabShell: View {
    @Environment(AccountContainer.self) private var container
    @Environment(StatusBarAppearance.self) private var statusBar
    @Environment(\.theme) private var theme

    var body: some View {
        @Bindable var shell = container.shell
        @Bindable var links = container.links
        @Bindable var home = container.router.home
        @Bindable var profile = container.router.profile
        let router = container.router
        ZStack {
            tab(.home) {
                NavigationStack(path: $home.path) {
                    HomeScreen()
                        .navigationDestination(for: Route.self, destination: destination)
                }
            }
            if router.visitedProfile {
                tab(.profile) {
                    NavigationStack(path: $profile.path) {
                        ProfileScreen(model: container.profile, isTabRoot: true)
                            .navigationDestination(for: Route.self, destination: destination)
                    }
                }
            }
            switch router.selected {
            case .search, .messages, .notifications:
                NotInShowcaseView(title: router.selected.title)
            case .home, .profile:
                EmptyView()
            }
            if router.currentRouter?.path.isEmpty == true {
                // Positioned against the bottom bar, not the scroll view, which extends under it.
                ComposeFAB { container.shell.notInShowcase = NotInShowcaseItem(title: "Composer") }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
            if let toast = shell.toast {
                ToastView(message: toast)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, Space.lg)
                    .transition(.opacity)
                    .task(id: toast.id) {
                        try? await Task.sleep(for: .seconds(3))
                        if shell.toast?.id == toast.id { shell.toast = nil }
                    }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            // The prompt shows only while the top thread allows replies, and only a mounted
            // prompt hides the bar's border (`PostThread/index.tsx:647-649`, review finding N2).
            let showsReplyPrompt = topThreadModel?.canReply ?? false
            VStack(spacing: 0) {
                if showsReplyPrompt {
                    ThreadComposePrompt(avatarURL: container.profile.profile?.avatar) {
                        container.shell.notInShowcase = NotInShowcaseItem(title: "Reply")
                    }
                }
                BottomBar(selected: router.selected, unreadText: container.unread.displayText,
                          avatarURL: container.profile.profile?.avatar, hidesBorder: showsReplyPrompt,
                          onSelect: router.select)
            }
        }
        // Link policy lives in `LinkRouter`; the view only presents its decisions (A59).
        .environment(\.facetHandler, FacetHandler { [links = container.links] action in links.handleFacet(action) })
        .sheet(item: $shell.notInShowcase) { item in
            NotInShowcaseView(title: item.title)
                .presentationDetents([.medium])
        }
        .sheet(item: $shell.linkWarning) { link in
            LinkWarningSheet(link: link) {
                container.links.confirmWarning(link)
            }
            .presentationDetents([.medium])
        }
        .sheet(item: $shell.linkConsent) { link in
            InAppBrowserConsentSheet { choice in
                container.links.answerConsent(choice, for: link)
            }
            .presentationDetents([.medium])
        }
        .sheet(item: $links.safariURL) { item in
            SafariView(url: item.url).ignoresSafeArea()
        }
        .task {
            container.ticker.start()
            async let unread: Void = container.unread.startPolling(activity: container.activity)
            async let profileLoad: Void = container.profile.loadProfile()
            _ = await (unread, profileLoad)
        }
        .onDisappear {
            container.ticker.stop()
            container.unread.stopPolling()
        }
        .onChange(of: router.currentScreenName, initial: true) {
            router.reportNavigation()
            container.pruneRoutes()
            updateStatusBar()
        }
        .onChange(of: theme.name) { updateStatusBar() }
    }

    /// The model of the thread on top of the selected tab's stack, if any.
    private var topThreadModel: ThreadModel? {
        guard let route = container.router.currentRouter?.path.last, case .thread = route else { return nil }
        return container.threadModel(for: route)
    }

    private func tab(_ tab: ShellTab, @ViewBuilder content: () -> some View) -> some View {
        let active = container.router.selected == tab
        return content()
            .opacity(active ? 1 : 0)
            .allowsHitTesting(active)
            .accessibilityHidden(!active)
    }

    @ViewBuilder
    private func destination(_ route: Route) -> some View {
        switch route {
        case .thread:
            if let model = container.threadModel(for: route) {
                ThreadScreen(model: model)
            }
        case .profile:
            ProfileScreen(model: container.profile, isTabRoot: false)
        }
    }

    private func updateStatusBar() {
        // The profile banner runs under the status bar with a dark gradient.
        let onProfileHeader = container.router.currentScreenName == "MyProfile"
            || container.router.currentScreenName == "Profile"
        statusBar.style = onProfileHeader ? .lightContent : theme.statusBarStyle
    }
}

private struct SafariView: UIViewControllerRepresentable {
    var url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}

/// Port of `LinkWarning.tsx`.
struct LinkWarningSheet: View {
    var link: PendingLink
    var onVisit: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme

    var body: some View {
        let misleading = link.displayText.contains(".")
        VStack(alignment: .leading, spacing: Space.md) {
            Text(misleading ? "Potentially misleading link" : "Leaving Bluesky")
                .textStyle(size: FontSize._2xl, weight: FontWeight.bold, leading: Leading.snug)
                .foregroundStyle(theme.text)
            Text("This link is taking you to the following website:")
                .textStyle(size: FontSize.md, leading: Leading.snug)
                .foregroundStyle(theme.text)
            Text(link.uri)
                .textStyle(size: FontSize.md, leading: Leading.snug)
                .foregroundStyle(theme.textContrastMedium)
                .padding(.horizontal, Space.md)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(RoundedRectangle(cornerRadius: Radius.sm).stroke(theme.borderContrastLow))
            if misleading {
                Text("Make sure this is where you intend to go!")
                    .textStyle(size: FontSize.md, leading: Leading.snug)
                    .foregroundStyle(theme.text)
            }
            DSButton(title: "Visit site", color: misleading ? .secondaryInverted : .primary, size: .large,
                     fullWidth: true, action: onVisit)
            DSButton(title: "Go back", color: .secondary, size: .large, fullWidth: true) { dismiss() }
        }
        .padding(Space.xl)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(theme.bg)
    }
}

/// Port of `InAppBrowserConsent.tsx`. `onChoose(nil)` means Cancel.
struct InAppBrowserConsentSheet: View {
    var onChoose: (Bool?) -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            Text("How should we open this link?")
                .textStyle(size: FontSize._2xl, weight: FontWeight.bold, leading: Leading.snug)
                .foregroundStyle(theme.text)
            Text("Your choice will be remembered for future links. You can change it at any time in settings.")
                .textStyle(size: FontSize.md, leading: Leading.snug)
                .foregroundStyle(theme.text)
            DSButton(title: "Use in-app browser", color: .primary, size: .large, fullWidth: true) { onChoose(true) }
            DSButton(title: "Use my default browser", color: .secondary, size: .large, fullWidth: true) { onChoose(false) }
            DSButton(title: "Cancel", color: .secondary, size: .large, fullWidth: true) { onChoose(nil) }
        }
        .padding(Space.xl)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(theme.bg)
    }
}
