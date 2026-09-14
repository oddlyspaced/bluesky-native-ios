import Foundation
import Observation

/// One row of the linear thread view.
struct ThreadRow: Identifiable, Hashable {
    enum Kind: Hashable {
        case parent
        case anchor
        case reply
    }

    var post: PostView
    var kind: Kind
    /// Draw the line coming down from the row above.
    var showsParentLine: Bool
    /// Draw the line continuing to the row below.
    var showsChildLine: Bool

    var id: String { post.uri }
}

/// Loads a post thread. Port of `usePostThread` in its linear view.
@MainActor
@Observable
final class ThreadModel {
    enum Status: Equatable {
        case loading
        case loaded
        case notFound
        case failed(String)
    }

    private(set) var rows: [ThreadRow] = []
    private(set) var status: Status = .loading

    private let api: any BlueskyAPI
    let uri: String

    init(api: any BlueskyAPI, uri: String) {
        self.api = api
        self.uri = uri
    }

    var anchor: PostView? {
        rows.first { $0.kind == .anchor }?.post
    }

    func load() async {
        do {
            let node = try await api.getPostThread(uri: uri)
            rows = Self.flatten(node)
            status = rows.isEmpty ? .notFound : .loaded
        } catch is CancellationError {
            return
        } catch XRPCError.http(_, "NotFound", _) {
            status = .notFound
        } catch {
            status = rows.isEmpty ? .failed(FeedModel.message(for: error)) : .loaded
        }
    }

    /// Flattens a thread into rows: ancestors (oldest first), the anchor, then each
    /// direct reply followed by its first-child chain, like RN's linear view
    /// (`getPostThreadV2` with `branchingFactor: 1`).
    static func flatten(_ node: ThreadNode, maxDepth: Int = 10) -> [ThreadRow] {
        guard case .post(let anchor, let parent, let replies) = node else { return [] }

        var ancestors: [PostView] = []
        var cursor = parent
        while case .post(let post, let next, _)? = cursor {
            ancestors.insert(post, at: 0)
            cursor = next
        }

        var rows: [ThreadRow] = ancestors.enumerated().map { index, post in
            ThreadRow(post: post, kind: .parent, showsParentLine: index > 0, showsChildLine: true)
        }
        rows.append(ThreadRow(post: anchor, kind: .anchor, showsParentLine: !ancestors.isEmpty,
                              showsChildLine: false))

        for reply in replies {
            var chain: [PostView] = []
            var current: ThreadNode? = reply
            while chain.count < maxDepth, case .post(let post, _, let children)? = current {
                chain.append(post)
                current = children.first
            }
            for (index, post) in chain.enumerated() {
                rows.append(ThreadRow(post: post, kind: .reply, showsParentLine: index > 0,
                                      showsChildLine: index < chain.count - 1))
            }
        }
        return rows
    }
}
