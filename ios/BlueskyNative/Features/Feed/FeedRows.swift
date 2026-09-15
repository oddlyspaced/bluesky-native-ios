import SwiftUI

/// The feed list body shared by Home and the profile Posts tab (review finding A11).
///
/// Port of the `PostFeed.tsx` row types used in this slice: loading placeholder, first-load
/// error, empty state, post rows, "View full thread", fallback marker, load-more error row,
/// the loading footer and the end-of-feed footer. The screen owns the `ScrollView`.
struct FeedRows<Leading: View, Empty: View, EndOfFeed: View>: View {
    var model: FeedModel
    var eventContext: PostEventContext
    /// RN footer minimum height: `max(headerOffset, 32) * 2` on native.
    var footerMinHeight: CGFloat
    @ViewBuilder var leadingRow: Leading
    @ViewBuilder var emptyState: Empty
    @ViewBuilder var endOfFeed: EndOfFeed

    var body: some View {
        switch model.status {
        case .idle, .loading:
            PostFeedLoadingPlaceholder()
        case .failed(let message):
            ErrorMessageRow(message: message) { Task { await model.reload() } }
        case .loaded:
            if model.isEmpty {
                emptyState
            } else {
                leadingRow
                ForEach(model.rows) { row in
                    switch row.kind {
                    case .post(let item, let reason):
                        PostFeedItemView(row: row, item: item, reason: reason, context: eventContext)
                            .onAppear {
                                // RN reports rows seen for 500 ms in index order (`List.onItemSeen`, N6).
                                model.rowAppeared(row)
                                if row.id == model.rows.last?.id { model.loadMore() }
                            }
                            .onDisappear { model.rowDisappeared(row) }
                    case .viewFullThread(let rootUri):
                        ViewFullThreadRow(rootUri: rootUri)
                    }
                }
                if model.showsFallbackMarker {
                    DiscoverFallbackHeader()
                }
                if let error = model.loadMoreError {
                    LoadMoreRetryRow(message: error) { Task { await model.retryAfterError() } }
                } else if model.isLoadingMore {
                    ProgressView()
                        .padding(.top, Space.xl)
                        .frame(maxWidth: .infinity)
                        .frame(height: footerMinHeight, alignment: .top)
                } else if !model.hasMore {
                    endOfFeed.frame(minHeight: footerMinHeight)
                }
            }
        }
    }
}

/// Port of `LoadMoreRetryBtn` (`PostFeed.tsx:822-828`).
struct LoadMoreRetryRow: View {
    var message: String
    var retry: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: retry) {
            HStack(spacing: 14) {
                Icon(.rotateCounterClockwise, size: 18, color: theme.textContrastMedium)
                Text("There was an issue fetching posts. Tap here to try again.")
                    .textStyle(size: FontSize.md, leading: Leading.snug)
                    .foregroundStyle(theme.textContrastMedium)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, Space.md)
            .padding(.horizontal, Space.xl)
            .padding(.top, 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleStyle(scale: 1))
        .accessibilityLabel("There was an issue fetching posts. Tap here to try again.")
        .accessibilityIdentifier("loadMoreRetryBtn")
    }
}

/// Port of `ViewFullThread` (`src/view/com/posts/ViewFullThread.tsx`).
struct ViewFullThreadRow: View {
    var rootUri: String

    @Environment(AccountContainer.self) private var container
    @Environment(\.theme) private var theme

    var body: some View {
        Button {
            container.openThread(uri: rootUri)
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Canvas { context, _ in
                    var line = Path()
                    line.move(to: CGPoint(x: 2, y: 0))
                    line.addLine(to: CGPoint(x: 2, y: 15))
                    context.stroke(line, with: .color(theme.palette.contrast100), lineWidth: 2)
                    for y in [22.0, 28.0, 34.0] {
                        context.fill(Path(ellipseIn: CGRect(x: 0.5, y: y - 1.5, width: 3, height: 3)),
                                     with: .color(theme.palette.contrast200))
                    }
                }
                .frame(width: 4, height: 40)
                .frame(width: AvatarSize.post)
                Text("View full thread")
                    .textStyle(size: FontSize.md, leading: Leading.snug)
                    .foregroundStyle(theme.textLink)
                    .padding(.top, 18)
                    .padding(.bottom, Space.xs)
                Spacer(minLength: 0)
            }
            .padding(.leading, 18)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("View full thread")
        .accessibilityAddTraits(.isLink)
    }
}

/// Port of `DiscoverFallbackHeader.tsx`.
struct DiscoverFallbackHeader: View {
    @Environment(AccountContainer.self) private var container
    @Environment(\.theme) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let fonts = ScaledFonts(multiplier: FontScale.multiplier(for: dynamicTypeSize))
        HStack(spacing: 0) {
            Icon(.info, size: 36, color: theme.textContrastMedium)
                .padding(.leading, Space.md)
                .frame(width: 68, alignment: .leading)
            // Legacy `Text type="md"` with a `md-medium` link (semi-bold, `src/lib/themes.ts:155-158`),
            // with the measured legacy-text tracking (`RNLineBox.legacyTracking`).
            (Text("We ran out of posts from your follows. Here's the latest from ")
                .foregroundStyle(theme.text)
             + Text("Discover").font(fonts.font(FontSize.md, FontWeight.semiBold))
                .foregroundStyle(theme.textLink)
             + Text(".").foregroundStyle(theme.text))
                .font(fonts.font(FontSize.md))
                .tracking(RNLineBox.legacyTracking(for: FontSize.md * fonts.multiplier))
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .onTapGesture { container.shell.notInShowcase = NotInShowcaseItem(title: "Discover") }
        }
        .padding(Space.md)
        .padding(.top, 1)
        .background(theme.bgContrast25)
        .overlay(alignment: .top) { theme.borderContrastLow.frame(height: 1) }
    }
}

/// Loading skeleton, port of `PostFeedLoadingPlaceholder` (`LoadingPlaceholder.tsx:44-130, 314-343`).
struct PostFeedLoadingPlaceholder: View {
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<8, id: \.self) { _ in
                HStack(alignment: .top, spacing: 0) {
                    Circle().fill(theme.bgContrast50)
                        .frame(width: AvatarSize.post, height: AvatarSize.post)
                        .padding(.trailing, Space.md)
                        .offset(y: -6)
                    VStack(alignment: .leading, spacing: 0) {
                        bar(width: 100).padding(.bottom, 10)
                        bar(fraction: 0.95).padding(.bottom, Space.sm)
                        bar(fraction: 0.95).padding(.bottom, Space.sm)
                        bar(fraction: 0.8).padding(.bottom, 11)
                        HStack(spacing: 0) {
                            placeholderIcon(.reply).padding(.leading, -6)
                            placeholderIcon(.repost)
                            placeholderIcon(.heart)
                            Color.clear.frame(maxWidth: .infinity, minHeight: 30)
                        }
                        .opacity(0.5)
                    }
                }
                .padding(.leading, 10)
                .padding(.top, Space.xl)
                .padding(.bottom, 5)
                .padding(.trailing, 15)
            }
        }
        .accessibilityLabel("Loading")
    }

    private func bar(width: CGFloat? = nil, fraction: CGFloat = 1) -> some View {
        GeometryReader { proxy in
            RoundedRectangle(cornerRadius: 6).fill(theme.bgContrast50)
                .frame(width: width ?? proxy.size.width * fraction, height: 6)
        }
        .frame(height: 6)
    }

    private func placeholderIcon(_ glyph: IconGlyph) -> some View {
        Icon(glyph, size: 18, color: theme.control)
            .padding(5)
            .frame(maxWidth: .infinity)
    }
}
