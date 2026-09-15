import SwiftUI

// Design tokens from the RN app's design system (ALF).
// Source: node_modules/@bsky.app/alf/dist/tokens.js, palette.js and themes.js,
// re-exported by src/alf/tokens.ts and src/alf/themes.ts. The RN app uses the stock
// palettes with no overrides.

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

/// The three ALF themes.
///
/// RN `useColorModeTheme` (`src/alf/util/useColorModeTheme.ts:31-37`) with the persisted
/// defaults `colorMode: 'system'` and `darkTheme: 'dim'` (`src/state/persisted/schema.ts:148-149`):
/// a light system appearance gives `light`, a dark one gives `dim`.
enum ThemeName: String, Sendable, CaseIterable {
    case light, dark, dim

    static func forSystem(_ scheme: ColorScheme, darkTheme: ThemeName = .dim) -> ThemeName {
        scheme == .light ? .light : darkTheme
    }
}

/// One ALF palette: contrast, primary, positive and negative scales plus static colours.
struct ThemePalette: Sendable {
    var contrast0, contrast25, contrast50, contrast100, contrast200, contrast300, contrast400: Color
    var contrast500, contrast600, contrast700, contrast800, contrast900, contrast950, contrast975, contrast1000: Color
    var primary25, primary50, primary100, primary500, primary600: Color
    var positive500, positive600: Color
    var negative500: Color

    let white = Color(hex: 0xFFFFFF)
    let black = Color(hex: 0x000000)
    let pink = Color(hex: 0xEC4899)
    let yellow = Color(hex: 0xFFC404)

    /// `DEFAULT_PALETTE`.
    static let light = ThemePalette(
        contrast0: Color(hex: 0xFFFFFF), contrast25: Color(hex: 0xF9FAFB), contrast50: Color(hex: 0xEFF2F6),
        contrast100: Color(hex: 0xDCE2EA), contrast200: Color(hex: 0xC0CAD8), contrast300: Color(hex: 0xA5B2C5),
        contrast400: Color(hex: 0x8798B0), contrast500: Color(hex: 0x667B99), contrast600: Color(hex: 0x526580),
        contrast700: Color(hex: 0x405168), contrast800: Color(hex: 0x313F54), contrast900: Color(hex: 0x232E3E),
        contrast950: Color(hex: 0x19222E), contrast975: Color(hex: 0x111822), contrast1000: Color(hex: 0x000000),
        primary25: Color(hex: 0xF5F9FF), primary50: Color(hex: 0xE5F0FF), primary100: Color(hex: 0xCCE1FF),
        primary500: Color(hex: 0x006AFF), primary600: Color(hex: 0x0059D6),
        positive500: Color(hex: 0x09B35E), positive600: Color(hex: 0x04904A),
        negative500: Color(hex: 0xE91646))

    /// `invertPalette(DEFAULT_PALETTE)`.
    static let dark = ThemePalette(
        contrast0: Color(hex: 0x000000), contrast25: Color(hex: 0x111822), contrast50: Color(hex: 0x19222E),
        contrast100: Color(hex: 0x232E3E), contrast200: Color(hex: 0x313F54), contrast300: Color(hex: 0x405168),
        contrast400: Color(hex: 0x526580), contrast500: Color(hex: 0x667B99), contrast600: Color(hex: 0x8798B0),
        contrast700: Color(hex: 0xA5B2C5), contrast800: Color(hex: 0xC0CAD8), contrast900: Color(hex: 0xDCE2EA),
        contrast950: Color(hex: 0xEFF2F6), contrast975: Color(hex: 0xF9FAFB), contrast1000: Color(hex: 0xFFFFFF),
        primary25: Color(hex: 0x001533), primary50: Color(hex: 0x001E47), primary100: Color(hex: 0x002861),
        primary500: Color(hex: 0x006AFF), primary600: Color(hex: 0x4291FF),
        positive500: Color(hex: 0x09B35E), positive600: Color(hex: 0x0DD370),
        negative500: Color(hex: 0xE91646))

    /// `invertPalette(DEFAULT_SUBDUED_PALETTE)`.
    static let dim = ThemePalette(
        contrast0: Color(hex: 0x151D28), contrast25: Color(hex: 0x1C2736), contrast50: Color(hex: 0x222E3F),
        contrast100: Color(hex: 0x2C3A4E), contrast200: Color(hex: 0x394960), contrast300: Color(hex: 0x485B75),
        contrast400: Color(hex: 0x586C89), contrast500: Color(hex: 0x6F839F), contrast600: Color(hex: 0x8D9DB4),
        contrast700: Color(hex: 0xABB8C9), contrast800: Color(hex: 0xC3CDDA), contrast900: Color(hex: 0xE2E7EE),
        contrast950: Color(hex: 0xF2F4F8), contrast975: Color(hex: 0xF9FAFB), contrast1000: Color(hex: 0xFFFFFF),
        primary25: Color(hex: 0x122136), primary50: Color(hex: 0x122949), primary100: Color(hex: 0x123464),
        primary500: Color(hex: 0x0F73FF), primary600: Color(hex: 0x4D97FF),
        positive500: Color(hex: 0x0AC266), positive600: Color(hex: 0x0EDD75),
        negative500: Color(hex: 0xEB2452))
}

/// A resolved theme: its palette and the semantic atoms features use.
///
/// Features read colours from `@Environment(\.theme)` only (review finding A17).
struct Theme: Sendable {
    var name: ThemeName
    var palette: ThemePalette

    // Atoms (`createThemes` in `@bsky.app/alf/dist/themes.js:21-89`).
    var bg: Color { palette.contrast0 }
    var bgContrast25: Color { palette.contrast25 }
    var bgContrast50: Color { palette.contrast50 }
    var text: Color { palette.contrast1000 }
    var textContrastLow: Color { palette.contrast400 }
    var textContrastMedium: Color { palette.contrast700 }
    var textContrastHigh: Color { palette.contrast900 }
    var borderContrastLow: Color { palette.contrast100 }
    var borderContrastMedium: Color { palette.contrast200 }
    /// `text_link`: primary_500 in light, primary_600 in dark and dim.
    var textLink: Color { name == .light ? palette.primary500 : palette.primary600 }

    // Semantic colours used by specific components.
    /// Post control glyphs and counts (`contrast_500`).
    var control: Color { palette.contrast500 }
    var like: Color { palette.pink }
    var repostActive: Color { palette.positive500 }
    /// Feed thread lines: contrast_100 in light, contrast_200 in dark and dim
    /// (`PostFeedItem.tsx` reply line).
    var feedReplyLine: Color { name == .light ? palette.contrast100 : palette.contrast200 }
    /// Fill of the default avatar in `UserAvatar.tsx:127,204`. Not a palette token and not themed.
    var defaultAvatarFill: Color { Color(hex: 0x0070FF) }
    /// Status bar content: dark on light, light on dark and dim (`src/view/shell/index.tsx:229-239`).
    var statusBarStyle: UIStatusBarStyle { name == .light ? .darkContent : .lightContent }

    static let light = Theme(name: .light, palette: .light)
    static let dark = Theme(name: .dark, palette: .dark)
    static let dim = Theme(name: .dim, palette: .dim)

    static func named(_ name: ThemeName) -> Theme {
        switch name {
        case .light: .light
        case .dark: .dark
        case .dim: .dim
        }
    }
}

extension EnvironmentValues {
    @Entry var theme: Theme = .light
}

/// Resolves the theme from the system appearance and puts it in the environment.
struct SystemThemeModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content.environment(\.theme, Theme.named(ThemeName.forSystem(colorScheme)))
    }
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

/// Avatar sizes used by the slice's RN components.
enum AvatarSize {
    /// Reply prompt in `ThreadComposePrompt.tsx`.
    static let composePrompt: CGFloat = 24
    /// Bottom bar profile tab: 26, or 25 inside the active ring (`BottomBar.tsx`).
    static let bottomBar: CGFloat = 26
    static let bottomBarActive: CGFloat = 25
    /// Feed rows, thread rows, composer prompt (`LINEAR_AVI_WIDTH`).
    static let post: CGFloat = 42
    /// Profile header (`Shell.tsx`).
    static let profile: CGFloat = 90
}

/// Fixed layout values from RN component styles that are not ALF tokens.
enum Layout {
    /// `Layout.Header.Outer` min height on native.
    static let headerMinHeight: CGFloat = 48
    /// Header slot width (`Layout.Header.Slot`).
    static let headerSlot: CGFloat = 33
    /// Profile banner height (`Shell.tsx:158`).
    static let bannerHeight: CGFloat = 150
    /// Profile avatar top offset (`Shell.tsx:253`).
    static let profileAvatarTop: CGFloat = 104
    /// Compose FAB diameter (`FABInner.tsx`).
    static let fabSize: CGFloat = 56
    /// Horizontal gutter on phones (`useGutters`).
    static let gutter: CGFloat = 16
    /// Post control button padding (`PostControlButton.tsx`).
    static let controlPadding: CGFloat = 5
    /// Primary post controls max width (`PostControls/index.tsx`).
    static let controlsMaxWidth: CGFloat = 320
    /// Minimum empty-state height: 75% of the window (`FollowingEndOfFeed.tsx`).
    static let endOfFeedHeightFraction: CGFloat = 0.75
}

/// A hairline rule (`StyleSheet.hairlineWidth` on native), one device pixel thick.
struct HairlineDivider: View {
    var color: Color?

    @Environment(\.theme) private var theme
    @Environment(\.pixelLength) private var pixelLength

    var body: some View {
        (color ?? theme.borderContrastLow).frame(height: pixelLength)
    }
}
