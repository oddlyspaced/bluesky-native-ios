import Foundation
import Testing
@testable import NativeShowcase

/// Review findings A20 and A58: AppRouter behaviour and route-scoped models.
@MainActor
@Suite("App router")
struct RouterTests {
    let analytics = RecordingAnalytics()

    private func makeRouter() -> AppRouter {
        AppRouter(analytics: analytics, shell: ShellState(), accountDid: "did:plc:alice", stackTabs: [.home, .profile])
    }

    @Test func tabTapsSwitchPopAndSoftReset() {
        let router = makeRouter()
        router.reportReady(initMs: 1)
        #expect(router.currentScreenName == "Home")

        router.openThread(uri: "at://t", feedDescriptor: "following")
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
        let router = makeRouter()
        router.softResetRoot(of: .profile)
        #expect(router.routers[.profile]?.softResetToken == 0)
        router.openThread(uri: "at://t")
        router.softResetRoot(of: .home)
        #expect(router.routers[.home]?.softResetToken == 0)
        router.select(.home)
        router.softResetRoot(of: .home)
        #expect(router.routers[.home]?.softResetToken == 1)
    }

    @Test func routeModelsAreLazyPerPushAndPruned() {
        let container = AccountContainer(api: FakeBlueskyAPI(), accountDid: "did:plc:alice", accountHandle: "alice.test",
                                         analytics: analytics, faults: DebugFaults())
        #expect(container.loadedHomeFeed == nil)
        #expect(container.registry.rootTabs == [.home, .profile])
        #expect(container.router.stackTabs == [.home, .profile])

        container.router.openThread(uri: "at://same")
        container.router.openThread(uri: "at://same")
        let routes = container.router.routers[.home]!.path
        #expect(container.routeModels.count == 0)
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
