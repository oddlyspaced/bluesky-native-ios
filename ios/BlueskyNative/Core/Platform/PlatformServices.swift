import SwiftUI
import UIKit

/// Key-value app preferences (review finding A59). Models depend on this protocol, never on
/// `UserDefaults`.
protocol PreferencesStore: Sendable {
    func bool(forKey key: String) -> Bool?
    func setBool(_ value: Bool, forKey key: String)
}

/// Live preferences in `UserDefaults` (required-reason API, reason CA92.1, declared in
/// `PrivacyInfo.xcprivacy`).
struct UserDefaultsPreferencesStore: PreferencesStore {
    func bool(forKey key: String) -> Bool? {
        UserDefaults.standard.object(forKey: key) as? Bool
    }

    func setBool(_ value: Bool, forKey key: String) {
        UserDefaults.standard.set(value, forKey: key)
    }
}

/// In-memory preferences for previews and tests.
final class MemoryPreferencesStore: PreferencesStore, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: Bool]

    init(_ values: [String: Bool] = [:]) {
        self.values = values
    }

    func bool(forKey key: String) -> Bool? {
        lock.withLock { values[key] }
    }

    func setBool(_ value: Bool, forKey key: String) {
        lock.withLock { values[key] = value }
    }
}

/// Whether the app is in the foreground (review finding A59). RN reads
/// `AppState.currentState === 'active'`; UIKit's application state is the same signal.
protocol AppActivity: Sendable {
    @MainActor var isActive: Bool { get }
}

struct UIApplicationActivity: AppActivity {
    @MainActor var isActive: Bool {
        UIApplication.shared.applicationState == .active
    }
}

/// Opens a URL outside the app: the default browser, mail, or another app.
protocol URLOpening: Sendable {
    @MainActor func open(_ url: URL)
}

struct UIApplicationURLOpener: URLOpening {
    @MainActor func open(_ url: URL) {
        UIApplication.shared.open(url)
    }
}

/// Platform services injected into the SwiftUI environment and handed to account models.
struct PlatformServices: Sendable {
    var preferences: any PreferencesStore
    var activity: any AppActivity
    var urlOpener: any URLOpening

    static let live = PlatformServices(preferences: UserDefaultsPreferencesStore(),
                                       activity: UIApplicationActivity(),
                                       urlOpener: UIApplicationURLOpener())
}

extension EnvironmentValues {
    @Entry var platform: PlatformServices = .live
}
