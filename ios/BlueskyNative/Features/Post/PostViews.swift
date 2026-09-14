import SwiftUI

/// Port of `src/view/com/util/PostMeta.tsx`: display name (600), NBSP + handle, and
/// "· " + short relative time, all 15pt with line height 17.
struct PostMeta: View {
    var post: PostView

    var body: some View {
        // RN sets lineHeight 17, below Inter's natural 18.15 at 15pt. Measured against the
        // RN screenshots, the glyphs sit as in a 17pt box but the row is about 0.85pt taller
        // below them, so that space is added to the bottom padding.
        let style = TextStyle(size: FontSize.md, leading: 17)
        HStack(alignment: .lastTextBaseline, spacing: 0) {
            Text(post.author.displayName?.isEmpty == false ? post.author.displayName! : post.author.handle)
                .inter(FontSize.md, FontWeight.semiBold)
                .foregroundStyle(Theme.text)
                .lineLimit(1)
                .layoutPriority(1)
            Text("\u{00A0}@\(post.author.handle)")
                .inter(FontSize.md)
                .foregroundStyle(Theme.textContrastMedium)
                .lineLimit(1)
            TimelineView(.everyMinute) { timeline in
                Text("· \(relativeTime(now: timeline.date))")
                    .inter(FontSize.md)
                    .foregroundStyle(Theme.textContrastMedium)
                    .lineLimit(1)
                    .fixedSize()
                    .padding(.leading, 4)
                    .accessibilityLabel(accessibilityDate)
            }
            .layoutPriority(2)
            Spacer(minLength: 0)
        }
        .textStyle(style)
        // Measured: RN draws these glyphs 2px (0.67pt at 3x) higher in the row.
        .offset(y: -0.67)
        .padding(.bottom, 4.85)
    }

    private func relativeTime(now: Date) -> String {
        guard let date = ATDate.parse(post.indexedAt) else { return "" }
        return TimeAgo.short(from: date, to: now)
    }

    private var accessibilityDate: String {
        ATDate.parse(post.indexedAt).map { NiceDate.long($0) } ?? ""
    }
}

/// Post text. Port of `RichText` for plain text: facets (links, mentions, tags) are not ported.
struct PostText: View {
    var text: String
    var size: CGFloat = FontSize.md

    var body: some View {
        Text(text)
            .textStyle(size: size, leading: Leading.snug)
            .foregroundStyle(Theme.text)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier("postText")
    }
}

/// Port of `src/components/PostControls/index.tsx`.
struct PostControls: View {
    var post: PostView
    var big: Bool
    var interactions: PostInteractions

    @Environment(ShellState.self) private var shell
    @State private var showsRepostMenu = false

    private var iconSize: CGFloat { big ? 22 : 18 }
    private var liked: Bool { post.viewer?.like != nil }
    private var reposted: Bool { post.viewer?.repost != nil }

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 0) {
                cell {
                    controlButton(glyph: .reply, color: Palette.contrast500, count: post.replyCount ?? 0,
                                  active: false, id: "replyBtn",
                                  label: "Reply (\(plural(post.replyCount ?? 0, "reply", "replies")))") {
                        shell.notInShowcase = NotInShowcaseItem(title: "Reply")
                    }
                }
                cell {
                    controlButton(glyph: .repost, color: reposted ? Palette.positive500 : Palette.contrast500,
                                  count: (post.repostCount ?? 0) + (post.quoteCount ?? 0), active: reposted,
                                  id: "repostBtn",
                                  label: "\(reposted ? "Undo repost" : "Repost") (\(plural(post.repostCount ?? 0, "repost", "reposts")))") {
                        showsRepostMenu = true
                    }
                }
                cell {
                    controlButton(glyph: .heart, color: liked ? Palette.pink : Palette.contrast500,
                                  count: post.likeCount ?? 0, active: liked, filled: liked, id: "likeBtn",
                                  label: "\(liked ? "Unlike" : "Like") (\(plural(post.likeCount ?? 0, "like", "likes")))") {
                        _ = interactions.toggleLike(post)
                    }
                }
            }
            .padding(.leading, big ? -2 : -6)
            .frame(maxWidth: 320, alignment: .leading)

            HStack(spacing: big ? 8 : 4) {
                controlButton(glyph: .bookmark, color: Palette.contrast500, count: 0, active: false,
                              id: "postBookmarkBtn", label: "Add to saved posts") {
                    shell.notInShowcase = NotInShowcaseItem(title: "Saved posts")
                }
                controlButton(glyph: .share, color: Palette.contrast500, count: 0, active: false,
                              id: "postShareBtn", label: "Open share menu") {
                    shell.notInShowcase = NotInShowcaseItem(title: "Share")
                }
                controlButton(glyph: .more, color: Palette.contrast500, count: 0, active: false,
                              id: "postDropdownBtn", label: "Open post options menu") {
                    shell.notInShowcase = NotInShowcaseItem(title: "Post options")
                }
            }
        }
        .padding(.top, big ? 0 : 2)
        .sheet(isPresented: $showsRepostMenu) {
            RepostMenu(reposted: reposted) { choice in
                showsRepostMenu = false
                switch choice {
                case .repost: _ = interactions.toggleRepost(post)
                case .quote: shell.notInShowcase = NotInShowcaseItem(title: "Quote post")
                }
            }
            .presentationDetents([.height(236)])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(Radius.lg)
        }
    }

    private func cell(@ViewBuilder _ content: () -> some View) -> some View {
        content().frame(maxWidth: .infinity, alignment: .leading)
    }

    private func controlButton(glyph: IconGlyph, color: Color, count: Int, active: Bool, filled: Bool = false,
                               id: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Icon(glyph, size: iconSize, color: color, filled: filled)
                if count > 0 {
                    Text(CountFormat.format(count))
                        .textStyle(size: big ? FontSize.md : FontSize.sm,
                                   weight: active ? FontWeight.semiBold : FontWeight.normal,
                                   leading: Leading.snug)
                        .foregroundStyle(color)
                        .fixedSize()
                }
            }
            .padding(5)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleStyle(scale: 1))
        .accessibilityLabel(label)
        .accessibilityIdentifier(id)
    }

    private func plural(_ count: Int, _ one: String, _ other: String) -> String {
        "\(count) \(count == 1 ? one : other)"
    }
}

/// Port of the native repost dialog in `RepostButton.tsx`.
struct RepostMenu: View {
    enum Choice { case repost, quote }

    var reposted: Bool
    var onChoose: (Choice) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 4) {
                option(glyph: .repost, title: reposted ? "Remove repost" : "Repost", id: "repostDropdownRepostBtn") {
                    onChoose(.repost)
                }
                option(glyph: .quote, title: "Quote post", id: "quoteBtn") {
                    onChoose(.quote)
                }
            }
            Button { dismiss() } label: {
                Text("Cancel")
                    .textStyle(size: FontSize.md, weight: FontWeight.medium, leading: Leading.tight)
                    .foregroundStyle(Theme.textContrastMedium)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Theme.bgContrast50, in: Capsule())
            }
            .buttonStyle(PressScaleStyle(scale: 1))
            .accessibilityLabel("Cancel quote post")
        }
        .padding(.horizontal, 20)
        .padding(.top, 28)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Theme.background)
        .accessibilityLabel("Repost or quote post")
    }

    private func option(glyph: IconGlyph, title: String, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Icon(glyph, size: IconSize.lg, color: Palette.primary500)
                Text(title)
                    .textStyle(size: FontSize.xl, weight: FontWeight.semiBold, leading: Leading.snug)
                    .foregroundStyle(Theme.text)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleStyle(scale: 1))
        .accessibilityIdentifier(id)
    }
}
