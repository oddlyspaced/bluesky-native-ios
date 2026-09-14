# Architecture review 1: CP-00 to CP-03, iOS

- Reviewer: `architecture-reviewer` agent (Nativestarter Migration Pack), run on 2026-09-15
- Code reviewed: `ios/` at commit `9fead7d`
- Verdict: **Blockers found: 2**
- Paths are relative to `ios/BlueskyNative/` unless they start with `ios/`.

## Blockers

| # | Area | Finding | Evidence | Fix |
|---|---|---|---|---|
| A1 | Security | A refresh still running on the old API actor writes tokens to the Keychain after sign-out or an account switch. A signed-out user is restored, or one account overwrites another. | `Core/Session/SessionStore.swift:124-133`; `Core/Networking/BlueskyAPI.swift:194-201` | Route updates through SessionStore on the main actor, and accept one only when its DID and generation match. Add `invalidate()` on the API actor and call it from signOut and activate. Call `com.atproto.server.deleteSession` on sign-out. |
| A2 | Performance | Keychain calls (`SecItemCopyMatching`, clear) run synchronously on the main thread at launch, sign-in and sign-out. | `Core/Session/SessionStore.swift:100-110,116,125`; `App/App.swift:47-51` | Make CredentialStore async, implemented as an actor, and keep `.restoring` until it finishes. |

## Major

| # | Area | Finding | Evidence | Fix |
|---|---|---|---|---|
| A3 | Concurrency | Refresh is not single-flight: actor reentrancy lets concurrent ExpiredToken calls each refresh with the same token. | `Core/Networking/BlueskyAPI.swift:185-201` | One `refreshTask`; refresh only if the failed token equals the current one. |
| A4 | Errors | A failed refresh (expired or revoked, InvalidToken, 401) never signs out, so every call fails forever. | `Core/Networking/BlueskyAPI.swift:185-192` | Terminal auth-failure callback sets signedOut and clears credentials; add tests. |
| A5 | Keychain | Every load error deletes the item; save failures are dropped with `try?`. | `Core/Session/SessionStore.swift:106-108,116,132` | Delete only on DecodingError; surface save failures. |
| A6 | Cancellation | `URLError(.cancelled)` is treated as a failure, and loadIfNeeded never recovers. | `Features/Feed/FeedModel.swift:58-62`; `Features/Thread/ThreadModel.swift:53-58`; `Features/Profile/ProfileScreen.swift:32-35` | Map cancellation to one case and reset status to idle. |
| A7 | State | refresh and loadMore have no in-flight guard or generation, so a stale page 2 can land after a refresh. | `Features/Feed/FeedModel.swift:49-77` | One load task and a generation counter; cancel loadMore on refresh; add a test. |
| A8 | State | Post shadows are never cleared. | `Features/Post/PostShadowStore.swift:40-42,108` | Store server identity per shadow and drop the shadow when it changes; never reset a URI with a pending request. |
| A9 | State | `PostInteractions` and screen models are created in view `body` or `init`, so their identity is lost on re-render. | `App/RootView.swift:40-41`; `Features/Shell/TabShell.swift:40,55-57` | Account-scoped container created once per session. |
| A10 | Platform API | `UITraitCollection.current.displayScale` is used in SwiftUI bodies, so hairlines depend on it. | `DesignSystem/Tokens.swift:120` | Use `@Environment(\.pixelLength)`. |
| A11 | Duplication | Feed list rendering is duplicated. | `Features/Feed/HomeScreen.swift:33-60`; `Features/Profile/ProfileScreen.swift:215-241` | Extract a FeedList component. |
| A12 | Duplication | The pill button is written four times; the design system has no Button. | `App/RootView.swift:75-91`; `Features/Post/PostViews.swift:187-194`; `Features/Feed/HomeScreen.swift:177-190`; `Features/Profile/ProfileScreen.swift:124-131` | Add a DSButton mirroring ALF Button. |
| A13 | Consistency | Display-name fallback is written four times with two different rules. | `Features/Post/PostViews.swift:14`; `Features/Profile/ProfileScreen.swift:146`; `Features/Thread/ThreadScreen.swift:86`; `Features/Feed/PostFeedItemView.swift:83,100` | Add `displayNameOrHandle`, ported from RN sanitizeDisplayName. |
| A14 | Performance | A DateFormatter is created per call in body, and dates are parsed on every render. | `Core/Formatting/Formatting.swift:16-39`; `Features/Post/PostViews.swift:30,47`; `Core/Formatting/TimeAgo.swift:54` | Cache formatters or use FormatStyle; parse dates once. |
| A15 | Performance | AsyncImage has no memory cache or downsampling. | `DesignSystem/UserAvatar.swift:13`; `Features/Profile/ProfileScreen.swift:95` | Image-loading service behind a protocol. |
| A16 | Scale | TabShell owns every model and route; hidden tabs stay mounted. | `Features/Shell/TabShell.swift:19-21,49-77,108-114` | Per-tab routers and screen factories; TabView with the system bar hidden and the custom BottomBar kept. |
| A17 | Tokens | Theme is static; features use Palette directly (21 sites). | `DesignSystem/Tokens.swift:60-69` | Theme as an environment value with light, dark and dim; semantic atoms only. |
| A18 | Tokens | Space tokens unused, 94 numeric paddings, raw colours and sizes, `windowHeight = 874`. | `DesignSystem/Tokens.swift:72-83`; see review text | Use the tokens; add AvatarSize and semantic colours. |
| A19 | Tokens | Sub-point offsets tuned on one 3x device live in shared components. | `Features/Post/PostViews.swift:36-38`; `Features/Profile/ProfileScreen.swift:161,176`; `Features/Thread/ThreadScreen.swift:148` | Centralise RN line-box compensation, rounded to pixelLength. |
| A20 | Tests | No tests for refresh failure, concurrent refresh, refresh after sign-out, cancellation, loadMore failure or overlap, repost rollback, Keychain, or incomplete-thread rows. | `ios/BlueskyNativeTests/NetworkingTests.swift:77-97` | Add fake-transport tests and a hosted Keychain round trip. |
| A21 | App Store | No app icon. | no `.xcassets` | Add an original AppIcon and AccentColor. |
| A22 | App Store | No `PrivacyInfo.xcprivacy`; UserDefaults is a required-reason API. | `App/App.swift:47-51` | Add a manifest with reason CA92.1. |
| A23 | App Store | Release build is unusable past the splash; the bundle prefix `xyz.blueskyweb` and the name use Bluesky's domain and trademark. | `App/RootView.swift:75-92`; `ios/project.yml:3,24,38` | Own bundle prefix and a name without "Bluesky". Not for store submission. |
| A24 | Scope | CP-00 to CP-03 landed in one commit. | commit `9fead7d` | Separate commits per checkpoint; record commits per gate. |

## Minor

| # | Finding | Evidence |
|---|---|---|
| A25 | NSAllowsLocalNetworking and the localhost URL ship in Release. | `ios/project.yml:34-35`; `Info.plist:23-27`; `App/AppConfig.swift:5` |
| A26 | Authenticated responses are cached on disk by `URLSession.shared`. | `Core/Networking/XRPCClient.swift:22` |
| A27 | Sign-out does not revoke the server session. | `Core/Session/SessionStore.swift:124-128` |
| A28 | The per-URI `queues` map grows forever. | `Features/Post/PostShadowStore.swift:79,152-160` |
| A29 | Compensating deletes use `try?`. | `Features/Post/PostShadowStore.swift:111,143` |
| A30 | Unstructured `Task {}` in view callbacks. | `Features/Feed/HomeScreen.swift:37,50`; `Features/Profile/ProfileScreen.swift:219,232`; `Features/Thread/ThreadScreen.swift:56` |
| A31 | `restore()` has no state guard. | `App/RootView.swift:26`; `Core/Session/SessionStore.swift:100` |
| A32 | Error copy is shared wrongly; raw server messages are shown. | `Features/Feed/FeedModel.swift:105-108` |
| A33 | ProfileModel lives in the view file. | `Features/Profile/ProfileScreen.swift:1-52` |
| A34 | Unused `@Environment(SessionStore.self)`. | `Features/Thread/ThreadScreen.swift:187` |
| A35 | A new ThreadModel is created on every destination evaluation; the thread reloads on each appear. | `Features/Shell/TabShell.swift:120`; `Features/Thread/ThreadScreen.swift:43` |
| A36 | "Post not found" row is a button with an empty action. | `Features/Thread/ThreadScreen.swift:54` |
| A37 | FeedRow.rows is computed in body. | `Features/Feed/HomeScreen.swift:39` |
| A38 | Slice id uses a per-process hash. | `Features/Feed/FeedTuner.swift:30` |
| A39 | `nonisolated(unsafe)` formatters with NSLock. | `Core/Models/Lexicon.swift:240-259` |
| A40 | Tests mirror the implementation (metricLabel ternary; no displayText boundary). | `ios/BlueskyNativeTests/ViewModelTests.swift:92-101,139-154` |
| A41 | Test helpers with data races. | `ios/BlueskyNativeTests/NetworkingTests.swift:10,183-193` |
| A42 | Unread load failure ignored; profile load waits for notifications. | `Features/Shell/TabShell.swift:100-103,161` |
| A43 | Force unwraps on a stored service URL. | `Core/Networking/XRPCClient.swift:53-56` |
| A44 | The Release configuration is never compiled by any documented step. | `ios/project.yml:42-43` |
| A45 | Info.plist duplicates project.yml. | `Info.plist`; `ios/project.yml:21-35` |

## Commands the reviewer ran

- `swiftc -parse` on all 34 Swift files: pass.
- git, find and grep inventories.
- Not run: xcodebuild, Instruments, Thread Sanitizer, App Store validation.
