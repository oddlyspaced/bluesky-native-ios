import Foundation
import Observation
import Security

/// Persists the signed-in account's tokens.
protocol CredentialStore: Sendable {
    func load() throws -> StoredSession?
    func save(_ session: StoredSession) throws
    func clear() throws
}

/// Keychain-backed credential store.
///
/// Tokens are stored as one generic password item with
/// `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`, so they are not backed up
/// or restored to another device.
struct KeychainCredentialStore: CredentialStore {
    var service = "xyz.blueskyweb.app.native.session"
    var account = "current"

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
            throw KeychainError(status: status)
        }
        return try JSONDecoder().decode(StoredSession.self, from: data)
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
            guard addStatus == errSecSuccess else { throw KeychainError(status: addStatus) }
        } else if status != errSecSuccess {
            throw KeychainError(status: status)
        }
    }

    func clear() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError(status: status)
        }
    }
}

struct KeychainError: Error, Equatable {
    var status: OSStatus
}

/// Creates a `BlueskyAPI` for a stored session. Tests inject a factory that returns a fake.
typealias APIFactory = @Sendable (StoredSession, @escaping @Sendable (StoredSession) -> Void) -> any BlueskyAPI

/// Signs in with `com.atproto.server.createSession`. Tests inject a fake.
typealias SignInFunction = @Sendable (_ service: URL, _ identifier: String, _ password: String) async throws -> StoredSession

/// Owns the signed-in state of the app.
@MainActor
@Observable
final class SessionStore {
    enum State: Equatable {
        case restoring
        case signedOut
        case signedIn(did: String, handle: String)
    }

    private(set) var state: State = .restoring
    private(set) var api: (any BlueskyAPI)?
    private(set) var lastError: String?

    private let credentials: any CredentialStore
    private let makeAPI: APIFactory
    private let signInCall: SignInFunction

    init(credentials: any CredentialStore, makeAPI: @escaping APIFactory, signIn: @escaping SignInFunction) {
        self.credentials = credentials
        self.makeAPI = makeAPI
        self.signInCall = signIn
    }

    /// Restores a saved session, if any.
    func restore() {
        do {
            if let saved = try credentials.load() {
                activate(saved)
                return
            }
        } catch {
            try? credentials.clear()
        }
        state = .signedOut
    }

    func signIn(service: URL, identifier: String, password: String) async {
        lastError = nil
        do {
            let session = try await signInCall(service, identifier, password)
            try? credentials.save(session)
            activate(session)
        } catch {
            lastError = String(describing: error)
            state = .signedOut
        }
    }

    func signOut() {
        try? credentials.clear()
        api = nil
        state = .signedOut
    }

    private func activate(_ session: StoredSession) {
        let store = credentials
        api = makeAPI(session) { updated in try? store.save(updated) }
        state = .signedIn(did: session.did, handle: session.handle)
    }
}

extension SessionStore {
    /// Live dependencies: XRPC over URLSession and the keychain.
    static func live(appViewProxy: String?) -> SessionStore {
        let transport = URLSessionTransport()
        return SessionStore(
            credentials: KeychainCredentialStore(),
            makeAPI: { session, onUpdate in
                AuthenticatedBlueskyAPI(
                    session: session,
                    client: XRPCClient(serviceURL: session.service, appViewProxy: appViewProxy, transport: transport),
                    onSessionUpdate: onUpdate
                )
            },
            signIn: { service, identifier, password in
                struct Body: Encodable {
                    var identifier: String
                    var password: String
                }
                let client = XRPCClient(serviceURL: service, appViewProxy: nil, transport: transport)
                let response: SessionResponse = try await client.procedure(
                    "com.atproto.server.createSession",
                    body: Body(identifier: identifier, password: password),
                    accessToken: nil)
                return StoredSession(service: service, did: response.did, handle: response.handle,
                                     accessJwt: response.accessJwt, refreshJwt: response.refreshJwt)
            }
        )
    }
}
