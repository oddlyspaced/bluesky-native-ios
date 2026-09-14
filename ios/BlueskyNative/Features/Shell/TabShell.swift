import Observation
import SwiftUI

enum ShellTab: Hashable {
    case home, search, messages, notifications, profile

    var title: String {
        switch self {
        case .home: "Home"
        case .search: "Search"
        case .messages: "Chat"
        case .notifications: "Notifications"
        case .profile: "Profile"
        }
    }
}

/// Screens pushed inside a tab.
enum Route: Hashable {
    case thread(uri: String)
}

/// Shell-level UI state that screens can change.
@MainActor
@Observable
final class ShellState {
    /// The thread screen hides the bar's top border behind its reply prompt.
    var hidesBottomBarBorder = false
    /// Title of a feature that is not ported, shown in a sheet.
    var notInShowcase: NotInShowcaseItem?
}

struct NotInShowcaseItem: Identifiable, Hashable {
    var title: String
    var id: String { title }
}

/// Port of the RN bottom-tab shell (`src/view/shell`), with Home and Profile ported.
struct TabShell: View {
    let context: AppContext

    @Environment(StatusBarAppearance.self) private var statusBar
    @Environment(PostShadowStore.self) private var shadows
    @State private var selected: ShellTab = .home
    @State private var homePath: [Route] = []
    @State private var profilePath: [Route] = []
    @State private var visitedProfile = false
    @State private var shell = ShellState()
    @State private var unread: UnreadNotificationsModel
    @State private var homeFeed: FeedModel
    @State private var profile: ProfileModel

    init(context: AppContext) {
        self.context = context
        _unread = State(initialValue: UnreadNotificationsModel(api: context.api))
        _homeFeed = State(initialValue: FeedModel(source: .following(context.api)))
        _profile = State(initialValue: ProfileModel(api: context.api, actor: context.accountDid))
    }

    var body: some View {
        ZStack {
            tab(.home) {
                NavigationStack(path: $homePath) {
                    HomeScreen(feed: homeFeed, context: context, avatarURL: profile.profile?.avatar,
                               openThread: { homePath.append(.thread(uri: $0)) })
                        .navigationDestination(for: Route.self, destination: destination)
                }
            }
            if visitedProfile {
                tab(.profile) {
                    NavigationStack(path: $profilePath) {
                        ProfileScreen(model: profile, context: context,
                                      openThread: { profilePath.append(.thread(uri: $0)) })
                            .navigationDestination(for: Route.self, destination: destination)
                    }
                }
            }
            switch selected {
            case .search, .messages, .notifications:
                NotInShowcaseView(title: selected.title)
            case .home, .profile:
                EmptyView()
            }
            if (selected == .home && homePath.isEmpty) || (selected == .profile && profilePath.isEmpty) {
                // Positioned against the bottom bar, not the scroll view, which extends under it.
                ComposeFAB { shell.notInShowcase = NotInShowcaseItem(title: "Composer") }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            BottomBar(selected: selected, unreadText: unread.displayText,
                      avatarURL: profile.profile?.avatar, hidesBorder: shell.hidesBottomBarBorder,
                      onSelect: select)
        }
        .environment(shell)
        .sheet(item: $shell.notInShowcase) { item in
            NotInShowcaseView(title: item.title)
                .presentationDetents([.medium])
        }
        .task {
            await unread.load()
            await profile.loadProfile()
        }
        .onChange(of: selected) { updateStatusBar() }
        .onChange(of: profilePath) { updateStatusBar() }
    }

    private func tab(_ tab: ShellTab, @ViewBuilder content: () -> some View) -> some View {
        let active = selected == tab
        return content()
            .opacity(active ? 1 : 0)
            .allowsHitTesting(active)
            .accessibilityHidden(!active)
    }

    @ViewBuilder
    private func destination(_ route: Route) -> some View {
        switch route {
        case .thread(let uri):
            ThreadScreen(model: ThreadModel(api: context.api, uri: uri), context: context)
        }
    }

    private func select(_ tab: ShellTab) {
        if tab == selected {
            // Re-tapping the active tab returns to its root, as in RN.
            switch tab {
            case .home: homePath.removeAll()
            case .profile: profilePath.removeAll()
            default: break
            }
            return
        }
        if tab == .profile { visitedProfile = true }
        selected = tab
    }

    private func updateStatusBar() {
        // The profile banner runs under the status bar with a dark gradient.
        statusBar.style = selected == .profile && profilePath.isEmpty ? .lightContent : .darkContent
    }
}

/// Port of `countUnread` (`src/state/queries/notifications/unread.tsx`).
@MainActor
@Observable
final class UnreadNotificationsModel {
    private(set) var count = 0
    private let api: any BlueskyAPI

    init(api: any BlueskyAPI) {
        self.api = api
    }

    /// "" for zero, "30+" from 30, otherwise the number.
    var displayText: String {
        count >= 30 ? "30+" : count == 0 ? "" : String(count)
    }

    func load() async {
        guard let notifications = try? await api.listNotifications(limit: 40) else { return }
        count = Self.countUnread(notifications)
    }

    /// Grouping does not change the count: RN adds grouped notifications back in.
    nonisolated static func countUnread(_ notifications: [NotificationView]) -> Int {
        notifications.filter { !$0.isRead }.count
    }
}
