# Parity report (iOS): RN app vs native SwiftUI port

- Date: 2026-09-15.
- Device: iPhone 17 Pro simulator, iOS 26.4 (`7F73AB4A-2709-4033-89D2-35CE10E650F4`), 1206x2622 px at 3x.
- RN build: the upstream e2e app `xyz.blueskyweb.app` (`bluesky-social-app` at `2bfb94d`, Metro in e2e mode).
- Native build: Debug `NativeShowcase` (`io.nativestarter.showcase.bluesky`).
- Server: the upstream dev network (PDS `http://localhost:3000`, AppView DID `did:plc:bw7ad3erl7btq6qwf66yqiov`), reseeded before every capture.
- **Acceptance: awaiting owner acceptance.** No difference in this report is accepted yet.

## Verdict

**Every captured screen is at or below the 0.02 threshold with masks. No screen passes raw.**
`diff.mjs` classifies 2 screens as `pass` (at most 0.01) and 11 as `drift` (above 0.01, at most
0.02). Each drift needs a written sign-off by a person who did not write the port
(`check-parity/references/thresholds.md`); none is signed.

Final run: 2026-09-15 13:10 to 13:14, one Debug build, all native states captured in one run.
Masked ratio = differing pixels after masks / 3,162,132. Status is from `diff.mjs` with the default
threshold 0.02 and fuzz 5%.

| State | Screen | Raw ratio (px) | Masked ratio (px) | Masked area | Status |
|---|---|---|---|---|---|
| base | home | 0.0288 (91,024) | 0.0136 (43,048) | 12.67% | drift |
| base | thread | 0.0199 (62,869) | 0.0074 (23,312) | 11.52% | pass |
| base | profile | 0.0174 (55,056) | 0.0109 (34,344) | 8.91% | drift |
| dark | home-dark | 0.0285 (90,151) | 0.0140 (44,164) | 12.67% | drift |
| dark | thread-dark | 0.0197 (62,159) | 0.0073 (23,072) | 11.52% | pass |
| dark | profile-dark | 0.0168 (52,967) | 0.0107 (33,967) | 8.91% | drift |
| largest Dynamic Type | home-xxxl | 0.0330 (104,295) | 0.0164 (52,005) | 13.13% | drift |
| largest Dynamic Type | thread-xxxl | 0.0266 (83,963) | 0.0119 (37,616) | 15.85% | drift |
| largest Dynamic Type | profile-xxxl | 0.0250 (79,089) | 0.0179 (56,567) | 9.03% | drift |
| empty seed | home-empty | 0.0267 (84,391) | 0.0189 (59,656) | 9.54% | drift |
| empty seed | profile-empty | 0.0195 (61,732) | 0.0116 (36,728) | 8.98% | drift |
| after like and repost | home-liked-reposted | 0.0284 (89,669) | 0.0136 (43,138) | 12.67% | drift |
| after like and repost | thread-liked-reposted | 0.0241 (76,280) | 0.0113 (35,585) | 11.54% | drift |

Mask areas stay below the 15% limit in `masking.md`, except `thread-xxxl` at 15.85%. At the largest
text size the thread date line wraps with its who-can-reply label, so the date-line mask covers two
lines.

The remaining pixels are, by inspection of the diff images:
- the default avatar figure (row 3 of "Differences that remain")
- anti-aliasing at glyph edges, 1 px in places where Yoga and SwiftUI round differently
- the Lucide chevrons and the share glyph where their boxes overlap text

**Events:** MATCH, 18 of 18, against an RN log derived from source (see "Event diff").

**Native error states** (no RN equivalent): `home-error`, `home-load-more-error`, `thread-error`,
`profile-error`, captured by `capture-errors-native.yml` in the same run.

## How the numbers were made

All captures use one Maestro flow for both apps (`parity/flows/`). `LABEL` selects the app.

1. Capture one state for one app. The script takes the shared seed lock, sets the simulator
   state, runs Maestro and resets the simulator:
   ```
   cd ios/parity
   ./run-capture.sh rn <state>        # state: base | dark | xxxl | empty | interactions
   ./run-capture.sh native <state>    # also: errors
   ```
   - `base`, `interactions` and `errors` run `migration-pack/skills/check-parity/scripts/capture.mjs`.
   - `dark` runs `xcrun simctl ui <udid> appearance dark` first.
   - `xxxl` runs `xcrun simctl ui <udid> content_size extra-extra-extra-large` first.
   - `empty` seeds `?users` only.
   - Every run overrides the status bar with `xcrun simctl status_bar <udid> override --time 9:41`,
     and resets appearance and content size to light and large at exit.
2. Build the masks from the RN and native images of the state:
   ```
   python3 make_masks.py masks-spec.json <state> out/<state>/rn/ios out/<state>/native/ios masks/<state>.json
   ```
3. Diff raw and masked with the Pack's script (threshold 0.02, fuzz 5%):
   ```
   node <pack>/skills/check-parity/scripts/diff.mjs --rn out/<state>/rn/ios --native out/<state>/native/ios --out out/<state>/diff-raw
   node <pack>/skills/check-parity/scripts/diff.mjs --rn out/<state>/rn/ios --native out/<state>/native/ios --out out/<state>/diff-masked --mask masks/<state>.json
   ```
4. Write the Pack report:
   ```
   node <pack>/skills/check-parity/scripts/report.mjs --diff out/<state>/diff-masked/results.json --out out/<state>/parity-report.md --title "<state> (iOS)"
   ```

The RN images of the committed states are in `parity/baseline/rn/`:

| State | Files |
|---|---|
| base (captured by the first port run, not overwritten) | `ios-home.png`, `ios-thread.png`, `ios-profile.png` |
| dark | `ios-home-dark.png`, `ios-thread-dark.png`, `ios-profile-dark.png` |
| largest Dynamic Type | `ios-home-xxxl.png`, `ios-thread-xxxl.png`, `ios-profile-xxxl.png` |
| empty seed (`?users`) | `ios-home-empty.png`, `ios-profile-empty.png` |
| after like and repost | `ios-home-liked-reposted.png`, `ios-thread-liked-reposted.png` |

## Masks

Masks follow `check-parity/references/masking.md`. Each mask is one of these, generated by
`make_masks.py` from bands in `masks-spec.json`, and measured on both images:

| Kind | What it hides | Reason |
|---|---|---|
| `status` | y 0 to 180 px | Status bar: clock, battery, signal |
| `glyphs` | Ink clusters of icon glyphs only. In post control rows the left group needs 36 px width, so the reply, repost and like counts stay visible; the right group (bookmark, share, more) has no text | Licence substitution: Lucide glyphs for the Central icon set (ASSETS.md section 2) |
| `tail` | The last two ink clusters of a post meta line: "·" and the relative time | Capture time |
| `rect` | The header logo slot, the thread anchor logo slot, the thread date line with the who-can-reply label that moves with its width, the FAB glyph, the info glyph, the bottom bar glyphs (the bell box stops below the badge) | Licence substitution, or capture time |

Not masked: avatars (the code-drawn default avatar differs from RN's artwork), counts, badges,
names, handles, post text, buttons, borders and backgrounds.

## Noise floor

Two captures of the same native build and seed (`out/base` and `out/base2`), diffed with the
same command and the same masks:

```
node <pack>/skills/check-parity/scripts/diff.mjs --rn out/base/native/ios --native out/base2/native/ios --out out/noise/raw
node <pack>/skills/check-parity/scripts/diff.mjs --rn out/base/native/ios --native out/base2/native/ios --out out/noise/masked --mask masks/base.json
```

| Screen | Raw (px) | Masked (px) |
|---|---|---|
| home | 0 (0.0000) | 0 (0.0000) |
| thread | 12,372 (0.0039) | 1,462 (0.0005) |
| profile | 0 (0.0000) | 0 (0.0000) |

The thread differs between two runs because its anchor date line shows the capture minute, and
the reply's relative time can change between "now" and "5s". The masked remainder is the
anti-aliased edge around those masks. In the previous run, one build earlier, all three screens
were 0 px. The masked noise floor (at most 0.0005) is far below the smallest masked ratio (0.0073).

## Line-box measurements

RN renders text with `@bsky.app/react-native-uitextview` and Yoga pixel rounding. The RN runtime
could not be inspected (see "Event diff"), so the port measures where RN boxes differ from the
centred line-box model and applies each difference in one place: `RNLineBox` in
`DesignSystem/Typography.swift`. Values are points, snapped to the device pixel grid.

Method: ink rows of the text column (x 215 to 700 px, past the avatars) and border rows
(`#DCE2EA` at x 1170) in the RN and native base captures. Values below are 3x pixels.

| Constant | Where | RN measurement | Native before |
|---|---|---|---|
| `postMeta` box +2 px | PostMeta (text_md, leading_tight 17) | meta glyph top same, body line 70 px below it | body line 68 px below it |
| `richText` box +1 px | RichText post text (text_md and text_lg, leading_snug) | plain feed row 273 px; thread reply 282 px; thread anchor border y 823 | 272 px; 281 px; 822 |
| `tabLabel` box +1 px, bar -1 px | Pager tab label (lineHeight 20) | underline y 454 to 459, hairline y 460, composer border y 645 | 453 to 458, 459, 645 |
| thread parent row -1 px | Feed rows with a thread line and no bottom padding | 248 px | 249 px |
| `profileDisplayName` glyph -1 px, box +2 px | Profile name (text_3xl, leading_tight 28) | name ink y 628, handle y 726 | 627, 724 |
| `profileHandle` box +1 px, `profileMetrics` box +1 px | Profile handle and metrics (leading_snug 20) | metrics y 811, tabs y 1024 | 808, 1020 |
| `profileDescription` box +1 px, glyph +3 px | Profile bio (RichText) | bio ink y 912 | 905 |
| `buttonLabel` box +1 px | Large ALF `Button` labels | end-of-feed pill 133 px (y 1136 to 1268) | 132 px |
| `legacyGlyphOffset` +1 px | RN legacy `Text` (end-of-feed messages) | message ink y 963 and 1340 | 962 and 1339 |
| `legacyTracking` 0.0043 em | RN legacy `Text` (Discover fallback header, end-of-feed messages) | 15pt line 808 px wide, 17pt line 903 px wide | 801 px, 894 px |

Legacy `Text` (`src/view/com/util/text/Text.tsx`) renders through RN's paragraph view, not the
UITextView of ALF `Text`, and measures about 1% wider. Three causes were tried and rejected by
measurement: pair kerning off (+1 px only), and a fixed optical size of 14 (the 17pt line became too
wide and wrapped). The tracking value is therefore the measured ratio, not a derived rule.

After these values every border and text line of the three base screens is at the same pixel
row in both apps (home borders 460, 645, 1166, 1439, 1712, 1985; thread 329, 823, 1105; profile
1110, 1382).

## Event diff

**Result: MATCH, 18 of 18 events, for the base flow.** The RN side is derived from source, not
captured.

The native app writes each event to `Documents/events.jsonl`. The RN event log could not be
captured without changing upstream:

- The e2e build sends events to `https://events.bsky.app/t` and logs them only at debug level in
  the `metric` context. The upstream `.env` has `EXPO_PUBLIC_LOG_DEBUG=session`, which hides them
  (`src/logger/index.tsx:43-45,115-121`). Showing them needs an `.env` change and a Metro restart.
  Neither is allowed for this work. The Metro log contained no `(metric)` lines.
- The Metro inspector WebSocket (`/inspector/debug`) closed with code 1006 right after it opened,
  with Node's built-in `WebSocket` and with the `ws` package.

So `parity/events/rn-expected-base.jsonl` lists the RN events for `flows/capture.yml`, written
from source:

| # | Event and props | RN source |
|---|---|---|
| 1-2 | `router:navigate {}`, `init {initMs}` (logged-out launch: the navigator is ready on Home behind `LoggedOut`) | `src/Navigation.tsx:1012-1035`; `createNativeStackNavigatorWithAuth.tsx:124-126` |
| 3 | `account:loggedIn {logContext: "LoginForm", withPassword: true}` | `src/state/session/index.tsx:325-329`; `TestCtrls.e2e.tsx:30-37` |
| 4-5 | `router:navigate {}`, `init {initMs}` (the shell remounts with the account key) | `App.tsx:150-152`; `Navigation.tsx:955` |
| 6 | `home:feedDisplayed {index: 0, feedType: "following", feedUrl: "following", reason: "focus"}` | `src/view/screens/Home.tsx:175-186` |
| 7-10 | `post:view {uri, authorDid, isReply, logContext: "FeedItem", feedDescriptor: "following", position: 0..3}` | `src/view/com/posts/PostFeed.tsx:991-1013,1072-1100` |
| 11 | `post:clickthroughItem {uri, authorDid, logContext: "FeedItem", feedDescriptor: "following"}` | `PostFeedItem.tsx:248-259` |
| 12 | `router:navigate {from: "Home"}` | `Navigation.tsx:1059-1067` |
| 13 | `thread:preferences:load {sort: "hotness", view: "linear"}` (`DEFAULT_THREAD_VIEW_PREFS` merged) | `useThreadPreferences.ts:55-72`; `preferences/const.ts:30-33` |
| 14 | `post:view {uri, authorDid, isReply: false, logContext: "Post", feedDescriptor: "following"}` | `src/screens/PostThread/index.tsx:96-112` |
| 15 | `post:view {uri, authorDid, isReply: true, logContext: "PostThreadItem"}` | `usePostViewTracking.ts:24` |
| 16-17 | `nav:click {item: "profile", surface: "bottomBar"}`, `router:navigate {from: "PostThread"}` | `BottomBar.tsx:99`; `Navigation.tsx:1066` |
| 18 | `post:view {..., feedDescriptor: "author|<did>|posts_and_author_threads", position: 0}` | `PostFeed.tsx:1092`; `Profile.tsx:436` |

Maestro's `back` step has no effect on iOS (XCUITest has no back action). The native log proved
it: the thread stayed open until the Profile tab tap. The expected RN list assumes the same for
the RN app.

Command and output:

```
python3 parity/events/normalize_events.py parity/out/base/native/events.jsonl > parity/out/base/native/events.normalized.jsonl
node <pack>/skills/check-parity/scripts/events.mjs --rn parity/events/rn-expected-base.jsonl \
  --native parity/out/base/native/events.normalized.jsonl --ignore uri,authorDid,initMs,secondsActive
MATCH (unordered): rn 18 event(s), native 18 event(s), ignoring uri, authorDid, initMs, secondsActive
```

- `normalize_events.py` drops `state:foreground` and `state:background`. RN registers its AppState
  listener after the bundle loads, so whether RN sees the launch activation depends on timing and
  cannot be derived from source. It replaces DIDs inside `feedDescriptor` with `<did>`.
- `--ignore` removes `uri` and `authorDid` (new per seed) and `initMs` and `secondsActive` (timing).
- Two native runs of the same flow give the same 18 events (`events.mjs` MATCH).

Events that the slice does not emit, by name:

| RN event | Why not in native |
|---|---|
| `feature:viewed`, `experiment:viewed` | GrowthBook feature flags are not ported. In the e2e build GrowthBook timed out, so values are null |
| `composer:open` | The composer is out of the slice; the native app shows "Not part of this showcase" |
| `share:press:nativeShare`, `share:press:copyLink`, `share:press:openDmSearch` | The share menu is out of the slice. `post:share` fires on the share tap, as RN fires it when the menu opens |
| `post:bookmark`, `post:unbookmark` | Bookmarks are out of the slice; RN fires them after the API call succeeds |
| `home:feedDisplayed` without `reason` (pager `onPageSelected`) | Whether the native PagerView fires on mount could not be derived from source |
| `invite:dialog:open` | Ported, fires on the Invite friends tap; not in the base flow |
| `link:clicked`, `post:clickReply`, `post:clickQuotePost`, `post:share`, `post:like`, `post:unlike`, `post:repost`, `post:unrepost`, `post:clickthroughAuthor`, `post:likedBy:click`, `nav:click` (topBar), `composerPrompt:*`, `feed:refresh`, `feed:endReached`, `thread:click:*`, `account:loggedOut` | Ported with RN's props; not part of the base flow. Unit tests cover `post:like`, `post:unlike`, `feed:refresh`, `feed:endReached`, `post:view`, `thread:preferences:load` and `thread:click:showOtherReplies` |

## States covered

| State | RN | Native | Notes |
|---|---|---|---|
| Home, thread, profile (light) | yes | yes | |
| Dark (system dark: RN uses dim) | yes | yes | |
| Largest Dynamic Type (`extra-extra-extra-large`, multiplier 1.353) | yes | yes | |
| Empty seed: home and profile | yes | yes | Home shows the fallback marker and end-of-feed block in both (RN `__DEV__` skips Discover) |
| After like and repost: home and thread anchor stats row | yes | yes | `capture-interactions.yml` |
| First-load feed error, load-more error, thread error, profile error | no | yes (`capture-errors-native.yml`) | RN has no fault control and the server must not be stopped, so no RN image exists. Native arms the Debug controls `e2eFailNextFeedLoad`, `e2eFailNextRefresh` (consumed by the Home re-tap soft reset with rows on screen), `e2eFailNextThread` and `e2eFailNextProfile` on the signed-out screen |
| Loading skeletons | no | no | Loads finish before a screenshot can be taken reliably |
| Tombstones, other replies, long posts, facets | no | no | The seed has none; unit tests cover the logic |

## Differences that remain

None of these is accepted. Each needs a named owner.

| # | Difference | RN | Native | Parity check |
|---|---|---|---|---|
| 1 | UI icons | Central icon set | Lucide glyphs, same sizes and colour tokens | `glyphs` masks |
| 2 | Logo and anchor mark | Butterfly mark | Neutral diamond; empty anchor slot | `rect` masks |
| 3 | Default avatar figure | Bluesky artwork | Generic silhouette in the same blue | Not masked; counted in every ratio |
| 4 | Header hide on scroll | Drag-driven with a snap on drag end | Follows the scroll delta; no snap (SwiftUI on iOS 17 has no drag end callback) | Not captured |
| 5 | Sign-out | Clears tokens | Also calls `com.atproto.server.deleteSession` (review finding A27) | Unit test |
| 6 | `post:view` visibility | 40% visible for 500 ms | Row on screen for 500 ms | Event diff |
| 7 | Tab roles | `accessibilityRole="tab"` | Buttons with the selected trait; SwiftUI has no tab trait | Not measured |
| 8 | E2E controls | 12 controls at top 100, right 0 | The same 12, plus 5 native-only fault controls at top 100, left 0 | 15 px at the left edge, not masked |
| 9 | Error states | Not capturable | Captured with injected faults | Native images only |
| 10 | Release build | Production app | Smoke build: no sign-in form, local networking allowed | Release `build` |
| 11 | Tag and other-user taps | Hashtag screen, other profiles | "Not part of this showcase" | Behaviour only |
| 12 | Tabs container | RN tab navigator | `ZStack` of per-tab `NavigationStack`s. `TabView` with a hidden bar reserved the system bar's safe area on iOS 26 and moved the bar and the feed by several pixels | Pixel diff |

The proposed out-of-scope rows in `plan/slice-plan.md` (embeds, long-press quote, chat badge,
other profile tabs and profiles, licence substitutions) also await owner acceptance.

## Pack tools used, and problems found

| Tool | Result |
|---|---|
| `capture.mjs` | Works for flows with `PLATFORM` and `LABEL` only. It cannot pass other variables, so `run-capture.sh` runs Maestro directly for `SEED` and `SUFFIX` |
| `references/maestro-flows.md` | Its advice to set defaults in a flow-header `env:` block breaks `-e`: in Maestro 2.4.0 the header value wins, so the first "RN" dark, largest-text and empty captures launched the native app. The flows compute defaults with `evalScript` instead |
| `references/maestro-flows.md` | A ternary `appId` in a flow header fails YAML parsing ("mapping values are not allowed"). The documented `runFlow` + `when` pattern works |
| `diff.mjs`, `events.mjs`, `report.mjs` | Worked as documented |
| Maestro `hierarchy` | Dumped the iOS home screen instead of the RN app after a flow ended, so no RN frames could be read |
