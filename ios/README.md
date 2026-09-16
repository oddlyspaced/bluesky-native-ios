# Native showcase (iOS): SwiftUI port of a Bluesky slice

A native SwiftUI port of a slice of the Bluesky social app, which is React Native and MIT
licensed. The port was built with the Nativestarter Migration Pack. The source of the port is
`bluesky-social-app` at commit `2bfb94d`.

The app talks to a real AT Protocol server. It uses no mock data and no hard-coded posts.

| Item | Value |
|---|---|
| Bundle id | `io.nativestarter.showcase.bluesky` |
| Display name | "Native showcase" |
| Xcode project, scheme, target | `BlueskyNative.xcodeproj`, `NativeShowcase`, `NativeShowcase` (tests: `NativeShowcaseTests`) |
| Language and UI | Swift 6 with complete strict concurrency, SwiftUI with `@Observable`, `URLSession` async/await |
| Deployment | iOS 17 minimum, iOS 26 SDK |
| Dependencies | None |

## Scope

The slice is defined in `../plan/slice-plan.md`. "In scope for every screen" is binding.

| Checkpoint | What is ported |
|---|---|
| CP-00 foundation | ALF tokens with light, dark and dim themes following the system (dark system appearance gives dim, as RN's defaults); Inter with RN's Dynamic Type multiplier table; XRPC client with `atproto-proxy`; single-flight token refresh; session store with generation checks; Keychain credential actor; server session revoke on sign-out; analytics event log (E2E builds only; Release uses a no-op sink); image loader; custom tab shell with per-tab routers; bottom bar with unread polling; E2E test controls |
| CP-01 home | Header (hides on scroll), Following and Feeds tabs, composer prompt with separate camera and image actions, Following timeline with RN's feed tuners and preferences, reason rows ("Reposted by you", "Pinned"), "Replied to" rows, rich text facets, "Show more" for long posts, like and repost with haptics, like animation and count wheel, fallback marker, loading, empty, first-load error and load-more error states, pull to refresh, soft reset |
| CP-02 thread | `app.bsky.unspecced.getPostThreadV2` with RN's parameters and traversal: parents, anchor, replies, tombstones, read-more rows, the other-replies bucket; anchor with engagement stats row and who-can-reply; "Write your reply" prompt above the bottom bar; RN's thread error copy; placeholder skeletons; swipe back |
| CP-03 profile | Own profile: banner, avatar, Edit Profile, Invite friends and More, name, handle, metrics, bio, section tabs, Posts tab feed with its empty state and "End of feed"; loading placeholder and error screen |

Views and models depend on the `BlueskyAPI`, `PreferencesStore`, `AppActivity` and `URLOpening` protocols, the `AnalyticsSink` protocol, the
`ImageLoading` protocol and the `HapticsPlaying` protocol. Tests inject fakes.

## Not ported

"Not part of this showcase" views or sheets stand in for these RN features:

- The Search, Chat and Notifications tabs, the composer, bookmarks, share and post menus, the
  drawer, the Feeds screen, hashtag screens and other users' profiles.
- Profile tabs other than Posts, Edit Profile and the invite dialog.
- Liked-by, reposted-by and quotes lists, and the thread options menu.

These are proposed out of scope in `../plan/slice-plan.md`, awaiting owner acceptance:

- Post embeds (images, video, link cards, quotes, record with media).
- Long-press repost to quote.
- The chat unread badge.
- Licence substitutions: Lucide icons, a neutral logo mark, a code-drawn default avatar, and an
  app name without "Bluesky".

Also not ported: moderation and labels, translations, feature flags (GrowthBook) and
`feature:viewed` events, feed feedback interactions (disabled for this slice's feeds in RN),
the Discover fallback feed (RN also skips it in `__DEV__`), and a sign-in form.

## Build and run

Prerequisites: Xcode 26.6, xcodegen, a booted iOS simulator, and the local Bluesky dev network
(PDS on `http://localhost:3000`, seed control on `http://localhost:1986`).

1. Generate the project. The `.xcodeproj` and `BlueskyNative/Info.plist` are generated from
   `project.yml`:
   ```
   cd ios
   xcodegen generate
   ```
2. Build and install the Debug build:
   ```
   xcodebuild -project BlueskyNative.xcodeproj -scheme NativeShowcase \
     -destination 'platform=iOS Simulator,id=7F73AB4A-2709-4033-89D2-35CE10E650F4' \
     -derivedDataPath build/dd build
   xcrun simctl install 7F73AB4A-2709-4033-89D2-35CE10E650F4 build/dd/Build/Products/Debug-iphonesimulator/NativeShowcase.app
   ```
3. Seed the network (this resets all data):
   ```
   curl -X POST "http://localhost:1986/?users&follows&posts&feeds&thread"
   ```
4. Sign in with the 1x1pt red control at the top right (`e2eSignInAlice`), or run a Maestro
   flow. The users are alice.test, bob.test and carla.test, with password `hunter2`.

**Debug controls.** The Debug build defines the `E2E` compilation condition. It ports RN
`TestCtrls.e2e.tsx`: a column of 1x1pt controls at top 100, right 0. `e2eSignInAlice`,
`e2eSignInBob` and `e2eSignOut` work; RN's other nine controls keep their slots. A second column
at top 100, left 0 holds five controls that RN does not have: `e2eFailNextFeedLoad`,
`e2eFailNextLoadMore`, `e2eFailNextRefresh`, `e2eFailNextThread` and `e2eFailNextProfile`. Each
arms one injected network failure, so Maestro can capture the error states. Arm them on the
signed-out screen: when signed in, a 1pt control is not a reliable tap target over the header.

**Release is a smoke build, not for store submission.** It has no E2E controls and no
sign-in form, so it stops at the signed-out screen. It still allows local networking. Build it with:

```
xcodebuild -project BlueskyNative.xcodeproj -scheme NativeShowcase -configuration Release \
  -destination 'generic/platform=iOS Simulator' -derivedDataPath build/dd build
```

**Keychain on reinstall.** The Keychain survives app deletion on iOS. On the first launch after
an install the app clears its stored session, as RN's app storage is cleared by a reinstall or
Maestro `clearState`.

## Test

```
xcodebuild -project BlueskyNative.xcodeproj -scheme NativeShowcase \
  -destination 'platform=iOS Simulator,id=7F73AB4A-2709-4033-89D2-35CE10E650F4' test
```

The suites cover:

- Decoding of JSON captured from the dev server (`BlueskyNativeTests/Fixtures`, tokens redacted),
  including thread V2, preferences, facets, repost reasons and union members.
- XRPC: proxy header, auth header, thread V2 parameters, like records with `via`, single-flight
  refresh under concurrency, a revoked refresh token ending the session, a transient refresh
  failure keeping it, and an invalidated API reporting no tokens.
- Session store: one ordered credential write chain, tested with gated saves and clears (a refresh
  from the previous account during a new sign-in, a quick sign-in after sign-out, sign-out during
  sign-in, refresh order), revoke with the newest refresh token after invalidation, first-launch
  Keychain clear, only corrupt Keychain items deleted, auth failure signing out. A hosted Keychain
  round trip. No test waits on a timer.
- Link policy (`LinkRouter`), app router and route-scoped models, unread polling stop.
- The toggle mutation queue (optimistic state, rollback, compensation, collapsed toggles),
  shadows yielding to fresh server state, and the `post:like` and `post:unlike` event props.
- Feed tuners, auto-pagination and fallback marker, first-load and load-more errors with retry,
  refresh failure with rows, stale reload results dropped, and `post:view` once per URI with
  position.
- Thread traversal: parents, reply lines, tombstones, read-more rows, the other-replies bucket,
  error copy, placeholders, and the stats-row rule.
- Relative time (ported RN cases and boundaries), counts, display names, `cleanError`, the
  Dynamic Type table, rich text segmentation, short URLs, link warnings, and the event log format.

## Parity

Maestro flows, masks and scripts live in `parity/`. One flow drives both apps; `LABEL` selects the
RN e2e app (`xyz.blueskyweb.app`) or this app.

```
cd ios/parity
./run-pair.sh base              # RN, then native on the same seed; also: dark, xxxl, empty, mergefeed,
                                # interactions, wrapped, api
./run-capture.sh native errors  # native-only error states
python3 make_masks.py masks-spec.json base out/base/rn/ios out/base/native/ios masks/base.json
node <pack>/skills/check-parity/scripts/diff.mjs --rn out/base/rn/ios --native out/base/native/ios \
  --out out/base/diff-masked --mask masks/base.json
node <pack>/skills/check-parity/scripts/events.mjs --rn events/rn-expected-base.jsonl \
  --native out/base/native/ios/events.normalized.jsonl --ignore initMs,secondsActive --ordered
```

`run-pair.sh` holds the shared seed lock (`/tmp/bsky-seed.lock`) for both apps and captures them in the
same run. `run-capture.sh` calls the Pack's `capture.mjs`, sets the simulator appearance or content size
for the state, and copies and normalises the native event log. The `wrapped` and `api` flows run
`flows/setupApi.js` after the seed: it writes records through the PDS XRPC API (a post that wraps to
three lines; a repost by bob, a threadgate, a post with facets and bio facets), so the RN app and this
app capture states that no upstream seed creates.

`make_masks.py` builds masks from the RN image and fixed slots only. It fails when native ink inside
any app mask lies outside the RN ink area of that mask, when a native ink cluster of any width crosses
a mask edge where RN has no matching cluster, or when a screen is more than 15% masked. Results, the
noise floor, the event diff and the remaining differences are in [PARITY.md](PARITY.md).

## Licensing

The RN source code is MIT licensed. Not every asset in the RN repository is (see its
`ASSETS.md`). This substitution is a real migration lesson: **check asset licences before you
port "the design", not after.**

| Upstream asset | Status | What this port does |
|---|---|---|
| UI glyphs in `assets/icons/` (Central icon system) | Licensed to Bluesky for its own use only (ASSETS.md section 2) | [Lucide](https://lucide.dev) icons (ISC), 24pt grid, 2pt round stroke, generated by `scripts/generate_icons.py`; licence in `DesignSystem/Icons/LICENSE-lucide.txt` |
| Butterfly logo, logomark, app icons, default avatar | Not licensed (ASSETS.md section 3) | A neutral brand-blue diamond (`ShowcaseMark`), an original app icon from the same mark, and a generic silhouette drawn in code |
| Splash illustration | Licensed to Bluesky only (ASSETS.md section 1) | Not used |
| Inter typeface | SIL OFL 1.1 | Bundled as `InterVariable.ttf` with `OFL.txt` |
| Name "Bluesky" | Trademark | Used descriptively only; the app is named "Native showcase" |
