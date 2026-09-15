import Foundation

/// Errors raised by XRPC calls.
enum XRPCError: Error, Equatable, Sendable {
    /// The server answered with a non-2xx status and, usually, an XRPC error body.
    case http(status: Int, error: String?, message: String?)
    /// The response was not HTTP or its body could not be decoded.
    case invalidResponse(String)
    /// The request URL could not be built from the service URL and NSID.
    case invalidRequest(String)
    /// The API was invalidated by sign-out or an account switch.
    case sessionInvalidated

    var isExpiredToken: Bool {
        if case .http(_, let error, _) = self { return error == "ExpiredToken" }
        return false
    }

    /// A refresh failure that ends the session. RN's `PasswordSession.refresh` calls
    /// `onDeleted` only for the lexicon's schema errors (`refreshSession.defs.js:24-26`);
    /// any other failure keeps the session ("network-error").
    var isTerminalAuthFailure: Bool {
        guard case .http(_, let error, _) = self else { return false }
        return error == "ExpiredToken" || error == "InvalidToken" || error == "AccountTakedown"
    }

    /// The first response that makes RN's session retry after a refresh: HTTP 401, or
    /// HTTP 400 with `ExpiredToken` (`password-session.js:115-159`).
    var needsTokenRefresh: Bool {
        guard case .http(let status, let error, _) = self else { return false }
        return status == 401 || (status == 400 && error == "ExpiredToken")
    }
}

/// Distinguishes cancellation from real failures (review finding A6).
enum RequestFailure {
    /// `CancellationError` or `URLError(.cancelled)`: the caller went away. Not an error to show.
    static func isCancellation(_ error: any Error) -> Bool {
        if error is CancellationError { return true }
        if let urlError = error as? URLError, urlError.code == .cancelled { return true }
        return false
    }
}

/// Sends one HTTP request. Tests replace it with a fake.
protocol HTTPTransport: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

struct URLSessionTransport: HTTPTransport {
    var session: URLSession

    /// A session with no URL cache and no cookie storage, so authenticated responses
    /// are never written to disk (review finding A26).
    static func ephemeral() -> URLSessionTransport {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        return URLSessionTransport(session: URLSession(configuration: configuration))
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw XRPCError.invalidResponse("Response is not HTTP")
        }
        return (data, http)
    }
}

/// Stateless XRPC request builder and decoder.
///
/// It mirrors how the RN app's agent talks to a PDS: queries are GET with URL
/// parameters, procedures are POST with a JSON body, and `app.bsky.*` calls carry
/// the `atproto-proxy` header so the PDS forwards them to the AppView.
struct XRPCClient: Sendable {
    var serviceURL: URL
    /// Value for the `atproto-proxy` header, e.g. `did:plc:...#bsky_appview`.
    var appViewProxy: String?
    var transport: any HTTPTransport

    static let decoder = JSONDecoder()
    static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys]
        return e
    }()

    func request(nsid: String, method: String, query: [URLQueryItem] = [], body: Data? = nil,
                 accessToken: String?) throws -> URLRequest {
        guard var components = URLComponents(url: serviceURL.appending(path: "xrpc/\(nsid)"),
                                             resolvingAgainstBaseURL: false) else {
            throw XRPCError.invalidRequest("Invalid service URL for \(nsid)")
        }
        if !query.isEmpty { components.queryItems = query }
        guard let url = components.url else {
            throw XRPCError.invalidRequest("Invalid query for \(nsid)")
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if let accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        if let appViewProxy, Self.isProxied(nsid) {
            request.setValue(appViewProxy, forHTTPHeaderField: "atproto-proxy")
        }
        return request
    }

    /// Only AppView lexicons are proxied. `com.atproto.*` goes to the PDS itself.
    static func isProxied(_ nsid: String) -> Bool {
        nsid.hasPrefix("app.bsky.")
    }

    func query<Response: Decodable>(_ nsid: String, _ parameters: [URLQueryItem] = [],
                                    accessToken: String?) async throws -> Response {
        let request = try request(nsid: nsid, method: "GET", query: parameters, accessToken: accessToken)
        return try await perform(request)
    }

    func procedure<Response: Decodable>(_ nsid: String, body: some Encodable,
                                        accessToken: String?) async throws -> Response {
        let data = try Self.encoder.encode(body)
        let request = try request(nsid: nsid, method: "POST", body: data, accessToken: accessToken)
        return try await perform(request)
    }

    /// A procedure whose output is empty or ignored.
    func procedure(_ nsid: String, body: (some Encodable)?, accessToken: String?) async throws {
        let data = try body.map { try Self.encoder.encode($0) }
        let request = try request(nsid: nsid, method: "POST", body: data, accessToken: accessToken)
        _ = try await send(request)
    }

    private func perform<Response: Decodable>(_ request: URLRequest) async throws -> Response {
        let data = try await send(request)
        do {
            return try Self.decoder.decode(Response.self, from: data)
        } catch {
            throw XRPCError.invalidResponse("\(Response.self): \(error)")
        }
    }

    private func send(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await transport.send(request)
        guard (200..<300).contains(response.statusCode) else {
            struct ErrorBody: Decodable {
                var error: String?
                var message: String?
            }
            let body = try? Self.decoder.decode(ErrorBody.self, from: data)
            throw XRPCError.http(status: response.statusCode, error: body?.error, message: body?.message)
        }
        return data
    }
}
