import Observation
import SwiftUI
import UIKit

/// App entry. A UIKit scene hosts the SwiftUI tree so screens can set the status bar
/// style (the profile banner uses light content, like the RN app).
@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }
}

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let environment = AppEnvironment.live()
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = RootHostingController(environment: environment)
        window.makeKeyAndVisible()
        self.window = window
    }
}

/// Shared, app-wide objects injected into the SwiftUI environment.
@MainActor
final class AppEnvironment {
    let session: SessionStore
    let statusBar: StatusBarAppearance

    init(session: SessionStore, statusBar: StatusBarAppearance = StatusBarAppearance()) {
        self.session = session
        self.statusBar = statusBar
    }

    static func live() -> AppEnvironment {
        // The keychain survives app deletion on iOS. RN keeps its session in app storage,
        // which a reinstall (or Maestro `clearState`) wipes, so clear stale tokens once
        // per install to keep the same signed-out first launch.
        let defaults = UserDefaults.standard
        let installKey = "hasLaunchedSinceInstall"
        if !defaults.bool(forKey: installKey) {
            try? KeychainCredentialStore().clear()
            defaults.set(true, forKey: installKey)
        }
        return AppEnvironment(session: .live(appViewProxy: AppConfig.appViewProxy))
    }
}

/// Status bar style requested by the visible screen.
@MainActor
@Observable
final class StatusBarAppearance {
    var style: UIStatusBarStyle = .darkContent {
        didSet { if oldValue != style { onChange?() } }
    }

    @ObservationIgnored var onChange: (() -> Void)?
}

final class RootHostingController: UIHostingController<AnyView> {
    private let statusBar: StatusBarAppearance

    init(environment: AppEnvironment) {
        statusBar = environment.statusBar
        super.init(rootView: AnyView(
            RootView()
                .environment(environment.session)
                .environment(environment.statusBar)
        ))
        statusBar.onChange = { [weak self] in self?.setNeedsStatusBarAppearanceUpdate() }
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { statusBar.style }
}
