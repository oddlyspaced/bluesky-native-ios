import SwiftUI
import Testing
import UIKit
@testable import NativeShowcase

/// Checks the RN line box rules (review findings A19, A57, N12) against a TextKit 1 layout built
/// the way `RCTTextLayoutManager` builds it, and against the SwiftUI text the port draws.
/// Runs at 3x (the iPhone 17 Pro capture device) and at 2x.
@MainActor
@Suite("Line box rules")
struct LineBoxRuleTests {
    private struct Reference {
        var baseline: CGFloat
        var boxHeight: CGFloat
        var lines: Int
        var inkTop: Int
        var inkBottom: Int
    }

    private static let threeLines = String(repeating: "Hg ", count: 40)

    private func inkRows(_ image: UIImage, skip: Int) -> (top: Int, bottom: Int)? {
        guard let cg = image.cgImage, let data = cg.dataProvider?.data, let bytes = CFDataGetBytePtr(data) else { return nil }
        let bpr = cg.bytesPerRow, bpp = cg.bitsPerPixel / 8
        var top: Int?, bottom: Int?
        for y in 0..<cg.height {
            var ink = false
            for x in 0..<cg.width where bytes[y * bpr + x * bpp + 3] > 60 {
                ink = true
                break
            }
            if ink {
                top = top ?? y
                bottom = y
            }
        }
        guard let top, let bottom else { return nil }
        return (top - skip, bottom - skip)
    }

    /// RN: TextKit 1, line fragment padding 0, no font leading, paragraph min = max = L,
    /// `RCTApplyBaselineOffset` for the paragraph renderer.
    private func reference(_ text: String, font: UIFont, lineHeight: CGFloat?, renderer: RNTextRenderer,
                           scale: CGFloat, width: CGFloat) -> Reference {
        var attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.black]
        if let lineHeight {
            let paragraph = NSMutableParagraphStyle()
            paragraph.minimumLineHeight = lineHeight
            paragraph.maximumLineHeight = lineHeight
            attributes[.paragraphStyle] = paragraph
            if renderer == .paragraph, lineHeight >= font.lineHeight {
                attributes[.baselineOffset] = (lineHeight - font.lineHeight) / 2
            }
        }
        let storage = NSTextStorage(attributedString: NSAttributedString(string: text, attributes: attributes))
        let manager = NSLayoutManager()
        manager.usesFontLeading = false
        let container = NSTextContainer(size: CGSize(width: width, height: .greatestFiniteMagnitude))
        container.lineFragmentPadding = 0
        manager.addTextContainer(container)
        storage.addLayoutManager(manager)
        let used = manager.usedRect(for: container)
        var lines = 0
        manager.enumerateLineFragments(forGlyphRange: NSRange(location: 0, length: manager.numberOfGlyphs)) { _, _, _, _, _ in
            lines += 1
        }
        let baseline = manager.lineFragmentRect(forGlyphAt: 0, effectiveRange: nil).minY + manager.location(forGlyphAt: 0).y
        let box = ((used.height + 0.001) * scale).rounded(.up) / scale
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        let pad: CGFloat = 20
        let image = UIGraphicsImageRenderer(size: CGSize(width: width, height: box + 2 * pad), format: format).image { _ in
            manager.drawGlyphs(forGlyphRange: NSRange(location: 0, length: storage.length), at: CGPoint(x: 0, y: pad))
        }
        let ink = inkRows(image, skip: Int(pad * scale))!
        return Reference(baseline: baseline, boxHeight: box, lines: lines, inkTop: ink.top, inkBottom: ink.bottom)
    }

    private func nativeInk(_ text: String, style: TextStyle, renderer: RNTextRenderer, scale: CGFloat,
                           width: CGFloat) -> (height: CGFloat, inkTop: Int, inkBottom: Int) {
        let pad: CGFloat = 20
        let text = Text(text)
            .textStyle(style, renderer: renderer)
            .foregroundStyle(.black)
            .frame(width: width, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .environment(\.displayScale, scale)
        // The layout size the app sees: the box `RNTextBoxLayout` reports.
        let height = UIHostingController(rootView: text)
            .sizeThatFits(in: CGSize(width: width, height: 10_000)).height
        let renderer = ImageRenderer(content: text.padding(.vertical, pad))
        renderer.scale = scale
        let ink = inkRows(renderer.uiImage!, skip: Int(pad * scale))!
        return (height, ink.top, ink.bottom)
    }

    @Test(arguments: [3.0, 2.0])
    func rulesMatchTextKitAndSwiftUI(scale: CGFloat) {
        let width: CGFloat = 300
        // (size, leading): text_md snug (20), text_md tight (17 < N), text_sm snug, text_lg snug,
        // text_3xl tight (below N), legacy 17 with no line height.
        let styles: [TextStyle] = [
            TextStyle(size: 15, leading: 1.3), TextStyle(size: 15, leading: 1.15), TextStyle(size: 13.1, leading: 1.3),
            TextStyle(size: 18, leading: 1.3), TextStyle(size: 30, weight: FontWeight.bold, leading: 1.15),
            TextStyle(size: 17, weight: FontWeight.semiBold),
        ]
        for base in styles {
            for multiplier in [1.0, FontScale.multiplier(for: .xxxLarge)] {
                let scaled = base.scaled(by: multiplier)
                let font = InterFont.uiFont(size: scaled.size, weight: base.weight)
                var style = base
                style.size = scaled.size
                style.lineHeight = scaled.lineHeight
                for renderer in [RNTextRenderer.paragraph, .textView] {
                    let metrics = RNTextMetrics(font: font, lineHeight: scaled.lineHeight, renderer: renderer)
                    for text in ["Hg", Self.threeLines] {
                        let rn = reference(text, font: font, lineHeight: scaled.lineHeight, renderer: renderer,
                                           scale: scale, width: width)
                        let lines = rn.lines
                        let label = "size \(scaled.size) L \(String(describing: scaled.lineHeight)) \(renderer) lines \(lines) @\(scale)x"
                        #expect(text == "Hg" ? lines == 1 : lines > 2, "\(label): line count")
                        // The formulas equal TextKit.
                        #expect(abs(metrics.firstBaseline - rn.baseline) < 0.01, "\(label): baseline")
                        #expect(abs(metrics.boxHeight(lines: lines, scale: scale) - rn.boxHeight) < 0.01, "\(label): box")
                        // The SwiftUI text lands on the same box and ink rows, within one pixel.
                        let native = nativeInk(text, style: style, renderer: renderer, scale: scale, width: width)
                        #expect(abs(native.height - rn.boxHeight) < 0.5 / scale, "\(label): native box \(native.height) rn \(rn.boxHeight)")
                        #expect(abs(native.inkTop - rn.inkTop) <= 1, "\(label): ink top \(native.inkTop) rn \(rn.inkTop)")
                        #expect(abs(native.inkBottom - rn.inkBottom) <= 1, "\(label): ink bottom \(native.inkBottom) rn \(rn.inkBottom)")
                    }
                }
            }
        }
    }
}
