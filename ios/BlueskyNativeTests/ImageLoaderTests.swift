import Foundation
import Testing
import UIKit
@testable import NativeShowcase

/// Serves one payload to `CachingImageLoader` and counts the transfers it starts.
/// `hangs` makes a transfer never finish, so a cancellation can be observed.
final class StubImageProtocol: URLProtocol {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var payload = Data()
    nonisolated(unsafe) private static var hangs = false
    nonisolated(unsafe) private static var started = 0

    static func reset(payload: Data, hangs: Bool = false) {
        lock.withLock {
            Self.payload = payload
            Self.hangs = hangs
            started = 0
        }
    }

    /// Transfers begun since `reset`.
    static var transfersStarted: Int { lock.withLock { started } }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let (payload, hangs) = Self.lock.withLock {
            Self.started += 1
            return (Self.payload, Self.hangs)
        }
        // A hanging transfer answers nothing; the loader must cancel it.
        guard !hangs else { return }
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: payload)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

/// Review finding A55, not fixed in round 2 and not recorded: the loader keyed its task on the URL
/// only, `RemoteImage` kept a stale image across a URL change, and a download was never cancelled.
/// No test referenced the loader at all.
@Suite("Image loader")
struct ImageLoaderTests {
    /// A 256 x 256 pixel source. It must be larger than every size under test: downsampling never
    /// scales up, so a small source would answer both sizes with the same image.
    private func pngData() -> Data {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: 256, height: 256), format: format).image { context in
            UIColor.blue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 256, height: 256))
        }.pngData()!
    }

    private func loader() -> CachingImageLoader {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubImageProtocol.self]
        return CachingImageLoader(session: URLSession(configuration: configuration))
    }

    private let url = URL(string: "https://cdn.example/avatar.jpg")!

    /// The cache and in-flight key carries the size, so one size never answers a request for
    /// another, and a repeat of the same request is served from the cache.
    @Test func eachSizeIsItsOwnEntryAndRepeatsAreCached() async throws {
        StubImageProtocol.reset(payload: pngData())
        let loader = loader()

        let small = try await loader.image(at: url, maxPixelSize: 32)
        let large = try await loader.image(at: url, maxPixelSize: 128)
        #expect(StubImageProtocol.transfersStarted == 2)
        // Each size gets its own decode: before the fix one entry answered both.
        #expect(small.size == CGSize(width: 32, height: 32))
        #expect(large.size == CGSize(width: 128, height: 128))

        _ = try await loader.image(at: url, maxPixelSize: 32)
        #expect(StubImageProtocol.transfersStarted == 2)
        #expect(await loader.downloadsInFlight == 0)
    }

    /// Cancelling the last waiter cancels the transfer instead of letting it run to completion.
    @Test func cancellingTheLastWaiterCancelsTheDownload() async throws {
        StubImageProtocol.reset(payload: pngData(), hangs: true)
        let loader = loader()
        let waiting = Task { try await loader.image(at: url, maxPixelSize: 64) }

        while await loader.downloadsInFlight == 0 { await Task.yield() }
        #expect(await loader.downloadsInFlight == 1)

        waiting.cancel()
        // The loader drops the transfer once its last waiter leaves.
        while await loader.downloadsInFlight > 0 { await Task.yield() }
        #expect(await loader.downloadsInFlight == 0)
        await #expect(throws: (any Error).self) { try await waiting.value }
    }

    /// A failed transfer is not cached and leaves nothing in flight.
    @Test func aDecodeFailureIsNotCached() async {
        StubImageProtocol.reset(payload: Data("not an image".utf8))
        let loader = loader()
        await #expect(throws: (any Error).self) { try await loader.image(at: url, maxPixelSize: 64) }
        #expect(await loader.downloadsInFlight == 0)
    }

    /// `RemoteImage` shows the placeholder again when its URL or size changes, instead of the
    /// image decoded for the previous request.
    @Test func aLoadedImageAnswersOnlyItsOwnRequest() {
        let request = RemoteImageRequest(url: url, maxPixelSize: 64)
        let loaded = LoadedRemoteImage(request: request, image: UIImage())

        #expect(loaded.answers(request))
        #expect(!loaded.answers(RemoteImageRequest(url: url, maxPixelSize: 128)))
        #expect(!loaded.answers(RemoteImageRequest(url: URL(string: "https://cdn.example/other.jpg")!,
                                                   maxPixelSize: 64)))
    }
}
