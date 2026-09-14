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
    }

    @MainActor
    static func uiFont(size: CGFloat, weight: CGFloat) -> UIFont {
        let key = Key(size: size, weight: weight)
        if let font = cache[key] { return font }
        let attributes: [UIFontDescriptor.AttributeName: Any] = [
            .name: "InterVariable",
            UIFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String): [weightAxis: weight],
            .featureSettings: [[
                UIFontDescriptor.FeatureKey.type: kContextualAlternatesType,
                UIFontDescriptor.FeatureKey.selector: kContextualAlternatesOffSelector,
            ]],
        ]
        let descriptor = UIFontDescriptor(fontAttributes: attributes)
        let font = UIFont(descriptor: descriptor, size: size)
        cache[key] = font
        return font
    }
}

/// ALF `fontWeight` tokens as `wght` axis values.
enum FontWeight {
    static let normal: CGFloat = 400
    static let medium: CGFloat = 500
    static let semiBold: CGFloat = 600
    static let bold: CGFloat = 700
}

/// A resolved RN text style: size, weight and an optional line height.
struct TextStyle: Sendable, Hashable {
    var size: CGFloat
    var weight: CGFloat = FontWeight.normal
    /// Absolute line height in points. nil means the font's natural line height,
    /// which is what RN does on native when no `lineHeight` is set.
    var lineHeight: CGFloat?

    /// Mirrors `normalizeTextStyles`: multipliers <= 2 become `round(fontSize * multiplier)`.
    init(size: CGFloat, weight: CGFloat = FontWeight.normal, leading: CGFloat? = nil) {
        self.size = size
        self.weight = weight
        if let leading {
            lineHeight = leading <= 2 ? (size * leading).rounded() : leading
        }
    }
}

private struct RNTextStyleModifier: ViewModifier {
    var style: TextStyle

    func body(content: Content) -> some View {
        let font = InterFont.uiFont(size: style.size, weight: style.weight)
        let natural = font.lineHeight
        let lineHeight = style.lineHeight ?? natural
        // RN on iOS sets min and max line height on the paragraph style and centres the
        // glyphs in the line box. SwiftUI lays each line out at the natural height, so the
        // extra (or missing) space is split above and below.
        let extra = lineHeight - natural
        content
            .font(Font(font as CTFont))
            .lineSpacing(max(0, extra))
            .padding(.vertical, extra / 2)
    }
}

extension View {
    /// Applies an RN-equivalent text style (Inter, weight, line height).
    func textStyle(_ style: TextStyle) -> some View {
        modifier(RNTextStyleModifier(style: style))
    }

    func textStyle(size: CGFloat, weight: CGFloat = FontWeight.normal, leading: CGFloat? = nil) -> some View {
        modifier(RNTextStyleModifier(style: TextStyle(size: size, weight: weight, leading: leading)))
    }
}
