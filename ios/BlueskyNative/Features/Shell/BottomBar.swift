import SwiftUI

/// Port of `src/view/shell/bottom-bar/BottomBar.tsx`.
///
/// Row with 8pt side padding, `bg` background and a hairline top border in
/// `border_contrast_low` (the `bg` colour when hidden). Each button is flex 1 with 13pt top and
/// 4pt bottom padding; the home indicator inset below is `clamp(safeArea.bottom, 15, 60)`.
struct BottomBar: View {
    var selected: ShellTab
    var unreadText: String
    var avatarURL: URL?
    var hidesBorder: Bool
    var onSelect: (ShellTab) -> Void

    @Environment(\.theme) private var theme

    private static let iconSlot: CGFloat = 30
    private static let topPadding: CGFloat = 13
    private static let bottomPadding: CGFloat = 4

    var body: some View {
        GeometryReader { proxy in
            let extraBottom = max(0, min(max(proxy.safeAreaInsets.bottom, 15), 60) - proxy.safeAreaInsets.bottom)
            HStack(alignment: .top, spacing: 0) {
                button(.home, id: "bottomBarHomeBtn") {
                    Icon(.home, size: 29, color: theme.text, filled: selected == .home)
                }
                // RN sets `bottomBarSearchBtn` on the stroke icon only, which shows while inactive.
                button(.search, id: selected == .search ? "" : "bottomBarSearchBtn") {
                    Icon(.search, size: 30, color: theme.text, filled: false)
                        .offset(y: -1)
                }
                button(.messages, id: "bottomBarMessagesBtn") {
                    Icon(.chat, size: 27, color: theme.text, filled: false)
                }
                button(.notifications, id: "bottomBarNotificationsBtn", badge: unreadText,
                       hint: Self.unreadHint(unreadText)) {
                    Icon(.bell, size: 28, color: theme.text, filled: selected == .notifications)
                }
                button(.profile, id: "bottomBarProfileBtn") {
                    profileAvatar
                }
            }
            .padding(.horizontal, Space.sm)
            .padding(.bottom, extraBottom)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .frame(height: Self.topPadding + Self.iconSlot + Self.bottomPadding)
        .background(theme.bg.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) {
            HairlineDivider(color: hidesBorder ? theme.bg : theme.borderContrastLow)
        }
    }

    /// Notifications hint: `plural(n, {one: '# unread item', other: '# unread items'})`, or
    /// "30+ unread items" style text when the count string carries "+".
    static func unreadHint(_ text: String) -> String {
        guard !text.isEmpty else { return "" }
        if text.contains("+") { return "\(text) unread items" }
        let count = Int(text) ?? 0
        return Plural.count(count, one: "unread item", other: "unread items")
    }

    private var profileAvatar: some View {
        let active = selected == .profile
        return UserAvatar(url: avatarURL, size: active ? AvatarSize.bottomBarActive : AvatarSize.bottomBar,
                          showsBorder: false)
            .padding(active ? 0 : 1)
            .overlay {
                Circle().strokeBorder(active ? theme.text : .clear, lineWidth: 1).padding(active ? -1 : 0)
            }
            .padding(active ? 1 : 0)
            .frame(width: 28, height: 28)
    }

    private func button(_ tab: ShellTab, id: String, badge: String = "", hint: String = "",
                        @ViewBuilder icon: () -> some View) -> some View {
        Button { onSelect(tab) } label: {
            icon()
                .frame(height: Self.iconSlot, alignment: .top)
                .frame(maxWidth: .infinity)
                .overlay(alignment: .topLeading) {
                    if !badge.isEmpty {
                        GeometryReader { geo in
                            Text(badge)
                                .textStyle(size: 12, weight: FontWeight.semiBold, maxScale: 1.5)
                                .monospacedDigit()
                                .foregroundStyle(theme.palette.white)
                                .padding(.horizontal, 5)
                                .padding(.top, 1)
                                .padding(.bottom, Space._2xs)
                                .background(theme.palette.primary500, in: Capsule())
                                .fixedSize()
                                .offset(x: geo.size.width * 0.52, y: Space.sm - Self.topPadding)
                        }
                    }
                }
                .padding(.top, Self.topPadding)
                .padding(.bottom, Self.bottomPadding)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleStyle(scale: 0.8))
        .accessibilityLabel(tab.title)
        .accessibilityHint(hint)
        .accessibilityIdentifier(id)
        .accessibilityAddTraits(selected == tab ? .isSelected : [])
        .accessibilityShowsLargeContentViewer {
            Text(tab.title)
        }
    }
}
