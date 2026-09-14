import Foundation

/// Errors raised by XRPC calls.
enum XRPCError: Error, Equatable, Sendable {
    /// The server answered with a non-2xx status and, usually, an XRPC error body.
    case http(status: Int, error: String?, message: String?)
    /// The response was not HTTP or its body could not be decoded.
    case invalidResponse(String)

    var isExpiredToken: Bool {
        if case .http(_, let error, _) = self { return error == "ExpiredToken" }
        return false
    }
}

/// Sends one HTTP request. Tests replace it with a fake.
protocol HTTPTransport: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

struct URLSessionTransport: HTTPTransport {
    var session: URLSession = .shared

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
                 accessToken: String?) -> URLRequest {
        var components = URLComponents(url: serviceURL.appending(path: "xrpc/\(nsid)"),
                                       resolvingAgainstBaseURL: false)!
        if !query.isEmpty { components.queryItems = query }
        var request = URLRequest(url: components.url!)
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
        let request = request(nsid: nsid, method: "GET", query: parameters, accessToken: accessToken)
        return try await perform(request)
    }

    func procedure<Response: Decodable>(_ nsid: String, body: some Encodable,
                                        accessToken: String?) async throws -> Response {
        let data = try Self.encoder.encode(body)
        let request = request(nsid: nsid, method: "POST", body: data, accessToken: accessToken)
        return try await perform(request)
    }

    /// A procedure whose output is empty or ignored.
    func procedure(_ nsid: String, body: some Encodable, accessToken: String?) async throws {
        let data = try Self.encoder.encode(body)
        let request = request(nsid: nsid, method: "POST", body: data, accessToken: accessToken)
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
