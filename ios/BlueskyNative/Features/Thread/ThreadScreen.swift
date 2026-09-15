import SwiftUI
import UIKit

/// Port of `src/screens/PostThread/index.tsx` (linear view).
///
/// RN has no pull to refresh on this screen (review finding P18), so neither does the port.
struct ThreadScreen: View {
    var model: ThreadModel

    @Environment(AccountContainer.self) private var container
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @State private var windowHeight: CGFloat = 0
    @State private var scrolledToAnchor = false

    /// `OUTER_SPACE` (`src/screens/PostThread/const.ts`).
    static let outerSpace: CGFloat = 16

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader {
                HeaderIconButton(glyph: .back, label: "Go back") { dismiss() }
                    .padding(.leading, -3)
            } center: {
                HeaderTitle(title: "Post")
            } trailing: {
                HeaderIconButton(glyph: .sliders, iconSize: IconSize.md, label: "Thread options") {
                    container.analytics.metric("thread:click:headerMenuOpen")
                    container.shell.notInShowcase = NotInShowcaseItem(title: "Thread options")
                }
            }
            switch model.status {
            case .failed(let title, let message):
                ThreadErrorView(title: title, message: message) { Task { await model.retry() } }
                Spacer(minLength: 0)
            case .loading, .loaded:
                list
            }
        }
        .background(theme.bg)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { windowHeight = $0 }
        .toolbar(.hidden, for: .navigationBar)
        .background(InteractivePopEnabler())
        .task {
            model.setPlaceholder(container.cachedPost(uri: model.anchorUri))
            await model.loadIfNeeded()
        }
    }

    private var list: some View {
        let items = model.items
        let tombstoneOnly = items.count == 1 && items[0].isTombstone
        return ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(items) { item in
                        row(item)
                            .id(item.id)
                            // RN reports rows seen for 500 ms in index order (`List.onItemSeen`, N6).
                            .onAppear { model.itemAppeared(item) }
                            .onDisappear { model.itemDisappeared(item) }
                    }
                    if model.status == .loaded {
                        // `ListFooter`: the top border is the line under the last item.
                        Color.clear
                            .frame(height: model.hasParents ? max(180, windowHeight - 200) : 180)
                            .overlay(alignment: .top) { if !tombstoneOnly { HairlineDivider() } }
                    }
                }
            }
            .onChange(of: model.status) { _, status in
                // RN renders parents after the anchor lays out and keeps the anchor at the top.
                guard status == .loaded, model.hasParents, !scrolledToAnchor,
                      let anchor = model.anchor else { return }
                scrolledToAnchor = true
                proxy.scrollTo(anchor.uri, anchor: .top)
            }
        }
    }

    @ViewBuilder
    private func row(_ item: ThreadListItem) -> some View {
        let context = PostEventContext.threadItem(model.feedDescriptor)
        switch item {
        case .post(_, let depth, let value, let isBlurred, let ui):
            let post = container.shadows.apply(to: value.post)
            if depth == 0 {
                ThreadAnchorView(post: post, serverPost: value.post, context: context)
            } else {
                ThreadPostView(post: post, serverPost: value.post, ui: ui, topBorder: !ui.showParentReplyLine
                    && !(depth < 0 && isFirstItem(item)), isBlurred: isBlurred && !model.otherItemsVisible,
                               context: context)
            }
        case .noUnauthenticated(_, let depth, let ui):
            NoUnauthenticatedRow(isAnchor: depth == 0, ui: ui)
        case .notFound:
            ThreadTombstone(kind: .notFound)
        case .blocked:
            ThreadTombstone(kind: .blocked)
        case .readMore(let uri, _, let count):
            ThreadReadMoreRow(count: count) { container.router.openThread(uri: uri) }
        case .readMoreUp(let uri):
            ThreadReadMoreUpRow { container.router.openThread(uri: uri) }
        case .showOtherReplies:
            ShowOtherRepliesRow { Task { await model.showOtherReplies() } }
        case .anchorSkeleton:
            ThreadAnchorSkeleton()
        case .replySkeleton(let index):
            ThreadPostSkeleton(index: index)
        }
    }

    private func isFirstItem(_ item: ThreadListItem) -> Bool {
        model.items.first?.id == item.id
    }
}

extension AccountContainer {
    /// A post already loaded by another screen, used as the thread placeholder
    /// (RN reads the query cache, `queryCache.ts:213-243`).
    func cachedPost(uri: String) -> PostView? {
        for model in [loadedHomeFeed, profile.posts].compactMap({ $0 }) {
            for slice in model.slices {
                if let item = slice.items.first(where: { $0.post.uri == uri }) { return item.post }
            }
        }
        return nil
    }
}

/// Keeps the swipe-back gesture while the navigation bar is hidden (review finding P10).
struct InteractivePopEnabler: UIViewControllerRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIViewController(context: Context) -> UIViewController {
        let controller = Probe()
        controller.coordinator = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: UIViewController, context: Context) {}

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        weak var navigationController: UINavigationController?

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            (navigationController?.viewControllers.count ?? 0) > 1
        }
    }

    private final class Probe: UIViewController {
        var coordinator: Coordinator?

        override func didMove(toParent parent: UIViewController?) {
            super.didMove(toParent: parent)
            guard let navigationController = parent?.navigationController ?? navigationController else { return }
            coordinator?.navigationController = navigationController
            navigationController.interactivePopGestureRecognizer?.isEnabled = true
            navigationController.interactivePopGestureRecognizer?.delegate = coordinator
        }
    }
}

/// Port of `ThreadItemAnchor.tsx`: the expanded post.
struct ThreadAnchorView: View {
    var post: PostView
    var serverPost: PostView
    var context: PostEventContext

    @Environment(AccountContainer.self) private var container
    @Environment(\.theme) private var theme

    private var isRoot: Bool {
        (post.record.reply?.root.uri ?? post.uri) == post.uri
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !isRoot {
                HStack(spacing: 0) {
                    theme.borderContrastLow.frame(width: 2)
                        .frame(width: AvatarSize.post)
                        .padding(.bottom, Space.xs)
                    Spacer(minLength: 0)
                }
                .frame(height: 16)
            }
            HStack(spacing: Space.md) {
                Button {
                    if let event = ThreadModel.authorTapEvent(for: post, isAnchor: true, context: context) {
                        container.analytics.record(event)
                    }
                    container.router.openProfile(did: post.author.did)
                } label: {
                    UserAvatar(url: post.author.avatar, size: AvatarSize.post)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(Names.displayNameOrHandle(displayName: post.author.displayName, handle: post.author.handle))'s avatar")
                VStack(alignment: .leading, spacing: 0) {
                    Text(Names.displayNameOrHandle(displayName: post.author.displayName, handle: post.author.handle))
                        .textStyle(size: FontSize.lg, weight: FontWeight.semiBold, leading: Leading.snug)
                        .foregroundStyle(theme.text)
                        .lineLimit(1)
                    Text(Names.sanitizeHandle(post.author.handle, prefix: "@"))
                        .textStyle(size: FontSize.md, leading: Leading.snug)
                        .foregroundStyle(theme.textContrastMedium)
                        .lineLimit(1)
                }
                .accessibilityElement(children: .combine)
                Spacer(minLength: 0)
            }
            .padding(.bottom, Space.md)

            if !post.record.text.isEmpty {
                PostText(post: post, size: FontSize.lg, truncates: false, testID: nil, selectable: true)
                    .padding(.top, 1)
            }

            // `ExpandedPostDetails`: `flex_row align_center flex_wrap gap_sm`, so the who-can-reply
            // label wraps under the date at large text sizes.
            FlowLayout(rowSpacing: Space.sm, columnSpacing: Space.sm, centersRows: true) {
                Text(post.indexedDate.map { NiceDate.dotSeparated($0) } ?? "")
                    .textStyle(size: FontSize.sm, leading: Leading.snug)
                    .foregroundStyle(theme.textContrastMedium)
                if post.record.reply == nil {
                    WhoCanReplyButton(post: post)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, Space.md)

            if Self.showsStats(post) {
                ThreadStatsRow(post: post)
            }

            PostControls(post: post, serverPost: serverPost, big: true, context: context, viaRepost: nil)
                .padding(.leading, -5)
                .padding(.bottom, Space._2xs)
        }
        .padding(.horizontal, ThreadScreen.outerSpace)
        .padding(.top, isRoot ? Space.lg : 0)
        .padding(.bottom, Space.sm)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("postThreadItem-by-\(post.author.handle)")
    }

    /// "Show this section unless we're *sure* it has no engagement" (`ThreadItemAnchor.tsx:440-445`).
    static func showsStats(_ post: PostView) -> Bool {
        post.repostCount != 0 || post.likeCount != 0 || post.quoteCount != 0 || post.bookmarkCount != 0
    }
}

/// Engagement stats row (`ThreadItemAnchor.tsx:440-517`, `LikesStat.tsx`).
struct ThreadStatsRow: View {
    var post: PostView

    @Environment(AccountContainer.self) private var container
    @Environment(\.theme) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        FlowLayout(rowSpacing: Space.sm, columnSpacing: Space.lg) {
            if let reposts = post.repostCount, reposts != 0 {
                stat(reposts, one: "repost", other: "reposts", id: "repostCount-expanded",
                     label: "Reposts of this post") {
                    container.shell.notInShowcase = NotInShowcaseItem(title: "Reposted by")
                }
            }
            if let quotes = post.quoteCount, quotes != 0, post.viewer?.embeddingDisabled != true {
                stat(quotes, one: "quote", other: "quotes", id: "quoteCount-expanded", label: "Quotes of this post") {
                    container.shell.notInShowcase = NotInShowcaseItem(title: "Quotes")
                }
            }
            if let likes = post.likeCount, likes != 0 {
                stat(likes, one: "like", other: "likes", id: "likeCount-expanded", label: "Likes on this post") {
                    container.analytics.metric("post:likedBy:click")
                    container.shell.notInShowcase = NotInShowcaseItem(title: "Liked by")
                }
            }
            if let saves = post.bookmarkCount, saves != 0 {
                statText(saves, one: "save", other: "saves")
                    .accessibilityIdentifier("bookmarkCount-expanded")
            }
        }
        .padding(.vertical, Space.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .top) { HairlineDivider() }
        .padding(.top, Space.md)
    }

    private func stat(_ count: Int, one: String, other: String, id: String, label: String,
                      action: @escaping () -> Void) -> some View {
        Button(action: action) { statText(count, one: one, other: other) }
            .buttonStyle(PressScaleStyle(scale: 1))
            .accessibilityLabel(label)
            .accessibilityIdentifier(id)
    }

    private func statText(_ count: Int, one: String, other: String) -> some View {
        let fonts = ScaledFonts(multiplier: FontScale.multiplier(for: dynamicTypeSize))
        return (Text(CountFormat.postStat(count)).font(fonts.font(FontSize.md, FontWeight.semiBold))
            .foregroundStyle(theme.text)
            + Text(" " + Plural.word(count, one: one, other: other)).font(fonts.font(FontSize.md))
            .foregroundStyle(theme.textContrastMedium))
            .textStyle(size: FontSize.md, leading: Leading.snug)
            .lineLimit(1)
    }
}

/// A wrapping row layout, for RN `flex_row flex_wrap` with row and column gaps.
struct FlowLayout: SwiftUI.Layout {
    typealias Subviews = LayoutSubviews

    var rowSpacing: CGFloat
    var columnSpacing: CGFloat
    /// RN `align_center`: items of different heights are centred within their line.
    var centersRows = false

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let height = rows.reduce(0) { $0 + $1.height } + rowSpacing * CGFloat(max(0, rows.count - 1))
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                let dy = centersRows ? (row.height - size.height) / 2 : 0
                subviews[index].place(at: CGPoint(x: x, y: y + dy), proposal: ProposedViewSize(size))
                x += size.width + columnSpacing
            }
            y += row.height + rowSpacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = current.indices.isEmpty ? size.width : current.width + columnSpacing + size.width
            if needed > width, !current.indices.isEmpty {
                rows.append(current)
                current = Row()
            }
            current.width = current.indices.isEmpty ? size.width : current.width + columnSpacing + size.width
            current.height = max(current.height, size.height)
            current.indices.append(index)
        }
        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }
}

/// Port of `WhoCanReply.tsx` for the anchor.
struct WhoCanReplyButton: View {
    var post: PostView

    @Environment(AccountContainer.self) private var container
    @Environment(\.theme) private var theme

    private enum Setting { case everybody, nobody, some }

    private var setting: Setting {
        guard let allow = post.threadgate?.record?.allow else { return .everybody }
        return allow.isEmpty ? .nobody : .some
    }

    /// `getThreadAuthor`: the root post's author DID.
    private var isThreadAuthor: Bool {
        let rootUri = post.record.reply?.root.uri ?? post.uri
        return ATURI(rootUri)?.host == container.accountDid
    }

    var body: some View {
        let color = isThreadAuthor ? theme.palette.primary500 : theme.textContrastMedium
        Button {
            container.shell.notInShowcase = NotInShowcaseItem(title: "Who can reply")
        } label: {
            HStack(spacing: Space.xs) {
                Icon(glyph, size: IconSize.sm, color: isThreadAuthor ? theme.palette.primary500 : theme.palette.contrast400)
                Text(text)
                    .textStyle(size: FontSize.sm, leading: Leading.tight)
                    .foregroundStyle(color)
                if isThreadAuthor {
                    Icon(.chevronRight, size: 8, color: theme.palette.primary500).rotationEffect(.degrees(90))
                }
            }
        }
        .buttonStyle(PressScaleStyle(scale: 1))
        .accessibilityLabel(isThreadAuthor ? "Edit who can reply" : "Who can reply")
    }

    private var text: String {
        switch setting {
        case .everybody: "Everybody can reply"
        case .nobody: "Replies disabled"
        case .some: "Some people can reply"
        }
    }

    private var glyph: IconGlyph {
        switch setting {
        case .everybody: .globe
        case .nobody: .circleBan
        case .some: .group
        }
    }
}

/// Port of `ThreadItemPost.tsx`: a reply or ancestor row in the linear view.
struct ThreadPostView: View {
    var post: PostView
    var serverPost: PostView
    var ui: ThreadPostUI
    var topBorder: Bool
    var isBlurred: Bool
    var context: PostEventContext

    @Environment(AccountContainer.self) private var container
    @Environment(\.theme) private var theme
    @State private var revealed = false

    /// The 12pt row above every reply (`ThreadItemPost.tsx:162-187`).
    private static let parentLineRow: CGFloat = 12

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                ZStack {
                    if ui.showParentReplyLine {
                        theme.borderContrastLow.frame(width: 2).padding(.bottom, Space.xs)
                    }
                }
                .frame(width: AvatarSize.post, height: Self.parentLineRow)
                Spacer(minLength: 0)
            }
            if isBlurred && !revealed {
                hiddenRow
            } else {
                content
            }
        }
        .padding(.horizontal, ThreadScreen.outerSpace)
        .padding(.bottom, ui.showChildReplyLine || ui.precedesChildReadMore ? 0 : Space.sm)
        .background(alignment: .topLeading) {
            if ui.showChildReplyLine || ui.precedesChildReadMore {
                theme.borderContrastLow
                    .frame(width: 2)
                    .padding(.top, Self.parentLineRow + AvatarSize.post + Space.xs)
                    .padding(.leading, ThreadScreen.outerSpace + (AvatarSize.post - 2) / 2)
            }
        }
        .overlay(alignment: .top) {
            if topBorder { HairlineDivider() }
        }
        .contentShape(Rectangle())
        .onTapGesture { container.router.openThread(uri: post.uri, feedDescriptor: context.feedDescriptor) }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("postThreadItem-by-\(post.author.handle)")
    }

    private var content: some View {
        HStack(alignment: .top, spacing: Space.md) {
            Button {
                // Reply and parent avatars log no event in RN (review finding N1).
                if let event = ThreadModel.authorTapEvent(for: post, isAnchor: false, context: context) {
                    container.analytics.record(event)
                }
                container.router.openProfile(did: post.author.did)
            } label: {
                UserAvatar(url: post.author.avatar, size: AvatarSize.post)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(Names.postMetaName(displayName: post.author.displayName, handle: post.author.handle))'s avatar")
            VStack(alignment: .leading, spacing: 0) {
                PostMeta(post: post)
                if !post.record.text.isEmpty {
                    PostText(post: post, testID: nil)
                        .padding(.bottom, Space._2xs)
                }
                PostControls(post: post, serverPost: serverPost, big: false, context: context, viaRepost: nil)
            }
        }
    }

    /// `PostHider` collapsed row.
    private var hiddenRow: some View {
        HStack(spacing: Space.sm) {
            Icon(.eyeSlash, size: IconSize.md, color: theme.textContrastMedium)
                .frame(width: AvatarSize.post, height: AvatarSize.post)
                .background(theme.bgContrast25, in: Circle())
                .padding(.trailing, Space.xs)
            Text("Hidden")
                .textStyle(size: FontSize.md, leading: Leading.snug)
                .foregroundStyle(theme.textContrastMedium)
                .lineLimit(1)
            Spacer(minLength: 0)
            Button("Show") { revealed = true }
                .textStyle(size: FontSize.md, leading: Leading.snug)
                .foregroundStyle(theme.palette.primary500)
        }
        .padding(.vertical, Space.md)
        .padding(.trailing, Space._2xs)
    }
}

/// Port of `ThreadItemPostTombstone.tsx`.
struct ThreadTombstone: View {
    enum Kind { case notFound, blocked }

    var kind: Kind
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 0) {
            Icon(kind == .blocked ? .personX : .trash, size: IconSize.md, color: theme.textContrastMedium)
                .frame(width: AvatarSize.post)
            Text(kind == .blocked ? "Post blocked" : "Post not found")
                .textStyle(size: FontSize.md, weight: FontWeight.semiBold, leading: Leading.snug)
                .foregroundStyle(theme.textContrastMedium)
            Spacer(minLength: 0)
        }
        .padding(.vertical, ThreadScreen.outerSpace / 1.2)
        .background(theme.bgContrast25, in: RoundedRectangle(cornerRadius: Radius.sm))
        .padding(.horizontal, ThreadScreen.outerSpace)
        .padding(.top, ThreadScreen.outerSpace / 1.2)
        .padding(.bottom, Space.xs)
        .accessibilityElement(children: .combine)
    }
}

/// Port of `ThreadItemPostNoUnauthenticated.tsx` and the anchor variant.
struct NoUnauthenticatedRow: View {
    var isAnchor: Bool
    var ui: ThreadPostUI
    @Environment(\.theme) private var theme

    private static let copy = "This author has chosen to make their posts visible only to people who are signed in."

    var body: some View {
        HStack(spacing: Space.md) {
            Icon(.lock, size: IconSize.md, color: theme.textContrastMedium)
                .frame(width: AvatarSize.post, height: AvatarSize.post)
                .background(theme.bgContrast25, in: Circle())
            Text(Self.copy)
                .textStyle(size: isAnchor ? FontSize.xl : FontSize.md, leading: Leading.snug, italic: true)
                .foregroundStyle(theme.textContrastMedium)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(isAnchor ? Space.lg : 0)
        .padding(.horizontal, isAnchor ? 0 : ThreadScreen.outerSpace)
        .padding(.vertical, isAnchor ? 0 : Space.md)
    }
}

/// Port of `ThreadItemReadMore.tsx` (linear).
struct ThreadReadMoreRow: View {
    var count: Int
    var action: () -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            UnevenRoundedRectangle(bottomLeadingRadius: Radius.sm)
                .strokeBorder(theme.borderContrastLow, lineWidth: 2)
                .mask(alignment: .bottomLeading) { Rectangle().padding(.top, 0).padding(.trailing, 2) }
                .frame(width: AvatarSize.post / 2 + 10, height: 18)
                .padding(.leading, (AvatarSize.post - 2) / 2 + ThreadScreen.outerSpace)
            Button(action: action) {
                HStack(spacing: Space.xs) {
                    Icon(.circlePlus, size: 18, color: theme.textContrastLow)
                    Text("Read \(Plural.count(count, one: "more reply", other: "more replies"))")
                        .textStyle(size: FontSize.sm, leading: Leading.snug)
                        .foregroundStyle(theme.textContrastMedium)
                }
                .padding(.top, Space.sm)
                .padding(.bottom, Space.md)
            }
            .buttonStyle(PressScaleStyle(scale: 1))
            .accessibilityLabel("Read more replies")
            Spacer(minLength: 0)
        }
    }
}

/// Port of `ThreadItemReadMoreUp.tsx`.
struct ThreadReadMoreUpRow: View {
    var action: () -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: Space.xs) {
                HStack(spacing: Space.md) {
                    Icon(.arrowTopCircle, size: IconSize.lg, color: theme.textContrastLow)
                        .frame(width: AvatarSize.post)
                    Text("Continue thread...")
                        .textStyle(size: FontSize.sm, leading: Leading.snug)
                        .foregroundStyle(theme.textContrastMedium)
                }
                theme.borderContrastLow.frame(width: 2, height: Space.sm)
                    .frame(width: AvatarSize.post)
                    .padding(.top, Space.xs)
            }
            .padding(.top, Space.lg)
            .padding(.horizontal, ThreadScreen.outerSpace)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(PressScaleStyle(scale: 1))
        .accessibilityLabel("Continue thread")
    }
}

/// Port of `ThreadItemShowOtherReplies.tsx`.
struct ShowOtherRepliesRow: View {
    var action: () -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: action) {
            HStack(spacing: Space.sm) {
                Icon(.eyeSlash, size: IconSize.sm, color: theme.textContrastMedium)
                    .frame(width: 26, height: 26)
                    .background(theme.bgContrast25, in: Circle())
                    .padding(.trailing, Space.xs)
                Text("Show more replies")
                    .textStyle(size: FontSize.sm, leading: Leading.snug)
                    .foregroundStyle(theme.textContrastMedium)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.vertical, Space.lg)
            .padding(.horizontal, Space.xl)
            .background(theme.bg)
            .overlay(alignment: .top) { HairlineDivider() }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleStyle(scale: 1))
        .accessibilityLabel("Show more replies")
    }
}

/// Port of `ThreadError.tsx`.
struct ThreadErrorView: View {
    var title: String
    var message: String
    var retry: () -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: Space.xl) {
            VStack(spacing: Space.xs) {
                Text(title)
                    .textStyle(size: FontSize.lg, weight: FontWeight.semiBold, leading: Leading.snug)
                    .foregroundStyle(theme.text)
                    .multilineTextAlignment(.center)
                Text(message)
                    .textStyle(size: FontSize.sm, leading: Leading.snug)
                    .foregroundStyle(theme.textContrastMedium)
                    .multilineTextAlignment(.center)
            }
            DSButton(title: "Retry", color: .secondaryInverted, size: .small, icon: .rotateCounterClockwise,
                     iconPosition: .trailing, action: retry)
        }
        .frame(maxWidth: 260)
        .padding(ThreadScreen.outerSpace)
        .padding(.top, Space._4xl - ThreadScreen.outerSpace)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("threadErrorView")
    }
}

/// `ThreadItemAnchorSkeleton` (`ThreadItemAnchor.tsx:679-701`).
struct ThreadAnchorSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            HStack(spacing: Space.md) {
                Skeleton.Circle(size: AvatarSize.post)
                VStack(alignment: .leading, spacing: 0) {
                    Skeleton.TextBar(lineHeight: 22, widthFraction: 0.2)
                    Skeleton.TextBar(lineHeight: 20, widthFraction: 0.4, blend: true)
                }
            }
            Skeleton.TextBar(lineHeight: 24, widthFraction: 1)
            Skeleton.TextBar(lineHeight: 24, widthFraction: 0.6)
            Skeleton.TextBar(lineHeight: 17, widthFraction: 0.5)
            Color.clear.frame(height: 32)
        }
        .padding(Space.lg)
        .accessibilityLabel("Loading")
    }
}

/// `ThreadItemPostSkeleton` (`ThreadItemPost.tsx:410-443`).
struct ThreadPostSkeleton: View {
    var index: Int

    var body: some View {
        HStack(alignment: .top, spacing: Space.md) {
            Skeleton.Circle(size: AvatarSize.post)
            VStack(alignment: .leading, spacing: Space.xs) {
                HStack(spacing: Space.sm) {
                    Skeleton.TextBar(lineHeight: 20, widthFraction: 0.2)
                    Skeleton.TextBar(lineHeight: 20, widthFraction: 0.3, blend: true)
                }
                if index % 2 == 0 {
                    Skeleton.TextBar(lineHeight: 20, widthFraction: 1, blend: true)
                    Skeleton.TextBar(lineHeight: 20, widthFraction: 0.6, blend: true)
                } else {
                    Skeleton.TextBar(lineHeight: 20, widthFraction: 0.6, blend: true)
                }
                Color.clear.frame(height: 28)
            }
        }
        .padding(.horizontal, ThreadScreen.outerSpace)
        .padding(.vertical, ThreadScreen.outerSpace / 1.5)
    }
}

/// Port of `ThreadComposePrompt.tsx`: the "Write your reply" pill above the tab bar.
struct ThreadComposePrompt: View {
    var avatarURL: URL?
    var onCompose: () -> Void

    @Environment(\.theme) private var theme
    @Environment(\.haptics) private var haptics
    @Environment(\.pixelLength) private var pixelLength

    var body: some View {
        HStack(spacing: Space.sm) {
            UserAvatar(url: avatarURL, size: AvatarSize.composePrompt, showsBorder: false)
            Text("Write your reply")
                .textStyle(size: FontSize.md, leading: Leading.snug)
                .foregroundStyle(theme.textContrastMedium)
            Spacer(minLength: 0)
        }
        .padding(Space.sm)
        .background(theme.bgContrast25, in: Capsule())
        .overlay { Capsule().strokeBorder(theme.borderContrastLow, lineWidth: pixelLength) }
        .contentShape(Capsule())
        .onTapGesture {
            onCompose()
            haptics.play(.light)
        }
        .onLongPressGesture {
            onCompose()
            haptics.play(.heavy)
        }
        .padding(.horizontal, Space.sm)
        .padding(.bottom, Space._2xs)
        .background {
            LinearGradient(stops: [.init(color: theme.bg.opacity(0), location: 0.15),
                                   .init(color: theme.bg, location: 0.4)],
                           startPoint: .top, endPoint: .bottom)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("Compose reply")
        .accessibilityHint("Opens composer")
        .accessibilityAction { onCompose() }
    }
}
