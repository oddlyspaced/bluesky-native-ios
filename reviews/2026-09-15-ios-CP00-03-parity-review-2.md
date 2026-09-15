# Parity review 2: CP-00 to CP-03, iOS

- Reviewer: `parity-reviewer` agent (Nativestarter Migration Pack), run on 2026-09-15
- Code reviewed: `ios/` and `parity/` at commit `4e72ea8`, diff `6ef63e8..4e72ea8`, against bluesky-social/social-app at `2bfb94d`
- Verdict: **Blockers found: 2** (N1, N21)
- Round-1 status: 25 fixed, 12 partially fixed, 1 not fixed (P35), 1 fixed in code without runtime evidence (P10)
- Paths: native paths are relative to `ios/BlueskyNative/` unless they start with `ios/` or `plan/`

## Round-1 verdicts

| # | Verdict | Note |
|---|---|---|
| P1 | Fixed | Prompt and footer border present. Prompt border 2 px low (N11); ignores replyDisabled (N2) |
| P2 | Partially fixed | Home borders match in the base state (460/645/1166/1439/1712/1985). Home drift 0.0136 masked, fail 0.0288 raw, not signed off. Constants do not hold outside the base state (N12) |
| P3 | Fixed | Feed tuners ported and wired |
| P4 | Fixed | MinuteTicker matches tick-every-minute and TimeElapsed; tail masks still hide output (N14) |
| P5 | Fixed | Load-more error row with retry |
| P6 | Partially fixed | About 40 metric sites ported. RN log derived from source. Unordered match, ordered mismatch (N6); one extra event (N1) |
| P7 | Fixed | Themes; dark captures |
| P8 | Fixed | `via` on like and repost records |
| P9 | Fixed | getPostThreadV2, other replies, tombstones. Tree view not ported (N5) |
| P10 | Fixed in code, no evidence | InteractivePopEnabler; no runtime proof (N16) |
| P11 | Fixed | Bottom-bar border flag derived from route |
| P12 | Fixed | Anchor stats row; 2 px short (N12) |
| P13 | Fixed | Dynamic Type multiplier table and caps |
| P14 | Partially fixed | Post-text facets ported; embeds proposed out of scope; bio has no facets (N3) |
| P15–P23 | Fixed | Reason rows, error states, thread error, thread states, profile states, empty feed, shadow, rollback, control guards |
| P24 | Partially fixed | Animations, count wheel, haptics; long-press quote proposed out of scope; extra haptic (N15) |
| P25–P28 | Fixed | Long text, soft reset, unread polling (chat badge proposed out of scope), session refresh |
| P29 | Partially fixed | Header hides on scroll without snap; bottom bar does not hide (N4) |
| P30 | Partially fixed | Selected trait and unread hint; no tab role |
| P31 | Fixed | Accessibility labels |
| P32 | Partially fixed | `HomeScreen`, `followingFeedPage`, `profileScreen` missing (N7) |
| P33 | Partially fixed | Counts stay visible; noise floor measured; new mask issues (N17–N19) |
| P34 | Partially fixed | Dark, xxxl, empty and interaction states in both apps; errors native only; several states not captured (N13) |
| P35 | Not fixed | No acceptor named (N21) |
| P36 | Partially fixed | Thread spacer fixed; home bottom-bar and thread prompt borders still off (N11) |
| P37–P38 | Fixed | Display-name fallback; composer prompt actions; repost label |
| P39 | Partially fixed | Decimal separator localised; compact suffixes hard-coded |

## Blockers

| # | Area | Finding | Native evidence | RN reference | Fix |
|---|---|---|---|---|---|
| N1 | Events: extra event | Tapping a reply or parent avatar logs `post:clickthroughAuthor`; RN logs it only on the anchor | `Features/Thread/ThreadScreen.swift:474-476` | `ThreadItemPost.tsx:280-286`; `ThreadItemAnchor.tsx:281` | Remove from ThreadPostView, keep on anchor, add a unit test |
| N21 | Gate: recorded differences | 11 drift screens without sign-off, 12 differences without an acceptor, proposed out-of-scope rows unaccepted | `ios/PARITY.md:8,12-15,239`; `plan/slice-plan.md:35-45` | `check-parity/references/thresholds.md:16,41-55` | A person who did not write the port signs off each drift and difference by name. Until then the gate stays open |

## Major

| # | Area | Finding | Native evidence | RN reference |
|---|---|---|---|---|
| N2 | Thread behaviour | Reply prompt shows when replies are disabled | `Features/Shell/TabShell.swift:63-67` | `src/screens/PostThread/index.tsx:158,647` |
| N3 | Facets | Profile bio renders without facets | `Features/Profile/ProfileScreen.swift:200-203` | `src/view/screens/Profile.tsx:621-640`; `ProfileHeaderStandard.tsx:148-156` |
| N4 | Minimal shell | Bottom bar does not hide on scroll | `Features/Shell/BottomBar.swift:21-53` | `BottomBar.tsx:15,75,172` |
| N5 | Thread view | Tree view not ported; logs `linear` always; not recorded | `ThreadModel.swift:358,363` | `useThreadPreferences.ts:58-69` |
| N6 | Event order | `--ordered` diff fails; native `post:view` order unstable between runs | `ios/parity/out/base/native/events.normalized.jsonl:7-10` | `src/view/com/posts/PostFeed.tsx:1071-1100` |
| N22 | Event gate | `thread:preferences:load` sent even when preferences failed | `ThreadModel.swift:353-364`; `FeedModel.swift:20-35` | `useThreadPreferences.ts:51-71`; `usePostThread/index.ts:74` |
| N23 | Event timing | Anchor `post:view` waits for the network load; RN may fire on placeholder anchor (unconfirmed) | `ThreadModel.swift:369,404-413` | `PostThread/index.tsx:96-112`; `usePostThread/index.ts:141-151` |
| N7 | testIDs | `HomeScreen`, `followingFeedPage`, `profileScreen` missing | `Features/Feed/HomeScreen.swift:36-40,70`; `ProfileScreen.swift:18-47` | `Home.tsx:95,320`; `Profile.tsx:63` |
| N12 | Line boxes | Constants fit the base state and one 3x device; stats row 2 px short; xxxl row 1 px off | `DesignSystem/Typography.swift:137-144,168-182` | `ThreadItemAnchor.tsx:440-517` |
| N13 | Evidence | Loading, reason rows, long text, facets, tombstones, other replies, load-more and refresh not captured; errors native only | `ios/PARITY.md:233-235` | `plan/slice-plan.md:27-28` |
| N16 | Evidence | Swipe-back has no test or flow | `ThreadScreen.swift:132-163` | native-stack gesture |
| N17 | Mask | Thread date-line mask hides the full timestamp and reply-setting label, a CP-02 criterion | `ios/parity/masks-spec.json` thread band | `plan/slice-plan.md` CP-02 |
| N18 | Mask | `thread-xxxl` mask area 15.85%, above the 15% limit | `ios/PARITY.md:37-39` | `check-parity/references/masking.md:52` |
| N19 | Mask | Glyph masks merged from RN and native images, so a native-only glyph can mask itself | `ios/parity/make_masks.py:106-117` | `masking.md` |

## Minor

| # | Finding | Native evidence |
|---|---|---|
| N11 | Thread prompt border RN 2275 vs native 2277; home bottom-bar border RN 2378 vs native 2379; PARITY.md claims all borders match | border-row profiles at x 1170 |
| N14 | Tail masks hide every relative time; freeze the clock instead | `ios/parity/masks-spec.json` |
| N20 | RN base baselines predate the current flow; recapture in the same run as native | `parity/baseline/rn/ios-home.png`, `ios-thread.png` |
| N24 | Normalizer drops `state:foreground` without RN evidence; `--ignore uri` can hide a view of the wrong post | `ios/parity/events/normalize_events.py:11,19-20` |
| N8 | Error copy lacks suspended, deactivated, profile-not-found, handle and birthdate branches | `Core/Formatting/ErrorText.swift:15-33` |
| N9 | Error copy matches message only, not code | `ErrorText.swift:6-7` |
| N10 | Fallback shows `localizedDescription`; XRPCError is not LocalizedError | `ErrorText.swift:12`; `Core/Networking/XRPCClient.swift:147` |
| N15 | Haptic on repost menu open; RN has none | `Features/Post/PostViews.swift:126` |
| N25 | Links have no long-press share | `Features/Post/RichText.swift:187-193` |

## Commands the reviewer ran

- `diff.mjs` raw and masked on all 5 captured states: all 13 PARITY.md ratios reproduced (masked 2 pass, 11 drift; raw 8 of 13 fail).
- `events.mjs` unordered: MATCH 18 of 18. With `--ordered`: MISMATCH on `post:view` lines 7-10. Native base vs base2 ordered: MISMATCH.
- Border-row profiles at x 1170 for all states; masked residual by 50 px band; md5 of RN baselines.
- RN event list checked against cited source: 16 of 18 confirmed, 2 not fully verified (N22, remount events).
- Not run: tests, xcodebuild, Maestro, simulator, Android.
