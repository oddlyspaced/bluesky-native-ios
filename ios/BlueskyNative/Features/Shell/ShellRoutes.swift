import SwiftUI

/// `PostThread` route (CP-02).
struct ThreadRoute: ScreenRoute {
    var uri: String
    var feedDescriptor: String?
    var routeName: String { "PostThread" }
}

/// `Profile` route (CP-03). Only the own profile is ported.
struct ProfileRoute: ScreenRoute {
    var did: String
    var routeName: String { "Profile" }
}

extension AppRouter {
    /// Profiles other than your own are out of the showcase.
    func openProfile(did: String) {
        guard did == accountDid else {
            shell.notInShowcase = NotInShowcaseItem(title: "Profile")
            return
        }
        push(ProfileRoute(did: did))
    }
}

extension AccountContainer {
    /// Pushes a thread. The route's model is created first and reports the screen's render events,
    /// so they precede `router:navigate` as in RN, where the container's `onStateChange` effect runs
    /// after the pushed screen's effects (`BaseNavigationContainer.tsx:322-399`).
    func openThread(uri: String, feedDescriptor: String? = nil) {
        guard let tabRouter = router.currentRouter else { return }
        let route = Route(ThreadRoute(uri: uri, feedDescriptor: feedDescriptor))
        if let model = threadModel(for: route) {
            model.setPlaceholder(cachedPost(uri: uri))
            model.reportRenderEvents()
        }
        tabRouter.path.append(route)
    }

    /// The route-scoped model of a pushed thread, created on first use.
    func threadModel(for route: Route) -> ThreadModel? {
        guard let thread = route.screen(as: ThreadRoute.self) else { return nil }
        return routeModels.model(for: route) {
            ThreadModel(api: api, anchor: thread.uri, feedDescriptor: thread.feedDescriptor, preferences: preferences,
                        analytics: analytics, faults: faults, userDid: accountDid)
        }
    }

    /// The route-scoped model of a pushed own profile, created on first use.
    func profileModel(for route: Route) -> ProfileModel? {
        guard let pushed = route.screen(as: ProfileRoute.self) else { return nil }
        return routeModels.model(for: route) {
            ProfileModel(api: api, actor: pushed.did,
                         posts: FeedModel(source: .author(actor: pushed.did, filter: .postsAndAuthorThreads), api: api,
                                          preferences: preferences, analytics: analytics, faults: faults,
                                          userDid: accountDid),
                         analytics: analytics, faults: faults)
        }
    }

    /// The thread model on top of the selected tab's stack, if one exists.
    var topThreadModel: ThreadModel? {
        guard let route = router.currentRouter?.path.last else { return nil }
        return routeModels.existing(for: route, as: ThreadModel.self)
    }
}

extension ScreenRegistry {
    func registerThreadScreens() {
        register(ThreadRoute.self) { _, route, container in
            if let model = container.threadModel(for: route) {
                ThreadScreen(model: model)
            }
        }
    }

    func registerProfileScreens() {
        registerRoot(.profile) { container in
            ProfileScreen(model: container.profile, isTabRoot: true)
        }
        register(ProfileRoute.self) { _, route, container in
            if let model = container.profileModel(for: route) {
                ProfileScreen(model: model, isTabRoot: false)
            }
        }
    }
}
