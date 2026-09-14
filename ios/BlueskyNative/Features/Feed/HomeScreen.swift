import SwiftUI

/// Port of the Home screen with the Following feed (`src/view/screens/Home.tsx`).
struct HomeScreen: View {
    var feed: FeedModel
    var context: AppContext
    var avatarURL: URL?
    var openThread: (String) -> Void

    @Environment(ShellState.self) private var shell
    @State private var selectedTab = 0
    @State private var windowHeight: CGFloat = 874

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ComposerPrompt(avatarURL: avatarURL) {
                    shell.notInShowcase = NotInShowcaseItem(title: "Composer")
                }
                content
            }
        }
        .refreshable { await feed.refresh() }
        .safeAreaInset(edge: .top, spacing: 0) { header }
        .background(Theme.background)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { windowHeight = $0 }
        .toolbar(.hidden, for: .navigationBar)
        .task { await feed.loadIfNeeded() }
    }

    @ViewBuilder
    private var content: some View {
        switch feed.status {
        case .idle, .loading:
            FeedLoadingPlaceholder()
        case .failed(let message):
            FeedErrorRow(message: message) { Task { await feed.refresh() } }
        case .loaded:
            ForEach(FeedRow.rows(for: feed.slices, firstRowHidesBorder: false)) { row in
                switch row.kind {
                case .post(let item, let reason):
                    PostFeedItemView(row: row, item: item, reason: reason,
                                     interactions: context.interactions, onOpen: openThread)
                case .viewFullThread(let rootUri):
                    ViewFullThreadRow { openThread(rootUri) }
                }
            }
            if feed.hasMore {
                Color.clear.frame(height: 1)
                    .onAppear { Task { await feed.loadMore() } }
            }
            if feed.showsFallbackMarker {
                DiscoverFallbackHeader()
            }
            if !feed.hasMore && !feed.isEmpty {
                FollowingEndOfFeed(minHeight: windowHeight * 0.75) {
                    shell.notInShowcase = NotInShowcaseItem(title: $0)
                }
            }
        }
    }

    private var header: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                HeaderIconButton(glyph: .menu, label: "Open drawer menu") {
                    shell.notInShowcase = NotInShowcaseItem(title: "Menu")
                }
                .padding(.leading, -3)
                ShowcaseMark(width: 30)
                    .frame(maxWidth: .infinity)
                HeaderIconButton(glyph: .hashtag, label: "View your feeds and explore more") {
                    shell.notInShowcase = NotInShowcaseItem(title: "Feeds")
                }
                .padding(.trailing, -3)
                .accessibilityIdentifier("viewHeaderHomeFeedPrefsBtn")
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 44)
            .padding(.bottom, 4)

            PagerTabBar(items: ["Following", "Feeds ✨"], selection: $selectedTab, stretches: true,
                        testID: "homeScreenFeedTabs") { index in
                // RN navigates to the Feeds screen from the last tab instead of paging.
                if index == 1 { shell.notInShowcase = NotInShowcaseItem(title: "Feeds") }
            }
        }
        .background(Theme.background.ignoresSafeArea(edges: .top))
        .zIndex(1)
    }
}

/// Port of `src/view/com/feeds/ComposerPrompt.tsx`.
struct ComposerPrompt: View {
    var avatarURL: URL?
    var onCompose: () -> Void

    var body: some View {
        Button(action: onCompose) {
            HStack(alignment: .top, spacing: 12) {
                UserAvatar(url: avatarURL, size: 42)
                HStack {
                    Text("What's up?")
                        .textStyle(size: FontSize.md, leading: 20)
                        .foregroundStyle(Theme.textContrastMedium)
                    Spacer()
                    HStack(spacing: 12) {
                        Icon(.camera, size: IconSize.lg, color: Palette.contrast300)
                            .accessibilityLabel("Open camera")
                        Icon(.image, size: IconSize.lg, color: Palette.contrast300)
                            .accessibilityLabel("Add image")
                    }
                }
                .frame(height: 40)
            }
            .padding(.leading, 18)
            .padding(.trailing, 15)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleStyle(scale: 1))
        .accessibilityLabel("Compose new post")
    }
}

/// Port of `DiscoverFallbackHeader.tsx`.
struct DiscoverFallbackHeader: View {
    var body: some View {
        HStack(spacing: 0) {
            Icon(.info, size: 36, color: Theme.textContrastMedium)
                .padding(.leading, 12)
                .frame(width: 68, alignment: .leading)
            (Text("We ran out of posts from your follows. Here's the latest from ")
                .foregroundStyle(Theme.text)
             + Text("Discover").inter(FontSize.md, FontWeight.semiBold).foregroundStyle(Palette.primary500)
             + Text(".").foregroundStyle(Theme.text))
                .inter(FontSize.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .padding(.top, 1)
        .background(Theme.bgContrast25)
        .overlay(alignment: .top) { Theme.borderContrastLow.frame(height: 1) }
    }
}

/// Port of `FollowingEndOfFeed.tsx`.
struct FollowingEndOfFeed: View {
    /// RN uses 75% of the window height as the minimum height.
    var minHeight: CGFloat
    var onAction: (String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            message("You've reached the end of your feed! Find some more accounts to follow.")
            actionButton("Find accounts to follow").padding(.top, 20)
            message("You can also discover new Custom Feeds to follow.").padding(.top, 20)
            actionButton("Discover new custom feeds").padding(.top, 12)
        }
        .frame(maxWidth: 460)
        .padding(.top, 41)
        .padding(.bottom, 80)
        .padding(.horizontal, 30)
        .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .top)
        .overlay(alignment: .top) { Theme.borderContrastLow.frame(height: 1) }
    }

    private func message(_ text: String) -> some View {
        Text(text)
            .inter(17, FontWeight.semiBold)
            .foregroundStyle(Theme.text)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func actionButton(_ title: String) -> some View {
        Button { onAction(title) } label: {
            HStack(spacing: 6) {
                Text(title)
                    .textStyle(size: FontSize.md, weight: FontWeight.medium, leading: Leading.tight)
                Icon(.chevronRight, size: 18, color: .white)
            }
            .foregroundStyle(.white)
            .padding(.vertical, 12)
            .padding(.horizontal, 24)
            .background(Palette.contrast900, in: Capsule())
        }
        .buttonStyle(PressScaleStyle(scale: 1))
    }
}

/// Loading skeleton, after `PostFeedLoadingPlaceholder`.
struct FeedLoadingPlaceholder: View {
    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<5, id: \.self) { _ in
                HStack(alignment: .top, spacing: 10) {
                    Circle().fill(Theme.bgContrast25).frame(width: 42, height: 42)
                    VStack(alignment: .leading, spacing: 8) {
                        Capsule().fill(Theme.bgContrast25).frame(width: 160, height: 12)
                        Capsule().fill(Theme.bgContrast25).frame(maxWidth: .infinity).frame(height: 12)
                        Capsule().fill(Theme.bgContrast25).frame(width: 200, height: 12)
                    }
                }
                .padding(.leading, 18)
                .padding(.trailing, 15)
                .padding(.vertical, 12)
                .overlay(alignment: .top) { HairlineDivider() }
            }
        }
        .accessibilityLabel("Loading")
    }
}

struct FeedErrorRow: View {
    var message: String
    var retry: () -> Void

    var body: some View {
        Button(action: retry) {
            Text(message)
                .textStyle(size: FontSize.md, leading: Leading.snug)
                .foregroundStyle(Theme.textContrastMedium)
                .multilineTextAlignment(.center)
                .padding(20)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .overlay(alignment: .top) { HairlineDivider() }
    }
}
