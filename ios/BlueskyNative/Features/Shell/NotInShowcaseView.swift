import SwiftUI

/// Shown for screens and actions that this showcase does not port.
struct NotInShowcaseView: View {
    var title: String

    var body: some View {
        VStack(spacing: 12) {
            Text(title)
                .textStyle(size: FontSize._2xl, weight: FontWeight.bold, leading: Leading.tight)
                .foregroundStyle(Theme.text)
            Text("Not part of this showcase")
                .textStyle(size: FontSize.md, weight: FontWeight.semiBold, leading: Leading.snug)
                .foregroundStyle(Theme.text)
            Text("This native port covers the home feed, post threads and your profile. The React Native app has this screen; it was not ported.")
                .textStyle(size: FontSize.md, leading: Leading.snug)
                .foregroundStyle(Theme.textContrastMedium)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
        .accessibilityIdentifier("notInShowcaseView")
    }
}
