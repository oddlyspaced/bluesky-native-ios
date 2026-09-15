import Foundation
import Observation
import os

/// Callbacks from a live API back to the session store.
///
/// The API actor never writes credentials itself. It reports token changes and terminal
/// auth failures here. Both callbacks are synchronous: the session store enqueues the work on
/// its credential write chain at once, so reports keep the order the API made them in.
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
/// Rules that protect the Keychain from stale writers (review findings A1, A46 to A49):
/// - Every credential write goes through one ordered chain (`CredentialWriteChain`).
/// - Every session transition starts a new generation. A token save checks, inside the chain
///   and just before it writes, that its generation is still current and its DID is active.
/// - Sign-out enqueues its Keychain clear at once, so a later sign-in's save always lands after it.
/// - A sign-in that returns after a sign-out or another sign-in is dropped.
/// - Sign-out waits for the old API's `invalidate()`, which waits for a refresh in flight, and
///   only then revokes the server session with the newest refresh token.
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

    @ObservationIgnored private let credentials: any CredentialStore
    @ObservationIgnored private let launchMarker: any LaunchMarker
    @ObservationIgnored private let makeAPI: APIFactory
    @ObservationIgnored private let signInCall: SignInFunction
    @ObservationIgnored private let writes = CredentialWriteChain()
    @ObservationIgnored private var restoreStarted = false
    /// Server revokes started by sign-out, chained in order.
    @ObservationIgnored private var revokeTask: Task<Void, Never>?
    @ObservationIgnored private let log = Logger(subsystem: "io.nativestarter.showcase.bluesky", category: "session")

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
        let start = writes.generation
        if await launchMarker.isFirstLaunchSinceInstall() {
            await clearCredentials(ifCurrent: start, reason: "stale credentials after reinstall")
            await launchMarker.markLaunched()
        }
        do {
            let saved = try await credentials.load()
            // A sign-in that finished while the Keychain answered wins.
            guard state == .restoring, writes.isCurrent(start) else { return }
            if let saved {
                activate(saved, generation: writes.bumpGeneration())
                return
            }
        } catch CredentialStoreError.corrupt {
            // Only an undecodable item is deleted. Other Keychain errors (for example,
            // the device is locked) keep the item for the next launch.
            await clearCredentials(ifCurrent: start, reason: "corrupt credentials")
        } catch {
            log.error("Loading credentials failed: \(String(describing: error), privacy: .public)")
        }
        if state == .restoring { state = .signedOut }
    }

    /// Signs in and saves the session before it becomes active.
    func signIn(service: URL, identifier: String, password: String) async {
        let start = writes.generation
        let session: StoredSession
        do {
            session = try await signInCall(service, identifier, password)
        } catch {
            log.error("Sign-in failed: \(String(describing: error), privacy: .public)")
            if case .signedIn = state { return }
            state = .signedOut
            return
        }
        // A sign-out or another sign-in finished while this one waited (review finding A49).
        guard writes.isCurrent(start) else {
            log.info("Dropped a sign-in that a later session transition replaced")
            return
        }
        // The new generation drops every token write still reported by the previous session.
        let generation = writes.bumpGeneration()
        let previous = api
        let credentials = self.credentials
        let writes = self.writes
        let log = self.log
        // The save runs after every pending write, including a sign-out's clear.
        let saved = await writes.enqueue { () -> Bool in
            guard writes.isCurrent(generation) else { return false }
            do {
                try await credentials.save(session)
                return true
            } catch {
                log.error("Saving the new session failed: \(String(describing: error), privacy: .public)")
                return false
            }
        }.value
        await previous?.invalidate()
        guard saved, writes.isCurrent(generation) else {
            if api == nil { state = .signedOut }
            return
        }
        activate(session, generation: generation)
    }

    /// Signs out: detaches the API, clears the Keychain, then revokes the server session.
    func signOut() {
        _ = writes.bumpGeneration()
        let old = api
        api = nil
        state = .signedOut
        let credentials = self.credentials
        let log = self.log
        // Unconditional and enqueued now, so a later sign-in's save always lands after it.
        writes.enqueue {
            do { try await credentials.clear() } catch {
                log.error("Clearing credentials failed: \(String(describing: error), privacy: .public)")
            }
        }
        guard let old else { return }
        let previousRevoke = revokeTask
        revokeTask = Task {
            await previousRevoke?.value
            // Waits for a refresh in flight, so the revoke uses the newest refresh token (A47).
            await old.invalidate()
            do { try await old.deleteSession() } catch {
                log.error("deleteSession failed: \(String(describing: error), privacy: .public)")
            }
        }
    }

    /// Returns when all credential writes and server revokes started so far have finished.
    func waitForPendingWork() async {
        while true {
            let enqueued = writes.enqueuedCount
            let revoke = revokeTask
            await writes.waitUntilIdle()
            await revoke?.value
            if enqueued == writes.enqueuedCount, revoke == revokeTask { return }
        }
    }

    /// Number of credential writes enqueued so far. Tests wait on it.
    var credentialWritesEnqueued: Int { writes.enqueuedCount }

    // MARK: - Private

    private func clearCredentials(ifCurrent generation: Int, reason: String) async {
        let credentials = self.credentials
        let writes = self.writes
        let log = self.log
        await writes.enqueue {
            guard writes.isCurrent(generation) else { return }
            do { try await credentials.clear() } catch {
                log.error("Clearing \(reason, privacy: .public) failed: \(String(describing: error), privacy: .public)")
            }
        }.value
    }

    private func activate(_ session: StoredSession, generation: Int) {
        let writes = self.writes
        let credentials = self.credentials
        let log = self.log
        let did = session.did
        let callbacks = SessionCallbacks(
            onTokensRefreshed: { updated in
                writes.enqueue {
                    guard writes.isCurrent(generation), updated.did == did else {
                        log.info("Dropped a token update from an inactive session")
                        return
                    }
                    do { try await credentials.save(updated) } catch {
                        log.error("Saving refreshed tokens failed: \(String(describing: error), privacy: .public)")
                    }
                }
            },
            onAuthFailure: { [weak self] in
                let store = self
                writes.enqueue {
                    await store?.handleAuthFailure(generation: generation)
                }
            }
        )
        api = makeAPI(session, callbacks)
        state = .signedIn(did: session.did, handle: session.handle)
    }

    private func handleAuthFailure(generation: Int) {
        guard writes.isCurrent(generation), api != nil else { return }
        log.info("Session expired; signing out")
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
