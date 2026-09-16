import Testing
import UIKit
@testable import NativeShowcase

/// Stands in for UIKit's own pop-gesture delegate: it refuses the gesture, as UIKit's delegate does
/// while the navigation bar is hidden, and it answers one other delegate message.
@MainActor
final class StubGestureDelegate: NSObject, UIGestureRecognizerDelegate {
    private(set) var askedShouldBegin = false
    private(set) var askedSimultaneous = false

    nonisolated func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        MainActor.assumeIsolated { askedShouldBegin = true }
        return false
    }

    nonisolated func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                                       shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        MainActor.assumeIsolated { askedSimultaneous = true }
        return true
    }
}

/// Review finding A63. The swipe-back fix must reach only this app's navigation controller and must
/// keep UIKit's gesture delegate. It replaces an unsupported `override` from an extension on
/// `UINavigationController`, which also replaced the delegate of every stack in the process.
///
/// What these tests prove: the proxy answers `gestureRecognizerShouldBegin` by stack depth, it
/// forwards every other delegate message to the delegate it replaced, it re-enables a disabled
/// gesture, it never wraps itself, the representable's controller reaches its own stack, and another
/// navigation controller in the same process keeps its own delegate.
///
/// What they do not prove: that a real swipe pops the screen. That needs the Maestro flow on a
/// simulator (`parity/flows/capture.yml`); `ios/PARITY.md` records the limit.
@MainActor
@Suite("Interactive pop")
struct InteractivePopTests {
    private func stack(depth: Int = 1) -> UINavigationController {
        let navigation = UINavigationController(rootViewController: UIViewController())
        navigation.loadViewIfNeeded()
        for _ in 1..<max(1, depth) { navigation.pushViewController(UIViewController(), animated: false) }
        return navigation
    }

    @Test func popIsRefusedAtTheRootAndAllowedOnceAScreenIsPushed() throws {
        let navigation = stack()
        let gesture = try #require(navigation.interactivePopGestureRecognizer)
        gesture.isEnabled = false
        // The installer must outlive the call: `UIGestureRecognizer.delegate` is weak.
        let installer = InteractivePopInstaller()
        installer.install(on: navigation)

        let proxy = try #require(installer.proxy(for: gesture))
        #expect(gesture.delegate === proxy)
        #expect(gesture.isEnabled)
        #expect(!proxy.gestureRecognizerShouldBegin(gesture))

        navigation.pushViewController(UIViewController(), animated: false)
        #expect(proxy.gestureRecognizerShouldBegin(gesture))
    }

    /// The proxy keeps UIKit's delegate: it answers only `gestureRecognizerShouldBegin` for the pop
    /// gestures and forwards the rest.
    @Test func everyOtherDelegateMessageReachesTheReplacedDelegate() throws {
        let navigation = stack(depth: 2)
        let gesture = try #require(navigation.interactivePopGestureRecognizer)
        let uikit = StubGestureDelegate()
        gesture.delegate = uikit
        let installer = InteractivePopInstaller()
        installer.install(on: navigation)
        let proxy: any UIGestureRecognizerDelegate = try #require(installer.proxy(for: gesture))

        let selector = #selector(UIGestureRecognizerDelegate.gestureRecognizer(_:shouldRecognizeSimultaneouslyWith:))
        #expect(proxy.responds(to: selector))
        #expect(proxy.gestureRecognizer?(gesture, shouldRecognizeSimultaneouslyWith: UIPanGestureRecognizer()) == true)
        #expect(uikit.askedSimultaneous)

        // The pop gesture is answered here, not forwarded: UIKit's delegate refuses it while the
        // navigation bar is hidden, which is the whole reason this proxy exists.
        #expect(proxy.gestureRecognizerShouldBegin?(gesture) == true)
        #expect(!uikit.askedShouldBegin)

        // A gesture that is not one of the stack's pop gestures is left to UIKit's delegate.
        #expect(proxy.gestureRecognizerShouldBegin?(UIPanGestureRecognizer()) == false)
        #expect(uikit.askedShouldBegin)
    }

    @Test func installingAgainReusesTheProxyAndNeverWrapsIt() throws {
        let navigation = stack()
        let gesture = try #require(navigation.interactivePopGestureRecognizer)
        let uikit = StubGestureDelegate()
        gesture.delegate = uikit
        let installer = InteractivePopInstaller()
        installer.install(on: navigation)
        let proxy = try #require(installer.proxy(for: gesture))
        installer.install(on: navigation)
        installer.install(on: navigation)

        #expect(installer.proxy(for: gesture) === proxy)
        #expect(gesture.delegate === proxy)
        #expect(proxy.original === uikit)
        #expect(!(proxy.original is PopGestureDelegateProxy))
    }

    /// The representable's controller walks up to the stack that holds its own screen.
    @Test func theHostControllerReachesItsOwnStack() throws {
        let navigation = stack()
        let screen = UIViewController()
        let host = InteractivePopHostController()
        screen.addChild(host)
        screen.view.addSubview(host.view)
        host.didMove(toParent: screen)
        navigation.pushViewController(screen, animated: false)

        host.enablePopGestures()
        let gesture = try #require(navigation.interactivePopGestureRecognizer)
        #expect(gesture.delegate is PopGestureDelegateProxy)
        #expect(gesture.isEnabled)
    }

    /// Review finding A63: a second navigation controller in the same process, such as a
    /// system-presented share sheet, keeps its own delegate.
    @Test func anotherStackInTheProcessKeepsItsDelegate() throws {
        let mine = stack()
        let theirs = stack()
        let theirGesture = try #require(theirs.interactivePopGestureRecognizer)
        let theirDelegate = theirGesture.delegate

        let installer = InteractivePopInstaller()
        installer.install(on: mine)

        #expect(theirGesture.delegate === theirDelegate)
        #expect(!(theirGesture.delegate is PopGestureDelegateProxy))
        #expect(installer.proxy(for: theirGesture) == nil)
    }
}
