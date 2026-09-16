# Parity report (iOS): RN app vs native SwiftUI port

- Date: 2026-09-16 (review round 3 fixes; every number below is from captures made on this date).
- Device: iPhone 17 Pro simulator, iOS 26.4 (`7F73AB4A-2709-4033-89D2-35CE10E650F4`), 1206x2622 px at 3x.
- RN build: the upstream e2e app `xyz.blueskyweb.app` (`bluesky-social-app` at `2bfb94d`, Metro in e2e mode
  on port 8081).
- Native build: Debug `NativeShowcase` at commit `49b3e80`, installed once and used for every capture.
- Server: the upstream dev network (PDS `http://localhost:3000`, seed manager `http://localhost:1986`,
  AppView DID `did:plc:bw7ad3erl7btq6qwf66yqiov`).
- **Acceptance: awaiting owner acceptance.** No difference in this report is accepted. No acceptor is named.

## Verdict

**With masks: 4 pass, 15 drift, 1 fail. Raw: 14 of 20 screens fail, 6 drift.**
Each drift and the fail need a written sign-off by a person who did not write the port
(`check-parity/references/thresholds.md`); none is signed.

Masked ratio = differing pixels after masks / 3,162,132, threshold 0.02, fuzz 5% (`diff.mjs` defaults).

| State | Screen | Raw ratio (px) | Raw status | Masked ratio (px) | Mask area | Masked status |
|---|---|---|---|---|---|---|
| base | home | 0.0266 (84,000) | fail | 0.0139 (43,799) | 13.54% | drift |
| base | thread | 0.0166 (52,358) | drift | 0.0089 (28,054) | 10.83% | pass |
| base | profile | 0.0174 (54,999) | drift | 0.0109 (34,615) | 9.10% | drift |
| dark | home-dark | 0.0267 (84,448) | fail | 0.0142 (44,917) | 13.54% | drift |
| dark | thread-dark | 0.0170 (53,673) | drift | 0.0091 (28,693) | 10.83% | pass |
| dark | profile-dark | 0.0162 (51,254) | drift | 0.0108 (34,240) | 9.10% | drift |
| largest Dynamic Type | home-xxxl | 0.0307 (97,174) | fail | 0.0170 (53,610) | 13.41% | drift |
| largest Dynamic Type | thread-xxxl | 0.0231 (73,004) | fail | 0.0150 (47,342) | 11.18% | drift |
| largest Dynamic Type | profile-xxxl | 0.0246 (77,907) | fail | 0.0179 (56,749) | 9.12% | drift |
| empty seed | home-empty | 0.0252 (79,828) | fail | 0.0188 (59,596) | 9.60% | drift |
| empty seed | profile-empty | 0.0194 (61,496) | drift | 0.0116 (36,668) | 9.00% | drift |
| mergefeed seed | home-mergefeed | 0.0223 (70,528) | fail | 0.0097 (30,593) | 13.38% | pass |
| after like and repost | home-liked-reposted | 0.0266 (83,978) | fail | 0.0139 (43,889) | 13.54% | drift |
| after like and repost | thread-liked-reposted | 0.0206 (65,079) | fail | 0.0125 (39,608) | 11.08% | drift |
| wrapped text (API setup) | home-wrapped | 0.0253 (80,036) | fail | 0.0128 (40,618) | 13.29% | drift |
| wrapped text (API setup) | thread-wrapped | 0.0228 (72,197) | fail | 0.0141 (44,688) | 12.65% | drift |
| wrapped text (API setup) | profile-wrapped | 0.0234 (74,037) | fail | 0.0157 (49,787) | 9.84% | drift |
| API setup states | home-api | 0.0402 (127,032) | fail | **0.0273 (86,373)** | 13.29% | **fail** |
| API setup states | thread-api | 0.0118 (37,212) | drift | 0.0051 (15,984) | 10.29% | pass |
| API setup states | profile-api | 0.0247 (78,185) | fail | 0.0172 (54,256) | 9.84% | drift |

Every mask area is at or below the 15% limit.

**`home-api` is the one failing screen, and the cause is measured** (difference 10 below): a feed slice
that has both a "Reposted by" reason row and a "Replied to" row is 2 px shorter in the port, and every
row below it inherits the shift. Row borders on that screen: RN 460, 645, 978, 1373, 1646, 1919, 2192;
native 460, 645, 978, 1371, 1644, 1917, 2190. A reason row on its own (`interactions`) and a
"Replied to" row on its own (`mergefeed`) both match RN at every border, so the 2 px belongs to the
combination.

**Mask checks pass.** `make_masks.py` exits 0 for all eight states: no native ink inside any mask lies
outside the RN ink area of that mask, and no native ink cluster crosses a mask edge without a matching
RN cluster. Round 2's four glyph escapes (`home-xxxl` control and info glyphs, `thread-xxxl` anchor like
glyph, `home-empty` info glyph) are gone (review findings F5, F6).

**Events:** ordered MATCH, 19 of 19, against the RN list derived from source (see "Event diff").

**Tests:** `xcodebuild … test` → 127 tests in 19 suites passed. Release build: `BUILD SUCCEEDED`.

**Native error states** (no RN equivalent): `home-error`, `home-load-more-error`, `thread-error`,
`profile-error`, captured by `capture-errors-native.yml`.

## How the numbers were made

One Maestro flow drives both apps (`parity/flows/`); `LABEL` selects the app.

1. Capture one state in both apps in the same run, under one seed lock:
   ```
   cd ios/parity
   ./run-pair.sh base     # also: dark, xxxl, empty, mergefeed, interactions, wrapped, api
   ./run-capture.sh native errors
   ```
   - `run-pair.sh` holds `/tmp/bsky-seed.lock` for both apps. The RN app seeds; the native app runs on the
     same seed (`RESEED=false`), so both show the same posts and timestamps. `interactions` likes and
     reposts, so each app seeds its own data.
   - `wrapped` and `api` add `flows/setupApi.js` after the seed. It writes records through the PDS XRPC
     API (`com.atproto.repo.createRecord`, `putRecord`) and then polls `app.bsky.feed.getTimeline`
     through the AppView until the new rows are indexed, so a flow never launches before the data exists.
   - `run-capture.sh` runs `migration-pack/skills/check-parity/scripts/capture.mjs` with `--env` for
     `SEED`, `SUFFIX` and `RESEED`, sets dark appearance or `extra-extra-extra-large` content size for
     those states, and overrides the status bar with `--time 9:41`.
   - For the native app it copies `Documents/events.jsonl` and writes `events.normalized.jsonl`.
2. Build masks from the RN image (and fixed slots), checked against the native image:
   ```
   python3 make_masks.py masks-spec.json <state> out/<state>/rn/ios out/<state>/native/ios masks/<state>.json
   ```
3. Diff raw and masked:
   ```
   node <pack>/skills/check-parity/scripts/diff.mjs --rn out/<state>/rn/ios --native out/<state>/native/ios --out out/<state>/diff-raw
   node <pack>/skills/check-parity/scripts/diff.mjs --rn out/<state>/rn/ios --native out/<state>/native/ios --out out/<state>/diff-masked --mask masks/<state>.json
   ```

New RN baselines from this run, as new files (no baseline is overwritten), in `parity/baseline/rn/`:
`ios-home-r3.png`, `ios-thread-r3.png`, `ios-profile-r3.png`, `ios-home-dark-r3.png`,
`ios-thread-dark-r3.png`, `ios-profile-dark-r3.png`, `ios-home-xxxl-r3.png`, `ios-thread-xxxl-r3.png`,
`ios-profile-xxxl-r3.png`, `ios-home-empty-r3.png`, `ios-profile-empty-r3.png`,
`ios-home-mergefeed-r3.png`, `ios-home-liked-reposted-r3.png`, `ios-thread-liked-reposted-r3.png`,
`ios-home-wrapped-r3.png`, `ios-thread-wrapped-r3.png`, `ios-profile-wrapped-r3.png`,
`ios-home-api-r3.png`, `ios-thread-api-r3.png`, `ios-profile-api-r3.png`.

## Masks

Masks follow `check-parity/references/masking.md`. `make_masks.py` never widens a mask from the native
image, and it now checks the native image in three ways (review finding F5):

1. Native ink inside any app mask must lie in the RN ink area of that same mask: the RN ink box widened
   by 4 px. For `tail` and `datetime` slots, where the clock text changes width, the area is the slot's
   columns and the RN ink rows widened by 4 px. Native ink in a mask with no RN ink, or outside that
   area, is an error. Every mask kind is checked and ink of any width counts.
2. A native ink cluster of any width that is partly inside and partly outside a mask is an error, unless
   RN has a cluster with the same box (within 4 px) or the ink lies inside the union of the masks it
   touches (a glyph split over two rects, such as the bell beside the badge).
3. A screen more than 15% masked is an error.

The `status` mask is measured too, but reported as a note, not an error: iOS draws that ink (the clock,
overridden to 9:41, and the "◀ <previous app>" back breadcrumb, which names whichever app Maestro
launched before).

| Kind | What it hides | Reason |
|---|---|---|
| `status` | y 0 to 180 px | Status bar: clock, battery, signal, system back breadcrumb |
| `glyphs` | A fixed icon slot centred on each RN glyph: 54 px (feed controls, 18pt), 66 px (anchor controls, 22pt), 72 px (header and composer, 24pt), 48 px (profile share and more); the ink box plus 4 px for the info and empty-state glyphs. Counts next to icons stay visible. `maxw` keeps non-glyph shapes (the FAB circle overlapping the last xxxl control row) unmasked | Licence substitution: Lucide glyphs for the Central icon set (ASSETS.md section 2) |
| `tail` | A 150 px slot from the RN "·" of a post meta line | The relative time follows the capture clock |
| `datetime` | A 150 px slot over the anchor time digits, `interactions` only | Each app seeds its own data in that state. The date and the who-can-reply label stay visible (review finding N17) |
| `rect` | The header logo slot, the thread anchor logo slot, the FAB glyph, the bottom bar glyphs | Licence substitution |

The bell is masked by two rects that leave the unread badge visible (review finding F5): one below the
badge (`[785, 2462, 885, 2506]`) and one to its left (`[785, 2414, 838, 2462]`). RN badge ink measures
x 839-892, y 2403-2460, so no mask covers it.

Not masked: avatars, counts, badges, names, handles, post text, the anchor date line and who-can-reply
label (except the `interactions` time digits), buttons, borders and backgrounds. The `wrapped` and `api`
specs were generated by measuring the RN image only: a `tail` band for each post meta line and a
`glyphs` band for each control row, matched by the post-controls x signature so no text row is masked.

**Clock (review finding N14).** The capture clock cannot be frozen for the RN app: the e2e build has no
clock mock (`src/env/common.ts:32` `IS_E2E` changes no time code; `tick-every-minute.tsx:9,12` reads
`Date.now()`), and `simctl` cannot set the simulator date. The `tail` slots therefore stay.

## Noise floor

Two native captures of the final build, taken under one seed lock so both run on the same seed
(`out/base` and `out/base2`), diffed with the same masks:

```
node <pack>/skills/check-parity/scripts/diff.mjs --rn out/base/native/ios --native out/base2/native/ios --out out/noise/raw
node <pack>/skills/check-parity/scripts/diff.mjs --rn out/base/native/ios --native out/base2/native/ios --out out/noise/masked --mask masks/base.json
```

| Screen | Raw (px) | Masked (px) |
|---|---|---|
| home | 0.0032 (10,221) | 0 |
| thread | 0.0017 (5,425) | 0 |
| profile | 0.0017 (5,386) | 0 |

The raw noise is the relative times. The masked noise floor is 0 px on all three screens, so every
masked ratio in the table above is signal, not capture noise.

## Line boxes (review finding F7)

`RNTextStyleModifier` (`DesignSystem/Typography.swift`) sets `lineSpacing` from the **unrounded** font
height, so each line advances exactly `lineHeight`, as RN's paragraph style does
(`RCTAttributedTextUtils.mm:229-232`; `RCTTextLayoutManager.mm:361-394` measures the box as
`ceil((n * L + 0.001) * scale) / scale`). With the previous pixel-rounded value the pitch was 19.82pt
for `text_md` at `leading_snug`, and wrapped text lost 1 px per extra line.

A three-line post was created through the PDS API before the capture (`flows/setupApi.js`) and captured
in both apps:

| Measurement | RN | Native |
|---|---|---|
| Feed row borders (`home-wrapped`, x 1170) | 460, 645, 1038 | 460, 645, 1038 |
| Feed row height (3 lines) | 393 px | 393 px |
| Text line ink rows | 750-793, 810-853, 870-904 | 750-793, 810-853, 870-904 |
| Thread anchor borders (`thread-wrapped`) | 329, 955 | 329, 955 |
| Anchor line pitch (`text_lg`, wrapped) | 67 px | 67 px |

Wrapped text is therefore n x `lineHeight` in both apps, and single-line parity is unchanged (the base,
dark, mergefeed and interactions numbers above are all at or below the 0.02 threshold). Two differences
remain: the wrapped anchor block sits 2 px higher in the port (difference 11), and a line height below
the font's natural height still cannot shrink the pitch (A57), which no captured state exercises.

Per-component constants in `RNLineBox` remain, fitted to the iPhone 17 Pro at 3x and not verified on a
2x device (difference 12).

## Event diff

**Result: ordered MATCH, 19 of 19 events, for `flows/capture.yml`.**

```
python3 events/normalize_events.py out/base/native/ios/events.jsonl > out/base/native/ios/events.normalized.jsonl
node <pack>/skills/check-parity/scripts/events.mjs --rn events/rn-expected-base.jsonl \
  --native out/base/native/ios/events.normalized.jsonl --ignore initMs,secondsActive --ordered
MATCH (ordered): rn 19 event(s), native 19 event(s), ignoring initMs, secondsActive
```

The two native runs of the same flow also match each other ordered (`out/base` against `out/base2`).

**The RN side is derived from source, not captured (review finding F8).** Two attempts:

1. The e2e build prints metrics to the Metro log only at debug level for the `metric` context
   (`src/analytics/metrics/client.ts:15,67`), and the upstream `.env` sets `EXPO_PUBLIC_LOG_DEBUG=session`
   (`src/logger/index.tsx:43-45,115-121`). The Metro inspector WebSocket closed with code 1006 on every
   attempt, so the JS runtime could not be read either.
2. A throwaway copy of the upstream checkout was made outside the repository, with only
   `EXPO_PUBLIC_LOG_DEBUG=metric` changed, and its own Metro started on port 8082 in e2e mode with a
   separate `TMPDIR` (the iOS bundle built there, 6504 modules). The installed e2e app is an Expo dev
   client (`EXDevLauncher.bundle`, scheme `exp+bluesky`), so the flow opened
   `exp+bluesky://expo-development-client/?url=http%3A%2F%2Flocalhost%3A8082` after a clean launch. **The
   app did not switch:** the 8082 Metro logged no bundle request during the run, and the simulator kept
   only connections to 8081. Moving the app to the other Metro needs the dev menu by hand or an e2e app
   rebuilt against port 8082, which is a native rebuild. The attempt stopped inside its time box, and
   the upstream checkout was not modified.

**Order points that are derived, not observed** (these need owner acceptance):

- Entries 12 and 13: the anchor `post:view` runs on the cached placeholder anchor
  (`PostThread/index.tsx:95-112`) before `router:navigate`, because `onStateChange` runs in the
  container's `useEffect` (`BaseNavigationContainer.tsx:322-399`) and React runs child effects first.
- Entries 15 and 16: on swipe back, Home's `useFocusEffect` (`Home.tsx:175-186`) sends
  `home:feedDisplayed` before the container's `router:navigate {from: "PostThread"}`.
- The pager sends `home:feedDisplayed` with `reason: "focus"` on first mount, with no separate
  `reason`-less event (`Home.tsx:188-205`).
- `thread:preferences:load` is not sent in this flow: Home loads preferences first, and RN sends the
  metric only when preferences arrive or change after the thread mounts (`useThreadPreferences.ts:33-71`).

| # | Event | RN source |
|---|---|---|
| 1-2 | `router:navigate {}`, `init` (logged-out launch) | `src/Navigation.tsx:1012-1035` |
| 3 | `account:loggedIn` | `src/state/session/index.tsx:325-329`; `TestCtrls.e2e.tsx:30-37` |
| 4-5 | `router:navigate {}`, `init` (shell remount) | `App.tsx:150-152`; `Navigation.tsx:955` |
| 6 | `home:feedDisplayed {reason: "focus"}` | `Home.tsx:175-186` |
| 7-10 | feed `post:view`, positions 0-3 | `PostFeed.tsx:1081-1099` |
| 11 | `post:clickthroughItem` (bob "Thread root") | `PostFeedItem.tsx:248-259` |
| 12 | anchor `post:view {logContext: "Post"}` | `PostThread/index.tsx:95-112` |
| 13 | `router:navigate {from: "Home"}` | `Navigation.tsx:1059-1067` |
| 14 | reply `post:view {logContext: "PostThreadItem"}` | `index.tsx:595-600`; `usePostViewTracking.ts:21-29` |
| 15-16 | `home:feedDisplayed`, `router:navigate {from: "PostThread"}` (swipe back) | `Home.tsx:175-186`; `Navigation.tsx:1066` |
| 17-18 | `nav:click {item: "profile"}`, `router:navigate {from: "Home"}` | `BottomBar.tsx:99`; `Navigation.tsx:1066` |
| 19 | profile feed `post:view`, position 0 | `PostFeed.tsx:1092`; `Profile.tsx:436` |

`normalize_events.py` resolves `authorDid` to a handle and each post `uri` to `<handle>|<text>` through
the PDS, so the diff checks that each event names the right post. It drops no event; only `initMs` and
`secondsActive` (timing) are ignored.

Not in the base flow, with unit tests: `post:like`, `post:unlike`, `feed:refresh`, `feed:endReached`,
`thread:preferences:load`, `thread:click:showOtherReplies`, `link:clicked` (`LinkRouter`).
`post:clickthroughAuthor` is sent only from the anchor avatar (review finding N1).

## States covered

| State | RN | Native | Evidence |
|---|---|---|---|
| Home, thread, profile (light) | yes | yes | table above; swipe back from the thread asserted in `capture.yml` (N16) |
| Dark (system dark: RN uses dim) | yes | yes | table above |
| Largest Dynamic Type | yes | yes | table above |
| Empty seed (`?users`) | yes | yes | table above |
| Mergefeed seed: "Replied to" rows, self replies, thread lines | yes | yes | `capture-mergefeed.yml` |
| After like and repost | yes | yes | `capture-interactions.yml` |
| Wrapped post text (3 lines, feed and anchor) | yes | yes | `capture-wrapped.yml`, "Line boxes" above (review finding F7) |
| Repost reason row ("Reposted by Bob") | yes | yes | `capture-api.yml`, `home-api` (review finding F9) |
| Post facets (mention, link, tag) | yes | yes | `capture-api.yml`, `home-api` |
| Profile bio facets | yes | yes | `capture-api.yml`, `profile-api` (review finding F4) |
| Replies disabled by a threadgate | yes | yes | `capture-api.yml`, `thread-api`: the anchor is the gated root. Neither app exposes the who-can-reply label or the reply pill as text to XCUITest, so the state is proven by the captured pixels, not by an assertion. Unit test: `ThreadTests.canReplyFollowsTheAnchor` |
| First-load, load-more, thread and profile errors | no | yes | RN has no fault control and the shared server must not be stopped. Unit tests: `FeedModelTests`, `ThreadTests.failureThenRetry`, `ProfileAndUnreadTests.profileErrorScreen` |
| Loading skeletons, preferences failure | no | no | Loads finish before a screenshot. Unit tests: `ThreadTests.placeholderShowsAnchorAndReplySkeletons`, `ThreadTests.preferencesFailureKeepsThePlaceholder` (review finding F3) |
| Not found, tombstones, other replies | no | no | No seed or API step creates them without changing upstream. Unit tests: `ThreadTests.notFoundAnchorRendersTombstone`, `tombstonesStopTheParentWalkAndSkipReplyBranches`, `hiddenRepliesGoToTheOtherBucket` |
| Load more after 30 posts, pull to refresh | no | no | A screenshot after scrolling is not deterministic. Unit tests: `FeedModelTests.loadMoreFailureKeepsPagingAndOffersRetry`, `refreshFailureWithRowsShowsRetryRow` |
| Link long press (share) | no | no | A context menu is not captured by Maestro. Unit tests: `LinkRouterTests.longPressSharesLinks`, `richTextOffersShareOnlyForValidLinks` (review finding F13) |

## Screen test ids (review finding F2)

`maestro --device 7F73AB4A-2709-4033-89D2-35CE10E650F4 hierarchy`, run on the signed-in app, now shows
every RN screen id together with the ids the capture flows use:

| Id | Exposed | Where it sits in the port |
|---|---|---|
| `HomeScreen` | yes | the home tab's hosting `NavigationStack` (`TabShell.swift`) |
| `homeScreen` | yes | its own container in `HomeScreen.swift` |
| `followingFeedPage` | yes | its own container in `HomeScreen.swift` |
| `followingFeedPage-feed`, `-feed-flatlist` | yes | the scroll view and its stack |
| `profileScreen` | yes | its own container in `ProfileScreen.swift` |
| `profileView` | yes | its own container inside it |
| `postsFeed`, `postsFeed-flatlist` | yes | the profile scroll view and the feed |

What was measured on the way: identifiers stacked on one resolved SwiftUI view collapse into the
outermost one, and a container whose content resolves to a single accessibility element is merged into
that element. A container with a **second child** (a zero-size view that is an ignored accessibility
element) stays a separate element. A hidden second child (`accessibilityHidden(true)`) does not work,
and neither does putting two ids in one modifier chain.

## Differences that remain

None of these is accepted. Each needs a named owner.

| # | Difference | RN | Native | Parity check |
|---|---|---|---|---|
| 1 | UI icons | Central icon set | Lucide glyphs, fitted to the RN ink box per glyph (`IconGlyph.inkFit`) | `glyphs` slots; `make_masks.py` exits 0 on all states; `IconFitTests` |
| 2 | Logo and anchor mark | Butterfly mark | Neutral diamond; empty anchor slot | `rect` masks |
| 3 | Default avatar figure | Bluesky artwork | Generic silhouette in the same blue | Not masked; counted |
| 4 | Header hide on scroll | Drag-driven with a snap on drag end | Follows the scroll delta; no snap | Not captured |
| 5 | Bottom bar minimal-shell transform | `footerMode` translate and fade | No transform; no screen in the slice enables minimal shell (N4) | Not applicable to the slice |
| 6 | Sign-out | Clears tokens | Also calls `com.atproto.server.deleteSession` with the newest refresh token | Unit tests |
| 7 | `post:view` visibility | 40% visible for 500 ms | Row laid out for 500 ms | Event diff |
| 8 | Tab roles | `accessibilityRole="tab"` | Buttons with the selected trait | Not measured |
| 9 | E2E controls | 12 controls at top 100, right 0 | The same 12, plus 5 native-only fault controls at top 100, left 0 | 15 px at the left edge, not masked |
| 10 | Feed slice with a reason row **and** a "Replied to" row | 395 px tall (`home-api`, borders 978 to 1373) | 393 px; every row below shifts up 2 px | `home-api` masked 0.0273, the one failing screen. A reason row alone (`interactions`) and a "Replied to" row alone (`mergefeed`) match RN at every border |
| 11 | Wrapped anchor text block | ink rows 557, 624, 691 (`thread-wrapped`) | 555, 622, 689: same pitch, 2 px higher | Row borders match (329, 955); counted |
| 12 | Line boxes | RN text layout | Rule for the line pitch; per-component constants fitted to one 3x device, not verified at 2x | F7 above; A57 open |
| 13 | Release build | Production app | Smoke build: no sign-in form, local networking allowed, no event log | Release `build` |
| 14 | Tag and other-user taps | Hashtag screen, other profiles | "Not part of this showcase" | Behaviour only |
| 15 | Tabs container | RN tab navigator | `ZStack` of per-tab `NavigationStack`s | Pixel diff |
| 16 | Thread tree view | Labs preference | Linear view only; the metric logs the server value | Proposed out of scope |

The proposed out-of-scope rows in `plan/slice-plan.md` also await owner acceptance.

## Fixed since review round 2

| Finding | What changed | Evidence |
|---|---|---|
| F2 | Screen ids exposed on their own containers | "Screen test ids" above |
| F3 | A preferences failure keeps the placeholder anchor and reply skeletons | `ThreadTests.preferencesFailureKeepsThePlaceholder` |
| F4 | Profile bio facets detected and resolved | `RichTextDetectionTests`; `profile-api` |
| F5 | All native ink inside every mask checked; bell rects clear the badge | `make_masks.py` exits 0 on eight states |
| F6 | Lucide glyph ink fitted to the RN boxes; control cells top-aligned as RN | `IconFitTests`; no escapes at xxxl |
| F7 | Wrapped text advances by `lineHeight` | "Line boxes" above |
| F9 | Reason rows, facets, bio facets and a threadgate captured in both apps | `capture-api.yml` |
| F10 | Only `threadViewPrefs` compared; stale preferences refetched after 15 s | `ThreadTests.stalePreferencesRefetchAndCompareOnlyThreadViewPrefs` |
| F11 | The counts in this report are generated from `results.json`, not written by hand | table above |
| F12 | Reply-prompt border moved up 2 px | RN and native borders now both at y 2275-2278 and 2344-2347 |
| F13 | Long press on a link shares it, with the RN warning flow | `LinkRouterTests.longPressSharesLinks` |

Two port bugs were found by the new captures and fixed:

- `dedupThreads` did not record a repost's thread root, so a reposted reply was followed by that
  reply's own thread (`FeedTunerTests.repostedReplyHidesItsThreadSlice`).
- Post control cells centred instead of top-aligning, which moved the xxxl glyphs
  (`PostControls`, RN `PostControls/index.tsx:218,255,265`).

## Corrections to earlier claims

- Round 2 said "same sizes" for the Lucide glyphs (old row 1). Wrong: six glyphs measured larger or
  offset against RN. They are now fitted per glyph and the claim is replaced by the `IconFitTests`
  measurement.
- Round 2's mask check only looked at `glyphs`, `tail` and `datetime` bands and only at clusters at
  least 36 px wide. It therefore missed native-only ink in `rect` masks and narrow ink.
- Round 2 reported a masked `thread` ratio of 0.0092 and 3 pass / 12 drift over 15 screens. This report
  measures 20 screens on a newer build; the counts are not comparable line by line.

## Pack tools used, and problems found

| Tool | Result |
|---|---|
| `capture.mjs --env` | Works; `run-capture.sh` passes `SEED`, `SUFFIX` and `RESEED` through it |
| `diff.mjs`, `events.mjs --ordered` | Worked as documented |
| `maestro hierarchy` | Worked; it is the only way to see which SwiftUI containers stay separate elements |
| Maestro text matching | RN does not expose the reply pill or the who-can-reply label as text to XCUITest, and a `notVisible` check on such text passes without proving anything. Flows use ids (`postThreadItem-by-<handle>`, `likeCount-expanded`) instead |
| Maestro `runScript` | Used for the API setup. A setup that writes records must wait for the AppView to index them, or the flow launches before the data exists |
