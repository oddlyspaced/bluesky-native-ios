import Foundation
import Observation

/// Port of RN's post shadow cache (`src/state/cache/post-shadow.ts`).
///
/// Every screen renders posts through `apply(to:)`, so a like or repost made on one
/// screen shows at once on every other screen that displays the same post URI.
@MainActor
@Observable
final class PostShadowStore {
    /// An override of one viewer field. `.unset` means "use the server value".
    enum Override: Equatable, Sendable {
        case unset
        case value(String?)
    }

    struct Shadow: Equatable, Sendable {
        var likeUri: Override = .unset
        var repostUri: Override = .unset
    }

    /// RN writes this placeholder while the create request is in flight.
    static let pendingURI = "pending"

    private(set) var shadows: [String: Shadow] = [:]

    func shadow(for uri: String) -> Shadow {
        shadows[uri] ?? Shadow()
    }

    func setLike(_ value: String?, for uri: String) {
        shadows[uri, default: Shadow()].likeUri = .value(value)
    }

    func setRepost(_ value: String?, for uri: String) {
        shadows[uri, default: Shadow()].repostUri = .value(value)
    }

    /// Forgets all overrides, for example after a refresh returns fresh server state.
    func reset(uris: some Sequence<String>) {
        for uri in uris { shadows[uri] = nil }
    }

    /// Merges the shadow into a server post, adjusting counts by +-1 against the
    /// server's viewer state, as `mergeShadow` does in RN.
    func apply(to post: PostView) -> PostView {
        guard let shadow = shadows[post.uri] else { return post }
        var merged = post
        var viewer = post.viewer ?? PostViewerState()
        if case .value(let likeUri) = shadow.likeUri {
            merged.likeCount = Self.adjust(post.likeCount, was: post.viewer?.like != nil, now: likeUri != nil)
            viewer.like = likeUri
        }
        if case .value(let repostUri) = shadow.repostUri {
            merged.repostCount = Self.adjust(post.repostCount, was: post.viewer?.repost != nil, now: repostUri != nil)
            viewer.repost = repostUri
        }
        merged.viewer = viewer
        return merged
    }

    private static func adjust(_ count: Int?, was: Bool, now: Bool) -> Int {
        let base = count ?? 0
        if was && !now { return max(0, base - 1) }
        if !was && now { return base + 1 }
        return base
    }
}

/// Like and repost actions with optimistic updates.
///
/// Port of `usePostLikeMutationQueue` / `usePostRepostMutationQueue`
/// (`src/state/queries/post.ts`): the shadow changes first, the network call follows,
/// and a failure restores the previous state. Taps on the same post are serialised.
@MainActor
final class PostInteractions {
    private let api: any BlueskyAPI
    let shadows: PostShadowStore
    private var queues: [String: Task<Void, Never>] = [:]

    init(api: any BlueskyAPI, shadows: PostShadowStore) {
        self.api = api
        self.shadows = shadows
    }

    /// Likes or unlikes the post, based on its current (shadowed) state.
    func toggleLike(_ serverPost: PostView) -> Task<Void, Never> {
        let post = shadows.apply(to: serverPost)
        let uri = post.uri
        let previous = post.viewer?.like
        let api = self.api
        if let likeUri = previous {
            shadows.setLike(nil, for: uri)
            return enqueue(uri) { [shadows] in
                do {
                    let resolved = likeUri == PostShadowStore.pendingURI ? nil : likeUri
                    if let resolved { try await api.deleteLike(uri: resolved) }
                } catch {
                    shadows.setLike(previous, for: uri)
                }
            }
        } else {
            shadows.setLike(PostShadowStore.pendingURI, for: uri)
            return enqueue(uri) { [shadows] in
                do {
                    let created = try await api.like(post.strongRef)
                    // A newer tap may have cleared the like while this request ran.
                    if shadows.shadow(for: uri).likeUri == .value(PostShadowStore.pendingURI) {
                        shadows.setLike(created, for: uri)
                    } else {
                        try? await api.deleteLike(uri: created)
                    }
                } catch {
                    shadows.setLike(nil, for: uri)
                }
            }
        }
    }

    /// Reposts or removes the repost, based on the current (shadowed) state.
    func toggleRepost(_ serverPost: PostView) -> Task<Void, Never> {
        let post = shadows.apply(to: serverPost)
        let uri = post.uri
        let previous = post.viewer?.repost
        let api = self.api
        if let repostUri = previous {
            shadows.setRepost(nil, for: uri)
            return enqueue(uri) { [shadows] in
                do {
                    if repostUri != PostShadowStore.pendingURI { try await api.deleteRepost(uri: repostUri) }
                } catch {
                    shadows.setRepost(previous, for: uri)
                }
            }
        } else {
            shadows.setRepost(PostShadowStore.pendingURI, for: uri)
            return enqueue(uri) { [shadows] in
                do {
                    let created = try await api.repost(post.strongRef)
                    if shadows.shadow(for: uri).repostUri == .value(PostShadowStore.pendingURI) {
                        shadows.setRepost(created, for: uri)
                    } else {
                        try? await api.deleteRepost(uri: created)
                    }
                } catch {
                    shadows.setRepost(nil, for: uri)
                }
            }
        }
    }

    private func enqueue(_ uri: String, _ work: @escaping @MainActor () async -> Void) -> Task<Void, Never> {
        let previous = queues[uri]
        let task = Task { @MainActor in
            await previous?.value
            await work()
        }
        queues[uri] = task
        return task
    }
}
