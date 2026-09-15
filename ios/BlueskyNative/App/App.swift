import Observation
import QuartzCore
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
    let analytics: any AnalyticsSink
    let faults: DebugFaults
    let platform: PlatformServices
    /// Media time when the app process built its environment, for RN's `init.initMs`.
    let launchTime: CFTimeInterval

    init(session: SessionStore, statusBar: StatusBarAppearance = StatusBarAppearance(),
         analytics: any AnalyticsSink = NoopAnalytics(), faults: DebugFaults = DebugFaults(),
         platform: PlatformServices = .live, launchTime: CFTimeInterval = CACurrentMediaTime()) {
        self.session = session
        self.statusBar = statusBar
        self.analytics = analytics
        self.faults = faults
        self.platform = platform
        self.launchTime = launchTime
    }

    static func live() -> AppEnvironment {
        #if E2E
        // The parity event diff reads this log (review finding A60).
        let analytics: any AnalyticsSink = JSONLinesEventLog.documents()
        #else
        // Release sends events nowhere: no local file with URIs, DIDs or visited links.
        let analytics: any AnalyticsSink = NoopAnalytics()
        #endif
        return AppEnvironment(session: .live(appViewProxy: AppConfig.appViewProxy), analytics: analytics)
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
            RootView(launchTime: environment.launchTime)
                .modifier(SystemThemeModifier())
                .environment(environment.session)
                .environment(environment.statusBar)
                .environment(environment.faults)
                .environment(\.analytics, environment.analytics)
                .environment(\.platform, environment.platform)
        ))
        statusBar.onChange = { [weak self] in self?.setNeedsStatusBarAppearanceUpdate() }
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { statusBar.style }
}
