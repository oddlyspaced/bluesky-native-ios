import SwiftUI

/// Port of `src/screens/PostThread/index.tsx` (linear view).
struct ThreadScreen: View {
    @State var model: ThreadModel
    var context: AppContext

    @Environment(ShellState.self) private var shell
    @Environment(PostShadowStore.self) private var shadows
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader {
                HeaderIconButton(glyph: .back, label: "Go back") { dismiss() }
                    .padding(.leading, -3)
            } center: {
                Text("Post")
                    .textStyle(size: FontSize.lg, weight: FontWeight.semiBold, leading: Leading.tight)
                    .foregroundStyle(Theme.text)
            } trailing: {
                HeaderIconButton(glyph: .sliders, iconSize: 18, label: "Thread options") {
                    shell.notInShowcase = NotInShowcaseItem(title: "Thread options")
                }
            }
            ScrollView {
                LazyVStack(spacing: 0) {
                    content
                }
                .padding(.bottom, 56)
            }
            .refreshable { await model.load() }
        }
        .overlay(alignment: .bottom) {
            if model.status == .loaded {
                ThreadComposePrompt {
                    shell.notInShowcase = NotInShowcaseItem(title: "Reply")
                }
            }
        }
        .background(Theme.background)
        .toolbar(.hidden, for: .navigationBar)
        .task { await model.load() }
        .onAppear { shell.hidesBottomBarBorder = true }
        .onDisappear { shell.hidesBottomBarBorder = false }
    }

    @ViewBuilder
    private var content: some View {
        switch model.status {
        case .loading:
            FeedLoadingPlaceholder()
        case .notFound:
            FeedErrorRow(message: "Post not found") {}
        case .failed(let message):
            FeedErrorRow(message: message) { Task { await model.load() } }
        case .loaded:
            ForEach(model.rows) { row in
                switch row.kind {
                case .anchor:
                    ThreadAnchorView(row: row, post: shadows.apply(to: row.post), interactions: context.interactions)
                case .parent, .reply:
                    ThreadPostView(row: row, post: shadows.apply(to: row.post), interactions: context.interactions)
                }
            }
        }
    }
}

/// Port of `ThreadItemAnchor.tsx`: the expanded post.
struct ThreadAnchorView: View {
    var row: ThreadRow
    var post: PostView
    var interactions: PostInteractions

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if row.showsParentLine {
                Theme.borderContrastLow.frame(width: 2, height: 12)
                    .frame(width: 42)
                    .padding(.bottom, 4)
            }
            HStack(spacing: 12) {
                UserAvatar(url: post.author.avatar, size: 42)
                VStack(alignment: .leading, spacing: 0) {
                    Text(post.author.displayName ?? post.author.handle)
                        .textStyle(size: FontSize.lg, weight: FontWeight.semiBold, leading: 22)
                        .foregroundStyle(Theme.text)
                        .lineLimit(1)
                    Text("@\(post.author.handle)")
                        .textStyle(size: FontSize.md, leading: Leading.snug)
                        .foregroundStyle(Theme.textContrastMedium)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.bottom, 12)

            if !post.record.text.isEmpty {
                PostText(text: post.record.text, size: FontSize.lg)
                    .padding(.top, 1)
            }

            HStack(spacing: 8) {
                Text(ATDate.parse(post.indexedAt).map { NiceDate.dotSeparated($0) } ?? "")
                    .textStyle(size: FontSize.sm, leading: Leading.snug)
                    .foregroundStyle(Theme.textContrastMedium)
                if row.kind == .anchor && post.record.reply == nil {
                    HStack(spacing: 4) {
                        Icon(.globe, size: 16, color: Palette.contrast400)
                        Text("Everybody can reply")
                            .textStyle(size: FontSize.sm, leading: 15)
                            .foregroundStyle(Theme.textContrastMedium)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Who can reply")
                }
            }
            .padding(.top, 12)

            PostControls(post: post, big: true, interactions: interactions)
                .padding(.leading, -5)
                .padding(.bottom, 2)
        }
        .padding(.horizontal, 16)
        .padding(.top, row.showsParentLine ? 0 : 16)
        .padding(.bottom, 8)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("postThreadItem-by-\(post.author.handle)")
    }
}

/// Port of `ThreadItemPost.tsx`: a reply or ancestor row.
struct ThreadPostView: View {
    var row: ThreadRow
    var post: PostView
    var interactions: PostInteractions

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                ZStack {
                    if row.showsParentLine {
                        Theme.borderContrastLow.frame(width: 2).padding(.bottom, 4)
                    }
                }
                // RN: a 12pt spacer row; measured about 11pt in the RN screenshot.
                .frame(width: 42, height: 11)
                Spacer()
            }
            HStack(alignment: .top, spacing: 12) {
                VStack(spacing: 0) {
                    UserAvatar(url: post.author.avatar, size: 42)
                }
                VStack(alignment: .leading, spacing: 0) {
                    PostMeta(post: post)
                    if !post.record.text.isEmpty {
                        PostText(text: post.record.text)
                            .padding(.bottom, 2)
                    }
                    PostControls(post: post, big: false, interactions: interactions)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, row.showsChildLine ? 0 : 8)
        .background(alignment: .topLeading) {
            if row.showsChildLine {
                Theme.borderContrastLow
                    .frame(width: 2)
                    .padding(.top, 12 + 42 + 4)
                    .padding(.leading, 16 + 20)
            }
        }
        .overlay(alignment: .top) {
            if !row.showsParentLine { HairlineDivider() }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("postThreadItem-by-\(post.author.handle)")
    }
}

/// Port of `ThreadComposePrompt.tsx`: the "Write your reply" pill above the tab bar.
struct ThreadComposePrompt: View {
    var onCompose: () -> Void

    @Environment(SessionStore.self) private var session

    var body: some View {
        Button(action: onCompose) {
            HStack(spacing: 8) {
                UserAvatar(url: nil, size: 24, showsBorder: false)
                Text("Write your reply")
                    .textStyle(size: FontSize.md, leading: Leading.snug)
                    .foregroundStyle(Theme.textContrastMedium)
                Spacer(minLength: 0)
            }
            .padding(8)
            .background(Theme.bgContrast25, in: Capsule())
            .overlay { Capsule().strokeBorder(Theme.borderContrastLow, lineWidth: Hairline.width) }
            .contentShape(Capsule())
        }
        .buttonStyle(PressScaleStyle(scale: 0.98))
        .padding(.horizontal, 8)
        .padding(.bottom, 2)
        .background {
            LinearGradient(stops: [.init(color: Theme.background.opacity(0), location: 0.15),
                                   .init(color: Theme.background, location: 0.4)],
                           startPoint: .top, endPoint: .bottom)
        }
        .accessibilityLabel("Compose reply")
        .accessibilityHint("Opens composer")
    }
}
