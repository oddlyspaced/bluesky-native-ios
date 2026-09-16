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
    /// The bio facet resolution, owned by the model so `cancel()` stops it (review finding A68).
    @ObservationIgnored private var facetTask: Task<[Facet]?, Never>?

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
                descriptionFacets = description.isEmpty ? nil : await resolveDescriptionFacets(description)
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

extension ProfileModel {
    /// The bio's facets, resolved in a task the model owns, so `cancel()` stops it and a second
    /// load replaces it (review finding A68).
    fileprivate func resolveDescriptionFacets(_ description: String) async -> [Facet]? {
        facetTask?.cancel()
        let api = self.api
        let task = Task {
            await RichTextDetection.detectAndResolve(description,
                                                     resolveHandle: { try await api.resolveHandle($0) })
        }
        facetTask = task
        defer { if facetTask == task { facetTask = nil } }
        return await task.value
    }
}

extension ProfileModel: RouteScopedModel {
    /// Stops the Posts tab and the bio facet resolution when a pushed profile's route leaves the
    /// stack (review findings A83, A68).
    func cancel() {
        facetTask?.cancel()
        facetTask = nil
        posts.cancel()
    }
}
