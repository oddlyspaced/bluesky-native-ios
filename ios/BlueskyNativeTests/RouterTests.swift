import Foundation
import Testing
@testable import NativeShowcase

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
}
