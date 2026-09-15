import Foundation
import Testing
@testable import NativeShowcase

/// Records requests and replies with queued responses.
final class RecordingTransport: HTTPTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var responses: [(Int, Data)]
    private var recorded: [URLRequest] = []

    var requests: [URLRequest] { lock.withLock { recorded } }

    init(_ responses: [(Int, String)]) {
        self.responses = responses.map { ($0.0, Data($0.1.utf8)) }
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (status, body) = lock.withLock {
            recorded.append(request)
            return responses.isEmpty ? (500, Data()) : responses.removeFirst()
        }
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
        return (body, response)
    }
}

/// Routes responses by path and access token. Requests whose path ends with `gatedSuffix`
/// wait at `gate`, so tests order concurrent calls without sleeps (review finding A51).
final class RoutingTransport: HTTPTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: [URLRequest] = []
    private let route: @Sendable (URLRequest) -> (Int, String)
    private let gatedSuffix: String?
    let gate: Gate

    var requests: [URLRequest] { lock.withLock { recorded } }

    init(gatedSuffix: String? = nil, gate: Gate = Gate(), route: @escaping @Sendable (URLRequest) -> (Int, String)) {
        self.gatedSuffix = gatedSuffix
        self.gate = gate
        self.route = route
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        lock.withLock { recorded.append(request) }
        if let gatedSuffix, request.url!.path.hasSuffix(gatedSuffix) {
            await gate.pass()
        }
        let (status, body) = route(request)
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
        return (Data(body.utf8), response)
    }
}

final class Box<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: T
    init(_ value: T) { stored = value }
    var value: T {
        get { lock.withLock { stored } }
        set { lock.withLock { stored = newValue } }
    }
}

/// In-memory credential store. `saveGate` and `clearGate` hold writes open for ordering tests.
actor MemoryCredentialStore: CredentialStore {
    var saved: StoredSession?
    var saves = 0
    var failLoad: CredentialStoreError?
    /// Every write in the order it finished: "save:<did>" or "clear".
    var log: [String] = []
    nonisolated let saveGate: Gate
    nonisolated let clearGate: Gate

    init(saveGate: Gate = Gate(open: true), clearGate: Gate = Gate(open: true)) {
        self.saveGate = saveGate
        self.clearGate = clearGate
    }

    func load() throws -> StoredSession? {
        if let failLoad { throw failLoad }
        return saved
    }

    func save(_ session: StoredSession) async throws {
        saves += 1
        await saveGate.pass()
        saved = session
        log.append("save:\(session.did)")
    }

    func clear() async throws {
        await clearGate.pass()
        saved = nil
        log.append("clear")
    }

    func setSaved(_ session: StoredSession?) { saved = session }
    func setFailLoad(_ error: CredentialStoreError?) { failLoad = error }
}

actor FakeLaunchMarker: LaunchMarker {
    var first: Bool
    init(first: Bool = false) { self.first = first }
    func isFirstLaunchSinceInstall() -> Bool { first }
    func markLaunched() { first = false }
}

@Suite("XRPC client and token refresh")
struct NetworkingTests {
    let service = URL(string: "http://localhost:3000")!
    let proxy = "did:plc:bw7ad3erl7btq6qwf66yqiov#bsky_appview"

    private func session(access: String = "a1", refresh: String = "r1") -> StoredSession {
        StoredSession(service: service, did: "did:plc:alice", handle: "alice.test", accessJwt: access, refreshJwt: refresh)
    }

    private let sessionJSON = #"{"accessJwt":"a2","refreshJwt":"r2","did":"did:plc:alice","handle":"alice.test"}"#

    @Test func appViewQueriesCarryProxyAndAuth() async throws {
        let timeline = String(decoding: try Fixtures.data("getTimeline"), as: UTF8.self)
        let transport = RecordingTransport([(200, timeline)])
        let api = AuthenticatedBlueskyAPI(session: session(),
                                          client: XRPCClient(serviceURL: service, appViewProxy: proxy, transport: transport))
        let page = try await api.getTimeline(cursor: nil, limit: 30)
        #expect(page.feed.count == 5)

        let request = try #require(transport.requests.first)
        #expect(request.httpMethod == "GET")
        #expect(request.url?.absoluteString == "http://localhost:3000/xrpc/app.bsky.feed.getTimeline?limit=30")
        #expect(request.value(forHTTPHeaderField: "atproto-proxy") == proxy)
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer a1")
    }

    @Test func threadV2UsesRNParameters() async throws {
        let body = String(decoding: try Fixtures.data("getPostThreadV2"), as: UTF8.self)
        let transport = RecordingTransport([(200, body)])
        let api = AuthenticatedBlueskyAPI(session: session(),
                                          client: XRPCClient(serviceURL: service, appViewProxy: proxy, transport: transport))
        _ = try await api.getPostThreadV2(PostThreadRequest(anchor: "at://x/app.bsky.feed.post/1"))
        let url = try #require(transport.requests.first?.url)
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        #expect(url.path == "/xrpc/app.bsky.unspecced.getPostThreadV2")
        #expect(items.map { "\($0.name)=\($0.value ?? "")" } == [
            "anchor=at://x/app.bsky.feed.post/1", "branchingFactor=1", "below=10", "sort=top",
        ])
    }

    @Test func likeRecordCarriesViaAndGoesToThePDS() async throws {
        let transport = RecordingTransport([
            (200, #"{"uri":"at://did:plc:alice/app.bsky.feed.like/3abc","cid":"c"}"#),
            (200, "{}"),
        ])
        let api = AuthenticatedBlueskyAPI(session: session(),
                                          client: XRPCClient(serviceURL: service, appViewProxy: proxy, transport: transport))
        let via = StrongRef(uri: "at://did:plc:carla/app.bsky.feed.repost/r1", cid: "rc")
        let uri = try await api.like(StrongRef(uri: "at://did:plc:bob/app.bsky.feed.post/1", cid: "cid1"), via: via)
        #expect(uri == "at://did:plc:alice/app.bsky.feed.like/3abc")
        try await api.deleteLike(uri: uri)

        let create = transport.requests[0]
        #expect(create.url?.path == "/xrpc/com.atproto.repo.createRecord")
        #expect(create.value(forHTTPHeaderField: "atproto-proxy") == nil)
        let body = try #require(create.httpBody.flatMap { try JSONSerialization.jsonObject(with: $0) as? [String: Any] })
        let record = try #require(body["record"] as? [String: Any])
        #expect(record["$type"] as? String == "app.bsky.feed.like")
        #expect((record["subject"] as? [String: String]) == ["uri": "at://did:plc:bob/app.bsky.feed.post/1", "cid": "cid1"])
        #expect((record["via"] as? [String: String]) == ["uri": via.uri, "cid": "rc"])

        let deleteBody = try #require(transport.requests[1].httpBody.flatMap {
            try JSONSerialization.jsonObject(with: $0) as? [String: String]
        })
        #expect(deleteBody == ["repo": "did:plc:alice", "collection": "app.bsky.feed.like", "rkey": "3abc"])
    }

    @Test func expiredTokenRefreshesOnceAndRetries() async throws {
        let profile = String(decoding: try Fixtures.data("getProfile"), as: UTF8.self)
        let transport = RecordingTransport([
            (400, #"{"error":"ExpiredToken","message":"Token has expired"}"#),
            (200, sessionJSON),
            (200, profile),
        ])
        let updated = Box<StoredSession?>(nil)
        let api = AuthenticatedBlueskyAPI(
            session: session(),
            client: XRPCClient(serviceURL: service, appViewProxy: proxy, transport: transport),
            callbacks: SessionCallbacks(onTokensRefreshed: { updated.value = $0 }, onAuthFailure: {}))
        let result = try await api.getProfile(actor: "alice.test")
        #expect(result.handle == "alice.test")
        #expect(transport.requests.map { $0.url!.path } == [
            "/xrpc/app.bsky.actor.getProfile", "/xrpc/com.atproto.server.refreshSession", "/xrpc/app.bsky.actor.getProfile",
        ])
        #expect(transport.requests[1].value(forHTTPHeaderField: "Authorization") == "Bearer r1")
        #expect(transport.requests[2].value(forHTTPHeaderField: "Authorization") == "Bearer a2")
        #expect(updated.value?.refreshJwt == "r2")
    }

    @Test func concurrentExpiredCallsShareOneRefresh() async throws {
        let profile = String(decoding: try Fixtures.data("getProfile"), as: UTF8.self)
        let json = sessionJSON
        // The refresh waits at the gate until all three calls have failed with the old token.
        let transport = RoutingTransport(gatedSuffix: "refreshSession") { request in
            if request.url!.path.hasSuffix("refreshSession") { return (200, json) }
            if request.value(forHTTPHeaderField: "Authorization") == "Bearer a1" {
                return (400, #"{"error":"ExpiredToken"}"#)
            }
            return (200, profile)
        }
        let refreshes = Box(0)
        let api = AuthenticatedBlueskyAPI(
            session: session(),
            client: XRPCClient(serviceURL: service, appViewProxy: proxy, transport: transport),
            callbacks: SessionCallbacks(onTokensRefreshed: { _ in refreshes.value += 1 }, onAuthFailure: {}))
        async let one = api.getProfile(actor: "a")
        async let two = api.getProfile(actor: "b")
        async let three = api.getProfile(actor: "c")
        await transport.gate.waitForArrivals(1)
        while transport.requests.filter({ $0.url!.path.hasSuffix("getProfile") }).count < 3 { await Task.yield() }
        transport.gate.open()
        _ = try await (one, two, three)
        let refreshCalls = transport.requests.filter { $0.url!.path.hasSuffix("refreshSession") }
        #expect(refreshCalls.count == 1)
        #expect(refreshes.value == 1)
    }

    @Test func revokedRefreshTokenEndsTheSession() async throws {
        let transport = RecordingTransport([
            (400, #"{"error":"ExpiredToken"}"#),
            (400, #"{"error":"ExpiredToken","message":"Token has been revoked"}"#),
        ])
        let failed = Box(false)
        let api = AuthenticatedBlueskyAPI(
            session: session(),
            client: XRPCClient(serviceURL: service, appViewProxy: proxy, transport: transport),
            callbacks: SessionCallbacks(onTokensRefreshed: { _ in }, onAuthFailure: { failed.value = true }))
        await #expect(throws: XRPCError.self) { _ = try await api.getProfile(actor: "a") }
        #expect(failed.value)
        // Later calls fail fast without touching the network.
        await #expect(throws: XRPCError.sessionInvalidated) { _ = try await api.getProfile(actor: "a") }
        #expect(transport.requests.count == 2)
    }

    @Test func transientRefreshFailureKeepsTheSession() async throws {
        let transport = RecordingTransport([
            (400, #"{"error":"ExpiredToken"}"#),
            (502, #"{"error":"UpstreamFailure"}"#),
        ])
        let failed = Box(false)
        let api = AuthenticatedBlueskyAPI(
            session: session(),
            client: XRPCClient(serviceURL: service, appViewProxy: proxy, transport: transport),
            callbacks: SessionCallbacks(onTokensRefreshed: { _ in }, onAuthFailure: { failed.value = true }))
        await #expect(throws: XRPCError.self) { _ = try await api.getProfile(actor: "a") }
        #expect(!failed.value)
    }

    /// A refresh on the wire when the API is invalidated reports nothing, and `invalidate()`
    /// waits for it, so the revoke that follows uses the rotated refresh token (A1, A47).
    @Test func invalidationWaitsForRefreshAndRevokesWithNewestToken() async throws {
        let json = sessionJSON
        let transport = RoutingTransport(gatedSuffix: "refreshSession") { request in
            if request.url!.path.hasSuffix("refreshSession") { return (200, json) }
            if request.url!.path.hasSuffix("deleteSession") { return (200, "{}") }
            return (400, #"{"error":"ExpiredToken"}"#)
        }
        let updated = Box(false)
        let api = AuthenticatedBlueskyAPI(
            session: session(),
            client: XRPCClient(serviceURL: service, appViewProxy: proxy, transport: transport),
            callbacks: SessionCallbacks(onTokensRefreshed: { _ in updated.value = true }, onAuthFailure: {}))
        let call = Task { try await api.getProfile(actor: "a") }
        await transport.gate.waitForArrivals(1)
        let invalidation = Task { await api.invalidate() }
        while !(await api.isInvalidated) { await Task.yield() }
        transport.gate.open()
        await invalidation.value
        try await api.deleteSession()
        await #expect(throws: XRPCError.sessionInvalidated) { _ = try await call.value }
        #expect(!updated.value)
        let revoke = try #require(transport.requests.last { $0.url!.path.hasSuffix("deleteSession") })
        #expect(revoke.value(forHTTPHeaderField: "Authorization") == "Bearer r2")
    }

    @Test func httpErrorsSurfaceXRPCBody() async {
        let transport = RecordingTransport([(400, #"{"error":"InvalidRequest","message":"Bad anchor"}"#)])
        let api = AuthenticatedBlueskyAPI(session: session(),
                                          client: XRPCClient(serviceURL: service, appViewProxy: proxy, transport: transport))
        await #expect(throws: XRPCError.http(status: 400, error: "InvalidRequest", message: "Bad anchor")) {
            _ = try await api.getPostThreadV2(PostThreadRequest(anchor: "at://missing"))
        }
    }

    @Test func cancellationIsNotAFailure() {
        #expect(RequestFailure.isCancellation(CancellationError()))
        #expect(RequestFailure.isCancellation(URLError(.cancelled)))
        #expect(!RequestFailure.isCancellation(URLError(.notConnectedToInternet)))
    }
}

@MainActor
@Suite("Session store")
struct SessionStoreTests {
    let service = URL(string: "http://localhost:3000")!

    private func makeStore(_ credentials: MemoryCredentialStore, marker: FakeLaunchMarker = FakeLaunchMarker(),
                           apis: Box<[FakeBlueskyAPI]> = Box([]),
                           callbacks: Box<[SessionCallbacks]> = Box([]),
                           signInGate: Gate = Gate(open: true)) -> SessionStore {
        SessionStore(
            credentials: credentials, launchMarker: marker,
            makeAPI: { saved, cb in
                let api = FakeBlueskyAPI(accountDid: saved.did)
                apis.value.append(api)
                callbacks.value.append(cb)
                return api
            },
            signIn: { service, identifier, _ in
                await signInGate.pass()
                return StoredSession(service: service, did: "did:plc:\(identifier)", handle: identifier,
                                     accessJwt: "a", refreshJwt: "r")
            })
    }

    private func refreshed(_ handle: String, token: String = "late") -> StoredSession {
        StoredSession(service: service, did: "did:plc:\(handle)", handle: handle, accessJwt: token, refreshJwt: token)
    }

    @Test func signsInSavesRestoresAndSignsOut() async {
        let credentials = MemoryCredentialStore()
        let store = makeStore(credentials)
        #expect(store.state == .restoring)
        await store.restore()
        #expect(store.state == .signedOut)
        await store.signIn(service: service, identifier: "alice.test", password: "hunter2")
        #expect(store.state == .signedIn(did: "did:plc:alice.test", handle: "alice.test"))
        #expect(await credentials.saved?.handle == "alice.test")

        let restored = makeStore(credentials)
        await restored.restore()
        #expect(restored.state == .signedIn(did: "did:plc:alice.test", handle: "alice.test"))

        let apis = Box<[FakeBlueskyAPI]>([])
        let signingOut = makeStore(credentials, apis: apis)
        await signingOut.restore()
        signingOut.signOut()
        await signingOut.waitForPendingWork()
        #expect(signingOut.state == .signedOut)
        #expect(await credentials.saved == nil)
        let api = apis.value.first
        #expect(api != nil)
        // The revoke waits for invalidation, so both are done once pending work is.
        #expect(await api?.invalidated == true)
        #expect(await api?.calls == ["deleteSession"])
    }

    @Test func firstLaunchClearsStaleKeychainItem() async {
        let credentials = MemoryCredentialStore()
        await credentials.setSaved(StoredSession(service: service, did: "did:plc:old", handle: "old", accessJwt: "a",
                                                 refreshJwt: "r"))
        let store = makeStore(credentials, marker: FakeLaunchMarker(first: true))
        await store.restore()
        #expect(store.state == .signedOut)
        #expect(await credentials.saved == nil)
    }

    @Test func restoreRunsOnce() async {
        let credentials = MemoryCredentialStore()
        let store = makeStore(credentials)
        await store.restore()
        await store.signIn(service: service, identifier: "alice.test", password: "x")
        await store.restore()
        #expect(store.state == .signedIn(did: "did:plc:alice.test", handle: "alice.test"))
    }

    @Test func onlyCorruptItemsAreDeleted() async {
        let credentials = MemoryCredentialStore()
        let saved = StoredSession(service: service, did: "did:plc:a", handle: "a", accessJwt: "a", refreshJwt: "r")
        await credentials.setSaved(saved)
        await credentials.setFailLoad(.keychain(errSecInteractionNotAllowed))
        let locked = makeStore(credentials)
        await locked.restore()
        #expect(locked.state == .signedOut)
        await credentials.setFailLoad(nil)
        #expect(await credentials.saved == saved)

        await credentials.setFailLoad(.corrupt)
        let corrupt = makeStore(credentials)
        await corrupt.restore()
        await credentials.setFailLoad(nil)
        #expect(await credentials.saved == nil)
    }

    @Test func staleRefreshAfterSignOutIsDropped() async {
        let credentials = MemoryCredentialStore()
        let callbacks = Box<[SessionCallbacks]>([])
        let store = makeStore(credentials, callbacks: callbacks)
        await store.restore()
        await store.signIn(service: service, identifier: "alice.test", password: "x")
        let staleCallbacks = callbacks.value.last
        store.signOut()
        await store.waitForPendingWork()
        let savesBefore = await credentials.saves
        staleCallbacks?.onTokensRefreshed(refreshed("alice.test"))
        await store.waitForPendingWork()
        #expect(await credentials.saved == nil)
        #expect(await credentials.saves == savesBefore)
        #expect(store.state == .signedOut)
    }

    /// Review finding A46 (a): alice's refresh is reported while bob's save is suspended.
    /// The chain runs it after bob's save and its generation check drops it.
    @Test func refreshFromPreviousAccountCannotLandAfterNewAccountSave() async {
        let saveGate = Gate(open: true)
        let credentials = MemoryCredentialStore(saveGate: saveGate)
        let callbacks = Box<[SessionCallbacks]>([])
        let store = makeStore(credentials, callbacks: callbacks)
        await store.restore()
        await store.signIn(service: service, identifier: "alice.test", password: "x")
        let alice = callbacks.value.last

        saveGate.close()
        let arrivals = saveGate.arrivalCount
        let bobSignIn = Task { await store.signIn(service: service, identifier: "bob.test", password: "x") }
        await saveGate.waitForArrivals(arrivals + 1)
        alice?.onTokensRefreshed(refreshed("alice.test"))
        saveGate.open()
        await bobSignIn.value
        await store.waitForPendingWork()

        #expect(await credentials.saved?.did == "did:plc:bob.test")
        #expect(await credentials.log == ["save:did:plc:alice.test", "save:did:plc:bob.test"])
        #expect(store.state == .signedIn(did: "did:plc:bob.test", handle: "bob.test"))
    }

    /// Review finding A46 (b): a quick sign-in after sign-out. The sign-out's clear is held open;
    /// the new save must land after it, so the new session survives.
    @Test func signOutClearCannotEraseQuickSignIn() async {
        let clearGate = Gate(open: true)
        let credentials = MemoryCredentialStore(clearGate: clearGate)
        let store = makeStore(credentials)
        await store.restore()
        await store.signIn(service: service, identifier: "alice.test", password: "x")

        clearGate.close()
        let arrivals = clearGate.arrivalCount
        store.signOut()
        await clearGate.waitForArrivals(arrivals + 1)
        let enqueued = store.credentialWritesEnqueued
        let bobSignIn = Task { await store.signIn(service: service, identifier: "bob.test", password: "x") }
        // Bob's save is enqueued behind the held clear before the clear is released.
        while store.credentialWritesEnqueued == enqueued { await Task.yield() }
        clearGate.open()
        await bobSignIn.value
        await store.waitForPendingWork()

        #expect(await credentials.log == ["save:did:plc:alice.test", "clear", "save:did:plc:bob.test"])
        #expect(await credentials.saved?.did == "did:plc:bob.test")
        #expect(store.state == .signedIn(did: "did:plc:bob.test", handle: "bob.test"))
    }

    /// Review finding A49: a sign-out while `createSession` is in flight wins.
    @Test func signOutDuringSignInWins() async {
        let signInGate = Gate()
        let credentials = MemoryCredentialStore()
        let store = makeStore(credentials, signInGate: signInGate)
        await store.restore()
        let signIn = Task { await store.signIn(service: service, identifier: "alice.test", password: "x") }
        await signInGate.waitForArrivals(1)
        store.signOut()
        signInGate.open()
        await signIn.value
        await store.waitForPendingWork()
        #expect(store.state == .signedOut)
        #expect(await credentials.saved == nil)
        #expect(await credentials.log == ["clear"])
    }

    /// Review finding A48: token updates save in the order the API reported them.
    @Test func refreshesSaveInReportedOrder() async {
        let saveGate = Gate(open: true)
        let credentials = MemoryCredentialStore(saveGate: saveGate)
        let callbacks = Box<[SessionCallbacks]>([])
        let store = makeStore(credentials, callbacks: callbacks)
        await store.restore()
        await store.signIn(service: service, identifier: "alice.test", password: "x")
        saveGate.close()
        let arrivals = saveGate.arrivalCount
        callbacks.value.last?.onTokensRefreshed(refreshed("alice.test", token: "t1"))
        callbacks.value.last?.onTokensRefreshed(refreshed("alice.test", token: "t2"))
        await saveGate.waitForArrivals(arrivals + 1)
        saveGate.open()
        await store.waitForPendingWork()
        #expect(await credentials.saved?.refreshJwt == "t2")
    }

    @Test func staleRefreshFromAnotherAccountIsDropped() async {
        let credentials = MemoryCredentialStore()
        let callbacks = Box<[SessionCallbacks]>([])
        let store = makeStore(credentials, callbacks: callbacks)
        await store.restore()
        await store.signIn(service: service, identifier: "alice.test", password: "x")
        let aliceCallbacks = callbacks.value.last
        await store.signIn(service: service, identifier: "bob.test", password: "x")
        aliceCallbacks?.onTokensRefreshed(refreshed("alice.test", token: "x"))
        await store.waitForPendingWork()
        #expect(await credentials.saved?.did == "did:plc:bob.test")
    }

    @Test func authFailureSignsOut() async {
        let credentials = MemoryCredentialStore()
        let callbacks = Box<[SessionCallbacks]>([])
        let store = makeStore(credentials, callbacks: callbacks)
        await store.restore()
        await store.signIn(service: service, identifier: "alice.test", password: "x")
        callbacks.value.last?.onAuthFailure()
        await store.waitForPendingWork()
        #expect(store.state == .signedOut)
        #expect(await credentials.saved == nil)
    }

    @Test func failedSignInStaysSignedOut() async {
        let credentials = MemoryCredentialStore()
        let store = SessionStore(credentials: credentials, launchMarker: FakeLaunchMarker(),
                                 makeAPI: { saved, _ in FakeBlueskyAPI(accountDid: saved.did) },
                                 signIn: { _, _, _ in
                                     throw XRPCError.http(status: 401, error: "AuthenticationRequired",
                                                          message: "Invalid identifier or password")
                                 })
        await store.restore()
        await store.signIn(service: service, identifier: "alice.test", password: "wrong")
        #expect(store.state == .signedOut)
        #expect(store.api == nil)
        #expect(await credentials.saves == 0)
    }
}

/// Runs against the real Keychain inside the hosted test app.
@Suite("Keychain credential store")
struct KeychainTests {
    @Test func roundTripAndClear() async throws {
        let store = KeychainCredentialStore(service: "io.nativestarter.showcase.bluesky.tests.\(UUID().uuidString)")
        #expect(try await store.load() == nil)
        let session = StoredSession(service: URL(string: "http://localhost:3000")!, did: "did:plc:alice",
                                    handle: "alice.test", accessJwt: "a1", refreshJwt: "r1")
        try await store.save(session)
        #expect(try await store.load() == session)
        var updated = session
        updated.accessJwt = "a2"
        try await store.save(updated)
        #expect(try await store.load()?.accessJwt == "a2")
        try await store.clear()
        #expect(try await store.load() == nil)
        try await store.clear()
    }
}

@Suite("SVG path parser")
struct SVGPathTests {
    @Test func parsesAllIconGlyphs() throws {
        for glyph in IconGlyph.allCases {
            for data in glyph.pathData {
                let path = try SVGPathParser.parse(data)
                #expect(!path.isEmpty, "\(glyph) produced an empty path")
                let box = path.boundingRect
                #expect(box.minX >= -0.5 && box.maxX <= 24.5 && box.minY >= -0.5 && box.maxY <= 24.5,
                        "\(glyph) is outside the 24pt grid: \(box)")
            }
        }
    }

    @Test func relativeCommandsAndArcs() throws {
        let square = try SVGPathParser.parse("M2 2h10v10h-10z")
        #expect(square.boundingRect == CGRect(x: 2, y: 2, width: 10, height: 10))
        let circle = try SVGPathParser.parse("M3 12a9 9 0 1 0 18 0a9 9 0 1 0 -18 0Z")
        let box = circle.boundingRect
        #expect(abs(box.minX - 3) < 0.01 && abs(box.maxX - 21) < 0.01)
        #expect(abs(box.minY - 3) < 0.01 && abs(box.maxY - 21) < 0.01)
        #expect(!(try SVGPathParser.parse("M1.5.5l2-2a1 1 0 011 1")).isEmpty)
    }

    @Test func rejectsGarbage() {
        #expect(throws: SVGPathParser.ParseError.self) { try SVGPathParser.parse("M1 x") }
    }
}
