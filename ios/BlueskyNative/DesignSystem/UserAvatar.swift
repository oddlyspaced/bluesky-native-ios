import SwiftUI

/// Port of `src/view/com/util/UserAvatar.tsx` for circular user avatars.
///
/// Images load through `ImageLoading` (memory cache, downsampled off the main actor).
struct UserAvatar: View {
    var url: URL?
    var size: CGFloat
    /// RN draws a hairline `MediaInsetBorder` unless `noBorder` is set.
    var showsBorder: Bool = true

    @Environment(\.theme) private var theme
    @Environment(\.pixelLength) private var pixelLength

    var body: some View {
        ZStack {
            if let url {
                RemoteImage(url: url, pointSize: size) {
                    theme.palette.contrast25
                }
            } else {
                DefaultAvatar()
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay {
            if showsBorder {
                Circle()
                    .strokeBorder(theme.borderContrastLow, lineWidth: pixelLength)
                    .opacity(0.6)
            }
        }
        .accessibilityHidden(true)
    }
}

/// Generic fallback avatar drawn in code: a blue disc with a white head and shoulders.
///
/// Bluesky's default avatar artwork is a brand asset (ASSETS.md section 3) and is not
/// copied. The geometry here is a plain circle-and-ellipse silhouette.
struct DefaultAvatar: View {
    @Environment(\.theme) private var theme

    var body: some View {
        let fill = theme.defaultAvatarFill
        Canvas { context, canvasSize in
            let s = canvasSize.width
            let disc = Path(ellipseIn: CGRect(origin: .zero, size: canvasSize))
            context.fill(disc, with: .color(fill))
            context.clip(to: disc)
            let headDiameter = s * 0.3
            context.fill(Path(ellipseIn: CGRect(x: (s - headDiameter) / 2, y: s * 0.24,
                                                width: headDiameter, height: headDiameter)),
                         with: .color(.white))
            context.fill(Path(ellipseIn: CGRect(x: s * 0.2, y: s * 0.64, width: s * 0.6, height: s * 0.5)),
                         with: .color(.white))
        }
        .accessibilityIdentifier("userAvatarFallback")
    }
}
