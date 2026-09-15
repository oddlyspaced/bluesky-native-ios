import Foundation
import Observation
import SwiftUI

enum ShellTab: Hashable, CaseIterable {
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

    /// `TAB_TO_NAV_ITEM` (`src/lib/routes/tab-to-nav-item.ts:10-14`).
    var navItem: String {
        switch self {
        case .home: "home"
        case .search: "search"
        case .messages: "chat"
        case .notifications: "notifications"
        case .profile: "profile"
        }
    }

    /// RN root route name of the tab (`src/Navigation.tsx:687-754`).
    var rootRouteName: String {
        switch self {
        case .home: "Home"
        case .search: "Search"
        case .messages: "Messages"
        case .notifications: "Notifications"
        case .profile: "MyProfile"
        }
    }
}

/// Screens pushed inside a tab. Each push gets its own id, so the same thread can be
/// pushed twice and each keeps its own model.
enum Route: Hashable {
    case thread(uri: String, feedDescriptor: String?, id: UUID)
    case profile(did: String, id: UUID)

    /// RN route name, for `router:navigate`.
    var routeName: String {
        switch self {
        case .thread: "PostThread"
        case .profile: "Profile"
        }
    }
}

/// Navigation state of one tab (review finding A16: per-tab routers).
@MainActor
@Observable
final class TabRouter {
    let tab: ShellTab
    var path: [Route] = []

    init(tab: ShellTab) {
        self.tab = tab
    }
}

/// The shell's navigation: selected tab, per-tab stacks, soft reset and `router:navigate`.
///
/// Port of the bottom-tab behaviour in `BottomBar.tsx:97-131`: a tap on another tab
/// switches to it; a tap on the current tab pops it to the root, or soft-resets it when it
/// is already at the root.
@MainActor
@Observable
final class AppRouter {
    private(set) var selected: ShellTab = .home
    let home = TabRouter(tab: .home)
    let profile = TabRouter(tab: .profile)
    private(set) var visitedProfile = false
    private(set) var homeSoftResetToken = 0
    private(set) var profileSoftResetToken = 0

    @ObservationIgnored private let analytics: any AnalyticsSink
    @ObservationIgnored private let shell: ShellState
    @ObservationIgnored private let accountDid: String
    @ObservationIgnored private var previousScreen: String?

    init(analytics: any AnalyticsSink, shell: ShellState, accountDid: String) {
        self.analytics = analytics
        self.shell = shell
        self.accountDid = accountDid
    }

    var currentRouter: TabRouter? {
        switch selected {
        case .home: home
        case .profile: profile
        default: nil
        }
    }

    /// The deepest focused RN route name (`getCurrentRouteName`).
    var currentScreenName: String {
        currentRouter?.path.last?.routeName ?? selected.rootRouteName
    }

    /// The thread's reply prompt sits above the bar and hides its top border
    /// (`useHideBottomBarBorderForScreen`), derived from the route (review finding P11).
    var isThreadOnTop: Bool {
        if case .thread? = currentRouter?.path.last { return true }
        return false
    }

    func select(_ tab: ShellTab) {
        analytics.metric("nav:click", ["item": .string(tab.navItem), "surface": "bottomBar"])
        if tab == selected {
            guard let router = currentRouter else { return }
            if router.path.isEmpty {
                switch tab {
                case .home: homeSoftResetToken += 1
                case .profile: profileSoftResetToken += 1
                default: break
                }
            } else {
                router.path.removeAll()
            }
            return
        }
        if tab == .profile { visitedProfile = true }
        selected = tab
    }

    func softResetHome() {
        guard selected == .home, home.path.isEmpty else { return }
        homeSoftResetToken += 1
    }

    func openThread(uri: String, feedDescriptor: String? = nil) {
        currentRouter?.path.append(.thread(uri: uri, feedDescriptor: feedDescriptor, id: UUID()))
    }

    /// Profiles other than your own are out of the showcase.
    func openProfile(did: String) {
        guard did == accountDid else {
            shell.notInShowcase = NotInShowcaseItem(title: "Profile")
            return
        }
        currentRouter?.path.append(.profile(did: did, id: UUID()))
    }

    /// Emits `router:navigate` when the focused screen changes (`src/Navigation.tsx:1059-1067`).
    func reportNavigation() {
        let current = currentScreenName
        guard let previous = previousScreen else {
            previousScreen = current
            return
        }
        guard previous != current else { return }
        analytics.metric("router:navigate", ["from": .string(previous)])
        previousScreen = current
    }

    /// Emits the on-ready `router:navigate {}` and `init` events (`Navigation.tsx:1012-1035`).
    func reportReady(initMs: Int) {
        previousScreen = currentScreenName
        analytics.metric("router:navigate")
        analytics.metric("init", ["initMs": .int(initMs)])
    }
}

/// Objects that live exactly as long as one signed-in session (review finding A9).
///
/// `SignedInRoot` creates one container per account in `@State`, so re-renders never
/// recreate models, and an account switch drops every model, shadow and queue.
@MainActor
@Observable
final class AccountContainer {
    let api: any BlueskyAPI
    let accountDid: String
    let accountHandle: String
    let analytics: any AnalyticsSink
    let faults: DebugFaults
    let shell = ShellState()
    let shadows = PostShadowStore()
    let ticker = MinuteTicker()
    let preferences: PreferencesModel
    let interactions: PostInteractions
    let unread: UnreadNotificationsModel
    let homeFeed: FeedModel
    let profile: ProfileModel
    let router: AppRouter

    @ObservationIgnored private var threadModels: [Route: ThreadModel] = [:]

    init(api: any BlueskyAPI, accountDid: String, accountHandle: String, analytics: any AnalyticsSink,
         faults: DebugFaults) {
        self.api = api
        self.accountDid = accountDid
        self.accountHandle = accountHandle
        self.analytics = analytics
        self.faults = faults
        let preferences = PreferencesModel(api: api)
        self.preferences = preferences
        let profile = ProfileModel(
            api: api, actor: accountDid,
            posts: FeedModel(source: .author(actor: accountDid, filter: .postsAndAuthorThreads), api: api,
                             preferences: preferences, analytics: analytics, faults: faults, userDid: accountDid),
            analytics: analytics, faults: faults)
        self.profile = profile
        interactions = PostInteractions(api: api, shadows: shadows, analytics: analytics,
                                        ownFollowersCount: { profile.profile?.followersCount })
        unread = UnreadNotificationsModel(api: api)
        homeFeed = FeedModel(source: .following, api: api, preferences: preferences, analytics: analytics,
                             faults: faults, userDid: accountDid)
        router = AppRouter(analytics: analytics, shell: shell, accountDid: accountDid)
    }

    /// Screen factory for threads: one model per pushed route (review finding A35).
    func threadModel(for route: Route) -> ThreadModel? {
        guard case .thread(let uri, let feedDescriptor, _) = route else { return nil }
        if let existing = threadModels[route] { return existing }
        let model = ThreadModel(api: api, anchor: uri, feedDescriptor: feedDescriptor, preferences: preferences,
                                analytics: analytics, faults: faults, userDid: accountDid)
        threadModels[route] = model
        return model
    }

    /// Drops thread models for routes no longer on any stack.
    func pruneRoutes() {
        let live = Set(router.home.path + router.profile.path)
        threadModels = threadModels.filter { live.contains($0.key) }
    }
}
