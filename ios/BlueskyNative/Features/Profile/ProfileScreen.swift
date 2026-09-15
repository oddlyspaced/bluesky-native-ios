import SwiftUI

/// Port of the own profile screen (`src/view/screens/Profile.tsx`, `Header/Shell.tsx`,
/// `ProfileHeaderStandard.tsx`, `Metrics.tsx`) with the Posts tab.
struct ProfileScreen: View {
    var model: ProfileModel
    /// True for the Profile tab root; false when pushed from a mention.
    var isTabRoot: Bool

    @Environment(AccountContainer.self) private var container
    @Environment(\.theme) private var theme
    @Environment(\.haptics) private var haptics
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0

    private static let topID = "profileTop"

    /// RN wraps `profileView` (`Profile.tsx:393`) in `Layout.Screen testID="profileScreen"`
    /// (`Profile.tsx:63`). The outer id sits on its own container with a zero-size second child, so
    /// SwiftUI keeps it as a separate accessibility element and the inner `profileView` (or
    /// `profileErrorScreen`) stays exposed. Measured with `maestro hierarchy` (review finding F2).
    var body: some View {
        VStack(spacing: 0) {
            screen
            Color.clear.frame(width: 0, height: 0).accessibilityElement(children: .ignore)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("profileScreen")
    }

    private var screen: some View {
        Group {
            switch model.status {
            case .loading:
                ProfileHeaderLoading()
                    .frame(maxHeight: .infinity, alignment: .top)
                    .ignoresSafeArea(edges: .top)
            case .failed(let title, let message):
                VStack(spacing: 0) {
                    ScreenHeader {
                        if !isTabRoot {
                            HeaderIconButton(glyph: .back, label: "Go back") { dismiss() }
                        }
                    } center: {
                        HeaderTitle(title: "Error")
                    } trailing: {
                        EmptyView()
                    }
                    ErrorScreenContent(title: title, message: message, testID: "profileErrorScreen") {
                        Task { await model.retry() }
                    }
                    Spacer(minLength: 0)
                }
            case .loaded:
                content
            }
        }
        .background(theme.bg)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            // The shell starts the profile load at sign-in. A failed load keeps its error screen
            // until Retry, as RN does; appearing again does not retry on its own.
            if model.status == .loading { await model.loadProfile() }
            await model.posts.loadIfNeeded()
        }
    }

    private var content: some View {
        GeometryReader { proxy in
            let topInset = proxy.safeAreaInsets.top
            ScrollViewReader { scroll in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        header(topInset: topInset).id(Self.topID)
                        PagerTabBar(items: ProfileModel.ownProfileTabs, selection: $selectedTab, stretches: false,
                                    testID: "profilePager")
                            .background(theme.bg)
                            // RN draws the bar's hairline below it (`top: '100%'`) on top of the feed.
                            .zIndex(1)
                        if selectedTab == 0 {
                            FeedRows(model: model.posts, eventContext: .feedItem(nil), footerMinHeight: 64) {
                                EmptyView()
                            } emptyState: {
                                ProfileEmptyState {
                                    container.shell.notInShowcase = NotInShowcaseItem(title: "Composer")
                                }
                            } endOfFeed: {
                                Text("End of feed")
                                    .textStyle(size: FontSize.sm, leading: Leading.snug)
                                    .foregroundStyle(theme.textContrastMedium)
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, Space._5xl)
                                    .overlay(alignment: .top) { HairlineDivider() }
                            }
                            .accessibilityElement(children: .contain)
                            .accessibilityIdentifier("postsFeed-flatlist")
                        } else {
                            NotInShowcaseView(title: ProfileModel.ownProfileTabs[selectedTab])
                                .frame(height: 320)
                        }
                    }
                }
                .accessibilityIdentifier("postsFeed")
                .ignoresSafeArea(edges: .top)
                .refreshable { await model.refresh() }
                .onChange(of: container.router.routers[.profile]?.softResetToken) {
                    withAnimation { scroll.scrollTo(Self.topID, anchor: .top) }
                    Task { await model.posts.reload() }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("profileView")
    }

    private func header(topInset: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .top) {
                if let banner = model.profile?.banner {
                    RemoteImage(url: banner, pointSize: 402) { theme.bgContrast25 }
                } else {
                    theme.bgContrast25
                }
                // `StatusBarShadow`: a 50% to 0% black gradient as tall as the top inset.
                LinearGradient(colors: [Color.black.opacity(0.5), .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: topInset)
            }
            .frame(height: Layout.bannerHeight)
            .frame(maxWidth: .infinity)
            .clipped()
            .accessibilityElement()
            .accessibilityLabel(model.profile?.banner == nil ? "Profile banner placeholder" : "View profile banner")
            .accessibilityIdentifier(model.profile?.banner == nil ? "userBannerFallback" : "userBannerImage")

            headerBody
        }
        .overlay(alignment: .topLeading) {
            Button {
                container.shell.notInShowcase = NotInShowcaseItem(title: "Avatar")
            } label: {
                UserAvatar(url: model.profile?.avatar, size: AvatarSize.profile, showsBorder: false)
                    .frame(width: AvatarSize.profile, height: AvatarSize.profile)
                    .padding(Space._2xs)
                    .background(theme.bg, in: Circle())
            }
            .buttonStyle(.plain)
            .padding(.leading, 10)
            .padding(.top, Layout.profileAvatarTop)
            .accessibilityLabel("View \(model.profile?.handle ?? "")'s avatar")
            .accessibilityAddTraits(.isImage)
            .accessibilityIdentifier("profileHeaderAviButton")
        }
        .overlay(alignment: .topLeading) {
            if !isTabRoot {
                Button { dismiss() } label: {
                    Icon(.back, size: IconSize.lg, color: theme.palette.white)
                        .frame(width: 31, height: 31)
                        .background(Color.black.opacity(0.5), in: Circle())
                }
                .buttonStyle(.plain)
                .padding(.leading, Space.md)
                .padding(.top, topInset)
                .accessibilityLabel("Back")
                .accessibilityIdentifier("profileHeaderBackBtn")
            }
        }
    }

    /// `ProfileHeaderStandard.tsx:113-170`: px 16, pt 12, pb 8; buttons row gap 4, pb 8;
    /// name and handle column gap 4, pt 2, pb 8; metrics and bio gap 12.
    private var headerBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Space.xs) {
                Spacer(minLength: 0)
                DSButton(title: "Edit Profile", accessibilityLabel: "Edit profile", color: .secondary, size: .small) {
                    haptics.play(.light)
                    container.shell.notInShowcase = NotInShowcaseItem(title: "Edit Profile")
                }
                .accessibilityIdentifier("profileHeaderEditProfileButton")
                DSIconButton(glyph: .share, label: "Invite friends") {
                    haptics.play(.light)
                    container.analytics.metric("invite:dialog:open", ["logContext": "ProfileHeader"])
                    container.shell.notInShowcase = NotInShowcaseItem(title: "Invite friends")
                }
                .accessibilityIdentifier("profileHeaderShareButton")
                DSIconButton(glyph: .more, label: "More options") {
                    container.shell.notInShowcase = NotInShowcaseItem(title: "More options")
                }
                .accessibilityIdentifier("profileHeaderDropdownBtn")
            }
            .padding(.leading, AvatarSize.profile)
            .padding(.bottom, Space.sm)

            if let profile = model.profile {
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text(Names.displayNameOrHandle(displayName: profile.displayName, handle: profile.handle))
                        .textStyle(size: FontSize._3xl, weight: FontWeight.bold, leading: Leading.tight,
                                   adjustment: RNLineBox.profileDisplayName)
                        .foregroundStyle(theme.text)
                        .accessibilityIdentifier("profileHeaderDisplayName")
                    Text(Names.sanitizeHandle(profile.handle, prefix: "@"))
                        .textStyle(size: FontSize.md, leading: Leading.snug, adjustment: RNLineBox.profileHandle)
                        .foregroundStyle(theme.textContrastMedium)
                        .lineLimit(1)
                }
                .padding(.top, Space._2xs)
                .padding(.bottom, Space.sm)

                VStack(alignment: .leading, spacing: Space.md) {
                    metrics(profile)
                    if let description = profile.description, !description.isEmpty {
                        RichTextView(text: description, facets: model.descriptionFacets, size: FontSize.md, lineLimit: 15,
                                     testID: "profileHeaderDescription",
                                     lineBoxAdjustment: RNLineBox.profileDescription)
                    }
                }
            }
        }
        .padding(.horizontal, Space.lg)
        .padding(.top, Space.md)
        .padding(.bottom, Space.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func metrics(_ profile: ProfileViewDetailed) -> some View {
        let followers = profile.followersCount ?? 0
        let follows = profile.followsCount ?? 0
        let posts = profile.postsCount ?? 0
        return HStack(spacing: Space.sm) {
            metric(followers, ProfileModel.followersLabel(followers))
                .accessibilityLabel("\(followers) \(ProfileModel.followersLabel(followers))")
                .accessibilityIdentifier("profileHeaderFollowersButton")
            metric(follows, "following")
                .accessibilityLabel("\(follows) following")
                .accessibilityIdentifier("profileHeaderFollowsButton")
            metric(posts, ProfileModel.postsLabel(posts))
        }
    }

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private func metric(_ count: Int, _ label: String) -> some View {
        let fonts = ScaledFonts(multiplier: FontScale.multiplier(for: dynamicTypeSize))
        return (Text(CountFormat.format(count) + " ").font(fonts.font(FontSize.md, FontWeight.semiBold))
            .foregroundStyle(theme.text)
            + Text(label).font(fonts.font(FontSize.md)).foregroundStyle(theme.textContrastMedium))
            .textStyle(size: FontSize.md, leading: Leading.snug, adjustment: RNLineBox.profileMetrics)
            .lineLimit(1)
    }
}

/// `ProfileHeaderLoading` (`src/screens/Profile/Header/index.tsx:34-54`).
struct ProfileHeaderLoading: View {
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            theme.bgContrast50.frame(height: Layout.bannerHeight)
            HStack {
                Spacer()
                Capsule().fill(theme.bgContrast50).frame(width: 140, height: 34)
            }
            .padding(.horizontal, Space.lg)
            .padding(.top, Space.md)
        }
        .overlay(alignment: .topLeading) {
            Circle().fill(theme.bgContrast50)
                .frame(width: AvatarSize.profile, height: AvatarSize.profile)
                .padding(Space._2xs)
                .background(theme.bg, in: Circle())
                .padding(.leading, 10)
                .padding(.top, Layout.profileAvatarTop)
        }
        .accessibilityLabel("Loading")
    }
}

/// `EmptyState` (`src/view/com/util/EmptyState.tsx`) for the own Posts tab: "No posts yet"
/// and a "Write a post" button (`Profile.tsx:436-454`).
struct ProfileEmptyState: View {
    var onWrite: () -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            Icon(.compose, size: 40, color: theme.textContrastLow)
                .frame(width: 64, height: 64)
                .padding(.top, Space._5xl)
            Text("No posts yet")
                .textStyle(size: FontSize.md, weight: FontWeight.medium, leading: Leading.snug)
                .foregroundStyle(theme.textContrastHigh)
                .multilineTextAlignment(.center)
                .padding(.top, Space.xs)
            DSButton(title: "Write a post", color: .primary, size: .small, action: onWrite)
                .padding(.top, Space.md)
                .padding(.bottom, Space._5xl)
        }
        .frame(maxWidth: .infinity)
    }
}
