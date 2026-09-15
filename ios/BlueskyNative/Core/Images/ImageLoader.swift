import ImageIO
import SwiftUI
import UIKit

/// Loads remote images. Views depend on this protocol through the environment.
protocol ImageLoading: Sendable {
    /// Returns the image at `url`, decoded and downsampled to `maxPixelSize` on its longest side.
    func image(at url: URL, maxPixelSize: Int) async throws -> UIImage
}

/// Memory-cached, downsampling image loader (review finding A15).
///
/// - Decoding and downsampling run on this actor, never on the main actor.
/// - One request per URL and size runs at a time; other callers await it.
/// - Decoded images stay in an `NSCache`, which the system empties under memory pressure.
actor CachingImageLoader: ImageLoading {
    static let shared = CachingImageLoader()

    private let cache = NSCache<NSString, UIImage>()
    private var inFlight: [String: Task<UIImage, any Error>] = [:]
    private let session: URLSession

    init(session: URLSession = URLSession(configuration: .ephemeral)) {
        self.session = session
        cache.totalCostLimit = 64 * 1024 * 1024
    }

    func image(at url: URL, maxPixelSize: Int) async throws -> UIImage {
        let key = "\(url.absoluteString)#\(maxPixelSize)"
        if let cached = cache.object(forKey: key as NSString) { return cached }
        if let running = inFlight[key] { return try await running.value }
        let session = self.session
        let task = Task<UIImage, any Error> {
            let (data, _) = try await session.data(from: url)
            guard let image = Self.downsample(data, maxPixelSize: maxPixelSize) else {
                throw URLError(.cannotDecodeContentData)
            }
            return image
        }
        inFlight[key] = task
        defer { inFlight[key] = nil }
        let image = try await task.value
        let cost = Int(image.size.width * image.size.height * image.scale * image.scale * 4)
        cache.setObject(image, forKey: key as NSString, cost: cost)
        return image
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

/// A remote image sized by its container, loaded through `ImageLoading`.
struct RemoteImage<Placeholder: View>: View {
    var url: URL
    /// Longest side in points; the loader downsamples to this size times the display scale.
    var pointSize: CGFloat
    @ViewBuilder var placeholder: Placeholder

    @Environment(\.imageLoader) private var loader
    @Environment(\.displayScale) private var displayScale
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                placeholder
            }
        }
        .task(id: url) {
            image = try? await loader.image(at: url, maxPixelSize: Int((pointSize * displayScale).rounded(.up)))
        }
    }
}
