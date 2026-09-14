import SwiftUI

// Design tokens extracted from the RN app's design system (ALF).
// Source: node_modules/@bsky.app/alf/dist/tokens.js and palette.js (DEFAULT_PALETTE),
// re-exported by src/alf/tokens.ts and src/alf/themes.ts. The RN app uses the
// stock palette with no overrides. This port ships the light theme only.

extension Color {
    /// Creates an sRGB colour from a 0xRRGGBB value.
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

/// `DEFAULT_PALETTE` from `@bsky.app/alf`.
enum Palette {
    static let white = Color(hex: 0xFFFFFF)
    static let black = Color(hex: 0x000000)
    static let pink = Color(hex: 0xEC4899)
    static let yellow = Color(hex: 0xFFC404)
    static let like = pink

    static let contrast0 = Color(hex: 0xFFFFFF)
    static let contrast25 = Color(hex: 0xF9FAFB)
    static let contrast50 = Color(hex: 0xEFF2F6)
    static let contrast100 = Color(hex: 0xDCE2EA)
    static let contrast200 = Color(hex: 0xC0CAD8)
    static let contrast300 = Color(hex: 0xA5B2C5)
    static let contrast400 = Color(hex: 0x8798B0)
    static let contrast500 = Color(hex: 0x667B99)
    static let contrast600 = Color(hex: 0x526580)
    static let contrast700 = Color(hex: 0x405168)
    static let contrast800 = Color(hex: 0x313F54)
    static let contrast900 = Color(hex: 0x232E3E)
    static let contrast950 = Color(hex: 0x19222E)
    static let contrast975 = Color(hex: 0x111822)
    static let contrast1000 = Color(hex: 0x000000)

    static let primary25 = Color(hex: 0xF5F9FF)
    static let primary50 = Color(hex: 0xE5F0FF)
    static let primary100 = Color(hex: 0xCCE1FF)
    static let primary500 = Color(hex: 0x006AFF)
    static let primary600 = Color(hex: 0x0059D6)

    static let positive500 = Color(hex: 0x09B35E)
    static let positive600 = Color(hex: 0x04904A)
    static let negative500 = Color(hex: 0xE91646)

    /// Fill of the default avatar SVG in `UserAvatar.tsx`. It is not a palette token.
    static let defaultAvatarBlue = Color(hex: 0x0070FF)
}

/// Light theme atoms (`createThemes` in `@bsky.app/alf/dist/themes.js`).
enum Theme {
    static let background = Palette.contrast0
    static let text = Palette.contrast1000
    static let textContrastLow = Palette.contrast400
    static let textContrastMedium = Palette.contrast700
    static let textContrastHigh = Palette.contrast900
    static let borderContrastLow = Palette.contrast100
    static let bgContrast25 = Palette.contrast25
    static let bgContrast50 = Palette.contrast50
}

/// `space` tokens.
enum Space {
    static let _2xs: CGFloat = 2
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let _2xl: CGFloat = 24
    static let _3xl: CGFloat = 28
    static let _4xl: CGFloat = 32
    static let _5xl: CGFloat = 40
}

/// `fontSize` tokens.
enum FontSize {
    static let _2xs: CGFloat = 9.4
    static let xs: CGFloat = 11.3
    static let sm: CGFloat = 13.1
    static let md: CGFloat = 15
    static let lg: CGFloat = 16.9
    static let xl: CGFloat = 18.8
    static let _2xl: CGFloat = 20.6
    static let _3xl: CGFloat = 24.3
    static let _4xl: CGFloat = 30
    static let _5xl: CGFloat = 37.5
}

/// `lineHeight` multipliers.
enum Leading {
    static let tight: CGFloat = 1.15
    static let snug: CGFloat = 1.3
    static let relaxed: CGFloat = 1.5
}

/// `borderRadius` tokens.
enum Radius {
    static let _2xs: CGFloat = 2
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let full: CGFloat = 999
}

/// ALF `border_*` atoms use `StyleSheet.hairlineWidth` on native.
@MainActor
enum Hairline {
    static var width: CGFloat { 1 / UITraitCollection.current.displayScale.clamped(min: 1) }
}

extension CGFloat {
    func clamped(min lower: CGFloat) -> CGFloat { Swift.max(lower, self) }
}

/// Icon sizes from `src/components/icons/common.tsx`.
enum IconSize {
    static let _2xs: CGFloat = 8
    static let xs: CGFloat = 12
    static let sm: CGFloat = 16
    static let md: CGFloat = 20
    static let lg: CGFloat = 24
    static let xl: CGFloat = 28
    static let _2xl: CGFloat = 32
}
