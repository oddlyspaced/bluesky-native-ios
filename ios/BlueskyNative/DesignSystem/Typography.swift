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

/// RN's iOS line box, in one place (review finding A19).
///
/// RN sets the paragraph's minimum and maximum line height to `lineHeight` and centres the
/// glyphs in that box. SwiftUI lays each line out at the font's natural height, so the
/// difference is split above and below and rounded to the device pixel grid.
enum RNLineBox {
    static func verticalInset(natural: CGFloat, lineHeight: CGFloat, pixelLength: CGFloat) -> CGFloat {
        let half = (lineHeight - natural) / 2
        guard pixelLength > 0 else { return half }
        return snap(half, pixelLength: pixelLength)
    }

    static func snap(_ value: CGFloat, pixelLength: CGFloat) -> CGFloat {
        guard pixelLength > 0 else { return value }
        return (value / pixelLength).rounded() * pixelLength
    }

    /// Tracking for text ported from RN's legacy `Text`. That component renders through RN's
    /// paragraph view, not the UITextView that ALF `Text` uses, and measures wider: 808 px against
    /// 801 px for the 15pt fallback line (37 gaps) and 903 px against 894 px for the 17pt
    /// end-of-feed line (40 gaps), both at 3x. That is 0.063pt and 0.075pt per gap, about 0.0043 em.
    /// The renderer could not be inspected, so the value is the measured ratio.
    static func legacyTracking(for fontSize: CGFloat) -> CGFloat {
        fontSize * 0.0043
    }

    /// Legacy `Text` glyphs sit 1px (3x) lower in RN with the same box: end-of-feed messages at
    /// y 963 and 1340 against 962 and 1339 once the pills above them match.
    static let legacyGlyphOffset: CGFloat = 1.0 / 3

    /// Large ALF `Button` label (text_md, leading_snug 20): the RN pill is 133px (44.33pt), so the
    /// label box is 1px (3x) taller, as ALF `Text` rendered through UITextView is elsewhere.
    static let buttonLabel = Adjustment(extraBottom: 1.0 / 3)

    /// Where RN's iOS text view (`@bsky.app/react-native-uitextview`) lays a text box out
    /// differently from the centred model above. The RN runtime cannot be inspected here, so
    /// each value is measured: ink rows of the RN and native captures at 3x
    /// (`ios/PARITY.md`, "Line-box measurements"). Values are points, snapped to the device
    /// pixel grid when applied.
    struct Adjustment: Hashable, Sendable {
        /// Extra height below the text box.
        var extraBottom: CGFloat = 0
        /// Moves the glyphs without changing the box (positive is down).
        var glyphOffset: CGFloat = 0

        static let none = Adjustment()
    }

    /// PostMeta (text_md, leading_tight 17): same glyph top, box 2px (3x) taller in RN.
    static let postMeta = Adjustment(extraBottom: 2.0 / 3)
    /// `RichText` post text (text_md or text_lg, leading_snug): box 1px (3x) taller in RN, below
    /// the glyphs. Measured on feed rows (273px against 272px), thread replies and the anchor.
    static let richText = Adjustment(extraBottom: 1.0 / 3)
    /// Pager tab label (text_md, lineHeight 20): the underline and hairline sit 1px (3x) lower in RN.
    static let tabLabel = Adjustment(extraBottom: 1.0 / 3)
    /// Profile display name (text_3xl, leading_tight 28): glyphs 1px higher and box 2px taller in RN.
    static let profileDisplayName = Adjustment(extraBottom: 2.0 / 3, glyphOffset: -1.0 / 3)
    /// Profile handle (text_md, leading_snug 20): box 1px taller in RN.
    static let profileHandle = Adjustment(extraBottom: 1.0 / 3)
    /// Profile metrics row (text_md, leading_snug 20): box 1px taller in RN.
    static let profileMetrics = Adjustment(extraBottom: 1.0 / 3)
    /// Profile description (RichText, text_md): the rich-text box rule, glyphs 3px lower in RN.
    static let profileDescription = Adjustment(extraBottom: 1.0 / 3, glyphOffset: 1)
}

private struct RNTextStyleModifier: ViewModifier {
    var style: TextStyle
    var adjustment: RNLineBox.Adjustment

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.pixelLength) private var pixelLength

    func body(content: Content) -> some View {
        let multiplier = FontScale.multiplier(for: dynamicTypeSize, cap: style.maxScale)
        let scaled = style.scaled(by: multiplier)
        let font = InterFont.uiFont(size: scaled.size, weight: style.weight, italic: style.italic)
        // SwiftUI sizes a one-line Text frame to the font's line height rounded up to the pixel
        // grid, so the insets are computed from that height; the box is then exactly `lineHeight`.
        let natural = pixelLength > 0 ? (font.lineHeight / pixelLength).rounded(.up) * pixelLength : font.lineHeight
        let lineHeight = scaled.lineHeight ?? natural
        // The top inset snaps to the pixel grid and the bottom takes the remainder, so the box is
        // exactly `lineHeight` tall. Snapping both sides added up to one pixel per line.
        let top = RNLineBox.verticalInset(natural: natural, lineHeight: lineHeight, pixelLength: pixelLength)
        let bottom = (lineHeight - natural) - top
        content
            .font(Font(font as CTFont))
            .tracking(style.legacyText ? RNLineBox.legacyTracking(for: scaled.size) : 0)
            // Line pitch is `font.lineHeight + lineSpacing`, so the spacing uses the unrounded font
            // height: each line then advances exactly `lineHeight`, as RN's paragraph style does, and
            // n wrapped lines measure n x lineHeight. With the pixel-rounded `natural` the pitch was
            // 19.82pt for text_md snug and a 3-line post row was 1 px (3x) short (review finding F7).
            // A line height below the font's height cannot shrink the pitch (A57, recorded).
            .lineSpacing(max(0, lineHeight - font.lineHeight))
            .padding(.top, top)
            .padding(.bottom, bottom)
            .offset(y: RNLineBox.snap(adjustment.glyphOffset + (style.legacyText ? RNLineBox.legacyGlyphOffset : 0),
                                      pixelLength: pixelLength))
            .padding(.bottom, RNLineBox.snap(adjustment.extraBottom, pixelLength: pixelLength))
    }
}

extension View {
    /// Applies an RN-equivalent text style (Inter, weight, line height, Dynamic Type).
    func textStyle(_ style: TextStyle, adjustment: RNLineBox.Adjustment = .none) -> some View {
        modifier(RNTextStyleModifier(style: style, adjustment: adjustment))
    }

    func textStyle(size: CGFloat, weight: CGFloat = FontWeight.normal, leading: CGFloat? = nil,
                   italic: Bool = false, maxScale: CGFloat? = nil, legacyText: Bool = false,
                   adjustment: RNLineBox.Adjustment = .none) -> some View {
        modifier(RNTextStyleModifier(style: TextStyle(size: size, weight: weight, leading: leading,
                                                      italic: italic, maxScale: maxScale, legacyText: legacyText),
                                     adjustment: adjustment))
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
