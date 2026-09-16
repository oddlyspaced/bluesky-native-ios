import SafariServices
import SwiftUI

/// Port of the RN bottom-tab shell (`src/view/shell`), with Home and Profile ported.
///
/// Tabs are a `ZStack` of per-tab `NavigationStack`s under the custom `BottomBar`, not a
/// `TabView` with its bar hidden. Reason (review finding A16): `TabView` on iOS 26 reserves
/// the system tab bar's safe area and draws its own background under the hidden bar, which
/// moved the feed and the bar by several pixels against the RN captures. Routers are keyed by
/// tab and screens come from `ScreenRegistry` (review finding A58). Like RN's lazy tabs, a tab
/// mounts on first visit and stays mounted.
struct TabShell: View {
    @Environment(AccountContainer.self) private var container
    @Environment(StatusBarAppearance.self) private var statusBar
    @Environment(\.theme) private var theme

    var body: some View {
        @Bindable var shell = container.shell
        @Bindable var links = container.links
        let router = container.router
        ZStack {
            ForEach(router.stackTabs.filter(router.visited.contains), id: \.self) { tab in
                if let tabRouter = router.routers[tab] {
                    TabStack(router: tabRouter, container: container)
                        .opacity(router.selected == tab ? 1 : 0)
                        .allowsHitTesting(router.selected == tab)
                        .accessibilityHidden(router.selected != tab)
                }
            }
            if !router.stackTabs.contains(router.selected) {
                NotInShowcaseView(title: router.selected.title)
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
            let showsReplyPrompt = container.topThreadModel?.canReply ?? false
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
        .sheet(item: $shell.shareURL) { item in
            ShareSheet(url: item.url)
                .presentationDetents([.medium, .large])
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
            // RN's `onStateChange` runs in the container's effect, after the focused screen's own
            // effects (`BaseNavigationContainer.tsx:322-399`), so the event waits one main-actor
            // turn, after screen handlers such as Home's `home:feedDisplayed` focus event.
            Task { @MainActor in router.reportNavigation() }
            updateStatusBar()
        }
        // Pruning follows route identity, not the screen name. A PostThread pushed from a
        // PostThread keeps the name "PostThread", so a name-keyed prune never ran and the popped
        // screen's model and its whole thread response leaked (review finding A72).
        .onChange(of: router.allRoutes) {
            container.pruneRoutes()
        }
        .onChange(of: theme.name) { updateStatusBar() }
    }

    private func updateStatusBar() {
        // The profile banner runs under the status bar with a dark gradient.
        let onProfileHeader = container.router.currentScreenName == "MyProfile"
            || container.router.currentScreenName == "Profile"
        statusBar.style = onProfileHeader ? .lightContent : theme.statusBarStyle
    }
}

/// One tab's stack: its root screen and pushed routes from the registry.
private struct TabStack: View {
    @Bindable var router: TabRouter
    let container: AccountContainer

    var body: some View {
        // RN `Layout.Screen testID="HomeScreen"` (`Home.tsx:95`) wraps the whole Home screen. The id
        // sits on the hosting stack, a separate container from the screen's own `homeScreen`, so
        // both ids stay exposed (measured with `maestro hierarchy`, review finding F2).
        //
        // The tab's feature registers the id; the shell no longer names a tab (review finding A71).
        if let identifier = container.registry.rootIdentifier(for: router.tab) {
            stack.accessibilityElement(children: .contain).accessibilityIdentifier(identifier)
        } else {
            stack
        }
    }

    private var stack: some View {
        // `interactivePopEnabled` re-enables this stack's pop gestures, which SwiftUI disables with
        // the hidden toolbar, and it reaches only this stack (review findings N16, A63).
        NavigationStack(path: $router.path) {
            container.registry.root(for: router.tab, container: container)
                .interactivePopEnabled()
                .navigationDestination(for: Route.self) { route in
                    container.registry.view(for: route, container: container)
                        .interactivePopEnabled()
                }
        }
    }
}

private struct SafariView: UIViewControllerRepresentable {
    var url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}

/// The system share sheet for one URL (RN `shareUrl`, `src/lib/sharing.ts`).
private struct ShareSheet: UIViewControllerRepresentable {
    var url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
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
            DSButton(title: link.share ? "Share link" : "Visit site", color: misleading ? .secondaryInverted : .primary,
                     size: .large, fullWidth: true, action: onVisit)
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
