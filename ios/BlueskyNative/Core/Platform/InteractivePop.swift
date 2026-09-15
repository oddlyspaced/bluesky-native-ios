import UIKit

/// Keeps swipe back on every pushed screen while the navigation bar is hidden
/// (review findings P10 and N16).
///
/// The screens hide SwiftUI's navigation bar to draw RN's header. SwiftUI then disables the
/// navigation controller's pop gestures each time it applies that toolbar state, after
/// `viewDidLoad` and on every push. RN's native stack keeps swipe back.
///
/// Measured on iOS 26.4 with the Maestro swipe step (`parity/flows/capture.yml`): with only the edge
/// gesture re-enabled, the swipe never began. The pop began through
/// `interactiveContentPopGestureRecognizer` (iOS 26), the gesture over the whole content area, once it
/// was enabled too. Both gestures are therefore re-enabled on layout, and both are refused at the
/// root of a stack.
extension UINavigationController: @retroactive UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        enablePopGestures()
    }

    override open func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        enablePopGestures()
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard popGestures.contains(where: { $0 === gestureRecognizer }) else { return true }
        return viewControllers.count > 1
    }

    private var popGestures: [UIGestureRecognizer] {
        var gestures = [interactivePopGestureRecognizer].compactMap { $0 }
        if #available(iOS 26.0, *), let content = interactiveContentPopGestureRecognizer {
            gestures.append(content)
        }
        return gestures
    }

    private func enablePopGestures() {
        for gesture in popGestures {
            if gesture.delegate !== self { gesture.delegate = self }
            if !gesture.isEnabled { gesture.isEnabled = true }
        }
    }
}
