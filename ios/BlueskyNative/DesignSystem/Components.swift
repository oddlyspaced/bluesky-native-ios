import SwiftUI

/// Scales or dims on press, like RN `PressableScale` and ghost buttons.
struct PressScaleStyle: ButtonStyle {
    var scale: CGFloat = 0.9

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed && scale == 1 ? 0.6 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Port of `Layout.Header.Outer` (`src/components/Layout/Header/index.tsx`): row, gap 8,
/// gutter 16, bottom padding 4, hairline bottom border. RN's `minHeight: 48` includes the
/// padding (border-box), so the content row is 44pt.
struct ScreenHeader<Leading: View, Center: View, Trailing: View>: View {
    var showsBottomBorder = true
    @ViewBuilder var leading: Leading
    @ViewBuilder var center: Center
    @ViewBuilder var trailing: Trailing

    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: Space.sm) {
            leading.frame(width: Layout.headerSlot)
            center.frame(maxWidth: .infinity, minHeight: Layout.headerSlot)
            trailing.frame(width: Layout.headerSlot)
        }
        .padding(.horizontal, Layout.gutter)
        .frame(minHeight: Layout.headerMinHeight - Space.xs)
        .padding(.bottom, Space.xs)
        .background(theme.bg)
        .overlay(alignment: .bottom) {
            if showsBottomBorder { HairlineDivider() }
        }
    }
}

/// `Layout.Header.TitleText`: text_lg, semi-bold, tight, centred, at most 2 lines, capped at 2x.
struct HeaderTitle: View {
    var title: String
    @Environment(\.theme) private var theme

    var body: some View {
        Text(title)
            .textStyle(size: FontSize.lg, weight: FontWeight.semiBold, leading: Leading.tight, maxScale: 2)
            .foregroundStyle(theme.text)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Small ghost icon button (33x33) in contrast_600, as used in headers.
struct HeaderIconButton: View {
    var glyph: IconGlyph
    var iconSize: CGFloat = IconSize.lg
    var label: String
    var action: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: action) {
            Icon(glyph, size: iconSize, color: theme.palette.contrast600)
                .frame(width: Layout.headerSlot, height: Layout.headerSlot)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleStyle(scale: 1))
        .accessibilityLabel(label)
    }
}

/// Port of ALF `Button` (`src/components/Button.tsx`) for the variants this slice uses:
/// `variant="solid"`, `shape="round"` (pill) with the sizes' paddings from `Button.tsx:457-481`.
struct DSButton: View {
    enum Color {
        /// `primary`: primary_500 fill, white text.
        case primary
        /// `secondary`: contrast_50 fill, contrast_700 text.
        case secondary
        /// `secondary_inverted`: contrast_900 fill, `text_inverted` (contrast_0) text.
        case secondaryInverted
    }

    enum Size {
        /// Padding 8 x 14, gap 5, text_sm.
        case small
        /// Padding 12 x 24, gap 6, text_md.
        case large
    }

    enum IconPosition { case leading, trailing }

    var title: String
    var accessibilityLabel: String?
    var accessibilityHint: String?
    var color: Color = .primary
    var size: Size = .large
    var icon: IconGlyph?
    var iconPosition: IconPosition = .leading
    var fullWidth = false
    var action: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: action) {
            HStack(spacing: size == .small ? 5 : 6) {
                if let icon, iconPosition == .leading { iconView(icon) }
                // Both sizes use leading_snug: the RN large pill measures 44pt (12 + 20 + 12).
                Text(title)
                    .textStyle(size: size == .small ? FontSize.sm : FontSize.md, weight: FontWeight.medium,
                               leading: Leading.snug)
                    .lineLimit(1)
                if let icon, iconPosition == .trailing { iconView(icon) }
            }
            .foregroundStyle(foreground)
            .padding(.vertical, size == .small ? Space.sm : Space.md)
            .padding(.horizontal, size == .small ? 14 : Space._2xl)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .background(background, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(PressScaleStyle(scale: 1))
        .accessibilityLabel(accessibilityLabel ?? title)
        .accessibilityHint(accessibilityHint ?? "")
    }

    private func iconView(_ glyph: IconGlyph) -> some View {
        Icon(glyph, size: size == .small ? IconSize.sm : 18, color: foreground)
    }

    private var foreground: SwiftUI.Color {
        switch color {
        case .primary: theme.palette.white
        case .secondary: theme.palette.contrast700
        case .secondaryInverted: theme.palette.contrast0
        }
    }

    private var background: SwiftUI.Color {
        switch color {
        case .primary: theme.palette.primary500
        case .secondary: theme.palette.contrast50
        case .secondaryInverted: theme.palette.contrast900
        }
    }
}

/// Round icon-only secondary button (33x33), as in the profile header.
struct DSIconButton: View {
    var glyph: IconGlyph
    var label: String
    var action: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: action) {
            Icon(glyph, size: IconSize.sm, color: theme.textContrastMedium)
                .frame(width: Layout.headerSlot, height: Layout.headerSlot)
                .background(theme.bgContrast50, in: Circle())
        }
        .buttonStyle(PressScaleStyle(scale: 1))
        .accessibilityLabel(label)
    }
}

/// Port of the pager `TabBar` (`src/view/com/pager/TabBar.tsx`).
///
/// Items: padding top 10 and horizontal 10, inner bottom padding 10 plus a 3pt transparent
/// border; text 15/600 with line height 20; unselected items at opacity 0.7; a 2pt primary
/// underline as wide as the label (min 45); a hairline below. testIDs: `<testID>`,
/// `<testID>-selector`, `<testID>-selector-<index>`, `<testID>-<item>`.
struct PagerTabBar: View {
    var items: [String]
    @Binding var selection: Int
    /// Home stretches its tabs across the width; the profile pager scrolls.
    var stretches: Bool
    var testID: String
    var onSelect: ((Int) -> Void)?

    @Environment(\.theme) private var theme
    @Environment(\.pixelLength) private var pixelLength

    private static let rowInset: CGFloat = 6
    private static let itemPadding: CGFloat = 10
    private static let labelBottom: CGFloat = 13
    private static let underlineHeight: CGFloat = 2
    private static let underlineMinWidth: CGFloat = 45

    var body: some View {
        Group {
            if stretches {
                row.padding(.horizontal, Self.rowInset)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    row.padding(.horizontal, Self.rowInset)
                }
            }
        }
        .accessibilityIdentifier("\(testID)-selector")
        .overlay(alignment: .bottom) {
            HairlineDivider().offset(y: pixelLength)
        }
        // The label box is RN's TextKit box, `ceil((L + 0.001) * scale) / scale`, so the underline
        // and the outer hairline (`top: '100%'`) sit that ceil below a plain `L` box, as in RN.
        // RN measured the bar 43pt tall, so the bar gives the ceil back after the overlay is placed.
        .padding(.bottom, -labelCeil)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(testID)
    }

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var labelCeil: CGFloat {
        let lineHeight = 20 * FontScale.multiplier(for: dynamicTypeSize)
        let metrics = RNTextMetrics(fontLineHeight: 0, ascender: 0, descender: 0, lineHeight: lineHeight,
                                    renderer: .paragraph)
        let scale = pixelLength > 0 ? 1 / pixelLength : 0
        return metrics.boxHeight(lines: 1, scale: scale) - lineHeight
    }

    private var row: some View {
        HStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, title in
                Button {
                    if let onSelect { onSelect(index) } else { selection = index }
                } label: {
                    tabLabel(title, selected: index == selection)
                        .padding(.horizontal, Self.itemPadding)
                        .padding(.top, Self.itemPadding)
                        .frame(maxWidth: stretches ? .infinity : nil)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("\(testID)-selector-\(index)")
                .accessibilityAddTraits(index == selection ? [.isSelected, .isButton] : .isButton)
            }
        }
    }

    private func tabLabel(_ title: String, selected: Bool) -> some View {
        Text(title)
            .textStyle(size: FontSize.md, weight: FontWeight.semiBold, leading: 20)
            .foregroundStyle(theme.text)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.bottom, Self.labelBottom)
            .opacity(selected ? 1 : 0.7)
            .background(alignment: .bottom) {
                if selected {
                    theme.palette.primary500
                        .frame(minWidth: Self.underlineMinWidth)
                        .frame(height: Self.underlineHeight)
                }
            }
            .accessibilityIdentifier("\(testID)-\(title)")
    }
}

/// Port of the compose FAB (`src/view/com/util/fab/FABInner.tsx`): 56pt primary circle
/// with the compose icon in white, 24pt from the right edge.
struct ComposeFAB: View {
    var action: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: action) {
            Icon(.compose, size: IconSize.lg, color: theme.palette.white)
                .frame(width: Layout.fabSize, height: Layout.fabSize)
                .background(theme.palette.primary500, in: Circle())
        }
        .buttonStyle(PressScaleStyle(scale: 0.9))
        .accessibilityLabel("New post")
        .accessibilityIdentifier("composeFAB")
        .padding(.trailing, Space._2xl)
        .padding(.bottom, Space.md)
    }
}

/// Port of `ErrorMessage` (`src/view/com/util/error/ErrorMessage.tsx`): a pink row with a
/// white warning icon, the message, and a round retry button.
struct ErrorMessageRow: View {
    var message: String
    var onRetry: (() -> Void)?

    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: Space.md) {
            Icon(.warning, size: IconSize.md, color: theme.palette.white)
            Text(message)
                .textStyle(size: FontSize.md, weight: FontWeight.medium, leading: Leading.snug)
                .foregroundStyle(theme.palette.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            if let onRetry {
                Button(action: onRetry) {
                    Icon(.rotateClockwise, size: IconSize.md, color: theme.palette.white)
                        .frame(width: Layout.headerSlot, height: Layout.headerSlot)
                        .contentShape(Circle())
                }
                .buttonStyle(PressScaleStyle(scale: 1))
                .accessibilityLabel("Retry")
                .accessibilityHint("Retries the last action, which errored out")
                .accessibilityIdentifier("errorMessageTryAgainButton")
            }
        }
        .padding(.horizontal, Layout.gutter)
        .padding(.vertical, Space.sm)
        .background(theme.palette.pink)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("errorMessageView")
    }
}

/// Port of `ErrorScreen` (`src/view/com/util/error/ErrorScreen.tsx:34-99`) without its header.
struct ErrorScreenContent: View {
    var title: String
    var message: String
    var testID: String
    var onRetry: (() -> Void)?

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            Icon(.warning, size: IconSize.lg, color: theme.palette.contrast0)
                .frame(width: 50, height: 50)
                .background(theme.palette.contrast950, in: Circle())
                .padding(.bottom, Space.md)
            Text(title)
                .textStyle(size: FontSize._2xl, weight: FontWeight.bold, leading: Leading.snug)
                .foregroundStyle(theme.text)
                .multilineTextAlignment(.center)
                .padding(.bottom, Space.md)
            Text(message)
                .textStyle(size: FontSize.md, leading: Leading.snug)
                .foregroundStyle(theme.text)
                .multilineTextAlignment(.center)
                .padding(.bottom, Space.xl)
            if let onRetry {
                DSButton(title: "Try again", accessibilityLabel: "Retry",
                         accessibilityHint: "Retries the last action, which errored out",
                         color: .secondaryInverted, size: .small, icon: .rotateCounterClockwise, action: onRetry)
                    .accessibilityIdentifier("errorScreenTryAgainButton")
            }
        }
        .padding(.horizontal, Space.xl)
        .padding(.vertical, Space._2xl)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(testID)
    }
}

/// Skeleton primitives (`src/components/Skeleton.tsx`).
enum Skeleton {
    /// A text bar: height `lineHeight * 0.7`, vertical padding `lineHeight * 0.15`, radius 12.
    struct TextBar: View {
        var lineHeight: CGFloat
        var widthFraction: CGFloat
        var blend = false

        @Environment(\.theme) private var theme

        var body: some View {
            GeometryReader { proxy in
                RoundedRectangle(cornerRadius: Radius.md)
                    .fill(theme.bgContrast50)
                    .frame(width: proxy.size.width * widthFraction, height: lineHeight * 0.7)
                    .padding(.vertical, lineHeight * 0.15)
            }
            .frame(height: lineHeight)
            .opacity(blend ? 0.6 : 1)
        }
    }

    struct Circle: View {
        var size: CGFloat
        @Environment(\.theme) private var theme

        var body: some View {
            SwiftUI.Circle().fill(theme.bgContrast50).frame(width: size, height: size)
        }
    }
}
