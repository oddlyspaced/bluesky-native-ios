import Foundation
import Security

/// Persists the signed-in account's tokens.
///
/// Every call is async so that Keychain I/O never runs on the main actor.
protocol CredentialStore: Sendable {
    func load() async throws -> StoredSession?
    func save(_ session: StoredSession) async throws
    func clear() async throws
}

/// Errors from the credential store.
enum CredentialStoreError: Error, Equatable, Sendable {
    /// A Keychain call failed with this `OSStatus`.
    case keychain(OSStatus)
    /// The stored item exists but does not decode as a `StoredSession`.
    case corrupt
}

/// Keychain-backed credential store.
///
/// Tokens are stored as one generic password item with
/// `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`, so they are not backed up
/// or restored to another device. The actor keeps every Keychain call off the main actor.
actor KeychainCredentialStore: CredentialStore {
    static let defaultService = "io.nativestarter.showcase.bluesky.session"

    private let service: String
    private let account: String

    init(service: String = KeychainCredentialStore.defaultService, account: String = "current") {
        self.service = service
        self.account = account
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    func load() throws -> StoredSession? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else {
            throw CredentialStoreError.keychain(status)
        }
        do {
            return try JSONDecoder().decode(StoredSession.self, from: data)
        } catch {
            throw CredentialStoreError.corrupt
        }
    }

    func save(_ session: StoredSession) throws {
        let data = try JSONEncoder().encode(session)
        let update: [String: Any] = [kSecValueData as String: data]
        let status = SecItemUpdate(baseQuery as CFDictionary, update as CFDictionary)
        if status == errSecItemNotFound {
            var add = baseQuery
            add[kSecValueData as String] = data
            add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let addStatus = SecItemAdd(add as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw CredentialStoreError.keychain(addStatus) }
        } else if status != errSecSuccess {
            throw CredentialStoreError.keychain(status)
        }
    }

    func clear() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw CredentialStoreError.keychain(status)
        }
    }
}

/// Records whether the app has launched since it was installed.
///
/// The Keychain survives app deletion on iOS. RN keeps its session in app storage,
/// which a reinstall (or Maestro `clearState`) wipes. The session store clears stale
/// tokens once per install to keep the same signed-out first launch.
/// The live value uses `UserDefaults` (required-reason API, reason CA92.1, declared in
/// `PrivacyInfo.xcprivacy`).
protocol LaunchMarker: Sendable {
    func isFirstLaunchSinceInstall() async -> Bool
    func markLaunched() async
}

struct UserDefaultsLaunchMarker: LaunchMarker {
    private static let key = "hasLaunchedSinceInstall"

    func isFirstLaunchSinceInstall() async -> Bool {
        !UserDefaults.standard.bool(forKey: Self.key)
    }

    func markLaunched() async {
        UserDefaults.standard.set(true, forKey: Self.key)
    }
}
