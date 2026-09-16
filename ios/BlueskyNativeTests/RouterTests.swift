import Foundation
import Testing
@testable import NativeShowcase

/// A route-scoped model that only records whether it was cancelled.
@MainActor
private final class StubRouteModel: RouteScopedModel {
    private(set) var cancelled = false
    func cancel() { cancelled = true }
}

/// Review findings A20, A58 and A66: AppRouter behaviour and route-scoped models.
///
/// Every push here goes through `AccountContainer.openThread`, the path production code uses.
/// `AppRouter.openThread` was a second entry point that pushed without creating the route's model
/// or reporting its render events, so it could not produce RN's event order. No production code
/// called it and only these tests did, so it is gone (review finding A66).
@MainActor
@Suite("App router")
struct RouterTests {
    let analytics = RecordingAnalytics()

    private func makeContainer() -> AccountContainer {
        AccountContainer(api: FakeBlueskyAPI(), accountDid: "did:plc:alice", accountHandle: "alice.test",
                         analytics: analytics, faults: DebugFaults())
    }

    @Test func tabTapsSwitchPopAndSoftReset() {
        let container = makeContainer()
        let router = container.router
        router.reportReady(initMs: 1)
        #expect(router.currentScreenName == "Home")

        container.openThread(uri: "at://t", feedDescriptor: "following")
        #expect(router.currentScreenName == "PostThread")
        router.reportNavigation()

        // Tap on the selected tab with a pushed screen pops to the root.
        router.select(.home)
        #expect(router.routers[.home]?.path.isEmpty == true)
        #expect(router.routers[.home]?.softResetToken == 0)
        router.reportNavigation()

        // Tap again at the root soft-resets.
        router.select(.home)
        #expect(router.routers[.home]?.softResetToken == 1)

        router.select(.profile)
        #expect(router.visited == [.home, .profile])
        #expect(router.currentScreenName == "MyProfile")
        router.reportNavigation()

        // A tab without a ported stack has no router.
        router.select(.search)
        #expect(router.currentRouter == nil)
        #expect(router.currentScreenName == "Search")

        #expect(analytics.events(named: "router:navigate").map(\.props) == [
            [:], ["from": "Home"], ["from": "PostThread"], ["from": "Home"],
        ])
        #expect(analytics.events(named: "nav:click").map { $0.props["item"] } == [
            "home", "home", "profile", "search",
        ])
    }

    @Test func otherProfilesAreNotPushed() {
        let shell = ShellState()
        let router = AppRouter(analytics: analytics, shell: shell, accountDid: "did:plc:alice")
        router.openProfile(did: "did:plc:bob")
        #expect(router.routers[.home]?.path.isEmpty == true)
        #expect(shell.notInShowcase?.title == "Profile")
        router.openProfile(did: "did:plc:alice")
        #expect(router.currentScreenName == "Profile")
    }

    @Test func softResetOnlyAtTheSelectedRoot() {
        let container = makeContainer()
        let router = container.router
        router.softResetRoot(of: .profile)
        #expect(router.routers[.profile]?.softResetToken == 0)
        container.openThread(uri: "at://t")
        router.softResetRoot(of: .home)
        #expect(router.routers[.home]?.softResetToken == 0)
        router.select(.home)
        router.softResetRoot(of: .home)
        #expect(router.routers[.home]?.softResetToken == 1)
    }

    @Test func routeModelsAreLazyPerPushAndPruned() {
        let container = makeContainer()
        #expect(container.loadedHomeFeed == nil)
        #expect(container.registry.rootTabs == [.home, .profile])
        #expect(container.router.stackTabs == [.home, .profile])

        // The same thread pushed twice keeps two screens and two models.
        container.openThread(uri: "at://same")
        container.openThread(uri: "at://same")
        let routes = container.router.routers[.home]!.path
        // The real push path creates each route's model as it pushes, so the events of the pushed
        // screen come before `router:navigate`, as in RN.
        #expect(container.routeModels.count == 2)
        let first = container.threadModel(for: routes[0])
        let second = container.threadModel(for: routes[1])
        #expect(first != nil && second != nil && first !== second)
        #expect(container.threadModel(for: routes[0]) === first)
        #expect(container.topThreadModel === second)
        #expect(container.registry.canPresent(routes[0]))

        container.router.routers[.home]!.path.removeLast()
        container.pruneRoutes()
        #expect(container.routeModels.count == 1)
        #expect(container.topThreadModel === first)
    }

    /// Review finding A72: a PostThread pushed from a PostThread keeps the screen name
    /// "PostThread". A prune keyed on the screen name therefore never ran, and the popped screen's
    /// model and its whole thread response leaked. Pruning follows route identity now.
    @Test func pruningFollowsRouteIdentityNotTheScreenName() {
        let container = makeContainer()
        container.openThread(uri: "at://a")
        let nameAfterFirstPush = container.router.currentScreenName
        let routesAfterFirstPush = container.router.allRoutes

        container.openThread(uri: "at://b")
        // The screen name cannot see this push; route identity can.
        #expect(container.router.currentScreenName == nameAfterFirstPush)
        #expect(container.router.allRoutes != routesAfterFirstPush)
        #expect(container.routeModels.count == 2)

        container.router.routers[.home]!.path.removeLast()
        container.pruneRoutes()
        #expect(container.routeModels.count == 1)
    }

    /// Review finding A83: `ViewabilityTracker.cancel` had no caller. A pruned route's model now
    /// stops the work it owns.
    @Test func aPrunedModelIsCancelled() {
        let store = RouteModelStore()
        let route = Route(ThreadRoute(uri: "at://a", feedDescriptor: nil))
        let model = store.model(for: route) { StubRouteModel() }
        #expect(store.count == 1)
        #expect(!model.cancelled)

        let dropped = store.prune(keeping: [])
        #expect(dropped == 1)
        #expect(model.cancelled)
        #expect(store.count == 0)
    }

    /// The models a route owns all stop their work when the route is pruned.
    @Test func theRouteScopedModelsCanBeCancelled() {
        let container = makeContainer()
        container.openThread(uri: "at://a")
        let routes = container.router.routers[.home]!.path
        #expect(container.threadModel(for: routes[0]) is any RouteScopedModel)
        #expect(container.profile is any RouteScopedModel)
        #expect(container.homeFeed is any RouteScopedModel)
    }
}
