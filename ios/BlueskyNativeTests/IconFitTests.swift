import SwiftUI
import Testing
@testable import NativeShowcase

/// Review finding F6: fitted Lucide glyphs must draw their ink inside the RN glyph's ink box, within
/// the 4 px tolerance of `ios/parity/make_masks.py`, at 3x.
///
/// The RN ink box comes from the round-2 captures: `delta` is native ink minus RN ink
/// (x0, y0, x1, y1) in px for the unfitted Lucide glyph in the same layout box. The test renders the
/// unfitted glyph, derives the RN box as `raw - delta`, renders the fitted glyph and checks containment.
@MainActor
@Suite("Icon ink fit")
struct IconFitTests {
    static let tolerance = 4

    struct Case: CustomTestStringConvertible, Sendable {
        var glyph: IconGlyph
        var size: CGFloat
        var lineWidth: CGFloat?
        var delta: (Int, Int, Int, Int)
        var source: String
        var testDescription: String { "\(glyph) \(size)pt (\(source))" }
    }

    nonisolated static let cases: [Case] = [
        Case(glyph: .hashtag, size: 24, delta: (9, -3, 9, 3), source: "home header, base"),
        Case(glyph: .repost, size: 18, delta: (-4, 7, 4, -7), source: "feed controls, base"),
        Case(glyph: .repost, size: 22, delta: (-5, 8, 5, -8), source: "anchor controls, base"),
        Case(glyph: .sliders, size: 20, delta: (-5, -4, 5, 6), source: "thread header, base"),
        Case(glyph: .info, size: 36, delta: (-6, -6, 6, 6), source: "fallback marker, base"),
        Case(glyph: .reply, size: 22, delta: (-2, -5, 2, -2), source: "anchor controls, interactions"),
        Case(glyph: .heart, size: 18, delta: (-2, -5, 2, -2), source: "feed controls, interactions"),
    ]

    /// Ink bounding box in px of a glyph drawn in a `size`-point box at 3x, 2pt stroke per 24pt grid.
    static func inkBox(_ glyph: IconGlyph, size: CGFloat, fit: (scale: CGFloat, dx: CGFloat, dy: CGFloat)?)
        -> (Int, Int, Int, Int)? {
        let view = IconShape(glyph: glyph, fit: fit)
            .stroke(Color.black, style: StrokeStyle(lineWidth: 2 * size / 24, lineCap: .round, lineJoin: .round))
            .frame(width: size, height: size)
            .padding(size)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 3
        guard let image = renderer.cgImage, let data = image.dataProvider?.data,
              let bytes = CFDataGetBytePtr(data) else { return nil }
        let perPixel = image.bitsPerPixel / 8
        let alphaOffset: Int = switch image.alphaInfo {
        case .premultipliedFirst, .first, .noneSkipFirst: 0
        default: perPixel - 1
        }
        var box: (Int, Int, Int, Int)?
        for y in 0..<image.height {
            for x in 0..<image.width where bytes[(y * image.bytesPerRow) + x * perPixel + alphaOffset] > 102 {
                let (x0, y0, x1, y1) = box ?? (x, y, x, y)
                box = (min(x0, x), min(y0, y), max(x1, x), max(y1, y))
            }
        }
        return box
    }

    @Test(arguments: cases)
    func fittedInkLiesInsideTheRNInkBox(_ item: Case) throws {
        let raw = try #require(Self.inkBox(item.glyph, size: item.size, fit: (1, 0, 0)))
        let fitted = try #require(Self.inkBox(item.glyph, size: item.size, fit: nil))
        let rn = (raw.0 - item.delta.0, raw.1 - item.delta.1, raw.2 - item.delta.2, raw.3 - item.delta.3)
        let t = Self.tolerance
        #expect(fitted.0 >= rn.0 - t && fitted.1 >= rn.1 - t && fitted.2 <= rn.2 + t && fitted.3 <= rn.3 + t,
                "fitted \(fitted) is not inside RN \(rn) +/- \(t) px (raw \(raw))")
    }
}
