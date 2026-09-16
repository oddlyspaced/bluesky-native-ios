import Foundation
import Observation

/// Loads a profile and owns its Posts tab. Port of the own-profile path of `Profile.tsx`.
@MainActor
@Observable
final class ProfileModel {
    enum Status: Equatable {
        case loading
        case loaded
        /// `ErrorScreen` title and `cleanError` message (`Profile.tsx:127-138`).
        case failed(title: String, message: String)
    }

    private(set) var profile: ProfileViewDetailed?
    /// Facets detected in the bio, with mentions resolved (`Profile.tsx:614-647`, review finding F4).
    private(set) var descriptionFacets: [Facet]?
    private(set) var status: Status = .loading
    let posts: FeedModel
    let actor: String

    @ObservationIgnored private let api: any BlueskyAPI
    @ObservationIgnored private let analytics: any AnalyticsSink
    @ObservationIgnored private let faults: DebugFaults?

    init(api: any BlueskyAPI, actor: String, posts: FeedModel, analytics: any AnalyticsSink = NoopAnalytics(),
         faults: DebugFaults? = nil) {
        self.api = api
        self.actor = actor
        self.posts = posts
        self.analytics = analytics
        self.faults = faults
    }

    func loadProfile() async {
        do {
            if faults?.consume(.profile) == true { throw InjectedFault() }
            let loaded = try await api.getProfile(actor: actor)
            // RN shows the header placeholder until the bio's facets resolve
            // (`Profile.tsx:209-210`), and resolves again only when the text changes.
            let description = loaded.description ?? ""
            if profile == nil || description != (profile?.description ?? "") {
                let api = self.api
                descriptionFacets = description.isEmpty ? nil : await RichTextDetection.detectAndResolve(
                    description, resolveHandle: { try await api.resolveHandle($0) })
            }
            profile = loaded
            status = .loaded
        } catch where RequestFailure.isCancellation(error) {
            return
        } catch {
            // A profile already on screen stays; only a first load shows the error screen.
            // RN titles any profile query error "Not Found" (`Profile.tsx:127-138`).
            if profile == nil { status = .failed(title: "Not Found", message: ErrorText.clean(error)) }
        }
    }

    func retry() async {
        status = .loading
        await loadProfile()
    }

    /// Pull to refresh: the profile and the Posts tab (`feed:refresh` comes from the feed).
    func refresh() async {
        async let profileLoad: Void = loadProfile()
        async let postsLoad: Void = posts.pullToRefresh()
        _ = await (profileLoad, postsLoad)
    }

    /// RN pluralises each metric label: "1 follower", "2 followers", "1 post".
    static func followersLabel(_ count: Int) -> String {
        Plural.word(count, one: "follower", other: "followers")
    }

    static func postsLabel(_ count: Int) -> String {
        Plural.word(count, one: "post", other: "posts")
    }

    /// Tabs RN shows on your own profile, in order (`Profile.tsx`).
    static let ownProfileTabs = ["Posts", "Replies", "Media", "Videos", "Likes", "Feeds", "Starter Packs", "Lists"]
}

extension ProfileModel: RouteScopedModel {
    /// Stops the Posts tab's work when a pushed profile's route leaves the stack
    /// (review finding A83).
    func cancel() {
        posts.cancel()
    }
}
