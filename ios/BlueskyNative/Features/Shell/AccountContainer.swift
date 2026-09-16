import Foundation
import Observation
import SwiftUI

enum ShellTab: Hashable, CaseIterable, Sendable {
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

// MARK: - Routes

/// A screen that can be pushed inside a tab (review finding A58). Each feature declares its own
/// route type and registers a factory for it in `ScreenRegistry`; the shell never switches over
/// route types.
protocol ScreenRoute: Hashable, Sendable {
    /// RN route name, for `router:navigate`.
    var routeName: String { get }
}

/// One push of a `ScreenRoute`. Equality is the push id, so the same thread pushed twice keeps
/// two screens and two models.
struct Route: Hashable, Sendable {
    let id: UUID
    let screen: any ScreenRoute

    init(_ screen: some ScreenRoute, id: UUID = UUID()) {
        self.id = id
        self.screen = screen
    }

    var routeName: String { screen.routeName }

    func screen<R: ScreenRoute>(as type: R.Type) -> R? {
        screen as? R
    }

    static func == (lhs: Route, rhs: Route) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// Navigation state of one tab: its stack and its soft-reset signal (review findings A16, A58).
@MainActor
@Observable
final class TabRouter {
    let tab: ShellTab
    var path: [Route] = []
    /// Changes when a tap on the selected tab at its root asks the root screen to soft-reset.
    private(set) var softResetToken = 0

    init(tab: ShellTab) {
        self.tab = tab
    }

    func requestSoftReset() {
        softResetToken += 1
    }
}

/// The shell's navigation: selected tab, per-tab stacks, soft reset and `router:navigate`.
///
/// Port of the bottom-tab behaviour in `BottomBar.tsx:97-131`: a tap on another tab switches to
/// it; a tap on the current tab pops it to the root, or soft-resets it when it is already at the
/// root.
@MainActor
@Observable
final class AppRouter {
    private(set) var selected: ShellTab = .home
    /// Like RN's lazy tabs, a tab mounts on its first visit and stays mounted.
    private(set) var visited: Set<ShellTab> = [.home]

    /// Tabs with a ported root screen. Other tabs show "Not part of this showcase".
    @ObservationIgnored let stackTabs: [ShellTab]
    @ObservationIgnored let routers: [ShellTab: TabRouter]
    @ObservationIgnored let accountDid: String
    @ObservationIgnored let shell: ShellState
    @ObservationIgnored private let analytics: any AnalyticsSink
    @ObservationIgnored private var previousScreen: String?

    init(analytics: any AnalyticsSink, shell: ShellState, accountDid: String,
         stackTabs: [ShellTab] = [.home, .profile]) {
        self.analytics = analytics
        self.shell = shell
        self.accountDid = accountDid
        self.stackTabs = ShellTab.allCases.filter(stackTabs.contains)
        routers = Dictionary(uniqueKeysWithValues: self.stackTabs.map { ($0, TabRouter(tab: $0)) })
    }

    /// The selected tab's router, when that tab has a ported stack.
    var currentRouter: TabRouter? {
        routers[selected]
    }

    /// Every route on every stack.
    var allRoutes: [Route] {
        stackTabs.compactMap { routers[$0] }.flatMap(\.path)
    }

    /// The deepest focused RN route name (`getCurrentRouteName`).
    var currentScreenName: String {
        currentRouter?.path.last?.routeName ?? selected.rootRouteName
    }

    func select(_ tab: ShellTab) {
        analytics.metric("nav:click", ["item": .string(tab.navItem), "surface": "bottomBar"])
        if tab == selected {
            guard let router = currentRouter else { return }
            if router.path.isEmpty {
                router.requestSoftReset()
            } else {
                router.path.removeAll()
            }
            return
        }
        visited.insert(tab)
        selected = tab
    }

    /// Soft-resets `tab` when it is selected and at its root (Home logo and feed tab re-tap).
    func softResetRoot(of tab: ShellTab) {
        guard selected == tab, let router = currentRouter, router.path.isEmpty else { return }
        router.requestSoftReset()
    }

    /// Pushes a screen on the selected tab's stack.
    func push(_ screen: some ScreenRoute) {
        currentRouter?.path.append(Route(screen))
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

// MARK: - Screen identifiers

/// The RN screen ids this port exposes (`Layout.Screen testID`), review findings F2, A64 and A71.
///
/// One place, so a screen, the shell and the capture flow cannot drift apart.
/// `parity/flows/capture.yml` asserts every id in `assertedInCaptureFlow` with `assertVisible`.
enum ScreenID {
    /// The home tab's hosting stack (`Home.tsx:95`). The shell reads it from `ScreenRegistry`.
    static let homeStack = "HomeScreen"
    /// `Home.tsx:308`.
    static let home = "homeScreen"
    /// `Home.tsx:320`.
    static let followingFeedPage = "followingFeedPage"
    /// `Profile.tsx:63`.
    static let profile = "profileScreen"
    /// The profile Posts feed list (`Profile.tsx:436`).
    static let postsFeed = "postsFeed"

    /// Every id `parity/flows/capture.yml` asserts, in the order the flow asserts them.
    static let assertedInCaptureFlow = [homeStack, home, followingFeedPage, profile, postsFeed]
}

// MARK: - Screen registry

/// Maps tab roots and route types to screens (review finding A58). Features register their own
/// factories, so a new screen does not change the shell.
@MainActor
final class ScreenRegistry {
    private var factories: [ObjectIdentifier: @MainActor (Route, AccountContainer) -> AnyView] = [:]
    private var roots: [ShellTab: @MainActor (AccountContainer) -> AnyView] = [:]
    /// The RN `Layout.Screen` testID of a tab's hosting stack, registered by the feature that owns
    /// the tab. The shell reads it instead of naming a tab itself (review finding A71).
    private var rootIdentifiers: [ShellTab: String] = [:]

    func register<R: ScreenRoute, Content: View>(
        _ type: R.Type, @ViewBuilder factory: @escaping @MainActor (R, Route, AccountContainer) -> Content
    ) {
        factories[ObjectIdentifier(type)] = { route, container in
            guard let screen = route.screen(as: R.self) else { return AnyView(EmptyView()) }
            return AnyView(factory(screen, route, container))
        }
    }

    func registerRoot<Content: View>(_ tab: ShellTab, identifier: String? = nil,
                                     @ViewBuilder factory: @escaping @MainActor (AccountContainer) -> Content) {
        roots[tab] = { AnyView(factory($0)) }
        rootIdentifiers[tab] = identifier
    }

    /// The id the shell puts on this tab's hosting stack, when the tab's feature registered one.
    func rootIdentifier(for tab: ShellTab) -> String? {
        rootIdentifiers[tab]
    }

    var rootTabs: [ShellTab] {
        ShellTab.allCases.filter { roots[$0] != nil }
    }

    func canPresent(_ route: Route) -> Bool {
        factories[ObjectIdentifier(type(of: route.screen))] != nil
    }

    func root(for tab: ShellTab, container: AccountContainer) -> AnyView {
        roots[tab]?(container) ?? AnyView(NotInShowcaseView(title: tab.title))
    }

    func view(for route: Route, container: AccountContainer) -> AnyView {
        factories[ObjectIdentifier(type(of: route.screen))]?(route, container)
            ?? AnyView(NotInShowcaseView(title: route.routeName))
    }
}

/// A route-scoped model that must stop its work when its route leaves the stack.
///
/// `RouteModelStore.prune` calls this on every model it drops, so a popped screen stops its
/// requests and its pending `post:view` reports (review finding A83).
@MainActor
protocol RouteScopedModel: AnyObject {
    func cancel()
}

/// Models that live exactly as long as their route is on a stack (review findings A35, A58).
/// A model is created on the first request for its route.
@MainActor
final class RouteModelStore {
    private var models: [Route: AnyObject] = [:]

    var count: Int { models.count }

    func model<Model: AnyObject>(for route: Route, make: () -> Model) -> Model {
        if let existing = models[route] as? Model { return existing }
        let created = make()
        models[route] = created
        return created
    }

    func existing<Model: AnyObject>(for route: Route, as type: Model.Type) -> Model? {
        models[route] as? Model
    }

    /// Drops models for routes no longer on any stack, and stops the work each dropped model owns
    /// (review finding A83). Returns the number dropped.
    @discardableResult
    func prune(keeping live: some Sequence<Route>) -> Int {
        let keep = Set(live)
        var dropped = 0
        models = models.filter { route, model in
            guard !keep.contains(route) else { return true }
            (model as? any RouteScopedModel)?.cancel()
            dropped += 1
            return false
        }
        return dropped
    }
}

// MARK: - Account container

/// Objects that live exactly as long as one signed-in session (review finding A9).
///
/// `SignedInRoot` creates one container per account in `@State`, so re-renders never recreate
/// models, and an account switch drops every model, shadow and queue.
///
/// - Account level: API, analytics, shadows, preferences, unread polling and the own profile (the
///   shell shows the own avatar, as RN's shell reads the profile query).
/// - Tab root: `homeFeed`, created on first use.
/// - Pushed screens: route-scoped models in `routeModels`, created by each feature's factory.
@MainActor
@Observable
final class AccountContainer {
    let api: any BlueskyAPI
    let accountDid: String
    let accountHandle: String
    let analytics: any AnalyticsSink
    let faults: DebugFaults
    let activity: any AppActivity
    let shell = ShellState()
    let shadows = PostShadowStore()
    let ticker = MinuteTicker()
    let preferences: PreferencesModel
    let interactions: PostInteractions
    let unread: UnreadNotificationsModel
    let profile: ProfileModel
    let router: AppRouter
    let links: LinkRouter
    @ObservationIgnored let registry: ScreenRegistry
    @ObservationIgnored let routeModels = RouteModelStore()

    @ObservationIgnored private var homeFeedStorage: FeedModel?

    init(api: any BlueskyAPI, accountDid: String, accountHandle: String, analytics: any AnalyticsSink,
         faults: DebugFaults, platform: PlatformServices = .live, registry: ScreenRegistry? = nil) {
        let registry = registry ?? .slice()
        self.api = api
        self.accountDid = accountDid
        self.accountHandle = accountHandle
        self.analytics = analytics
        self.faults = faults
        self.registry = registry
        activity = platform.activity
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
        let router = AppRouter(analytics: analytics, shell: shell, accountDid: accountDid,
                               stackTabs: registry.rootTabs)
        self.router = router
        links = LinkRouter(analytics: analytics, shell: shell, preferences: platform.preferences,
                           urlOpener: platform.urlOpener) { [weak router] did in router?.openProfile(did: did) }
    }

    /// The Following feed, created when Home first asks for it.
    var homeFeed: FeedModel {
        if let homeFeedStorage { return homeFeedStorage }
        let created = FeedModel(source: .following, api: api, preferences: preferences, analytics: analytics,
                                faults: faults, userDid: accountDid)
        homeFeedStorage = created
        return created
    }

    /// The Following feed, if Home created it.
    var loadedHomeFeed: FeedModel? { homeFeedStorage }

    /// Drops route-scoped models for routes no longer on any stack.
    func pruneRoutes() {
        routeModels.prune(keeping: router.allRoutes)
    }
}

extension ScreenRegistry {
    /// The screens of this slice.
    static func slice() -> ScreenRegistry {
        let registry = ScreenRegistry()
        registry.registerRoot(.home, identifier: ScreenID.homeStack) { _ in HomeScreen() }
        registry.registerProfileScreens()
        registry.registerThreadScreens()
        return registry
    }
}
