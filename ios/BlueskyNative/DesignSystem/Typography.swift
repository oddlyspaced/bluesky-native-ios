import SwiftUI
import UIKit

/// Inter font handling, ported from `src/alf/fonts.ts` and `src/alf/typography.tsx`.
///
/// On iOS the RN app uses the bundled variable font `InterVariable` for every weight,
/// with `fontVariant: ['no-contextual']` (contextual alternates off) and zero tracking.
enum InterFont {
    /// OpenType `wght` axis tag as a four-char code.
    private static let weightAxis = 0x7767_6874 // 'wght'

    @MainActor private static var cache: [Key: UIFont] = [:]

    private struct Key: Hashable {
        var size: CGFloat
        var weight: CGFloat
        var italic: Bool
    }

    @MainActor
    static func uiFont(size: CGFloat, weight: CGFloat, italic: Bool = false) -> UIFont {
        let key = Key(size: size, weight: weight, italic: italic)
        if let font = cache[key] { return font }
        let attributes: [UIFontDescriptor.AttributeName: Any] = [
            .name: "InterVariable",
            UIFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String): [weightAxis: weight],
            .featureSettings: [[
                UIFontDescriptor.FeatureKey.type: kContextualAlternatesType,
                UIFontDescriptor.FeatureKey.selector: kContextualAlternatesOffSelector,
            ]],
        ]
        var descriptor = UIFontDescriptor(fontAttributes: attributes)
        if italic, let slanted = descriptor.withSymbolicTraits(.traitItalic) {
            descriptor = slanted
        }
        let font = UIFont(descriptor: descriptor, size: size)
        cache[key] = font
        return font
    }

    @MainActor
    static func font(size: CGFloat, weight: CGFloat, italic: Bool = false) -> Font {
        Font(uiFont(size: size, weight: weight, italic: italic) as CTFont)
    }
}

/// ALF `fontWeight` tokens as `wght` axis values.
enum FontWeight {
    static let normal: CGFloat = 400
    static let medium: CGFloat = 500
    static let semiBold: CGFloat = 600
    static let bold: CGFloat = 700
}

/// RN iOS font scaling for Dynamic Type.
///
/// RN multiplies font size and line height by `RCTFontSizeMultiplier()`
/// (`RCTUtils.mm:366-388`), capped only by `maxFontSizeMultiplier` when that prop is >= 1
/// (`RCTTextAttributes.mm:238-254`). The app sets no global cap. This table is RN's.
enum FontScale {
    static func multiplier(for size: DynamicTypeSize) -> CGFloat {
        switch size {
        case .xSmall: 0.823
        case .small: 0.882
        case .medium: 0.941
        case .large: 1.0
        case .xLarge: 1.118
        case .xxLarge: 1.235
        case .xxxLarge: 1.353
        case .accessibility1: 1.786
        case .accessibility2: 2.143
        case .accessibility3: 2.643
        case .accessibility4: 3.143
        case .accessibility5: 3.571
        @unknown default: 1.0
        }
    }

    /// Applies an RN `maxFontSizeMultiplier` cap (ignored below 1, as in RN).
    static func multiplier(for size: DynamicTypeSize, cap: CGFloat?) -> CGFloat {
        let base = multiplier(for: size)
        guard let cap, cap >= 1 else { return base }
        return min(base, cap)
    }
}

/// A resolved RN text style: size, weight and an optional line height.
struct TextStyle: Sendable, Hashable {
    var size: CGFloat
    var weight: CGFloat = FontWeight.normal
    var italic = false
    /// Absolute line height in points at scale 1. nil means the font's natural line height,
    /// which is what RN does on native when no `lineHeight` is set.
    var lineHeight: CGFloat?
    /// RN `maxFontSizeMultiplier`, where a component sets one.
    var maxScale: CGFloat?
    /// True for text ported from RN's legacy `Text` (`src/view/com/util/text/Text.tsx`), which
    /// renders slightly wider than ALF `Text` (see `RNLineBox.legacyTracking`).
    var legacyText = false

    /// Mirrors `normalizeTextStyles`: multipliers <= 2 become `round(fontSize * multiplier)`.
    init(size: CGFloat, weight: CGFloat = FontWeight.normal, leading: CGFloat? = nil, italic: Bool = false,
         maxScale: CGFloat? = nil, legacyText: Bool = false) {
        self.size = size
        self.weight = weight
        self.italic = italic
        self.maxScale = maxScale
        self.legacyText = legacyText
        if let leading {
            lineHeight = leading <= 2 ? (size * leading).rounded() : leading
        }
    }

    /// The style at a Dynamic Type multiplier: font size and line height both scale.
    func scaled(by multiplier: CGFloat) -> (size: CGFloat, lineHeight: CGFloat?) {
        (size * multiplier, lineHeight.map { $0 * multiplier })
    }
}

/// The iOS view that draws a piece of RN text. The rule for each is derived from source
/// (review findings A19, A57, N12):
/// - `paragraph`: RN `Text` (Fabric Paragraph). `RCTAttributedTextUtils.mm:229-232` sets the
///   paragraph's minimum and maximum line height to `L`; `RCTApplyBaselineOffset` (`:300-340`)
///   raises the glyphs by `(L - N)/2` when `L >= N`, where `N` is `UIFont.lineHeight`.
/// - `textView`: `UITextView` from `@bsky.app/react-native-uitextview`, used for ALF `Text` with
///   `selectable` on iOS (`Text.tsx:183-186`): the same paragraph style, no baseline offset.
///
/// Both measure with TextKit 1 (`RCTTextLayoutManager.mm:228-237,374,392-394`): line fragments
/// are `L` tall, and the box is `ceil((n * L + 0.001) * scale) / scale`.
enum RNTextRenderer: Sendable {
    case paragraph
    case textView
}

/// RN's iOS line box for one font, line height and renderer.
///
/// TextKit puts the baseline `L + descender` below the top of a line fragment of height `L`
/// (extra height goes above the glyphs; a fragment shorter than `N` clips above them). The
/// `paragraph` renderer then raises it by `(L - N)/2` when `L >= N`. Without a line height the
/// fragment is `N` tall and the baseline is at the ascender. `LineBoxRuleTests` checks these
/// formulas against TextKit and SwiftUI output at 3x and 2x.
struct RNTextMetrics: Equatable, Sendable {
    /// Distance from one baseline to the next.
    var pitch: CGFloat
    /// Baseline of the first line, from the top of the box.
    var firstBaseline: CGFloat

    init(fontLineHeight: CGFloat, ascender: CGFloat, descender: CGFloat, lineHeight: CGFloat?,
         renderer: RNTextRenderer) {
        guard let lineHeight else {
            pitch = fontLineHeight
            firstBaseline = ascender
            return
        }
        pitch = lineHeight
        let offset = renderer == .paragraph && lineHeight >= fontLineHeight ? (lineHeight - fontLineHeight) / 2 : 0
        firstBaseline = lineHeight + descender - offset
    }

    @MainActor
    init(font: UIFont, lineHeight: CGFloat?, renderer: RNTextRenderer) {
        self.init(fontLineHeight: font.lineHeight, ascender: font.ascender, descender: font.descender,
                  lineHeight: lineHeight, renderer: renderer)
    }

    /// RCTTextLayoutManager's box height for `lines` lines.
    func boxHeight(lines: Int, scale: CGFloat) -> CGFloat {
        let raw = CGFloat(max(1, lines)) * pitch + 0.001
        guard scale > 0 else { return raw }
        // A value such as 106/3 is stored as 35.333333333333336; SwiftUI multiplies it back by the
        // scale, gets 106.00000000000001 and ceils it to one more pixel. The tiny subtraction keeps
        // SwiftUI's own pixel ceiling on the same pixel.
        return (raw * scale).rounded(.up) / scale - 1e-6
    }
}

enum RNLineBox {
    static func snap(_ value: CGFloat, pixelLength: CGFloat) -> CGFloat {
        guard pixelLength > 0 else { return value }
        return (value / pixelLength).rounded() * pixelLength
    }

    /// Tracking for text ported from RN's legacy `Text`. That component measures wider: 808 px
    /// against 801 px for the 15pt fallback line (37 gaps) and 903 px against 894 px for the 17pt
    /// end-of-feed line (40 gaps), both at 3x, about 0.0043 em. The cause was not found in source,
    /// so this one value is still a measured ratio (PARITY.md).
    static func legacyTracking(for fontSize: CGFloat) -> CGFloat {
        fontSize * 0.0043
    }
}

/// Lays one text view out as RN does: the box is RN's box height for the number of lines the
/// text has, and the text's first baseline sits on RN's first baseline.
private struct RNTextBoxLayout: SwiftUI.Layout {
    var metrics: RNTextMetrics
    var scale: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let text = subviews.first else { return .zero }
        let dimensions = text.dimensions(in: proposal)
        return CGSize(width: dimensions.width, height: metrics.boxHeight(lines: lines(dimensions), scale: scale))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard let text = subviews.first else { return }
        let dimensions = text.dimensions(in: ProposedViewSize(width: bounds.width, height: proposal.height))
        let baseline = scale > 0 ? (metrics.firstBaseline * scale).rounded() / scale : metrics.firstBaseline
        text.place(at: CGPoint(x: bounds.minX, y: bounds.minY + baseline - dimensions[VerticalAlignment.firstTextBaseline]),
                   proposal: ProposedViewSize(width: bounds.width, height: dimensions.height))
    }

    private func lines(_ dimensions: ViewDimensions) -> Int {
        let span = dimensions[VerticalAlignment.lastTextBaseline] - dimensions[VerticalAlignment.firstTextBaseline]
        return Int((span / metrics.pitch).rounded()) + 1
    }
}

private struct RNTextStyleModifier: ViewModifier {
    var style: TextStyle
    var renderer: RNTextRenderer

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.displayScale) private var displayScale

    func body(content: Content) -> some View {
        let multiplier = FontScale.multiplier(for: dynamicTypeSize, cap: style.maxScale)
        let scaled = style.scaled(by: multiplier)
        let font = InterFont.uiFont(size: scaled.size, weight: style.weight, italic: style.italic)
        let metrics = RNTextMetrics(font: font, lineHeight: scaled.lineHeight, renderer: renderer)
        RNTextBoxLayout(metrics: metrics, scale: displayScale) {
            pitched(content
                .font(Font(font as CTFont))
                .tracking(style.legacyText ? RNLineBox.legacyTracking(for: scaled.size) : 0),
                    pitch: metrics.pitch, natural: font.lineHeight)
        }
    }

    /// Wrapped lines one `pitch` apart. iOS 26 sets the exact line height, also below the font's
    /// natural height. Earlier iOS versions can only add spacing, so a pitch below the natural
    /// height keeps the natural pitch there (PARITY.md records this).
    @ViewBuilder
    private func pitched(_ view: some View, pitch: CGFloat, natural: CGFloat) -> some View {
        if #available(iOS 26.0, *) {
            view.lineHeight(.exact(points: pitch))
        } else {
            view.lineSpacing(max(0, pitch - natural))
        }
    }
}

extension View {
    /// Applies an RN-equivalent text style (Inter, weight, line height, Dynamic Type) with the
    /// line box of the RN view that draws it.
    func textStyle(_ style: TextStyle, renderer: RNTextRenderer = .paragraph) -> some View {
        modifier(RNTextStyleModifier(style: style, renderer: renderer))
    }

    func textStyle(size: CGFloat, weight: CGFloat = FontWeight.normal, leading: CGFloat? = nil,
                   italic: Bool = false, maxScale: CGFloat? = nil, legacyText: Bool = false,
                   renderer: RNTextRenderer = .paragraph) -> some View {
        modifier(RNTextStyleModifier(style: TextStyle(size: size, weight: weight, leading: leading,
                                                      italic: italic, maxScale: maxScale, legacyText: legacyText),
                                     renderer: renderer))
    }
}

/// Font runs for concatenated `Text` that must scale like RN (metrics, legacy text runs).
struct ScaledFonts {
    var multiplier: CGFloat

    @MainActor
    func font(_ size: CGFloat, _ weight: CGFloat = FontWeight.normal, italic: Bool = false) -> Font {
        InterFont.font(size: size * multiplier, weight: weight, italic: italic)
    }
}
