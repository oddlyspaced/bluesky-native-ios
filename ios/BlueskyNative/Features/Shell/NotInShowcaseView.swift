import SwiftUI

/// Shown for screens and actions that this showcase does not port.
struct NotInShowcaseView: View {
    var title: String

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: Space.md) {
            Text(title)
                .textStyle(size: FontSize._2xl, weight: FontWeight.bold, leading: Leading.tight)
                .foregroundStyle(theme.text)
            Text("Not part of this showcase")
                .textStyle(size: FontSize.md, weight: FontWeight.semiBold, leading: Leading.snug)
                .foregroundStyle(theme.text)
            Text("This native port covers the home feed, post threads and your profile. The React Native app has this screen; it was not ported.")
                .textStyle(size: FontSize.md, leading: Leading.snug)
                .foregroundStyle(theme.textContrastMedium)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, Space._4xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.bg)
        .accessibilityIdentifier("notInShowcaseView")
    }
}
