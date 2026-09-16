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
        enablePopGestures()
    }

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
}

/// Installs `PopGestureDelegateProxy` on one navigation controller's pop gestures and keeps them
/// enabled. One installer belongs to one screen; it never touches another stack.
@MainActor
final class InteractivePopInstaller {
    /// Proxies by gesture, so a second install reuses the first proxy and never wraps a proxy in
    /// a proxy.
    private var proxies: [ObjectIdentifier: PopGestureDelegateProxy] = [:]

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
            if let existing = proxies[key] {
                proxy = existing
            } else {
                proxy = PopGestureDelegateProxy(original: gesture.delegate,
                                                navigationController: navigationController)
                proxies[key] = proxy
            }
            if gesture.delegate !== proxy { gesture.delegate = proxy }
            if !gesture.isEnabled { gesture.isEnabled = true }
        }
    }

    /// The proxy installed on `gesture`, if this installer installed one. Tests read it.
    func proxy(for gesture: UIGestureRecognizer) -> PopGestureDelegateProxy? {
        proxies[ObjectIdentifier(gesture)]
    }
}

/// Answers `gestureRecognizerShouldBegin` for a stack's pop gestures and forwards every other
/// `UIGestureRecognizerDelegate` message to the delegate it replaced (review finding A63).
final class PopGestureDelegateProxy: NSObject, UIGestureRecognizerDelegate {
    /// UIKit's own delegate. Weak: it is owned by the navigation controller and it refers back to
    /// it, so a strong reference here would make a cycle.
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
