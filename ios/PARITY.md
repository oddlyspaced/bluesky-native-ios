# Parity report (iOS): RN app vs native SwiftUI port

- Date: 2026-09-15 and 2026-09-16 (review round 2 fixes).
- Device: iPhone 17 Pro simulator, iOS 26.4 (`7F73AB4A-2709-4033-89D2-35CE10E650F4`), 1206x2622 px at 3x.
- RN build: the upstream e2e app `xyz.blueskyweb.app` (`bluesky-social-app` at `2bfb94d`, Metro in e2e mode).
- Native build: Debug `NativeShowcase` at commit `7461701` for every capture below. Later commits change
  no captured pixel: the repost-menu haptic, error copy for errors the captures do not show, and removed
  unused code.
- Server: the upstream dev network (PDS `http://localhost:3000`, AppView DID `did:plc:bw7ad3erl7btq6qwf66yqiov`).
- **Acceptance: awaiting owner acceptance.** No difference in this report is accepted. No acceptor is named.

## Verdict

**With masks, no screen fails: 3 pass and 12 drift. Raw, 9 of 15 screens fail.**
Each drift needs a written sign-off by a person who did not write the port
(`check-parity/references/thresholds.md`); none is signed.

Masked ratio = differing pixels after masks / 3,162,132, threshold 0.02, fuzz 5% (`diff.mjs` defaults).

| State | Screen | Raw ratio (px) | Raw status | Masked ratio (px) | Mask area | Masked status |
|---|---|---|---|---|---|---|
| base | home | 0.0281 (88,903) | fail | 0.0138 (43,648) | 13.52% | drift |
| base | thread | 0.0176 (55,623) | drift | 0.0092 (29,014) | 10.82% | pass |
| base | profile | 0.0173 (54,727) | drift | 0.0109 (34,464) | 9.09% | drift |
| dark | home-dark | 0.0280 (88,440) | fail | 0.0142 (44,764) | 13.52% | drift |
| dark | thread-dark | 0.0170 (53,706) | drift | 0.0090 (28,422) | 10.82% | pass |
| dark | profile-dark | 0.0161 (50,753) | drift | 0.0108 (34,050) | 9.09% | drift |
| largest Dynamic Type | home-xxxl | 0.0316 (99,960) | fail | 0.0166 (52,558) | 13.81% | drift |
| largest Dynamic Type | thread-xxxl | 0.0240 (75,938) | fail | 0.0152 (48,073) | 11.17% | drift |
| largest Dynamic Type | profile-xxxl | 0.0248 (78,471) | fail | 0.0179 (56,695) | 9.11% | drift |
| empty seed | home-empty | 0.0260 (82,106) | fail | 0.0189 (59,830) | 9.59% | drift |
| empty seed | profile-empty | 0.0194 (61,496) | drift | 0.0116 (36,728) | 8.99% | drift |
| mergefeed seed | home-mergefeed | 0.0226 (71,570) | fail | 0.0098 (30,872) | 13.37% | pass |
| after like and repost | home-liked-reposted | 0.0278 (87,918) | fail | 0.0138 (43,738) | 13.52% | drift |
| after like and repost | thread-liked-reposted | 0.0214 (67,715) | fail | 0.0127 (40,301) | 11.07% | drift |

Every mask area is at or below the 15% limit. `thread-xxxl` was 15.85% in round 1; it is 11.17% now,
because RN and native share one seed and the anchor date line is no longer masked (review finding N18).

**Mask check failures (review finding N19).** `make_masks.py` reports native ink outside the RN-derived
slots and exits 1. The pixels stay unmasked and are counted in the ratios above:

| Screen | Native ink outside RN slots |
|---|---|
| home-xxxl | a control glyph (x 647-696, y 900-942); the fallback info glyph (x 76-175, y 2317-2374) |
| thread-xxxl | the anchor like glyph (x 550-610, y 898-949) |
| home-empty | the fallback info glyph (x 76-175, y 689-788) |

**Events:** ordered MATCH, 19 of 19, against the RN list derived from source (see "Event diff").

**Native error states** (no RN equivalent): `home-error`, `home-load-more-error`, `thread-error`,
`profile-error`, captured by `capture-errors-native.yml`.

## How the numbers were made

One Maestro flow drives both apps (`parity/flows/`); `LABEL` selects the app.

1. Capture one state in both apps in the same run (review finding N20):
   ```
   cd ios/parity
   ./run-pair.sh base     # also: dark, xxxl, empty, mergefeed, interactions
   ./run-capture.sh native errors
   ```
   - `run-pair.sh` holds `/tmp/bsky-seed.lock` for both apps. The RN app seeds; the native app runs on the
     same seed (`RESEED=false`), so both show the same posts and timestamps. `interactions` likes and
     reposts, so each app seeds its own data.
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
`ios-home-r2.png`, `ios-thread-r2.png`, `ios-profile-r2.png`, `ios-home-dark-r2.png`,
`ios-thread-dark-r2.png`, `ios-profile-dark-r2.png`, `ios-home-xxxl-r2.png`, `ios-thread-xxxl-r2.png`,
`ios-profile-xxxl-r2.png`, `ios-home-empty-r2.png`, `ios-profile-empty-r2.png`,
`ios-home-mergefeed-r2.png`, `ios-home-liked-reposted-r2.png`, `ios-thread-liked-reposted-r2.png`.

## Masks

Masks follow `check-parity/references/masking.md`. `make_masks.py` never widens a mask from the native
image (review finding N19).

| Kind | What it hides | Reason |
|---|---|---|
| `status` | y 0 to 180 px | Status bar: clock, battery, signal |
| `glyphs` | A fixed icon slot centred on each RN glyph: 54 px (feed controls, 18pt), 66 px (anchor controls, 22pt), 72 px (header and composer, 24pt), 48 px (profile share and more); the ink box plus 4 px for the info and empty-state glyphs. Counts next to icons stay visible | Licence substitution: Lucide glyphs for the Central icon set (ASSETS.md section 2) |
| `tail` | A 150 px slot from the RN "·" of a post meta line | The relative time follows the capture clock |
| `datetime` | A 150 px slot over the anchor time digits, `interactions` only | Each app seeds its own data in that state. The date and the who-can-reply label stay visible (review finding N17) |
| `rect` | The header logo slot, the thread anchor logo slot, the FAB glyph, the bottom bar glyphs (the bell box stops below the badge) | Licence substitution |

Not masked: avatars, counts, badges, names, handles, post text, the anchor date line and who-can-reply
label (except the `interactions` time digits), buttons, borders and backgrounds.

**Clock (review finding N14).** The capture clock cannot be frozen for the RN app: the e2e build has no
clock mock (`src/env/common.ts:32` `IS_E2E` changes no time code; `tick-every-minute.tsx:9,12` reads
`Date.now()`), and `simctl` cannot set the simulator date. The `tail` slots therefore stay.

## Noise floor

Two native captures of the final build on the same seed (`out/base` and `out/base2`, the second with
`RESEED=false ./run-capture.sh native base2 out/base2`), diffed with the same masks:

```
node <pack>/skills/check-parity/scripts/diff.mjs --rn out/base/native/ios --native out/base2/native/ios --out out/noise/raw
node <pack>/skills/check-parity/scripts/diff.mjs --rn out/base/native/ios --native out/base2/native/ios --out out/noise/masked --mask masks/base.json
```

| Screen | Raw (px) | Masked (px) |
|---|---|---|
| home | 0.0033 (10,316) | 0 |
| thread | 0.0017 (5,444) | 0 |
| profile | 0.0017 (5,405) | 0 |

The raw noise is the relative times. The masked noise floor is 0 px on all three screens.

## Line boxes (review findings N12, A57, A19: open)

The port still uses per-component constants in `RNLineBox` (`DesignSystem/Typography.swift`), **fitted to
the iPhone 17 Pro at 3x**. They are not verified on a 2x device.

A rule-based model was built, verified and reverted:

- From source: RN `Text` sets paragraph minimum and maximum line height to L
  (`RCTAttributedTextUtils.mm:229-232`) and raises glyphs by (L - N)/2 when L >= N
  (`RCTApplyBaselineOffset`, `:300-340`); `RCTTextLayoutManager.mm:361-394` measures the box as
  `ceil((n * L + 0.001) * scale) / scale`.
- The formulas matched a TextKit 1 layout built like `RCTTextLayoutManager`, and SwiftUI text with iOS 26
  `.lineHeight(.exact)` matched TextKit ink rows within 1 px, at 3x and 2x (test in commit `a2ef4c4`).
- In the app, the rules did not keep parity. Base capture on one seed: home masked 0.0357 (fail)
  against 0.0138 (drift) with the constants. Ink rows: native feed glyphs 2 px higher from the first
  row (meta 679 against 681, text 749 against 751), the thread anchor body 3 px lower (562 against 559),
  the profile bio 1 px higher. A TextKit probe showed the `numberOfLines` path gives the same heights, so
  the remaining offsets come from layout rounding (Yoga `PixelGrid.cpp:87-127`) or the renderer choice
  at runtime, which could not be derived. Commit `7461701` reverted the rules.

Consequence: wrapped text with a line height below the font's natural height still grows about 1.4pt
per extra line (A57). The base screens have no such wrapped text.

Border rows at x 1170 with the constants (base): home 460, 645, 1166, 1439, 1712, 1985 (same in both
apps); thread 329, 823, 1105 (same); profile 1110, 1382 (same). The thread reply-prompt border is
RN 2275 against native 2277 (review finding N11, open). Round 1 claimed every border matched; that
was wrong for this row and for the home bottom bar.

## Event diff

**Result: ordered MATCH, 19 of 19 events, for `flows/capture.yml`.** The RN side is derived from source,
not captured: the e2e build logs metrics only at debug level in a context the upstream `.env` hides
(`src/logger/index.tsx:43-45,115-121`), and changing `.env` or restarting Metro is not allowed.

```
python3 events/normalize_events.py out/base/native/ios/events.jsonl > out/base/native/ios/events.normalized.jsonl
node <pack>/skills/check-parity/scripts/events.mjs --rn events/rn-expected-base.jsonl \
  --native out/base/native/ios/events.normalized.jsonl --ignore initMs,secondsActive --ordered
MATCH (ordered): rn 19 event(s), native 19 event(s), ignoring initMs, secondsActive
```

- `normalize_events.py` resolves `authorDid` to a handle and each post `uri` to `<handle>|<text>` through
  the PDS, so the diff checks that each event names the right post. It drops no event. Only `initMs`
  and `secondsActive` (timing) are ignored (review finding N24; round 1 ignored `uri` and `authorDid`).
- Two native runs give the same ordered list (`events.mjs --ordered`, `out/base` against `out/base2`: MATCH).
- Order proof from source:
  - Feed `post:view`: `List.tsx:123-131` reports `onViewableItemsChanged` items; RN `ViewabilityHelper.js:228-310`
    reports a change's newly viewable rows in ascending index after 500 ms. The port does the same
    (`Core/Analytics/ViewabilityTracker.swift`, review finding N6).
  - Thread push: the anchor `post:view` effect runs on the cached placeholder anchor (`PostThread/index.tsx:95-112`)
    before `router:navigate`, because `onStateChange` runs in the container's `useEffect`
    (`BaseNavigationContainer.tsx:322-399`) and React runs child effects first (review finding N23).
  - `thread:preferences:load` is not sent in this flow: Home loads preferences first, and RN sends the
    metric only when preferences arrive or change after the thread mounts
    (`useThreadPreferences.ts:33-71`, `prevServerPrefs` starts as `useState(serverPrefs)`).
  - Swipe back: Home's `useFocusEffect` (`Home.tsx:175-186`) sends `home:feedDisplayed` before the container's
    `router:navigate {from: "PostThread"}`.
- The launch activation sends no `state:foreground`, as RN registers its AppState listener after launch.

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

Not in the base flow, with unit tests: `post:like`, `post:unlike`, `feed:refresh`, `feed:endReached`,
`thread:preferences:load` (late arrival only; `view` from `lab_treeViewEnabled`), `thread:click:showOtherReplies`,
`link:clicked` (`LinkRouter`). `post:clickthroughAuthor` is sent only from the anchor avatar (review finding N1).

## States covered

| State | RN | Native | Evidence |
|---|---|---|---|
| Home, thread, profile (light) | yes | yes | table above; swipe back from the thread asserted in the flow (N16) |
| Dark (system dark: RN uses dim) | yes | yes | table above |
| Largest Dynamic Type | yes | yes | table above |
| Empty seed (`?users`) | yes | yes | table above |
| Mergefeed seed: "Replied to" rows, self replies, thread lines | yes | yes | `capture-mergefeed.yml` (N13) |
| After like and repost | yes | yes | `capture-interactions.yml` |
| First-load, load-more, thread and profile errors | no | yes | RN has no fault control and the shared server must not be stopped. Unit tests: `FeedModelTests`, `ThreadTests.failureThenRetry`, `ProfileAndUnreadTests.profileErrorScreen` |
| Loading skeletons | no | no | Loads finish before a screenshot. Unit test: `ThreadTests.placeholderShowsAnchorAndReplySkeletons` |
| Repost reason rows, long posts, facets, tombstones, other replies | no | no | No upstream seed creates them (`dev-env/mock-server.ts`). Unit tests: `FeedTunerTests`, `RichTextTests`, `ThreadTests.tombstonesStopTheParentWalkAndSkipReplyBranches`, `ThreadTests.hiddenRepliesGoToTheOtherBucket` |
| Load more after 30 posts, pull to refresh | no | no | A screenshot after scrolling is not deterministic. Unit tests: `FeedModelTests.loadMoreFailureKeepsPagingAndOffersRetry`, `refreshFailureWithRowsShowsRetryRow` |
| Reply prompt hidden when replies are disabled | no | no | The seed has no threadgate. Unit test: `ThreadTests.canReplyFollowsTheAnchor` (N2) |

## Differences that remain

None of these is accepted. Each needs a named owner.

| # | Difference | RN | Native | Parity check |
|---|---|---|---|---|
| 1 | UI icons | Central icon set | Lucide glyphs, same sizes and colour tokens | `glyphs` slots; 4 native glyphs fall outside RN slots (see Verdict) |
| 2 | Logo and anchor mark | Butterfly mark | Neutral diamond; empty anchor slot | `rect` masks |
| 3 | Default avatar figure | Bluesky artwork | Generic silhouette in the same blue | Not masked; counted |
| 4 | Header hide on scroll | Drag-driven with a snap on drag end | Follows the scroll delta; no snap | Not captured |
| 5 | Bottom bar minimal-shell transform | `footerMode` translate and fade, driven only by screens that enable minimal shell (`minimal-mode.tsx`) | No transform. No screen in the slice enables minimal shell, so RN shows no transform here either (N4) | Not applicable to the slice |
| 6 | Sign-out | Clears tokens | Also calls `com.atproto.server.deleteSession` with the newest refresh token | Unit tests |
| 7 | `post:view` visibility | 40% visible for 500 ms | Row laid out for 500 ms | Event diff |
| 8 | Tab roles | `accessibilityRole="tab"` | Buttons with the selected trait | Not measured |
| 9 | E2E controls | 12 controls at top 100, right 0 | The same 12, plus 5 native-only fault controls at top 100, left 0 | 15 px at the left edge, not masked |
| 10 | Release build | Production app | Smoke build: no sign-in form, local networking allowed, no event log | Release `build` |
| 11 | Tag and other-user taps | Hashtag screen, other profiles | "Not part of this showcase" | Behaviour only |
| 12 | Tabs container | RN tab navigator | `ZStack` of per-tab `NavigationStack`s | Pixel diff |
| 13 | Screen testIDs `HomeScreen`, `followingFeedPage`, `profileScreen` | Present | Not exposed: SwiftUI exposes only the outer id of a one-child container chain (measured with `maestro hierarchy`) | N7, open |
| 14 | Thread reply-prompt border | y 2275 | y 2277 | N11, open |
| 15 | Line boxes | RN text layout | Constants fitted to one 3x device | N12, A57, A19, open |
| 16 | Link long press | Share sheet (`Link.tsx:258-281`) | No long-press action | N25, open |
| 17 | Thread tree view | Labs preference | Linear view only; the metric logs the server value | Proposed out of scope |

The proposed out-of-scope rows in `plan/slice-plan.md` also await owner acceptance.

## Corrections to earlier claims

- Round 1 said every border and text line matched (old lines 156-158). Wrong: the thread reply-prompt
  border and the home bottom-bar border differed (N11).
- Round 1 said the native thread stayed open because Maestro `back` has no effect on iOS, and assumed
  the same for RN (old line 210). The flow now swipes back. That step showed the native pop gestures
  were disabled while RN popped; commit `b55151f` fixed it.
- Round 1 dropped `state:foreground` in the normaliser and ignored `uri` and `authorDid` without RN
  evidence (N24). Both are corrected.

## Pack tools used, and problems found

| Tool | Result |
|---|---|
| `capture.mjs --env` | Works; `run-capture.sh` passes `SEED`, `SUFFIX` and `RESEED` through it |
| `diff.mjs`, `events.mjs --ordered` | Worked as documented |
| `maestro hierarchy` | Worked on the native app; showed the collapsed container ids (N7) |
| Maestro `swipe` | Pops RN and, after the fix, native; the assertion must use a thread-only element |
