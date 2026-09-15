import Foundation
import Observation
import os

/// Callbacks from a live API back to the session store.
///
/// The API actor never writes credentials itself. It reports token changes and terminal
/// auth failures here, and the session store decides on the main actor whether they
/// still apply (same account, same activation).
struct SessionCallbacks: Sendable {
    var onTokensRefreshed: @Sendable (StoredSession) -> Void
    var onAuthFailure: @Sendable () -> Void

    static let none = SessionCallbacks(onTokensRefreshed: { _ in }, onAuthFailure: {})
}

/// Creates a `BlueskyAPI` for a stored session. Tests inject a factory that returns a fake.
typealias APIFactory = @Sendable (StoredSession, SessionCallbacks) -> any SessionBoundAPI

/// Signs in with `com.atproto.server.createSession`. Tests inject a fake.
typealias SignInFunction = @Sendable (_ service: URL, _ identifier: String, _ password: String) async throws -> StoredSession

/// Owns the signed-in state of the app.
///
/// Rules that protect the Keychain from stale writers (review finding A1):
/// - Every activation gets a new `generation`.
/// - A token update is accepted only when its DID and generation match the active session.
/// - Sign-out and account switches call `invalidate()` on the old API before anything else,
///   so a refresh still in flight cannot report new tokens.
@MainActor
@Observable
final class SessionStore {
    enum State: Equatable {
        case restoring
        case signedOut
        case signedIn(did: String, handle: String)
    }

    private(set) var state: State = .restoring
    private(set) var api: (any SessionBoundAPI)?
    private(set) var lastError: String?

    @ObservationIgnored private let credentials: any CredentialStore
    @ObservationIgnored private let launchMarker: any LaunchMarker
    @ObservationIgnored private let makeAPI: APIFactory
    @ObservationIgnored private let signInCall: SignInFunction
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var activeDid: String?
    @ObservationIgnored private var restoreStarted = false
    @ObservationIgnored private let log = Logger(subsystem: "io.nativestarter.showcase.bluesky", category: "session")

    /// Background work started by sign-out (server revoke, Keychain clear). Tests await it.
    @ObservationIgnored private(set) var pendingWork: Task<Void, Never>?

    init(credentials: any CredentialStore, launchMarker: any LaunchMarker, makeAPI: @escaping APIFactory,
         signIn: @escaping SignInFunction) {
        self.credentials = credentials
        self.launchMarker = launchMarker
        self.makeAPI = makeAPI
        self.signInCall = signIn
    }

    /// Restores a saved session, if any. State stays `.restoring` until the Keychain answers.
    /// Calling it again after the first call does nothing.
    func restore() async {
        guard state == .restoring, !restoreStarted else { return }
        restoreStarted = true
        let credentials = self.credentials
        if await launchMarker.isFirstLaunchSinceInstall() {
            do { try await credentials.clear() } catch {
                log.error("Clearing stale credentials failed: \(String(describing: error), privacy: .public)")
            }
            await launchMarker.markLaunched()
        }
        do {
            if let saved = try await credentials.load(), state == .restoring {
                activate(saved)
                return
            }
        } catch CredentialStoreError.corrupt {
            // Only an undecodable item is deleted. Other Keychain errors (for example,
            // the device is locked) keep the item for the next launch.
            try? await credentials.clear()
        } catch {
            log.error("Loading credentials failed: \(String(describing: error), privacy: .public)")
        }
        if state == .restoring { state = .signedOut }
    }

    func signIn(service: URL, identifier: String, password: String) async {
        lastError = nil
        do {
            let session = try await signInCall(service, identifier, password)
            try await credentials.save(session)
            activate(session)
        } catch {
            lastError = String(describing: error)
            if case .signedIn = state { return }
            state = .signedOut
        }
    }

    /// Signs out: invalidates the API, revokes the server session and clears the Keychain.
    func signOut() {
        guard let old = deactivate() else {
            state = .signedOut
            return
        }
        state = .signedOut
        let credentials = self.credentials
        let log = self.log
        let previous = pendingWork
        pendingWork = Task {
            await previous?.value
            do { try await old.deleteSession() } catch {
                log.error("deleteSession failed: \(String(describing: error), privacy: .public)")
            }
            do { try await credentials.clear() } catch {
                log.error("Clearing credentials failed: \(String(describing: error), privacy: .public)")
            }
        }
    }

    // MARK: - Private

    private func activate(_ session: StoredSession) {
        _ = deactivate()
        generation += 1
        let generation = self.generation
        activeDid = session.did
        let callbacks = SessionCallbacks(
            onTokensRefreshed: { [weak self] updated in
                Task { @MainActor in await self?.acceptRefreshedTokens(updated, generation: generation) }
            },
            onAuthFailure: { [weak self] in
                Task { @MainActor in self?.handleAuthFailure(generation: generation) }
            }
        )
        api = makeAPI(session, callbacks)
        state = .signedIn(did: session.did, handle: session.handle)
    }

    /// Detaches the current API and returns it, already invalidated.
    private func deactivate() -> (any SessionBoundAPI)? {
        guard let old = api else { return nil }
        generation += 1
        activeDid = nil
        api = nil
        Task { await old.invalidate() }
        return old
    }

    func acceptRefreshedTokens(_ updated: StoredSession, generation: Int) async {
        guard generation == self.generation, updated.did == activeDid else {
            log.info("Dropped a token update from an inactive session")
            return
        }
        do { try await credentials.save(updated) } catch {
            lastError = String(describing: error)
            log.error("Saving refreshed tokens failed: \(String(describing: error), privacy: .public)")
        }
    }

    private func handleAuthFailure(generation: Int) {
        guard generation == self.generation, api != nil else { return }
        lastError = "Session expired"
        signOut()
    }
}

extension SessionStore {
    /// Live dependencies: XRPC over an ephemeral URLSession and the Keychain.
    static func live(appViewProxy: String?) -> SessionStore {
        let transport = URLSessionTransport.ephemeral()
        return SessionStore(
            credentials: KeychainCredentialStore(),
            launchMarker: UserDefaultsLaunchMarker(),
            makeAPI: { session, callbacks in
                AuthenticatedBlueskyAPI(
                    session: session,
                    client: XRPCClient(serviceURL: session.service, appViewProxy: appViewProxy, transport: transport),
                    callbacks: callbacks
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
