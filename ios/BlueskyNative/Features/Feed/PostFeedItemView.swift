import SwiftUI

/// Port of `src/view/com/posts/PostFeedItem.tsx`.
///
/// Layout (pt): padding left 10, right 15; an 8pt top row (reason, thread line);
/// avatar column 8 + 42 + 10; content from x = 70; bottom padding 8 unless the row
/// continues a thread; hairline top border unless hidden or a thread child.
struct PostFeedItemView: View {
    var row: FeedRow
    var item: FeedSlice.Item
    var reason: FeedViewPost.Reason?
    var interactions: PostInteractions
    var onOpen: (String) -> Void

    @Environment(PostShadowStore.self) private var shadows

    var body: some View {
        let post = shadows.apply(to: item.post)
        VStack(alignment: .leading, spacing: 0) {
            topRow
            HStack(alignment: .top, spacing: 0) {
                UserAvatar(url: post.author.avatar, size: 42)
                    .padding(.leading, 8)
                    .padding(.trailing, 10)
                VStack(alignment: .leading, spacing: 0) {
                    PostMeta(post: post)
                    if row.showReplyTo, post.record.reply != nil {
                        repliedTo
                    }
                    if !post.record.text.isEmpty {
                        PostText(text: post.record.text)
                            .padding(.bottom, 2)
                    }
                    PostControls(post: post, big: false, interactions: interactions)
                }
            }
            .padding(.top, 1)
        }
        .padding(.leading, 10)
        .padding(.trailing, 15)
        .padding(.bottom, row.isThreadLastChild || (!row.isThreadChild && !row.isThreadParent) ? 8 : 0)
        .background(alignment: .topLeading) {
            if row.isThreadParent {
                // Line from 4pt under the avatar to the bottom of the row.
                Theme.borderContrastLow
                    .frame(width: 2)
                    .padding(.top, topRowHeight + 1 + 42 + 4)
                    .padding(.leading, 10 + 8 + 20)
            }
        }
        .overlay(alignment: .top) {
            if !row.hideTopBorder && !row.isThreadChild { HairlineDivider() }
        }
        .background(Theme.background)
        .contentShape(Rectangle())
        .onTapGesture { onOpen(item.post.uri) }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("feedItem-by-\(post.author.handle)")
    }

    private var topRowHeight: CGFloat {
        if case .repost = reason { return 8 + 17 + 2 }
        return 8
    }

    /// The 8pt spacer above the avatar, which also carries the repost reason and the
    /// incoming thread line for child rows.
    private var topRow: some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack(alignment: .top) {
                if row.isThreadChild {
                    Theme.borderContrastLow
                        .frame(width: 2)
                        .padding(.bottom, 4)
                }
            }
            .frame(width: 42, height: topRowHeight)
            VStack(alignment: .leading, spacing: 0) {
                Color.clear.frame(height: 8)
                if case .repost(let by) = reason {
                    HStack(spacing: 3) {
                        Icon(.repost, size: 13, color: Theme.textContrastMedium)
                        Text("Reposted by \(by.displayName ?? by.handle)")
                            .textStyle(size: FontSize.sm, weight: FontWeight.medium, leading: 17)
                            .foregroundStyle(Theme.textContrastMedium)
                            .lineLimit(1)
                    }
                    .padding(.leading, -16)
                    .padding(.bottom, 2)
                }
            }
        }
        .padding(.leading, 8)
    }

    private var repliedTo: some View {
        HStack(spacing: 4) {
            Icon(.cornerDownRight, size: IconSize.xs, color: Theme.textContrastMedium)
                .offset(y: -1)
            Text(item.parentAuthor.map { "Replied to \($0.displayName ?? $0.handle)" } ?? "Replied to a post")
                .textStyle(size: FontSize.sm, leading: 17)
                .foregroundStyle(Theme.textContrastMedium)
                .lineLimit(1)
        }
        .padding(.bottom, 4)
    }
}

/// Port of `ViewFullThread`: a link row between the root and the last replies.
struct ViewFullThreadRow: View {
    var onOpen: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Theme.borderContrastLow.frame(width: 2, height: 40).frame(width: 42)
            Text("View full thread")
                .textStyle(size: FontSize.md, leading: Leading.snug)
                .foregroundStyle(Palette.primary500)
            Spacer()
        }
        .padding(.leading, 18)
        .contentShape(Rectangle())
        .onTapGesture(perform: onOpen)
        .accessibilityAddTraits(.isLink)
    }
}
