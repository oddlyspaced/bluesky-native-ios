import SwiftUI

/// Parsed icon paths on the 24x24 Lucide grid. Parsed once per glyph.
enum IconPathCache {
    static let paths: [IconGlyph: Path] = Dictionary(uniqueKeysWithValues: IconGlyph.allCases.map { glyph in
        var combined = Path()
        for data in glyph.pathData {
            if let path = try? SVGPathParser.parse(data) { combined.addPath(path) }
        }
        return (glyph, combined)
    })
}

/// A glyph scaled from its 24x24 grid into the proposed rect.
struct IconShape: Shape {
    var glyph: IconGlyph
    /// The ink fit to apply; nil uses `glyph.inkFit`. Tests pass `(1, 0, 0)` for the raw Lucide glyph.
    var fit: (scale: CGFloat, dx: CGFloat, dy: CGFloat)?

    func path(in rect: CGRect) -> Path {
        let fit = self.fit ?? glyph.inkFit
        let inGrid = CGAffineTransform(translationX: 12 + fit.dx, y: 12 + fit.dy)
            .scaledBy(x: fit.scale, y: fit.scale)
            .translatedBy(x: -12, y: -12)
        let toRect = CGAffineTransform(translationX: rect.minX, y: rect.minY)
            .scaledBy(x: rect.width / 24, y: rect.height / 24)
        return (IconPathCache.paths[glyph] ?? Path()).applying(inGrid.concatenating(toRect))
    }
}

extension IconGlyph {
    /// Fits a Lucide glyph's ink to the RN glyph it replaces, in the same layout box (review
    /// finding F6). Scale about the grid centre, offset in grid units; the stroke is not scaled.
    /// Measured on 3x captures (`ios/PARITY.md`, "Glyph ink fit"):
    /// - hashtag (24pt header): native ink 54x60 px, 9 px right of RN's 54x54
    /// - repost: 60x40 px against RN 50x56 (22pt anchor); 50x32 against 42x46 (18pt feed)
    /// - sliders (20pt thread options): 50x50 px against RN 40x40
    /// - info (36pt fallback marker): 100x100 px against RN 88x88 (RN uses a 1.5 stroke on r 9)
    /// - reply (22pt anchor): 60x58 px against RN 56x55; heart (18pt): 50x48 against 46x45
    var inkFit: (scale: CGFloat, dx: CGFloat, dy: CGFloat) {
        switch self {
        case .hashtag: (0.89, -3, 0)
        case .repost: (0.88, 0, 0)
        case .sliders: (0.85, 0, 0)
        case .info: (0.88, 0, 0)
        case .reply: (0.92, 0, 0)
        case .heart: (0.92, 0, 0)
        default: (1, 0, 0)
        }
    }
}

/// Renders a Lucide glyph at `size` points, stroked at 2pt on the 24pt grid.
///
/// `filled` stands in for the RN "Filled" icon variants (active tab, liked heart):
/// the outline is filled with the same colour and stroked on top.
struct Icon: View {
    var glyph: IconGlyph
    var size: CGFloat
    var color: Color
    var filled: Bool

    init(_ glyph: IconGlyph, size: CGFloat, color: Color, filled: Bool = false) {
        self.glyph = glyph
        self.size = size
        self.color = color
        self.filled = filled
    }

    var body: some View {
        let lineWidth = 2 * size / 24
        ZStack {
            if filled {
                IconShape(glyph: glyph).fill(color)
            }
            IconShape(glyph: glyph)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Neutral placeholder mark for the header.
///
/// The Bluesky butterfly is a trademark (ASSETS.md section 3), so this showcase
/// draws a plain brand-blue diamond in the same 30x27 slot instead.
struct ShowcaseMark: View {
    var width: CGFloat
    var color: Color?

    @Environment(\.theme) private var theme

    var body: some View {
        let height = width * 57 / 64
        let side = height / 2.squareRoot() * 0.92
        RoundedRectangle(cornerRadius: side * 0.18)
            .fill(color ?? theme.palette.primary500)
            .frame(width: side, height: side)
            .rotationEffect(.degrees(45))
            .frame(width: width, height: height)
            .accessibilityElement()
            .accessibilityLabel("Showcase logo")
    }
}
