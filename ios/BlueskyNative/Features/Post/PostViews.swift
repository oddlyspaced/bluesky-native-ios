import SwiftUI

/// Port of `src/view/com/util/PostMeta.tsx`: display name (600), NBSP + `@handle`, and
/// "· " + short relative time, all text_md with `leading_tight` (17pt), then `pb_xs`.
///
/// On native the name, handle and time are not links (`WebOnlyInlineLinkText`); a tap falls
/// through to the row.
struct PostMeta: View {
    var post: PostView

    @Environment(\.theme) private var theme
    @Environment(MinuteTicker.self) private var ticker

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 0) {
            Text(Names.postMetaName(displayName: post.author.displayName, handle: post.author.handle))
                .font(InterFont.font(size: scaledSize, weight: FontWeight.semiBold))
                .foregroundStyle(theme.text)
                .lineLimit(1)
                .layoutPriority(1)
            Text("\u{00A0}" + Names.sanitizeHandle(post.author.handle, prefix: "@"))
                .foregroundStyle(theme.textContrastMedium)
                .lineLimit(1)
            Text("· \(relativeTime)")
                .foregroundStyle(theme.textContrastMedium)
                .lineLimit(1)
                .fixedSize()
                .padding(.leading, Space.xs)
                .layoutPriority(2)
                .accessibilityLabel(post.indexedDate.map { NiceDate.long($0) } ?? "")
            Spacer(minLength: 0)
        }
        .textStyle(size: FontSize.md, leading: Leading.tight)
        .padding(.bottom, Space.xs)
    }

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var scaledSize: CGFloat {
        FontSize.md * FontScale.multiplier(for: dynamicTypeSize)
    }

    private var relativeTime: String {
        guard let date = post.indexedDate else { return "" }
        return TimeAgo.short(from: date, to: ticker.now)
    }
}

/// Post text with RN's long-text rule: 25 or more newlines clamp the text to 25 lines and
/// show "Show more" (`PostFeedItem.tsx:496-548`, `ShowMoreTextButton.tsx`). The rule is read
/// once when the row appears.
struct PostText: View {
    var post: PostView
    var size: CGFloat = FontSize.md
    /// The thread anchor never truncates.
    var truncates = true
    var testID: String? = "postText"
    /// RN passes `selectable` on the thread anchor only (`ThreadItemAnchor.tsx:405-407`).
    var selectable = false

    @Environment(\.theme) private var theme
    @State private var expanded = false

    var body: some View {
        let limited = truncates && !expanded && RichTextRules.countLines(post.record.text) >= RichTextRules.maxPostLines
        VStack(alignment: .leading, spacing: 0) {
            RichTextView(text: post.record.text, facets: post.record.facets, size: size,
                         lineLimit: limited ? RichTextRules.maxPostLines : nil, testID: testID,
                         selectable: selectable)
            if limited {
                Button {
                    withAnimation(.easeInOut) { expanded = true }
                } label: {
                    Text("Show more")
                        .textStyle(size: size, leading: Leading.snug)
                        .foregroundStyle(theme.textLink)
                        .padding(.bottom, size / 3)
                }
                .buttonStyle(PressScaleStyle(scale: 1))
                .accessibilityLabel("Expand post text")
            }
        }
    }
}

/// Port of `src/components/PostControls/index.tsx` with `PostControlButton`, `RepostButton`,
/// `AnimatedLikeIcon` and `CountWheel`.
struct PostControls: View {
    /// The shadowed post to render.
    var post: PostView
    /// The server copy, used as the shadow's base.
    var serverPost: PostView
    var big: Bool
    var context: PostEventContext
    var viaRepost: StrongRef?

    @Environment(AccountContainer.self) private var container
    @Environment(\.theme) private var theme
    @Environment(\.haptics) private var haptics
    @State private var showsRepostMenu = false
    @State private var likeToggled = false

    private var iconSize: CGFloat { big ? 22 : 18 }
    private var liked: Bool { post.viewer?.like != nil }
    private var reposted: Bool { post.viewer?.repost != nil }
    private var replyDisabled: Bool { post.viewer?.replyDisabled == true }
    private var isBlocked: Bool {
        let viewer = post.author.viewer
        return viewer?.blocking != nil || viewer?.blockedBy == true || viewer?.blockingByList != nil
    }

    var body: some View {
        HStack(spacing: Space.md) {
            HStack(spacing: 0) {
                cell {
                    controlButton(glyph: .reply, color: theme.control, count: post.replyCount ?? 0, active: false,
                                  id: "replyBtn", countID: nil,
                                  label: "Reply (\(Plural.count(post.replyCount ?? 0, one: "reply", other: "replies")))") {
                        onReply()
                    }
                    .opacity(replyDisabled ? 0.6 : 1)
                    .disabled(replyDisabled)
                }
                cell {
                    let reposts = (post.repostCount ?? 0) + (post.quoteCount ?? 0)
                    controlButton(glyph: .repost, color: reposted ? theme.repostActive : theme.control,
                                  count: reposts, active: reposted, id: "repostBtn", countID: "repostCount",
                                  label: "\(reposted ? "Undo repost" : "Repost") (\(Plural.count(reposts, one: "repost", other: "reposts")))") {
                        haptics.play(.light)
                        showsRepostMenu = true
                    }
                }
                cell {
                    likeButton
                }
            }
            .padding(.leading, big ? -2 : -6)
            .frame(maxWidth: Layout.controlsMaxWidth, alignment: .leading)

            HStack(spacing: big ? Space.sm : Space.xs) {
                controlButton(glyph: .bookmark, color: theme.control, count: 0, active: false,
                              id: "postBookmarkBtn", countID: nil, label: "Add to saved posts") {
                    container.shell.notInShowcase = NotInShowcaseItem(title: "Saved posts")
                }
                controlButton(glyph: .share, color: theme.control, count: 0, active: false,
                              id: "postShareBtn", countID: nil, label: "Open share menu") {
                    var props = context.props(for: post)
                    props["postContext"] = .string(big ? "thread" : "feed")
                    container.analytics.metric("post:share", props)
                    container.shell.notInShowcase = NotInShowcaseItem(title: "Share")
                }
                controlButton(glyph: .more, color: theme.control, count: 0, active: false,
                              id: "postDropdownBtn", countID: nil, label: "Open post options menu") {
                    container.shell.notInShowcase = NotInShowcaseItem(title: "Post options")
                }
            }
        }
        .padding(.top, big ? 0 : Space._2xs)
        .sheet(isPresented: $showsRepostMenu) {
            RepostMenu(reposted: reposted, embeddingDisabled: post.viewer?.embeddingDisabled == true) { choice in
                showsRepostMenu = false
                switch choice {
                case .repost: onRepost()
                case .quote: onQuote()
                }
            }
            .presentationDetents([.height(236)])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(Radius.lg)
        }
    }

    private var likeButton: some View {
        Button {
            guard !isBlocked else {
                container.shell.showToast("Cannot interact with a blocked user", kind: .warning)
                return
            }
            haptics.play(.light)
            likeToggled = true
            container.interactions.toggleLike(serverPost, via: viaRepost, context: context)
        } label: {
            HStack(spacing: Space.xs) {
                AnimatedLikeIcon(liked: liked, size: iconSize, offColor: theme.control, likeColor: theme.like)
                CountWheel(count: post.likeCount ?? 0, isOn: liked, hasBeenToggled: likeToggled,
                           size: big ? FontSize.md : FontSize.sm, color: liked ? theme.like : theme.control)
                    .accessibilityIdentifier("likeCount")
            }
            .padding(Layout.controlPadding)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleStyle(scale: 1))
        .accessibilityLabel("\(liked ? "Unlike" : "Like") (\(Plural.count(post.likeCount ?? 0, one: "like", other: "likes")))")
        .accessibilityIdentifier("likeBtn")
    }

    private func onReply() {
        guard !replyDisabled else { return }
        haptics.play(.light)
        container.analytics.metric("post:clickReply", context.props(for: post))
        container.shell.notInShowcase = NotInShowcaseItem(title: "Reply")
    }

    private func onRepost() {
        guard !isBlocked else {
            container.shell.showToast("Cannot interact with a blocked user", kind: .warning)
            return
        }
        if !reposted { haptics.play(.medium) }
        container.interactions.toggleRepost(serverPost, via: viaRepost, context: context)
    }

    private func onQuote() {
        guard !isBlocked else {
            container.shell.showToast("Cannot interact with a blocked user", kind: .warning)
            return
        }
        haptics.play(.medium)
        container.analytics.metric("post:clickQuotePost", context.props(for: post))
        container.shell.notInShowcase = NotInShowcaseItem(title: "Quote post")
    }

    private func cell(@ViewBuilder _ content: () -> some View) -> some View {
        content().frame(maxWidth: .infinity, alignment: .leading)
    }

    private func controlButton(glyph: IconGlyph, color: Color, count: Int, active: Bool, id: String,
                               countID: String?, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Space.xs) {
                Icon(glyph, size: iconSize, color: color)
                if count > 0 {
                    Text(CountFormat.postStat(count))
                        .textStyle(size: big ? FontSize.md : FontSize.sm,
                                   weight: active ? FontWeight.semiBold : FontWeight.normal,
                                   leading: Leading.snug)
                        .foregroundStyle(color)
                        .fixedSize()
                        .accessibilityIdentifier(countID ?? "")
                }
            }
            .padding(Layout.controlPadding)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleStyle(scale: 1))
        .accessibilityLabel(label)
        .accessibilityIdentifier(id)
    }
}

extension CountFormat {
    /// `useFormatPostStatCount` (`src/components/PostControls/util.ts:9-23`): compact, truncated,
    /// one decimal below 10,000 and none from 10,000.
    static func postStat(_ count: Int, locale: Locale = AppLocale.formatting) -> String {
        format(count, locale: locale)
    }
}

/// Port of `AnimatedLikeIcon` (`src/components/PostControls/custom-animations/LikeIcon.tsx`).
///
/// On the change to liked (not on first render, not with Reduce Motion): a 300 ms keyframe
/// scale on the filled heart (1, 0.7 at 10%, 1.2 at 40%, 1) and two expanding circles.
struct AnimatedLikeIcon: View {
    var liked: Bool
    var size: CGFloat
    var offColor: Color
    var likeColor: Color

    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var trigger = 0

    private struct Frame {
        var heartScale: CGFloat = 1
        var pinkOpacity: Double = 0
        var pinkScale: CGFloat = 0
        var maskOpacity: Double = 0
        var maskScale: CGFloat = 0
    }

    var body: some View {
        ZStack {
            if liked {
                Color.clear
                    .keyframeAnimator(initialValue: Frame(), trigger: trigger) { _, frame in
                        ZStack {
                            Circle().fill(likeColor).frame(width: size, height: size)
                                .scaleEffect(frame.pinkScale).opacity(frame.pinkOpacity)
                            Circle().fill(theme.bg).frame(width: size, height: size)
                                .scaleEffect(frame.maskScale).opacity(frame.maskOpacity)
                            Icon(.heart, size: size, color: likeColor, filled: true)
                                .scaleEffect(frame.heartScale)
                        }
                    } keyframes: { _ in
                        KeyframeTrack(\.heartScale) {
                            LinearKeyframe(0.7, duration: 0.03)
                            LinearKeyframe(1.2, duration: 0.09)
                            LinearKeyframe(1.0, duration: 0.18)
                        }
                        KeyframeTrack(\.pinkOpacity) {
                            LinearKeyframe(0.4, duration: 0.03)
                            LinearKeyframe(0.4, duration: 0.255)
                            LinearKeyframe(0, duration: 0.015)
                        }
                        KeyframeTrack(\.pinkScale) {
                            LinearKeyframe(1.5, duration: 0.12)
                            LinearKeyframe(1.5, duration: 0.18)
                            LinearKeyframe(0, duration: 0.001)
                        }
                        KeyframeTrack(\.maskOpacity) {
                            LinearKeyframe(1, duration: 0.03)
                            LinearKeyframe(1, duration: 0.255)
                            LinearKeyframe(0, duration: 0.015)
                        }
                        KeyframeTrack(\.maskScale) {
                            LinearKeyframe(0, duration: 0.12)
                            LinearKeyframe(1.5, duration: 0.18)
                            LinearKeyframe(0, duration: 0.001)
                        }
                    }
            } else {
                Icon(.heart, size: size, color: offColor)
            }
        }
        .frame(width: size, height: size)
        .onChange(of: liked) { _, isLiked in
            if isLiked && !reduceMotion { trigger += 1 }
        }
    }
}

/// Port of `CountWheel` (`src/components/PostControls/custom-animations/CountWheel.tsx`).
///
/// When `shouldRoll` holds after a user toggle, the new number slides in from 18pt below
/// (like) or above (unlike) over 400 ms with ease-out cubic, and the old number slides out.
struct CountWheel: View {
    var count: Int
    var isOn: Bool
    var hasBeenToggled: Bool
    var size: CGFloat
    var color: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var exiting: Int?
    @State private var progress: CGFloat = 1
    @State private var direction: CGFloat = 1

    private static let distance: CGFloat = 18

    /// `shouldRoll` (`PostControls/util.ts`).
    static func shouldRoll(count: Int, isOn: Bool) -> Bool {
        if !isOn && count == 0 { return true }
        if count > 1 && count < 1000 { return true }
        if count > 0 {
            if isOn && count % 100 == 0 { return true }
            if !isOn && count % 100 == 99 { return true }
        }
        return false
    }

    var body: some View {
        ZStack(alignment: .leading) {
            if count > 0 {
                label(count)
                    .offset(y: direction * Self.distance * (1 - progress))
                    .opacity(Double(progress))
            }
            if let exiting, count > 1 || !isOn {
                label(exiting)
                    .offset(y: -direction * Self.distance * progress)
                    .opacity(Double(1 - progress))
            }
        }
        .onChange(of: count) { old, new in
            guard hasBeenToggled, !reduceMotion, Self.shouldRoll(count: new, isOn: isOn) else { return }
            exiting = old
            direction = isOn ? 1 : -1
            progress = 0
            withAnimation(.timingCurve(0.33, 1, 0.68, 1, duration: 0.4)) {
                progress = 1
            } completion: {
                exiting = nil
            }
        }
    }

    private func label(_ value: Int) -> some View {
        Text(CountFormat.postStat(value))
            .textStyle(size: size, weight: isOn ? FontWeight.semiBold : FontWeight.normal, leading: Leading.snug)
            .foregroundStyle(color)
            .fixedSize()
    }
}

/// Port of the native repost dialog in `RepostButton.tsx:112-216`.
struct RepostMenu: View {
    enum Choice { case repost, quote }

    var reposted: Bool
    var embeddingDisabled: Bool
    var onChoose: (Choice) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: Space.xl) {
            VStack(spacing: Space.xs) {
                option(glyph: .repost, title: reposted ? "Remove repost" : "Repost", enabled: true,
                       id: "repostDropdownRepostBtn") {
                    onChoose(.repost)
                }
                option(glyph: .quote, title: embeddingDisabled ? "Quote posts disabled" : "Quote post",
                       enabled: !embeddingDisabled, id: "quoteBtn") {
                    onChoose(.quote)
                }
            }
            DSButton(title: "Cancel", accessibilityLabel: "Cancel quote post", color: .secondary, size: .large,
                     fullWidth: true) {
                dismiss()
            }
        }
        .padding(.horizontal, Space.xl)
        .padding(.top, Space._3xl)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(theme.bg)
        .accessibilityLabel("Repost or quote post")
    }

    private func option(glyph: IconGlyph, title: String, enabled: Bool, id: String,
                        action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Space.sm) {
                Icon(glyph, size: IconSize.lg, color: enabled ? theme.palette.primary500 : theme.textContrastLow)
                Text(title)
                    .textStyle(size: FontSize.xl, weight: FontWeight.semiBold, leading: Leading.snug)
                    .foregroundStyle(enabled ? theme.text : theme.textContrastLow)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Space.md)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleStyle(scale: 1))
        .disabled(!enabled)
        .accessibilityLabel(title)
        .accessibilityIdentifier(id)
    }
}
