# Parity review 3: CP-00 to CP-03, iOS

- Reviewer: `parity-reviewer` agent (Nativestarter Migration Pack), run on 2026-09-16
- Code reviewed: diff `4e72ea8..44754fd -- ios parity`, against bluesky-social/social-app at `2bfb94d`
- Verdict: **Blockers found: 2** (F1, F2)
- Round-2 status: 14 fixed, 2 partially fixed, 6 not fixed, 2 accepted with reason but no named person (N4, N14), 1 proposed out of scope (N5)
- Paths: native paths are relative to `ios/BlueskyNative/` unless they start with `ios/`

## Round-2 verdicts

| # | Verdict | Evidence |
|---|---|---|
| N1 | Fixed | `Features/Thread/ThreadScreen.swift:443` passes `isAnchor: false`; anchor still logs (`:156`); matches `ThreadItemAnchor.tsx:281` |
| N2 | Fixed (unit test only) | `TabShell.swift:52` reads `ThreadModel.canReply` (`ThreadModel.swift:323-326`) |
| N3 | Not fixed, not recorded | `ProfileScreen.swift:204` passes `facets: nil` (F4) |
| N4 | Accepted with a verified reason; no named person | RN scroll changes only `headerMode` (`MainScrollProvider.tsx:104-115`); the footer changes only by screen count (`minimal-mode.tsx:31-45`) |
| N5 | Proposed out of scope | `slice-plan.md:45`; metric logs the server value (`ThreadModel.swift:406-409`) |
| N6 | Fixed | Ordered MATCH 19 of 19 reproduced; native base vs base2 ordered MATCH |
| N7 | Not fixed; recorded reason incomplete | Only one-child containers tried (F2) |
| N8–N10 | Fixed | `Core/Formatting/ErrorText.swift:11-14,44-55,60-66` |
| N11 | Not fixed, recorded | PARITY.md:150-151,238 (F12) |
| N12 | Not fixed, recorded | Rule model reverted in `7461701` (F7) |
| N13 | Partially fixed | Mergefeed captured; other states unit-test or native only (F9) |
| N14 | Accepted with a verified reason; no named person | Tail slot hides only the clock value |
| N15, N16 | Fixed | No haptic on repost menu open; swipe-back flow step asserts the result |
| N17, N18 | Fixed | Date-line mask only in `interactions`; `thread-xxxl` mask area 11.17% |
| N19 | Partially fixed | Masks from RN image only; native-escape check has gaps (F5) |
| N20 | Fixed | r2 baseline md5 equals the matching captures |
| N21 | Not fixed | No acceptor (F1) |
| N22 | Fixed; adds an unrecorded difference | `ThreadModel.swift:361-373,395-399` (F3) |
| N23, N24 | Fixed | Anchor view on placeholder; normalizer drops no event and resolves ids through the PDS |
| N25 | Not fixed, recorded | (F13) |

## Blockers

| # | Area | Finding | Fix |
|---|---|---|---|
| F1 | Recorded differences | 11 drift screens, 17 difference rows and 6 proposed out-of-scope rows have no named acceptor (`ios/PARITY.md:10,14,221-243`; `plan/slice-plan.md:37,60`) | The owner accepts or rejects each drift, difference and N4, N14, N5 by name and date |
| F2 | testIDs | `HomeScreen`, `followingFeedPage`, `profileScreen` not exposed (`Features/Feed/HomeScreen.swift:40-43,73`; `Features/Profile/ProfileScreen.swift:104-105`). Commit `c6adce5` wrapped the screen in a one-child `VStack`, so the recorded reason (one-child chains) was never tested against a container with a second child | Give the outer container a second child (for example a zero-size hidden view), or set the id on the hosting stack; verify with `maestro hierarchy`. Otherwise the owner changes the spec |

## Major

| # | Area | Finding | RN reference | Fix |
|---|---|---|---|---|
| F3 | Errors | A preferences failure shows the thread error screen with Retry; PARITY.md has no row for it | `usePostThread/index.ts:74,141-151` keeps placeholder data while preferences load | Keep the placeholder or skeletons as RN does, or record and accept |
| F4 | Facets | Profile bio renders without facets (`ProfileScreen.swift:203-204`) | `ProfileHeaderStandard.tsx:148-151` | Detect and render bio facets, or record |
| F5 | Masks | `rect` bands are never checked against native ink (`ios/parity/make_masks.py:132-133`); glyph bands check only native clusters at least 36 px wide (`:139-140`); the bell rect `[785,2440,885,2506]` covers the lower ~20 px of the unread badge | `check-parity/references/masking.md` | Check all native ink inside every mask against RN ink; stop the bell rect above the badge |
| F6 | Icons | `make_masks.py` reports 4 native glyphs outside RN slots: `home-xxxl` control glyph and info glyph, `thread-xxxl` anchor like glyph, `home-empty` info glyph. PARITY.md:225 says "same sizes" | RN glyph boxes | Size Lucide glyphs to the RN icon box at xxxl and in the empty state, or correct the row and accept |
| F7 | Line boxes | `Typography.swift:207` still clamps `lineSpacing`; per-component constants at `:169-182`. The claim that base screens have no wrapped text avoids the question; no capture has multi-line post text or a 2x device | `RCTAttributedTextUtils.mm:229-232`; `RCTTextLayoutManager.mm:361-394` | Capture a wrapped-text state (for example a 3-line post created through the API before capture) before row 15 is accepted |
| F8 | Events evidence | RN event list derived from source; order not observed at runtime for entries 12/13, 15/16, and a pager `home:feedDisplayed` without `reason` on first mount | `Home.tsx:188-205`; `Navigation.tsx:1057-1066` | Capture a real RN metric log in a separate e2e checkout with debug metric logging, or owner accepts the derived list |
| F9 | States evidence | Loading, first-load error, load-more error, not-found, facets, reply-disabled and reason rows have no RN capture | `plan/slice-plan.md:27-28` | Add RN captures where a seed or API setup step can produce the state; otherwise record each as unit-test-only and accept |

## Minor

| # | Finding | Fix |
|---|---|---|
| F10 | Thread preferences metric compares the whole `ActorPreferences` and never refetches; RN compares `threadViewPrefs` by reference with a 15 s stale time (`preferences/index.ts:65-66`) | Compare only thread view prefs; refetch when older than 15 s |
| F11 | `ios/PARITY.md:14` counts 3 pass, 12 drift; the table has 3 pass, 11 drift | Correct the count |
| F12 | Thread reply-prompt border: RN y 2275, native y 2277 | Move the border up 2 px |
| F13 | No long-press share on links (`Features/Post/RichText.swift`) | Context menu with share (`Link.tsx:258-281`) |

## Commands the reviewer ran

- `diff.mjs` raw and masked for base, xxxl, empty and mergefeed: all 18 ratios match PARITY.md.
- `events.mjs --ordered`: MATCH 19 of 19; native base vs base2 ordered MATCH.
- `make_masks.py` for 6 states: identical to committed masks, with the same 4 ERROR lines.
- A scan of native ink inside every mask rect (found F5).
- md5 of r2 baselines against captures: equal.
- All 19 derived RN events checked against source for names and props.
- Not run: xcodebuild, tests, Maestro, simulator, Android.
