import SwiftUI
import UIKit

/// Keeps swipe back on this app's pushed screens while the navigation bar is hidden
/// (review findings P10, N16 and A63).
///
/// The screens hide SwiftUI's navigation bar to draw RN's header. SwiftUI then disables the
/// navigation controller's pop gestures each time it applies that toolbar state, after
/// `viewDidLoad` and on every push. RN's native stack keeps swipe back.
///
/// Measured on iOS 26.4 with the Maestro swipe step (`parity/flows/capture.yml`): with only the edge
/// gesture re-enabled, the swipe never began. The pop began through
/// `interactiveContentPopGestureRecognizer` (iOS 26), the gesture over the whole content area, once it
/// was enabled too. Both gestures are therefore re-enabled, and both are refused at the root of a
/// stack.
///
/// **Scope (review finding A63).** The previous version overrode `viewDidLoad` and
/// `viewDidLayoutSubviews` from an extension on `UINavigationController`. Swift does not support
/// overriding from an extension: dispatch is undefined and there is no `super` contract. That
/// extension also declared `@retroactive UIGestureRecognizerDelegate` and replaced the gesture
/// delegate of **every** `UINavigationController` in the process, system stacks such as the share
/// sheet included.
///
/// This version:
/// - reaches exactly one navigation controller, the one that holds the screen the modifier is
///   applied to, through a `UIViewControllerRepresentable` that walks up from its own view
///   controller;
/// - keeps UIKit's delegate. `PopGestureDelegateProxy` answers `gestureRecognizerShouldBegin` for
///   the two pop gestures and forwards every other message to the delegate it replaced, so UIKit's
///   own transition delegate keeps working;
/// - overrides nothing from an extension.
extension View {
    /// Re-enables the stack's pop gestures for this screen.
    func interactivePopEnabled() -> some View {
        background(InteractivePopEnabler().frame(width: 0, height: 0).accessibilityHidden(true))
    }
}

/// Reaches this screen's own `UINavigationController` and installs the pop-gesture proxy on it.
struct InteractivePopEnabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> InteractivePopHostController {
        InteractivePopHostController()
    }

    func updateUIViewController(_ controller: InteractivePopHostController, context: Context) {
        controller.enablePopGestures()
    }

    /// SwiftUI's teardown hook. The proxy must be removed here, not left to deallocate: see
    /// `InteractivePopInstaller.uninstall()`.
    static func dismantleUIViewController(_ controller: InteractivePopHostController, coordinator: Coordinator) {
        controller.restorePopGestureDelegates()
    }
}

/// An empty controller whose only job is to own an `InteractivePopInstaller` and to find the
/// navigation controller it was pushed into.
///
/// It re-enables the gestures on every layout of its own view, and once more on the next main-queue
/// turn, because SwiftUI applies the hidden-toolbar state (which disables the gestures) during the
/// same push.
final class InteractivePopHostController: UIViewController {
    private let installer = InteractivePopInstaller()
    private var rescheduled = false

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        enablePopGestures()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        enablePopGestures()
    }

    override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        // Leaving the parent is the screen going away: put UIKit's delegates back.
        if parent == nil {
            restorePopGestureDelegates()
        } else {
            enablePopGestures()
        }
    }

    /// `rescheduled` guards only the turn it was armed in; it is cleared on that turn, so a rapid
    /// push sequence can schedule one pass per turn. That is harmless: `install` is idempotent and
    /// reuses the proxy it already made.
    func enablePopGestures() {
        guard let navigation = navigationController else { return }
        installer.install(on: navigation)
        guard !rescheduled else { return }
        rescheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            rescheduled = false
            if let later = navigationController { installer.install(on: later) }
        }
    }

    /// Puts UIKit's gesture delegates back. Called when this controller leaves its parent and from
    /// `InteractivePopEnabler.dismantleUIViewController`.
    func restorePopGestureDelegates() {
        installer.uninstall()
    }
}

/// Installs `PopGestureDelegateProxy` on one navigation controller's pop gestures and keeps them
/// enabled. One installer belongs to one screen; it never touches another stack.
@MainActor
final class InteractivePopInstaller {
    /// What this installer wrapped, by gesture, so a second install reuses the first proxy and
    /// never wraps a proxy in a proxy, and so `uninstall()` can put the delegates back.
    private var installed: [ObjectIdentifier: Installation] = [:]

    private struct Installation {
        /// Strong. A `UIGestureRecognizer` refers to its view weakly, so this keeps nothing else
        /// alive, and `uninstall()` needs the gesture to put its delegate back.
        var gesture: UIGestureRecognizer
        var proxy: PopGestureDelegateProxy
    }

    /// The edge gesture and, from iOS 26, the gesture over the whole content area.
    static func popGestures(of navigationController: UINavigationController) -> [UIGestureRecognizer] {
        var gestures = [navigationController.interactivePopGestureRecognizer].compactMap { $0 }
        if #available(iOS 26.0, *), let content = navigationController.interactiveContentPopGestureRecognizer {
            gestures.append(content)
        }
        return gestures
    }

    func install(on navigationController: UINavigationController) {
        for gesture in Self.popGestures(of: navigationController) {
            let key = ObjectIdentifier(gesture)
            let proxy: PopGestureDelegateProxy
            if let existing = installed[key] {
                proxy = existing.proxy
            } else {
                // The delegate captured here is UIKit's own. `uninstall()` puts it back.
                proxy = PopGestureDelegateProxy(original: gesture.delegate,
                                                navigationController: navigationController)
                installed[key] = Installation(gesture: gesture, proxy: proxy)
            }
            if gesture.delegate !== proxy { gesture.delegate = proxy }
            if !gesture.isEnabled { gesture.isEnabled = true }
        }
    }

    /// Puts back the delegate each gesture had before this installer wrapped it.
    ///
    /// `UIGestureRecognizer.delegate` is weak, and the only strong reference to a proxy is this
    /// installer, which the screen's host controller owns. Without this, popping the screen would
    /// leave the navigation controller with a pop gesture whose delegate is nil instead of the
    /// delegate UIKit installed.
    func uninstall() {
        for installation in installed.values {
            // Never clobber a delegate that somebody else installed after this one.
            guard installation.gesture.delegate === installation.proxy else { continue }
            installation.gesture.delegate = installation.proxy.original
        }
        installed.removeAll()
    }

    /// The proxy installed on `gesture`, if this installer installed one. Tests read it.
    func proxy(for gesture: UIGestureRecognizer) -> PopGestureDelegateProxy? {
        installed[ObjectIdentifier(gesture)]?.proxy
    }
}

/// Answers `gestureRecognizerShouldBegin` for a stack's pop gestures and forwards every other
/// `UIGestureRecognizerDelegate` message to the delegate it replaced (review finding A63).
final class PopGestureDelegateProxy: NSObject, UIGestureRecognizerDelegate {
    /// UIKit's own delegate. Weak: it is owned by the navigation controller and it refers back to
    /// it, so a strong reference here would make a cycle.
    ///
    /// Assumption: the navigation controller keeps this delegate alive for as long as the gesture
    /// exists. If it ever does not, this goes nil, and `gestureRecognizerShouldBegin` then answers
    /// `true` for a gesture that is not one of the stack's pop gestures. That is what UIKit does
    /// for a recognizer with no delegate, so the fallback matches the unwrapped behaviour.
    private(set) weak var original: (any UIGestureRecognizerDelegate)?
    private weak var navigationController: UINavigationController?

    init(original: (any UIGestureRecognizerDelegate)?, navigationController: UINavigationController) {
        self.original = original
        self.navigationController = navigationController
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let navigationController else { return false }
        let isPopGesture = InteractivePopInstaller.popGestures(of: navigationController)
            .contains { $0 === gestureRecognizer }
        guard isPopGesture else {
            // Not ours: UIKit's delegate decides, as it would without this proxy.
            return original?.gestureRecognizerShouldBegin?(gestureRecognizer) ?? true
        }
        // A stack at its root has nothing to pop.
        return navigationController.viewControllers.count > 1
    }

    // MARK: - Forwarding

    override func responds(to aSelector: Selector!) -> Bool {
        if super.responds(to: aSelector) { return true }
        return original?.responds(to: aSelector) ?? false
    }

    override func forwardingTarget(for aSelector: Selector!) -> Any? {
        guard original?.responds(to: aSelector) == true else { return nil }
        return original
    }
}
