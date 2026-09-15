import SwiftUI

/// Port of `src/view/com/posts/PostFeedItem.tsx`.
///
/// Layout (pt): padding left 10, right 15; an 8pt top row (reason, thread line);
/// avatar column 8 + 42 + 10; body row margin top 1; bottom padding 8 unless the row
/// continues a thread; hairline top border unless hidden or a thread child.
struct PostFeedItemView: View {
    var row: FeedRow
    var item: FeedSlice.Item
    var reason: FeedViewPost.Reason?
    var context: PostEventContext

    @Environment(AccountContainer.self) private var container
    @Environment(\.theme) private var theme
    @Environment(\.pixelLength) private var pixelLength

    private static let topRowHeight: CGFloat = 8
    private static let reasonHeight: CGFloat = 17 + Space._2xs
    /// A thread parent row has no bottom padding. Measured: RN parent rows are 1px (3x) shorter
    /// than a plain row minus 8pt (248px against 249px), from Yoga's pixel rounding.
    private static let threadParentBottom: CGFloat = -1.0 / 3

    private var bottomPadding: CGFloat {
        if row.isThreadLastChild || (!row.isThreadChild && !row.isThreadParent) { return Space.sm }
        return row.isThreadParent ? RNLineBox.snap(Self.threadParentBottom, pixelLength: pixelLength) : 0
    }

    var body: some View {
        let post = container.shadows.apply(to: item.post)
        VStack(alignment: .leading, spacing: 0) {
            topRow
            HStack(alignment: .top, spacing: 0) {
                Button(action: openAuthor) {
                    UserAvatar(url: post.author.avatar, size: AvatarSize.post)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(Names.postMetaName(displayName: post.author.displayName, handle: post.author.handle))'s avatar")
                .padding(.leading, Space.sm)
                .padding(.trailing, 10)
                VStack(alignment: .leading, spacing: 0) {
                    PostMeta(post: post)
                    if row.showReplyTo, item.parentAuthor != nil || item.isParentBlocked || item.isParentNotFound {
                        repliedTo
                    }
                    if !post.record.text.isEmpty {
                        PostText(post: post)
                            .padding(.bottom, Space._2xs)
                    }
                    PostControls(post: post, serverPost: item.post, big: false, context: context,
                                 viaRepost: row.viaRepost)
                }
            }
            .padding(.top, 1)
        }
        .padding(.leading, 10)
        .padding(.trailing, 15)
        .padding(.bottom, bottomPadding)
        .background(alignment: .topLeading) {
            if row.isThreadParent {
                // Line from 4pt under the avatar to the bottom of the row.
                theme.feedReplyLine
                    .frame(width: 2)
                    .padding(.top, topRowHeight + 1 + AvatarSize.post + Space.xs)
                    .padding(.leading, 10 + Space.sm + (AvatarSize.post - 2) / 2)
            }
        }
        .overlay(alignment: .top) {
            if !row.hideTopBorder && !row.isThreadChild { HairlineDivider() }
        }
        .background(theme.bg)
        .contentShape(Rectangle())
        .onTapGesture(perform: openThread)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("feedItem-by-\(post.author.handle)")
    }

    private var topRowHeight: CGFloat {
        switch reason {
        case .repost, .pin: Self.topRowHeight + Self.reasonHeight
        default: Self.topRowHeight
        }
    }

    private func openThread() {
        container.analytics.metric("post:clickthroughItem", context.props(for: item.post))
        container.router.openThread(uri: item.post.uri, feedDescriptor: context.feedDescriptor)
    }

    private func openAuthor() {
        container.analytics.metric("post:clickthroughAuthor", context.props(for: item.post))
        container.router.openProfile(did: item.post.author.did)
    }

    /// The 8pt spacer above the avatar, which also carries the reason and the incoming
    /// thread line for child rows (`PostFeedItem.tsx:357-385`).
    private var topRow: some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack(alignment: .top) {
                if row.isThreadChild {
                    theme.feedReplyLine
                        .frame(width: 2)
                        .padding(.bottom, Space.xs)
                }
            }
            .frame(width: AvatarSize.post, height: topRowHeight)
            VStack(alignment: .leading, spacing: 0) {
                Color.clear.frame(height: Self.topRowHeight)
                reasonView
            }
        }
        .padding(.leading, Space.sm)
    }

    /// Port of `PostFeedReason.tsx`.
    @ViewBuilder
    private var reasonView: some View {
        switch reason {
        case .repost(let by, _, _, _):
            let text = by.did == container.accountDid
                ? "Reposted by you"
                : "Reposted by \(Names.reasonName(displayName: by.displayName, handle: by.handle))"
            Button { container.router.openProfile(did: by.did) } label: {
                reasonLabel(glyph: .repost, text: text)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(text)
        case .pin:
            reasonLabel(glyph: .pin, text: "Pinned")
        default:
            EmptyView()
        }
    }

    private func reasonLabel(glyph: IconGlyph, text: String) -> some View {
        HStack(spacing: 3) {
            Icon(glyph, size: 13, color: theme.textContrastMedium)
            Text(text)
                .textStyle(size: FontSize.sm, weight: FontWeight.medium, leading: Leading.snug)
                .foregroundStyle(theme.textContrastMedium)
                .lineLimit(1)
        }
        .padding(.leading, -16)
        .padding(.bottom, Space._2xs)
    }

    /// Port of `PostRepliedTo.tsx`.
    private var repliedTo: some View {
        HStack(spacing: Space.xs) {
            Icon(.cornerDownRight, size: IconSize.xs, color: theme.textContrastMedium)
                .offset(y: -1)
            repliedToText
                .textStyle(size: FontSize.sm, leading: Leading.snug)
                .foregroundStyle(theme.textContrastMedium)
                .lineLimit(1)
        }
        .padding(.bottom, Space.xs)
    }

    private var repliedToText: some View {
        Group {
            if item.isParentBlocked {
                Text("Replied to a blocked post")
            } else if item.isParentNotFound {
                Text("Replied to a post")
            } else if let parent = item.parentAuthor, parent.did == container.accountDid {
                Text("Replied to you")
            } else if let parent = item.parentAuthor {
                Text("Replied to ") + Text(Names.displayNameOrHandle(displayName: parent.displayName, handle: parent.handle))
            }
        }
    }
}
