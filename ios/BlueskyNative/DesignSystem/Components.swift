import SwiftUI

/// A hairline rule in `border_contrast_low`.
struct HairlineDivider: View {
    var color: Color = Theme.borderContrastLow

    var body: some View {
        color.frame(height: Hairline.width)
    }
}

/// Port of `Layout.Header.Outer` (`src/components/Layout/Header/index.tsx`):
/// row, gap 8, horizontal gutter 16, min height 48, bottom padding 4.
struct ScreenHeader<Leading: View, Center: View, Trailing: View>: View {
    var showsBottomBorder = true
    @ViewBuilder var leading: Leading
    @ViewBuilder var center: Center
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 8) {
            leading.frame(width: 33)
            center.frame(maxWidth: .infinity, minHeight: 33)
            trailing.frame(width: 33)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 44)
        .padding(.bottom, 4)
        .background(Theme.background)
        .overlay(alignment: .bottom) {
            if showsBottomBorder { HairlineDivider() }
        }
    }
}

/// Small ghost icon button (33x33) in contrast_600, as used in headers.
struct HeaderIconButton: View {
    var glyph: IconGlyph
    var iconSize: CGFloat = IconSize.lg
    var label: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Icon(glyph, size: iconSize, color: Palette.contrast600)
                .frame(width: 33, height: 33)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleStyle(scale: 1))
        .accessibilityLabel(label)
    }
}

/// Dims or scales on press, like RN `PressableScale` and ghost buttons.
struct PressScaleStyle: ButtonStyle {
    var scale: CGFloat = 0.9

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed && scale == 1 ? 0.6 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Port of the pager `TabBar` (`src/view/com/pager/TabBar.tsx`).
///
/// Items: padding top 10 and horizontal 10, inner bottom padding 10 plus a 3pt
/// transparent border; text 15/600 with line height 20; unselected items at opacity
/// 0.7; a 2pt primary underline as wide as the label (min 45); a hairline below.
struct PagerTabBar: View {
    var items: [String]
    @Binding var selection: Int
    /// Home stretches its tabs across the width; the profile pager scrolls.
    var stretches: Bool
    var testID: String
    var onSelect: ((Int) -> Void)?

    var body: some View {
        Group {
            if stretches {
                row.padding(.horizontal, 6)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    row.padding(.horizontal, 6)
                }
            }
        }
        .overlay(alignment: .bottom) {
            HairlineDivider().offset(y: Hairline.width)
        }
        .accessibilityIdentifier(testID)
    }

    private var row: some View {
        HStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, title in
                Button {
                    if let onSelect { onSelect(index) } else { selection = index }
                } label: {
                    tabLabel(title, selected: index == selection)
                        .padding(.horizontal, 10)
                        .padding(.top, 10)
                        .frame(maxWidth: stretches ? .infinity : nil)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("\(testID)-selector-\(index)")
                .accessibilityAddTraits(index == selection ? .isSelected : [])
            }
        }
    }

    private func tabLabel(_ title: String, selected: Bool) -> some View {
        Text(title)
            .textStyle(size: FontSize.md, weight: FontWeight.semiBold, leading: 20)
            .foregroundStyle(Theme.text)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.bottom, 13)
            .opacity(selected ? 1 : 0.7)
            .background(alignment: .bottom) {
                if selected {
                    Palette.primary500
                        .frame(minWidth: 45)
                        .frame(height: 2)
                }
            }
    }
}

/// Port of the compose FAB (`src/view/com/util/fab/FABInner.tsx`): 56pt primary circle
/// with the compose icon in white, 24pt from the right edge.
struct ComposeFAB: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Icon(.compose, size: IconSize.lg, color: .white)
                .frame(width: 56, height: 56)
                .background(Palette.primary500, in: Circle())
        }
        .buttonStyle(PressScaleStyle(scale: 0.9))
        .accessibilityLabel("New post")
        .accessibilityIdentifier("composeFAB")
        .padding(.trailing, 24)
        .padding(.bottom, 12)
    }
}

extension Text {
    /// Sets Inter at a size and weight on a `Text` value, so styled runs can be concatenated.
    @MainActor
    func inter(_ size: CGFloat, _ weight: CGFloat = FontWeight.normal) -> Text {
        font(Font(InterFont.uiFont(size: size, weight: weight) as CTFont))
    }
}
