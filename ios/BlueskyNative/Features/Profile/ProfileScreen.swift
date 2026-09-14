import Observation
import SwiftUI

/// Loads a profile and its Posts tab. Port of the own-profile path of `Profile.tsx`.
@MainActor
@Observable
final class ProfileModel {
    enum Status: Equatable {
        case loading
        case loaded
        case failed(String)
    }

    private(set) var profile: ProfileViewDetailed?
    private(set) var status: Status = .loading
    let posts: FeedModel

    private let api: any BlueskyAPI
    let actor: String

    init(api: any BlueskyAPI, actor: String) {
        self.api = api
        self.actor = actor
        // The Posts tab uses posts_and_author_threads (Profile.tsx, lib/api/feed/author.ts).
        posts = FeedModel(source: .author(api, actor: actor, filter: .postsAndAuthorThreads))
    }

    func loadProfile() async {
        do {
            profile = try await api.getProfile(actor: actor)
            status = .loaded
        } catch is CancellationError {
            return
        } catch {
            if profile == nil { status = .failed(FeedModel.message(for: error)) }
        }
    }

    func refresh() async {
        async let profileLoad: Void = loadProfile()
        async let postsLoad: Void = posts.refresh()
        _ = await (profileLoad, postsLoad)
    }

    /// RN pluralises each metric label: "1 follower", "2 followers", "1 post".
    static func metricLabel(_ count: Int, one: String, other: String) -> String {
        count == 1 ? one : other
    }

    /// Tabs RN shows on your own profile, in order.
    static let ownProfileTabs = ["Posts", "Replies", "Media", "Videos", "Likes", "Feeds", "Starter Packs", "Lists"]
}

/// Port of the profile screen header (`ProfileHeaderStandard.tsx`, `Shell.tsx`) and the Posts tab.
struct ProfileScreen: View {
    var model: ProfileModel
    var context: AppContext
    var openThread: (String) -> Void

    @Environment(ShellState.self) private var shell
    @State private var selectedTab = 0

    var body: some View {
        GeometryReader { proxy in
            let topInset = proxy.safeAreaInsets.top
            ScrollView {
                LazyVStack(spacing: 0, pinnedViews: []) {
                    header(topInset: topInset)
                    PagerTabBar(items: ProfileModel.ownProfileTabs, selection: $selectedTab, stretches: false,
                                testID: "profilePager")
                        .background(Theme.background)
                    if selectedTab == 0 {
                        postsTab
                    } else {
                        NotInShowcaseView(title: ProfileModel.ownProfileTabs[selectedTab])
                            .frame(height: 320)
                    }
                }
            }
            .ignoresSafeArea(edges: .top)
            .refreshable { await model.refresh() }
        }
        .background(Theme.background)
        .toolbar(.hidden, for: .navigationBar)
        .task { await model.posts.loadIfNeeded() }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("profileView")
    }

    private func header(topInset: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Banner: 150pt, contrast_25 when the profile has none, under the status bar.
            ZStack(alignment: .top) {
                if let banner = model.profile?.banner {
                    AsyncImage(url: banner) { $0.resizable().scaledToFill() } placeholder: { Theme.bgContrast25 }
                } else {
                    Theme.bgContrast25
                }
                LinearGradient(colors: [Color.black.opacity(0.5), .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: topInset)
            }
            .frame(height: 150)
            .frame(maxWidth: .infinity)
            .clipped()
            .accessibilityIdentifier(model.profile?.banner == nil ? "userBannerFallback" : "userBannerImage")

            headerBody
        }
        .overlay(alignment: .topLeading) {
            UserAvatar(url: model.profile?.avatar, size: 90, showsBorder: false)
                .frame(width: 90, height: 90)
                .padding(2)
                .background(Theme.background, in: Circle())
                .padding(.leading, 10)
                .padding(.top, 104)
                .accessibilityIdentifier("profileHeaderAviButton")
        }
    }

    private var headerBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                Spacer(minLength: 0)
                Button { shell.notInShowcase = NotInShowcaseItem(title: "Edit Profile") } label: {
                    Text("Edit Profile")
                        .textStyle(size: FontSize.sm, weight: FontWeight.medium, leading: Leading.snug)
                        .foregroundStyle(Theme.textContrastMedium)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 14)
                        .background(Theme.bgContrast50, in: Capsule())
                }
                .buttonStyle(PressScaleStyle(scale: 1))
                .accessibilityIdentifier("profileHeaderEditProfileButton")
                roundButton(.share, id: "profileHeaderShareButton", label: "Share") {
                    shell.notInShowcase = NotInShowcaseItem(title: "Share")
                }
                roundButton(.more, id: "profileHeaderDropdownBtn", label: "More options") {
                    shell.notInShowcase = NotInShowcaseItem(title: "More options")
                }
            }
            .padding(.leading, 90)
            .padding(.bottom, 8)

            if let profile = model.profile {
                VStack(alignment: .leading, spacing: 4) {
                    Text(profile.displayName?.isEmpty == false ? profile.displayName! : profile.handle)
                        .textStyle(size: FontSize._3xl, weight: FontWeight.bold, leading: Leading.tight)
                        .foregroundStyle(Theme.text)
                        .accessibilityIdentifier("profileHeaderDisplayName")
                    Text("@\(profile.handle)")
                        .textStyle(size: FontSize.md, leading: Leading.snug)
                        .foregroundStyle(Theme.textContrastMedium)
                        .lineLimit(1)
                }
                .padding(.top, 2)
                .padding(.bottom, 8)

                VStack(alignment: .leading, spacing: 12) {
                    // Measured: the RN metrics row is about 1.75pt taller than its text.
                    metrics(profile)
                        .padding(.bottom, 1.75)
                    if let description = profile.description, !description.isEmpty {
                        Text(description)
                            .textStyle(size: FontSize.md, leading: Leading.snug)
                            .foregroundStyle(Theme.text)
                            .lineLimit(15)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("profileHeaderDescription")
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        // RN: pb 8. Measured 1pt less between the bio and the tab bar in the RN screenshot.
        .padding(.bottom, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func metrics(_ profile: ProfileViewDetailed) -> some View {
        let followers = profile.followersCount ?? 0
        let follows = profile.followsCount ?? 0
        let posts = profile.postsCount ?? 0
        return HStack(spacing: 8) {
            metric(followers, ProfileModel.metricLabel(followers, one: "follower", other: "followers"))
                .accessibilityIdentifier("profileHeaderFollowersButton")
            metric(follows, "following")
                .accessibilityIdentifier("profileHeaderFollowsButton")
            metric(posts, ProfileModel.metricLabel(posts, one: "post", other: "posts"))
        }
    }

    private func metric(_ count: Int, _ label: String) -> some View {
        (Text(CountFormat.format(count)).inter(FontSize.md, FontWeight.semiBold).foregroundStyle(Theme.text)
         + Text(" \(label)").inter(FontSize.md).foregroundStyle(Theme.textContrastMedium))
            .textStyle(size: FontSize.md, leading: Leading.snug)
            .lineLimit(1)
    }

    private func roundButton(_ glyph: IconGlyph, id: String, label: String,
                             action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Icon(glyph, size: 16, color: Theme.textContrastMedium)
                .frame(width: 33, height: 33)
                .background(Theme.bgContrast50, in: Circle())
        }
        .buttonStyle(PressScaleStyle(scale: 1))
        .accessibilityLabel(label)
        .accessibilityIdentifier(id)
    }

    @ViewBuilder
    private var postsTab: some View {
        let feed = model.posts
        switch feed.status {
        case .idle, .loading:
            FeedLoadingPlaceholder()
        case .failed(let message):
            FeedErrorRow(message: message) { Task { await feed.refresh() } }
        case .loaded:
            ForEach(FeedRow.rows(for: feed.slices, firstRowHidesBorder: true)) { row in
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
            } else {
                Text(feed.isEmpty ? "No posts yet" : "End of feed")
                    .inter(FontSize.sm)
                    .foregroundStyle(Theme.textContrastMedium)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .overlay(alignment: .top) { HairlineDivider() }
            }
        }
    }
}
