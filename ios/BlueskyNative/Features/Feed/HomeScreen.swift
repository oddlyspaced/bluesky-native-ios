import SwiftUI

/// Port of the Home screen with the Following feed (`src/view/screens/Home.tsx`,
/// `HomeHeaderLayoutMobile.tsx`, `FeedPage.tsx`).
struct HomeScreen: View {
    @Environment(AccountContainer.self) private var container
    @Environment(\.theme) private var theme
    @Environment(\.haptics) private var haptics
    @State private var selectedTab = 0
    @State private var windowHeight: CGFloat = 0
    @State private var headerHeight: CGFloat = 0
    @State private var header = MinimalShellHeader()

    /// `useHeaderOffset` at font scale 1: 52 + 23 + 20 - 4.
    private static let headerOffset: CGFloat = 91

    private var feed: FeedModel { container.homeFeed }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    Color.clear.frame(height: 0).id(Self.topID)
                        .onGeometryChange(for: CGFloat.self) { $0.frame(in: .scrollView).minY } action: { minY in
                            header.scrolled(to: -minY, headerHeight: headerHeight)
                        }
                    FeedRows(model: feed, eventContext: .feedItem(feed.feedDescriptor),
                             footerMinHeight: max(Self.headerOffset, 32) * 2) {
                        ComposerPrompt(avatarURL: container.profile.profile?.avatar)
                    } emptyState: {
                        FollowingEmptyState()
                    } endOfFeed: {
                        FollowingEndOfFeed(minHeight: windowHeight * Layout.endOfFeedHeightFraction)
                    }
                }
                .accessibilityIdentifier("followingFeedPage-feed-flatlist")
            }
            .accessibilityIdentifier("followingFeedPage-feed")
            // `FeedPage testID="followingFeedPage"` (`Home.tsx:320`) wraps the feed list.
            .accessibilityElement(children: .contain)
            .refreshable { await feed.pullToRefresh() }
            .safeAreaInset(edge: .top, spacing: 0) {
                headerView
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { headerHeight = $0 }
                    .offset(y: -header.mode * headerHeight)
                    .opacity((1 - header.mode) * (1 - header.mode))
                    .allowsHitTesting(header.mode == 0)
            }
            .onChange(of: container.router.homeSoftResetToken) {
                withAnimation { proxy.scrollTo(Self.topID, anchor: .top) }
                header.show()
                container.analytics.metric("feed:refresh", ["feedType": .string(feed.feedType),
                                                            "feedUrl": .string(feed.feedDescriptor),
                                                            "reason": "soft-reset"])
                Task { await feed.reload() }
            }
        }
        .background(theme.bg)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { windowHeight = $0 }
        .toolbar(.hidden, for: .navigationBar)
        .task { await feed.loadIfNeeded() }
        .onChange(of: container.router.currentScreenName, initial: true) { _, screen in
            // `useFocusEffect` in `Home.tsx:175-186`: every time Home becomes the focused screen.
            guard screen == ShellTab.home.rootRouteName else { return }
            container.analytics.metric("home:feedDisplayed", [
                "index": 0, "feedType": .string(feed.feedType), "feedUrl": .string(feed.feedDescriptor),
                "reason": "focus",
            ])
        }
        .accessibilityIdentifier("homeScreen")
    }

    private static let topID = "homeTop"

    private var headerView: some View {
        VStack(spacing: 0) {
            HStack(spacing: Space.sm) {
                HeaderIconButton(glyph: .menu, label: "Open drawer menu") {
                    container.analytics.metric("nav:click", ["item": "menu", "surface": "topBar"])
                    container.shell.notInShowcase = NotInShowcaseItem(title: "Menu")
                }
                .padding(.leading, -3)
                Button(action: onLogoPress) {
                    ShowcaseMark(width: 30)
                }
                .buttonStyle(PressScaleStyle(scale: 0.9))
                .frame(maxWidth: .infinity)
                HeaderIconButton(glyph: .hashtag, label: "View your feeds and explore more") {
                    container.analytics.metric("nav:click", ["item": "feeds", "surface": "topBar"])
                    container.shell.notInShowcase = NotInShowcaseItem(title: "Feeds")
                }
                .padding(.trailing, -3)
                .accessibilityIdentifier("viewHeaderHomeFeedPrefsBtn")
            }
            .padding(.horizontal, Layout.gutter)
            .frame(minHeight: Layout.headerMinHeight - Space.xs)
            .padding(.bottom, Space.xs)

            PagerTabBar(items: ["Following", "Feeds ✨"], selection: $selectedTab, stretches: true,
                        testID: "homeScreenFeedTabs") { index in
                if index == 0 {
                    // Re-selecting the current feed tab soft-resets it (`Home.tsx:209-211`).
                    container.router.softResetHome()
                } else {
                    // RN navigates to the Feeds screen from the last tab instead of paging.
                    container.shell.notInShowcase = NotInShowcaseItem(title: "Feeds")
                }
            }
        }
        .background(theme.bg.ignoresSafeArea(edges: .top))
        .zIndex(1)
    }

    /// `HomeHeaderLayoutMobile.tsx:66-77`: in dev builds the logo opens the Debug screen;
    /// otherwise it plays a light haptic and soft-resets the feed.
    private func onLogoPress() {
        #if DEBUG
        container.shell.notInShowcase = NotInShowcaseItem(title: "Debug")
        #else
        haptics.play(.light)
        container.router.softResetHome()
        #endif
    }
}

/// Port of RN's minimal-shell header mode (`MainScrollProvider.tsx`): 0 is visible, 1 hidden.
///
/// SwiftUI on iOS 17 has no drag begin and end callbacks for `ScrollView`, so the port follows
/// the scroll delta continuously (`mode += dy / headerHeight`, clamped) and always shows the
/// header within one header height of the top. RN also snaps when a drag ends; PARITY.md
/// records this difference.
@MainActor
@Observable
final class MinimalShellHeader {
    private(set) var mode: CGFloat = 0
    @ObservationIgnored private var lastOffset: CGFloat = 0

    func scrolled(to rawOffset: CGFloat, headerHeight: CGFloat) {
        let offset = max(0, rawOffset)
        defer { lastOffset = offset }
        guard headerHeight > 0 else { return }
        if offset < headerHeight {
            if mode != 0 { withAnimation(.spring(duration: 0.3)) { mode = 0 } }
            return
        }
        let next = min(1, max(0, mode + (offset - lastOffset) / headerHeight))
        if next != mode { mode = next }
    }

    func show() {
        withAnimation(.spring(duration: 0.3)) { mode = 0 }
    }
}

/// Port of `src/view/com/feeds/ComposerPrompt.tsx`.
struct ComposerPrompt: View {
    var avatarURL: URL?

    @Environment(AccountContainer.self) private var container
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(alignment: .top, spacing: Space.md) {
            UserAvatar(url: avatarURL, size: AvatarSize.post)
            HStack {
                Text("What's up?")
                    .textStyle(size: FontSize.md, leading: 20)
                    .foregroundStyle(theme.textContrastMedium)
                Spacer()
                HStack(spacing: Space.md) {
                    iconButton(.camera, label: "Open camera", hint: "Opens device camera",
                               event: "composerPrompt:camera:press", title: "Camera")
                    iconButton(.image, label: "Add image", hint: "Opens image picker",
                               event: "composerPrompt:gallery:press", title: "Image picker")
                }
            }
            .frame(height: 40)
        }
        .padding(.leading, 18)
        .padding(.trailing, 15)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .onTapGesture(perform: compose)
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: "Compose new post", compose)
        .accessibilityLabel("Compose new post")
        .accessibilityHint("Opens the post composer")
    }

    private func compose() {
        container.analytics.metric("composerPrompt:press")
        container.shell.notInShowcase = NotInShowcaseItem(title: "Composer")
    }

    private func iconButton(_ glyph: IconGlyph, label: String, hint: String, event: String,
                            title: String) -> some View {
        Button {
            container.analytics.metric(event)
            container.shell.notInShowcase = NotInShowcaseItem(title: title)
        } label: {
            Icon(glyph, size: IconSize.lg, color: theme.palette.contrast300)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleStyle(scale: 1))
        .accessibilityLabel(label)
        .accessibilityHint(hint)
    }
}

/// Port of `FollowingEndOfFeed.tsx`.
struct FollowingEndOfFeed: View {
    /// RN uses 75% of the window height as the minimum height.
    var minHeight: CGFloat

    @Environment(AccountContainer.self) private var container
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            FollowingMessage(text: "You've reached the end of your feed! Find some more accounts to follow.")
            DSButton(title: "Find accounts to follow", color: .secondaryInverted, size: .large,
                     icon: .chevronRight, iconPosition: .trailing) {
                container.shell.notInShowcase = NotInShowcaseItem(title: "Find accounts to follow")
            }
            .padding(.top, Space.xl)
            FollowingMessage(text: "You can also discover new Custom Feeds to follow.").padding(.top, Space.xl)
            DSButton(title: "Discover new custom feeds", color: .secondaryInverted, size: .large,
                     icon: .chevronRight, iconPosition: .trailing) {
                container.shell.notInShowcase = NotInShowcaseItem(title: "Discover new custom feeds")
            }
            .padding(.top, Space.md)
        }
        .frame(maxWidth: 460)
        .padding(.top, 41)
        .padding(.bottom, 80)
        .padding(.horizontal, 30)
        .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .top)
        .overlay(alignment: .top) { theme.borderContrastLow.frame(height: 1) }
    }
}

/// Port of `FollowingEmptyState.tsx`.
struct FollowingEmptyState: View {
    @Environment(AccountContainer.self) private var container
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            Icon(.magnifyingGlass, size: 62, color: theme.textContrastMedium)
                .padding(.bottom, Space.lg)
            FollowingMessage(text: "Your following feed is empty! Follow more users to see what's happening.")
            DSButton(title: "Find accounts to follow", color: .secondaryInverted, size: .large,
                     icon: .chevronRight, iconPosition: .trailing) {
                container.shell.notInShowcase = NotInShowcaseItem(title: "Find accounts to follow")
            }
            .padding(.top, Space.xl)
            FollowingMessage(text: "You can also discover new Custom Feeds to follow.").padding(.top, Space.xl)
            DSButton(title: "Discover new custom feeds", color: .secondaryInverted, size: .large,
                     icon: .chevronRight, iconPosition: .trailing) {
                container.shell.notInShowcase = NotInShowcaseItem(title: "Discover new custom feeds")
            }
            .padding(.top, Space.md)
        }
        .frame(maxWidth: 460)
        .padding(.vertical, Space._5xl)
        .padding(.horizontal, 30)
        .frame(maxWidth: .infinity)
    }
}

private struct FollowingMessage: View {
    var text: String
    @Environment(\.theme) private var theme

    var body: some View {
        // Legacy `Text type="xl-medium"`: 17pt semi-bold with the measured legacy-text tracking.
        Text(text)
            .textStyle(size: 17, weight: FontWeight.semiBold, legacyText: true)
            .foregroundStyle(theme.text)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
    }
}
