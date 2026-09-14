import Foundation
import SwiftUI
import Testing
@testable import BlueskyNative

/// Records requests and replies with queued responses.
final class RecordingTransport: HTTPTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var responses: [(Int, Data)]
    private(set) var requests: [URLRequest] = []

    init(_ responses: [(Int, String)]) {
        self.responses = responses.map { ($0.0, Data($0.1.utf8)) }
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (status, body) = lock.withLock {
            requests.append(request)
            return responses.isEmpty ? (500, Data()) : responses.removeFirst()
        }
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
        return (body, response)
    }
}

@Suite("XRPC client")
struct NetworkingTests {
    let service = URL(string: "http://localhost:3000")!
    let proxy = "did:plc:kmmukaomzqnk3fln2m5guony#bsky_appview"

    private func session(access: String = "a1", refresh: String = "r1") -> StoredSession {
        StoredSession(service: service, did: "did:plc:alice", handle: "alice.test", accessJwt: access, refreshJwt: refresh)
    }

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

    @Test func repoProceduresGoToThePDSWithoutProxy() async throws {
        let transport = RecordingTransport([
            (200, #"{"uri":"at://did:plc:alice/app.bsky.feed.like/3abc","cid":"c"}"#),
            (200, "{}"),
        ])
        let api = AuthenticatedBlueskyAPI(session: session(),
                                          client: XRPCClient(serviceURL: service, appViewProxy: proxy, transport: transport))
        let uri = try await api.like(StrongRef(uri: "at://did:plc:bob/app.bsky.feed.post/1", cid: "cid1"))
        #expect(uri == "at://did:plc:alice/app.bsky.feed.like/3abc")
        try await api.deleteLike(uri: uri)

        let create = transport.requests[0]
        #expect(create.url?.path == "/xrpc/com.atproto.repo.createRecord")
        #expect(create.httpMethod == "POST")
        #expect(create.value(forHTTPHeaderField: "atproto-proxy") == nil)
        let body = try #require(create.httpBody.flatMap { try JSONSerialization.jsonObject(with: $0) as? [String: Any] })
        #expect(body["repo"] as? String == "did:plc:alice")
        #expect(body["collection"] as? String == "app.bsky.feed.like")
        let record = try #require(body["record"] as? [String: Any])
        #expect(record["$type"] as? String == "app.bsky.feed.like")
        #expect((record["subject"] as? [String: String]) == ["uri": "at://did:plc:bob/app.bsky.feed.post/1", "cid": "cid1"])

        let delete = transport.requests[1]
        let deleteBody = try #require(delete.httpBody.flatMap { try JSONSerialization.jsonObject(with: $0) as? [String: String] })
        #expect(deleteBody == ["repo": "did:plc:alice", "collection": "app.bsky.feed.like", "rkey": "3abc"])
    }

    @Test func expiredTokenRefreshesOnceAndRetries() async throws {
        let profile = String(decoding: try Fixtures.data("getProfile"), as: UTF8.self)
        let transport = RecordingTransport([
            (400, #"{"error":"ExpiredToken","message":"Token has expired"}"#),
            (200, #"{"accessJwt":"a2","refreshJwt":"r2","did":"did:plc:alice","handle":"alice.test"}"#),
            (200, profile),
        ])
        let updated = Box<StoredSession?>(nil)
        let api = AuthenticatedBlueskyAPI(
            session: session(),
            client: XRPCClient(serviceURL: service, appViewProxy: proxy, transport: transport),
            onSessionUpdate: { updated.value = $0 })
        let result = try await api.getProfile(actor: "alice.test")
        #expect(result.handle == "alice.test")
        #expect(transport.requests.map { $0.url!.path } == [
            "/xrpc/app.bsky.actor.getProfile", "/xrpc/com.atproto.server.refreshSession", "/xrpc/app.bsky.actor.getProfile",
        ])
        #expect(transport.requests[1].value(forHTTPHeaderField: "Authorization") == "Bearer r1")
        #expect(transport.requests[2].value(forHTTPHeaderField: "Authorization") == "Bearer a2")
        #expect(updated.value?.refreshJwt == "r2")
    }

    @Test func httpErrorsSurfaceXRPCBody() async {
        let transport = RecordingTransport([(400, #"{"error":"NotFound","message":"Post not found"}"#)])
        let api = AuthenticatedBlueskyAPI(session: session(),
                                          client: XRPCClient(serviceURL: service, appViewProxy: proxy, transport: transport))
        await #expect(throws: XRPCError.http(status: 400, error: "NotFound", message: "Post not found")) {
            _ = try await api.getPostThread(uri: "at://missing")
        }
    }

    @MainActor
    @Test func sessionStoreSignsInSavesAndSignsOut() async {
        let store = MemoryCredentialStore()
        let session = SessionStore(
            credentials: store,
            makeAPI: { saved, _ in FakeBlueskyAPI(accountDid: saved.did) },
            signIn: { service, identifier, _ in
                StoredSession(service: service, did: "did:plc:\(identifier)", handle: identifier,
                              accessJwt: "a", refreshJwt: "r")
            })
        session.restore()
        #expect(session.state == .signedOut)
        await session.signIn(service: service, identifier: "alice.test", password: "hunter2")
        #expect(session.state == .signedIn(did: "did:plc:alice.test", handle: "alice.test"))
        #expect(session.api?.accountDid == "did:plc:alice.test")
        #expect(store.saved?.handle == "alice.test")

        let restored = SessionStore(credentials: store, makeAPI: { saved, _ in FakeBlueskyAPI(accountDid: saved.did) },
                                    signIn: { _, _, _ in throw FakeBlueskyAPI.Failure() })
        restored.restore()
        #expect(restored.state == .signedIn(did: "did:plc:alice.test", handle: "alice.test"))

        session.signOut()
        #expect(session.state == .signedOut)
        #expect(store.saved == nil)
    }

    @MainActor
    @Test func failedSignInStaysSignedOut() async {
        let session = SessionStore(credentials: MemoryCredentialStore(),
                                   makeAPI: { saved, _ in FakeBlueskyAPI(accountDid: saved.did) },
                                   signIn: { _, _, _ in
                                       throw XRPCError.http(status: 401, error: "AuthenticationRequired",
                                                            message: "Invalid identifier or password")
                                   })
        session.restore()
        await session.signIn(service: service, identifier: "alice.test", password: "wrong")
        #expect(session.state == .signedOut)
        #expect(session.lastError != nil)
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
        // A 10x10 square drawn with relative commands.
        let square = try SVGPathParser.parse("M2 2h10v10h-10z")
        #expect(square.boundingRect == CGRect(x: 2, y: 2, width: 10, height: 10))
        // A full circle of radius 9 around (12, 12) from two arcs, as in Lucide circles.
        let circle = try SVGPathParser.parse("M3 12a9 9 0 1 0 18 0a9 9 0 1 0 -18 0Z")
        let box = circle.boundingRect
        #expect(abs(box.minX - 3) < 0.01 && abs(box.maxX - 21) < 0.01)
        #expect(abs(box.minY - 3) < 0.01 && abs(box.maxY - 21) < 0.01)
        // Compact numbers: "1.5.5" is 1.5 and .5; flags without separators.
        let compact = try SVGPathParser.parse("M1.5.5l2-2a1 1 0 011 1")
        #expect(!compact.isEmpty)
    }

    @Test func rejectsGarbage() {
        #expect(throws: SVGPathParser.ParseError.self) { try SVGPathParser.parse("M1 x") }
    }
}

final class Box<T>: @unchecked Sendable {
    var value: T
    init(_ value: T) { self.value = value }
}

final class MemoryCredentialStore: CredentialStore, @unchecked Sendable {
    var saved: StoredSession?
    func load() throws -> StoredSession? { saved }
    func save(_ session: StoredSession) throws { saved = session }
    func clear() throws { saved = nil }
}
