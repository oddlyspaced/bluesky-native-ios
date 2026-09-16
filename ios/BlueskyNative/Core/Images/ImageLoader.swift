import ImageIO
import SwiftUI
import UIKit

/// Loads remote images. Views depend on this protocol through the environment.
protocol ImageLoading: Sendable {
    /// Returns the image at `url`, decoded and downsampled to `maxPixelSize` on its longest side.
    func image(at url: URL, maxPixelSize: Int) async throws -> UIImage
}

/// Memory-cached, downsampling image loader (review findings A15 and A55).
///
/// - Decoding and downsampling run on this actor, never on the main actor.
/// - One request per URL **and** size runs at a time; other callers await it.
/// - A transfer is cancelled once its last waiter goes away, so a row that scrolls off screen
///   stops its download instead of running to completion (review finding A55).
/// - Decoded images stay in an `NSCache`, which the system empties under memory pressure.
actor CachingImageLoader: ImageLoading {
    static let shared = CachingImageLoader()

    private let cache = NSCache<NSString, UIImage>()
    private var downloads: [String: Download] = [:]
    private let session: URLSession

    /// One shared transfer and the number of callers still waiting for it.
    private struct Download {
        var task: Task<UIImage, any Error>
        var waiters: Int
    }

    init(session: URLSession = URLSession(configuration: .ephemeral)) {
        self.session = session
        cache.totalCostLimit = 64 * 1024 * 1024
    }

    /// Transfers in flight. Tests read it.
    var downloadsInFlight: Int { downloads.count }

    func image(at url: URL, maxPixelSize: Int) async throws -> UIImage {
        let key = Self.key(url: url, maxPixelSize: maxPixelSize)
        if let cached = cache.object(forKey: key as NSString) { return cached }
        let task = joinOrStart(key: key, url: url, maxPixelSize: maxPixelSize)
        do {
            let image = try await withTaskCancellationHandler {
                try await task.value
            } onCancel: {
                // This caller went away. The transfer stops when it was the last waiter.
                Task { await self.leave(key: key) }
            }
            leave(key: key)
            let cost = Int(image.size.width * image.size.height * image.scale * image.scale * 4)
            cache.setObject(image, forKey: key as NSString, cost: cost)
            return image
        } catch {
            // A cancelled caller has already left, in `onCancel`.
            if !Task.isCancelled { leave(key: key) }
            throw error
        }
    }

    /// The cache and in-flight key. It carries the pixel size as well as the URL, so an image
    /// decoded for one size never answers a request for another (review finding A55).
    private static func key(url: URL, maxPixelSize: Int) -> String {
        "\(url.absoluteString)#\(maxPixelSize)"
    }

    private func joinOrStart(key: String, url: URL, maxPixelSize: Int) -> Task<UIImage, any Error> {
        if let running = downloads[key] {
            downloads[key]?.waiters = running.waiters + 1
            return running.task
        }
        let session = self.session
        let task = Task<UIImage, any Error> {
            let (data, _) = try await session.data(from: url)
            try Task.checkCancellation()
            guard let image = Self.downsample(data, maxPixelSize: maxPixelSize) else {
                throw URLError(.cannotDecodeContentData)
            }
            return image
        }
        downloads[key] = Download(task: task, waiters: 1)
        return task
    }

    /// One caller stopped waiting. The transfer is cancelled when no caller is left.
    private func leave(key: String) {
        guard var download = downloads[key] else { return }
        download.waiters -= 1
        if download.waiters <= 0 {
            downloads[key] = nil
            download.task.cancel()
        } else {
            downloads[key] = download
        }
    }

    private static func downsample(_ data: Data, maxPixelSize: Int) -> UIImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else { return nil }
        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max(1, maxPixelSize),
        ] as CFDictionary
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

extension EnvironmentValues {
    @Entry var imageLoader: any ImageLoading = CachingImageLoader.shared
}

/// The identity of one `RemoteImage` load: the URL **and** the decoded size.
struct RemoteImageRequest: Hashable, Sendable {
    var url: URL
    var maxPixelSize: Int
}

/// What a `RemoteImage` currently holds, and the request it answers.
struct LoadedRemoteImage {
    var request: RemoteImageRequest
    var image: UIImage

    /// True when this image answers the request being rendered.
    ///
    /// A `RemoteImage` whose URL or size changed must show its placeholder again, not the image
    /// of the previous URL (review finding A55).
    func answers(_ request: RemoteImageRequest) -> Bool {
        self.request == request
    }
}

/// A remote image sized by its container, loaded through `ImageLoading`.
struct RemoteImage<Placeholder: View>: View {
    var url: URL
    /// Longest side in points; the loader downsamples to this size times the display scale.
    var pointSize: CGFloat
    @ViewBuilder var placeholder: Placeholder

    @Environment(\.imageLoader) private var loader
    @Environment(\.displayScale) private var displayScale
    @State private var loaded: LoadedRemoteImage?

    private var request: RemoteImageRequest {
        RemoteImageRequest(url: url, maxPixelSize: Int((pointSize * displayScale).rounded(.up)))
    }

    var body: some View {
        ZStack {
            if let loaded, loaded.answers(request) {
                Image(uiImage: loaded.image).resizable().scaledToFill()
            } else {
                placeholder
            }
        }
        // Keyed on the size as well as the URL: a size change reloads instead of keeping the
        // decode made for the old size (review finding A55).
        .task(id: request) {
            let request = self.request
            guard let image = try? await loader.image(at: request.url, maxPixelSize: request.maxPixelSize),
                  !Task.isCancelled else { return }
            loaded = LoadedRemoteImage(request: request, image: image)
        }
    }
}
