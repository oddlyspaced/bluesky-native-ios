# Parity report (iOS): RN app vs native SwiftUI port

- Captures: 2026-09-16 (review round 3 fixes; every number below is from captures made on this date).
- Numbers: re-measured 2026-10-21 from those same captures, after the comparator was corrected
  (see "Comparator correction" below). ImageMagick 7.1.2-32 Q16-HDRI.
- Device: iPhone 17 Pro simulator, iOS 26.4 (`7F73AB4A-2709-4033-89D2-35CE10E650F4`), 1206x2622 px at 3x.
- RN build: the upstream e2e app `xyz.blueskyweb.app` (`bluesky-social-app` at `2bfb94d`, Metro in e2e mode
  on port 8081).
- Native build: Debug `NativeShowcase` at commit `49b3e80`, installed once and used for every capture.
- Server: the upstream dev network (PDS `http://localhost:3000`, seed manager `http://localhost:1986`,
  AppView DID `did:plc:bw7ad3erl7btq6qwf66yqiov`).
- **Acceptance: awaiting owner acceptance.** No difference in this report is accepted. No acceptor is named.

## Verdict

**With masks: 2 pass, 17 drift, 1 fail. Raw: 14 of 20 screens fail, 6 drift.**
Each drift and the fail need a written sign-off by a person who did not write the port
(`check-parity/references/thresholds.md`); none is signed.

Masked ratio = differing pixels after masks / 3,162,132, threshold 0.02, fuzz 5% (`diff.mjs` defaults).

| State | Screen | Raw ratio (px) | Raw status | Masked ratio (px) | Mask area | Masked status |
|---|---|---|---|---|---|---|
| base | home | 0.0275 (86,808) | fail | 0.0144 (45,515) | 13.54% | drift |
| base | thread | 0.0171 (54,190) | drift | 0.0099 (31,261) | 10.63% | pass |
| base | profile | 0.0179 (56,658) | drift | 0.0113 (35,799) | 9.10% | drift |
| dark | home-dark | 0.0277 (87,690) | fail | 0.0148 (46,916) | 13.54% | drift |
| dark | thread-dark | 0.0176 (55,599) | drift | 0.0101 (31,930) | 10.63% | drift |
| dark | profile-dark | 0.0168 (53,097) | drift | 0.0113 (35,716) | 9.10% | drift |
| largest Dynamic Type | home-xxxl | 0.0319 (100,715) | fail | 0.0177 (56,118) | 13.41% | drift |
| largest Dynamic Type | thread-xxxl | 0.0238 (75,341) | fail | 0.0162 (51,184) | 10.71% | drift |
| largest Dynamic Type | profile-xxxl | 0.0254 (80,357) | fail | 0.0186 (58,700) | 9.12% | drift |
| empty seed | home-empty | 0.0260 (82,098) | fail | 0.0194 (61,480) | 9.60% | drift |
| empty seed | profile-empty | 0.0200 (63,096) | drift | 0.0120 (37,905) | 9.00% | drift |
| mergefeed seed | home-mergefeed | 0.0232 (73,379) | fail | 0.0102 (32,208) | 13.38% | drift |
| after like and repost | home-liked-reposted | 0.0273 (86,263) | fail | 0.0144 (45,610) | 13.54% | drift |
| after like and repost | thread-liked-reposted | 0.0213 (67,264) | fail | 0.0137 (43,187) | 10.88% | drift |
| wrapped text (API setup) | home-wrapped | 0.0262 (82,827) | fail | 0.0134 (42,375) | 13.29% | drift |
| wrapped text (API setup) | thread-wrapped | 0.0236 (74,533) | fail | 0.0173 (54,636) | 10.12% | drift |
| wrapped text (API setup) | profile-wrapped | 0.0241 (76,313) | fail | 0.0163 (51,451) | 9.84% | drift |
| API setup states | home-api | 0.0416 (131,669) | fail | **0.0281 (88,948)** | 13.29% | **fail** |
| API setup states | thread-api | 0.0125 (39,464) | drift | 0.0059 (18,654) | 10.09% | pass |
| API setup states | profile-api | 0.0254 (80,376) | fail | 0.0178 (56,345) | 9.84% | drift |

Every mask area is at or below the 15% limit.

**Comparator correction, 2026-10-21.** Every ratio in this table was re-measured, because the tool
that produced the first set was reading a number that had stopped meaning what it said. `diff.mjs`
took its differing-pixel count from `magick compare -metric AE`. On ImageMagick 7.1.2-32 that is no
longer a pixel count but a sum of normalised per-channel magnitudes: a 40x40 red rectangle over
white, which is 1600 differing pixels, reports `AE = 800`, and the same rectangle in
`rgb(254,254,254)` reports `AE = 4.71`. The Pack now counts the pixels itself and records the
ImageMagick build in `results.json`; see the Pack commit "Count differing pixels instead of reading
magick's AE metric".

The first set of numbers was measured on the older ImageMagick, which was close to correct, so the
ratios moved only a little, by 2 to 20% of their own value. **Two verdicts changed, both to the
worse side:** `thread-dark` 0.0096 pass to 0.0101 drift, and `home-mergefeed` 0.0097 pass to 0.0102
drift. Both crossed the pass/drift line at 0.01, so the masked count goes from 4 pass, 15 drift to
2 pass, 17 drift. `home-api` stays the one fail, 0.0273 to 0.0281: the blocker is real and is not an
artefact of the tooling.

This also retires the † footnote that stood here. It marked six thread rows whose ratios came from
an earlier mask-narrowing pass rather than from a measurement, and whose pixel counts and mask areas
had been measured with the older, wider bands. Every row above is now measured in one pass, from the
committed masks in `ios/parity/masks/`, so no row is second-hand and none is marked.

**`home-api` is the one failing screen. What is measured, and what was tried.**

A feed slice that carries both a "Reposted by" reason row and a "Replied to" row measures 393 px in the
port against RN's 395 px. Row borders: RN 460, 645, 978, 1373, 1646, 1919, 2192; native 460, 645, 978,
1371, 1644, 1917, 2190. Every row below the slice inherits the 2 px shift, which is most of the 88,948
differing pixels.

The 2 px is **not** in the reason block: the reason row starts at y 1013 in both apps, and the gap from
its bottom to the first content row is 22 px in both. It is two separate 1 px losses further down the
same slice: the meta line to the "Replied to" row (RN 66 px, native 65) and the controls to the row end
(RN 79 px, native 78).

A rule-based fix was written and then reverted. The reason block's height was taken from the laid-out
view, composing it as RN does (`pt_sm` on the wrapper, `PostFeedItem.tsx:376`; `marginBottom: 2` in
`PostFeedReason.tsx` `styles.includeReason`; the label's own line box) instead of the constant
`17 + Space._2xs`. The capture was byte-identical, 393 px and 0.0281 masked, so the constant was not the
cause, and the change was removed rather than committed as a fix.

A constant cannot close the remaining 2 px without breaking the screens that match today. The same two
gaps are exact whenever only one header is present: `mergefeed` (a "Replied to" row, no reason row) is
273 px in both apps with identical row borders, and `interactions` (a reason row, no "Replied to" row)
is 185 px in both. Adding a pixel to either gap would make those screens 1 px long, trading one failing
screen for two regressions. The residue is sub-pixel accumulation in the stacked small-text line boxes
(the open A57 and A19 item), not a wrong value.

**This screen therefore stays a `fail` and the checkpoint stays open.** A fail is never signed off
(`check-parity/references/thresholds.md`); only drift can be accepted in writing.

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

## Verified without a capture (review round 3 fixes)

The test server was only partly up during this pass: the AppView's ports 2584 and 3003 were closed
and its Postgres and Redis were down. No capture, no Maestro run and no new parity number was made
in this pass. Every claim in this section rests on `xcodebuild … test` alone, not on pixels and not
on a live gesture. The numbers in the tables above are unchanged and still come from the
2026-09-16 captures made before this pass.

| Finding | Verified by a test | Not verified |
|---|---|---|
| A63 swipe back | `InteractivePopTests`: the proxy refuses the pop at the root of a stack and allows it once a screen is pushed; every other `UIGestureRecognizerDelegate` message reaches the delegate it replaced; a disabled gesture is re-enabled; a second install reuses the proxy instead of wrapping it; the representable's controller reaches its own stack; a second `UINavigationController` in the process keeps its own delegate | That a real swipe pops the screen. The last live measurement is the Maestro swipe step on iOS 26.4 (`flows/capture.yml`), made against the previous implementation. The new one re-enables the gestures from its own screen's layout and one main-queue turn later, not from the navigation controller's own layout pass, so `./run-pair.sh base` must run again before swipe back can be claimed as measured |
| A64 screen ids | `ScreenIdentifierTests`: the shell takes the home stack's id from `ScreenRegistry`, a root registered without an id leaves its stack unlabelled, and the five ids hold RN's values. `parity/flows/capture.yml` now asserts all five with `assertVisible` | That a screen still exposes its id at runtime. **No unit test can read this.** SwiftUI answers accessibility for an out-of-process client (XCUITest, and `maestro hierarchy` through it) and does not fill in `UIView.accessibilityElements` or `accessibilityElementCount()` in process. Measured: a `UIHostingController` holding `HomeScreen` and `ProfileScreen`, in a scene-backed `UIWindow`, laid out and flushed through `CATransaction`, renders its `HostingScrollView` and reports zero accessibility children and zero identifiers. The `assertVisible` steps are therefore the only check that catches a removed id, and they need `./run-pair.sh base` |
| A69 unlabeled spacers | Nothing. **Not fixed.** | Each of the four screen ids on Home and Profile sits on a container whose second child is a zero-size view marked `accessibilityElement(children: .ignore)`, and each of those children is its own unlabeled accessibility element. The fix needs the same out-of-process tree read that round 2 used (`maestro hierarchy`) to confirm the ids stay exposed afterwards: the round-2 measurement in "Screen test ids" records that a hidden second child does **not** keep the container separate, and that two ids in one modifier chain collapse. Changing the structure without that measurement would risk the F2 result, which is measured and passing, so it was left alone and recorded here. To close it: run `maestro --device <udid> hierarchy` on the signed-in app, try a second child that is not an accessibility element, and keep whichever form still shows all five ids |
| A71 shell tab check | `ScreenIdentifierTests.theShellTakesTheHomeStackIdFromTheRegistry` and `onlyARegisteredIdentifierLabelsAStack`. `TabShell` now reads `registry.rootIdentifier(for:)` and names no tab | Nothing further; this one needs no capture |
| A84 overlapping preference guards | Nothing. **Not fixed.** | The review's Minor list gives this finding as a phrase with no file, line or evidence path, and the preference guards are spread over `PreferencesModel.load`, `fetch`, `loadOrDefaults` and `isStale`, and `ThreadModel.load`. Which overlap was meant is ambiguous, and changing a guard blind would alter when the app refetches preferences, which the F10 stale-time work measured. It is recorded here rather than guessed at. A84 needs the reviewer to name the two guards |
| A55, A66, A67, A68, A70, A72, A78, A82, A83, A85, A86, A87 | The test suite. Each is named in its commit message and has at least one test asserting the new behaviour | Nothing; none of these needs a capture |

## The E2E build and Release are different binaries (review finding A65)

Review finding A60 moved the event log behind `#if E2E`, so **Release emits no events at all**. Every
event-parity claim in this report was therefore produced by a binary that is not the shipping one.
This section names every difference. None of it is softened: the event evidence describes the E2E
build, and it is not evidence about Release.

| What differs | E2E build (Debug) | Release | Where |
|---|---|---|---|
| Analytics sink | `JSONLinesEventLog`, appending to `Documents/events.jsonl` | `NoopAnalytics`, which discards every event | `App/App.swift:56-62`; `Core/Analytics/Analytics.swift:54,113` |
| Fault hook | `DebugFaults.arm` and its storage compile; five faults can be armed | `consume` folds to a constant `false`; no fault can be injected | `Features/Shell/ShellSupport.swift:97-111` |
| Service URL | `AppConfig.e2eService` = `http://localhost:3000`, the dev network | The constant does not exist; the app has no service to sign in to | `App/AppConfig.swift` |
| AppView proxy DID | `did:plc:bw7ad3erl7btq6qwf66yqiov#bsky_appview` | `did:web:api.bsky.app#bsky_appview` | `App/AppConfig.swift` |
| Sign-in path | `E2ETestControls` signs in as alice or bob with one tap | No sign-in form and no controls; the app stops at the signed-out screen | `App/RootView.swift`; `README.md` |
| `.test` handles | Linkified as mentions, so the dev network's handles render as RN's do | Left as plain text, matching the SDK | `App/AppConfig.swift`; review finding A67 |
| Compilation condition | `SWIFT_ACTIVE_COMPILATION_CONDITIONS: DEBUG E2E` | Neither is set | `ios/project.yml:46-49` |

**What this costs the event-parity claims.**

1. The "ordered MATCH, 19 of 19" result cannot be reproduced on Release, by construction, because
   Release records nothing. There is no Release event log to diff, now or ever, while A60 stands.
2. The events were produced against a different AppView proxy DID and a different service URL, so
   the data that drove them came from a different backend than Release would talk to.
3. Events 3 to 5 (`account:loggedIn`, then the shell remount's `router:navigate` and `init`) are
   reached through a sign-in path that does not exist in Release. Release has no way to reach the
   signed-in shell at all, so it can never produce entries 3 to 19.
4. The four native-only error captures (`home-error`, `home-load-more-error`, `thread-error`,
   `profile-error`) use a fault hook that Release does not compile, so they describe states a
   Release build cannot be driven into by the same route.
5. Since A67, one behaviour differs between the two builds on purpose: `.test` mentions linkify in
   the E2E build only. Any captured screen showing a `.test` mention as a link shows E2E behaviour.

**Therefore:** every event result in this report is scoped to the E2E build. No row in "Event diff"
should be read as a statement about the shipping binary. The honest summary is that event parity is
demonstrated for a build that differs from Release in seven named ways, and that Release's event
behaviour is not measured, because there is nothing to measure.

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
| 10 | Feed slice with a reason row **and** a "Replied to" row | 395 px tall (`home-api`, borders 978 to 1373) | 393 px; every row below shifts up 2 px | `home-api` masked 0.0281, the one failing screen. The loss is 1 px in the meta to "Replied to" gap (RN 66, native 65) and 1 px in the controls to row-end gap (RN 79, native 78); the reason block matches. A reason row alone (`interactions`, 185 px in both) and a "Replied to" row alone (`mergefeed`, 273 px in both) match RN exactly, so no constant closes it without regressing them |
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

## The `home-api` failure: measured cause (2026-09-16)

`home-api` stays a **fail** at 0.0281 masked. The checkpoint stays open. Two attempts were
made and both were reverted; neither is presented as a fix.

**What matches.** The reason block ("Reposted by") starts at y 1013 in both apps, and the gap
from its bottom to the first content row is 22 px in both. A slice with only a reason row
(`interactions`) is 185 px in both apps. A slice with only a "Replied to" row (`mergefeed`) is
273 px in both, with identical borders.

**What differs.** Only a slice carrying both headers: 395 px in RN against 393 px in the port.
The loss is two separate 1 px gaps: meta to "Replied to" (RN 66, native 65) and controls to row
end (RN 79, native 78).

**Attempt 1, constant composition (reverted).** RN composes the reason block as `pt_sm` on the
wrapper (`PostFeedItem.tsx:376`) plus the label's line box plus `marginBottom: 2`
(`PostFeedReason.tsx`). The port used a constant. Replacing it with the block's laid-out height
produced a byte-identical capture: 393 px, 0.0281. The constant was not the cause.

**Attempt 2, RN's paragraph model (not viable in SwiftUI).** RN sets
`paragraphStyle.minimumLineHeight = maximumLineHeight = lineHeight`
(`RCTAttributedTextUtils.mm:229-233`) and a baseline offset (`:300-339`). A probe showed SwiftUI
`Text` ignores `NSParagraphStyle` carried in an `AttributedString`: at lineHeight 17 over three
lines, UIKit `boundingRect` gives 51.0 px (3 x 17) while SwiftUI gives 54.67 px either way. Only
`baselineOffset` survives, and it grew the single-line box by 1 pt, which would regress screens
that match today. Reaching RN's model needs a UIKit-backed text primitive
(`UIViewRepresentable`), as RN itself uses.

**Cause.** Not the line-box model. Every box in the failing slice is single-line and
pixel-snapped, and RN rounds `lineHeight` the same way (`typography.tsx:41-44`). The gaps are
correct with one header and wrong only with two, which points to Yoga's absolute-position pixel
rounding when two small-text headers stack.

**Recommended fix, not attempted here.** Replace the text primitive with a `UIViewRepresentable`
over `UITextView`/`UILabel`, so paragraph attributes and RN's rounding both apply. That is a
foundation-level change and belongs in its own checkpoint, not in a parity fix pass.

A failing screen is never signed off (`check-parity/references/thresholds.md`). This row is not
offered for acceptance.
