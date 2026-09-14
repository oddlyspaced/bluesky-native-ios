# Bluesky native showcase (iOS)

A native SwiftUI port of a slice of the Bluesky social app, which is React Native and MIT licensed. The port was built with the Nativestarter Migration Pack. The source of the port is `bluesky-social-app`, pinned commit `2bfb94d`.

The app talks to a real AT Protocol server. It uses no mock data and no hard-coded posts.

- Bundle id: `xyz.blueskyweb.app.native`
- Display name: "Bluesky native showcase"
- Swift 6 (strict concurrency), iOS 26 SDK, minimum iOS 17
- SwiftUI with `@Observable` and `URLSession` async/await
- No third-party dependencies

## What is ported

| Checkpoint | Scope |
|---|---|
| CP-00 foundation | Design tokens from ALF (palette, spacing, radii, type scale, Inter), XRPC client with `atproto-proxy`, token refresh, keychain session, custom tab shell and bottom bar |
| CP-01 home feed | Header, Following/Feeds tabs, "What's up?" prompt, Following timeline with the RN feed tuner (reply grouped under its parent, root deduplicated), thread lines, "We ran out of posts" fallback header, end-of-feed block, compose FAB, pull to refresh, paging |
| CP-02 post thread | Header ("Post"), expanded anchor post with "12:55 AM · Sep 15, 2026" and "Everybody can reply", reply rows, "Write your reply" pill, back |
| CP-03 profile | Own profile: banner under the status bar, avatar ring, Edit Profile, share and more buttons, name, handle, "2 followers 2 following 1 post", bio, 8-tab pager, Posts tab (`posts_and_author_threads`), "End of feed" |

**Interactions.** These work against the server:
- Like and unlike, with optimistic state and rollback on failure.
- Repost and undo repost, through the RN confirm menu with "Repost" / "Remove repost", "Quote post" and "Cancel".
- Like and repost state shows on every screen that displays the post, through a port of RN's post shadow cache.
- Tap a post to open its thread, then go back.
- Switch tabs. Re-tapping the active tab returns to the tab root.
- The notification badge uses RN's `countUnread` over `listNotifications`.

**Automation IDs.** The RN `testID`s are reused as `accessibilityIdentifier`, so one Maestro flow drives both apps. IDs: `e2eSignInAlice`, `bottomBarHomeBtn`, `bottomBarSearchBtn`, `bottomBarMessagesBtn`, `bottomBarNotificationsBtn`, `bottomBarProfileBtn`, `feedItem-by-<handle>`, `postThreadItem-by-<handle>`, `replyBtn`, `repostBtn`, `likeBtn`, `postBookmarkBtn`, `postShareBtn`, `postDropdownBtn`, `quoteBtn`, `composeFAB`, `profileView`, `profilePager`, `profileHeader*`, `viewHeaderHomeFeedPrefsBtn`, `homeScreenFeedTabs`.

**Debug sign-in.** The Debug build defines the `E2E` compilation condition. It mirrors RN `TestCtrls.e2e.tsx`:
- A 1x1pt red control column at top 100, right 0.
- `e2eSignInAlice`, `e2eSignInBob` and `e2eSignOut` sign in to `http://localhost:3000` or sign out. They use proxy `did:plc:kmmukaomzqnk3fln2m5guony#bsky_appview`.

## What is not ported

The following items show an honest "Not part of this showcase" view or sheet:
- The Search, Chat and Notifications tabs.
- The composer (FAB, "What's up?", "Write your reply", the Reply button, "Quote post").
- Bookmarks, share, post and thread options menus, and the drawer menu.
- The Feeds screen.
- Profile tabs other than Posts, Edit Profile.
- Account creation and the password sign-in form.

The following are also not ported:
- Rich-text facets (links, mentions, hashtags) and embeds (images, video, quotes, link cards).
- Moderation, labels, content hiding and translations.
- The Discover fallback feed. RN also skips it in `__DEV__`.
- Header hide-on-scroll (minimal shell).
- Swipe-back gesture (the navigation bar is hidden).
- The threaded thread view and reply sorting.
- Other users' profiles (avatar taps do nothing).
- Dark and dim themes.
- Dynamic Type font scaling beyond the system default.

## Layout

```
ios/
  project.yml                   xcodegen spec (the .xcodeproj is generated and git-ignored)
  BlueskyNative/
    App/                        entry, scene, root view, config, debug e2e controls
    Core/Networking/            XRPCClient, BlueskyAPI protocol, AuthenticatedBlueskyAPI
    Core/Session/               SessionStore (@Observable), KeychainCredentialStore
    Core/Models/                lexicon models (postView, feedViewPost, threadViewPost, ...)
    Core/Formatting/            TimeAgo (useTimeAgo port), NiceDate, CountFormat
    DesignSystem/               Tokens, Typography (Inter), Components, UserAvatar, Icons/
    Features/Shell/             TabShell, BottomBar, NotInShowcaseView
    Features/Feed/              FeedModel, FeedTuner, HomeScreen, PostFeedItemView
    Features/Post/              PostShadowStore + PostInteractions, PostMeta, PostControls, RepostMenu
    Features/Thread/            ThreadModel, ThreadScreen
    Features/Profile/           ProfileModel, ProfileScreen
    Resources/Fonts/            InterVariable.ttf + OFL.txt
  BlueskyNativeTests/           Swift Testing suites, FakeBlueskyAPI, JSON fixtures
  parity/                       Maestro flows, compare.sh, native screenshots
  scripts/generate_icons.py     Lucide -> IconGlyph.generated.swift
```

View models depend on the `BlueskyAPI` protocol only. Tests inject `FakeBlueskyAPI`.

## Build and run

Prerequisites: Xcode 26.6, xcodegen, and a booted iOS simulator.

1. Generate the project:
   ```
   cd ios
   xcodegen generate
   ```
2. Build and install:
   ```
   xcodebuild -project BlueskyNative.xcodeproj -scheme BlueskyNative \
     -destination 'platform=iOS Simulator,id=7F73AB4A-2709-4033-89D2-35CE10E650F4' \
     -derivedDataPath build/dd build
   xcrun simctl install 7F73AB4A-2709-4033-89D2-35CE10E650F4 build/dd/Build/Products/Debug-iphonesimulator/BlueskyNative.app
   xcrun simctl launch 7F73AB4A-2709-4033-89D2-35CE10E650F4 xyz.blueskyweb.app.native
   ```
3. Start the local Bluesky dev network. The PDS is at `http://localhost:3000`, and the seeding control is at `http://localhost:1986`.
4. Seed the network. This resets all data:
   ```
   curl -X POST "http://localhost:1986/?users&follows&posts&feeds&thread"
   ```
5. Tap the red 1pt control at the top right, or run a Maestro flow. The users are alice.test, bob.test and carla.test, with password `hunter2`.

**Keychain on reinstall.** The keychain survives app deletion on iOS. On the first launch after install, the app clears its stored session. This matches RN, where a reinstall or Maestro `clearState` signs out.

## Test

```
xcodebuild -project BlueskyNative.xcodeproj -scheme BlueskyNative \
  -destination 'platform=iOS Simulator,id=7F73AB4A-2709-4033-89D2-35CE10E650F4' test
```

The suites cover:
- XRPC decoding of JSON captured from the dev server (`BlueskyNativeTests/Fixtures`, tokens redacted), plus unions.
- XRPC request building: proxy only on `app.bsky.*`, the auth header, record bodies, and refresh-once on `ExpiredToken`.
- The `useTimeAgo` test cases ported from RN, `niceDate` and compact counts.
- Optimistic like and repost: success, rollback, a fast like-then-unlike, and counts that never go negative.
- The feed tuner, feed model (paging, fallback marker, error and retry), thread flattening, profile, unread count and session store.
- The SVG path parser over every glyph.

To refresh a fixture after a seed, run this in `BlueskyNativeTests/Fixtures`. Redact the JWTs in `createSession.json` before you commit it.

```
TOKEN=$(curl -s -X POST http://localhost:3000/xrpc/com.atproto.server.createSession \
  -H 'Content-Type: application/json' -d '{"identifier":"alice.test","password":"hunter2"}' | jq -r .accessJwt)
curl -s -H "Authorization: Bearer $TOKEN" \
  -H 'atproto-proxy: did:plc:kmmukaomzqnk3fln2m5guony#bsky_appview' \
  "http://localhost:3000/xrpc/app.bsky.feed.getTimeline?limit=30" > getTimeline.json
```

## Capture parity

Run Maestro from `ios/parity`, because Maestro resolves `takeScreenshot` paths against the working directory:

```
cd ios/parity
maestro --device 7F73AB4A-2709-4033-89D2-35CE10E650F4 test -e PLATFORM=ios capture-native.yml
./compare.sh <path-to-rn-baseline-shots>
maestro --device 7F73AB4A-2709-4033-89D2-35CE10E650F4 test interactions-native.yml
```

- `capture-native.yml` runs the same steps as the RN baseline flow with the native app id. It reseeds the server first.
- `compare.sh` prints raw and masked `magick compare -metric AE -fuzz 5%` ratios.
- `interactions-native.yml` runs like, repost, thread, "Remove repost" and unlike on the live server.

Results and accepted differences are in [PARITY.md](PARITY.md).

## Licensing

The RN source code is MIT licensed. Not every asset in the RN repository is (see its `ASSETS.md`). This substitution is a real migration lesson: **check asset licences before you port "the design", not after.**

| Upstream asset | Status | What this port does |
|---|---|---|
| UI glyphs in `assets/icons/` (Central icon system, Iconists) | Licensed to Bluesky for its own use only (ASSETS.md section 2) | Uses [Lucide](https://lucide.dev) icons (ISC), 24pt grid, 2pt round stroke. `scripts/generate_icons.py` converts them; the licence is in `DesignSystem/Icons/LICENSE-lucide.txt`. |
| Butterfly logo, logomark, app icons, default avatar (Bluesky trademarks) | Not licensed (ASSETS.md section 3) | Header and splash use a neutral brand-blue diamond (`ShowcaseMark`, accessibility label "Showcase logo"). The avatar fallback is a generic silhouette drawn in code. No app icon is bundled. |
| Splash illustration (commissioned artwork) | Licensed to Bluesky only (ASSETS.md section 1) | Not used. The signed-out screen keeps the layout without the art. |
| Inter typeface | SIL OFL 1.1 | Bundled as `InterVariable.ttf` with `OFL.txt`, used exactly as RN does on iOS: variable `wght` axis, contextual alternates off. |
| Name "Bluesky" | Trademark | Used descriptively only ("Bluesky native showcase", "a port of the Bluesky app"), not as the product identity. |

The first icon generator copied path data from the upstream icon components. It was deleted before any generated file was written, and no upstream glyph or logo path remains in `ios/`.
