import SwiftUI

/// Port of `src/view/shell/bottom-bar/BottomBar.tsx`.
///
/// Row with 8pt side padding, white background and a hairline top border. Each button
/// is flex 1 with 13pt top and 4pt bottom padding; the home indicator inset below is
/// `clamp(safeArea.bottom, 15, 60)`.
struct BottomBar: View {
    var selected: ShellTab
    var unreadText: String
    var avatarURL: URL?
    var hidesBorder: Bool
    var onSelect: (ShellTab) -> Void

    var body: some View {
        GeometryReader { proxy in
            let extraBottom = max(0, min(max(proxy.safeAreaInsets.bottom, 15), 60) - proxy.safeAreaInsets.bottom)
            HStack(alignment: .top, spacing: 0) {
                button(.home, id: "bottomBarHomeBtn") {
                    Icon(.home, size: 29, color: Theme.text, filled: selected == .home)
                }
                button(.search, id: "bottomBarSearchBtn") {
                    Icon(.search, size: 30, color: Theme.text, filled: false)
                        .offset(y: -1)
                }
                button(.messages, id: "bottomBarMessagesBtn") {
                    Icon(.chat, size: 27, color: Theme.text, filled: false)
                }
                button(.notifications, id: "bottomBarNotificationsBtn", badge: unreadText) {
                    Icon(.bell, size: 28, color: Theme.text, filled: selected == .notifications)
                }
                button(.profile, id: "bottomBarProfileBtn") {
                    profileAvatar
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, extraBottom)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .frame(height: 13 + 30 + 4)
        .background(Theme.background.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) {
            HairlineDivider(color: hidesBorder ? Theme.background : Theme.borderContrastLow)
        }
    }

    private var profileAvatar: some View {
        let active = selected == .profile
        return UserAvatar(url: avatarURL, size: active ? 25 : 26, showsBorder: false)
            .padding(active ? 0 : 1)
            .overlay {
                Circle().strokeBorder(active ? Theme.text : .clear, lineWidth: 1).padding(active ? -1 : 0)
            }
            .padding(active ? 1 : 0)
            .frame(width: 28, height: 28)
    }

    private func button(_ tab: ShellTab, id: String, badge: String = "",
                        @ViewBuilder icon: () -> some View) -> some View {
        Button { onSelect(tab) } label: {
            icon()
                .frame(height: 30, alignment: .top)
                .frame(maxWidth: .infinity)
                .overlay(alignment: .topLeading) {
                    if !badge.isEmpty {
                        GeometryReader { geo in
                            Text(badge)
                                .inter(12, FontWeight.semiBold)
                                .monospacedDigit()
                                .foregroundStyle(.white)
                                .padding(.horizontal, 5)
                                .padding(.top, 1)
                                .padding(.bottom, 2)
                                .background(Palette.primary500, in: Capsule())
                                .fixedSize()
                                .offset(x: geo.size.width * 0.52, y: 8 - 13)
                        }
                    }
                }
                .padding(.top, 13)
                .padding(.bottom, 4)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleStyle(scale: 0.8))
        .accessibilityLabel(tab.title)
        .accessibilityIdentifier(id)
        .accessibilityAddTraits(selected == tab ? .isSelected : [])
    }
}
