# Owner sign-off: CP-00 to CP-03

This file is the single place where the owner accepts or rejects every recorded difference between
the React Native app and the two native ports. Three review rounds on iOS and one on Android each
recorded "no human sign-off" as a blocker. That blocker closes here, and only here.

Status: **nothing in this file is signed.**

## The rule

From `migration-pack/skills/check-parity/references/thresholds.md`:

1. A `drift` result (above 1%, at most 2% of pixels) is a decision, not a number. The owner opens the
   diff image and both screenshots, names what differs, and accepts it in writing or sends the port
   back.
2. A `fail` result (above 2%) is **never** signed off. The port is fixed and captured again.
3. The person who wrote the port must not sign off its own drift. Every port commit in this repo was
   written by Claude, so Claude must not sign any row below.
4. The checkpoint gate "Parity report passes, or every drift is accepted in writing" is ticked only
   when every row in groups A to E carries a name and a date.

## What cannot be signed

Two results are `fail`. No signature makes them pass. Both keep their checkpoint open.

| Platform | Screen | Measure | Cause |
|---|---|---|---|
| iOS | `home-api` | 0.0273 masked, threshold 0.02 | A feed slice with a reason row **and** a "Replied to" row is 393 px in the port against RN's 395 px. Every row below inherits the 2 px shift. Measured cause and two reverted attempts are in `ios/PARITY.md`, section "The `home-api` failure". |
| Android | error home | 4.91% masked | A behaviour difference, not a capture artefact. After a reseed the port refetches the feed and shows the load-more retry row; RN does not refetch and keeps the end-of-feed state. |

The owner does not need to decide anything about these two. They are engineering work that is not
finished.

Three more items are not signable, for a different reason: they are defects to fix, not differences
to accept. Their causes were established on 2026-09-16 and are recorded in `android/PARITY.md`,
section "Event diff".

| Platform | Defect | Cause |
|---|---|---|
| Android | The port never emits the second `home:feedDisplayed`, the one with no `reason` key that RN fires when the pager settles on the initial tab | RN has two call sites (`Home.tsx:178` and `Home.tsx:199`); the port has one, with `reason` hardcoded |
| Android | On back-navigation the port logs `router:navigate {from: PostThread}` before the focus event; RN logs it after | The shell effect (`AppShell.kt:296-304`) runs before the destination's own effect |
| Android | The profile feed never emits `feed:endReached` | The port auto-paginates inline in the load coroutine (`FeedPager.kt:85`), so `isFetching` is already true when the gate at `ProfileScreen.kt:165` first evaluates |

Two differences this list previously carried have been withdrawn. The port's `post:view` positions
and `isReply` match RN exactly, and the profile `post:view` **is** emitted. Both were artifacts of a
comparator that aligns two logs by position, so one missing event near the head manufactured a
cascade of false mismatches. The earlier entries were wrong, and the RN log for this flow is captured
from the device rather than derived, so it is ground truth.

## How to review a row

For each row in group A:

1. Open the three images named in the row: the RN capture, the native capture and the diff.
   They are under `ios/parity/baseline/` and `android/parity/baseline/`, with the diffs under
   `parity/out/`.
2. Name what differs, in your own words, in the Notes column.
3. Write your name and the date, or write "rejected" and the reason.

A rejection is not a failure of the process. It sends one screen back to be fixed and captured again.

## Group A: screens that drift

Every screen below is above 1% and at or below 2% after masks. Numbers come from
`ios/PARITY.md` and `android/PARITY.md`.

**These numbers are provisional.** Both platforms are in a fix round as this file is written.
Refresh this table from the two parity reports, and confirm the commit each number came from, before
you ask for a signature.

### iOS, 15 screens (4 pass, 15 drift, 1 fail)

| # | State | Screen | Masked ratio | Accepted by | Date | Notes |
|---|---|---|---|---|---|---|
| A1 | base | home | 0.0139 | | | |
| A2 | base | profile | 0.0109 | | | |
| A3 | dark | home-dark | 0.0142 | | | |
| A4 | dark | profile-dark | 0.0108 | | | |
| A5 | largest Dynamic Type | home-xxxl | 0.0170 | | | |
| A6 | largest Dynamic Type | thread-xxxl | 0.0150 | | | |
| A7 | largest Dynamic Type | profile-xxxl | 0.0179 | | | |
| A8 | empty seed | home-empty | 0.0188 | | | |
| A9 | empty seed | profile-empty | 0.0116 | | | |
| A10 | after like and repost | home-liked-reposted | 0.0139 | | | |
| A11 | after like and repost | thread-liked-reposted | 0.0126 | | | |
| A12 | wrapped text | home-wrapped | 0.0128 | | | |
| A13 | wrapped text | thread-wrapped | 0.0141 | | | |
| A14 | wrapped text | profile-wrapped | 0.0157 | | | |
| A15 | API setup | profile-api | 0.0172 | | | |

### Android, 7 screens

| # | State | Screen | Masked ratio | Accepted by | Date | Notes |
|---|---|---|---|---|---|---|
| A16 | base | home | 1.61% | | | |
| A17 | dark | home | 1.75% | | | |
| A18 | font scale 2.0 | home | 1.68% | | | |
| A19 | font scale 2.0 | thread | 1.45% | | | |
| A20 | font scale 2.0 | profile | 1.26% | | | |
| A21 | empty seed | home | 1.38% | | | |
| A22 | after like and repost | home | 1.62% | | | |

## Group B: differences the ports keep on purpose, iOS

From `ios/PARITY.md`, "Differences that remain". Row 10 of that table is the `home-api` fail and is
not listed here, because a fail is not signed.

| # | Difference | Accepted by | Date | Notes |
|---|---|---|---|---|
| B1 | UI icons: Lucide glyphs, fitted per glyph to the RN ink box, in place of the Central icon set | | | |
| B2 | Logo and anchor mark: a neutral diamond in place of the butterfly | | | |
| B3 | Default avatar: a generic silhouette in the same blue | | | |
| B4 | Header hide on scroll follows the scroll delta, with no snap on drag end | | | |
| B5 | Bottom bar minimal-shell transform is absent; no screen in the slice enables it | | | |
| B6 | Sign-out also calls `com.atproto.server.deleteSession`, which RN does not | | | |
| B7 | `post:view` fires when a row is laid out for 500 ms, where RN needs 40% visible for 500 ms | | | |
| B8 | Tabs use the selected trait, not `accessibilityRole="tab"` | | | |
| B9 | Five native-only fault controls in the E2E build, 15 px at the left edge, not masked | | | |
| B10 | Wrapped anchor text sits 2 px higher at the same pitch; the row borders match | | | |
| B11 | Line pitch is a rule, with per-component constants fitted to one 3x device and not verified at 2x | | | |
| B12 | The Release build is a smoke build: no sign-in form, local networking allowed, no event log | | | |
| B13 | Tag taps and other-user taps say "Not part of this showcase" | | | |
| B14 | The tab container is a `ZStack` of per-tab navigation stacks, not an RN tab navigator | | | |
| B15 | The thread shows the linear view only; the metric logs the server value | | | |

## Group C: differences the ports keep on purpose, Android

From `android/PARITY.md`, "Differences that remain". Row 2 of that table is the error-home fail and
is not listed here.

| # | Difference | Accepted by | Date | Notes |
|---|---|---|---|---|
| C1 | Relative time: the port shows "now" where RN shows "1m" to "3m", because the tick starts at a different moment | | | |
| C2 | Header dropdown and share glyph shapes (Lucide) | | | |
| C3 | Code-drawn fallback avatars | | | |
| C4 | No scroll indicator on the profile, where RN shows a scrollbar | | | |
| C5 | Profile description links and mentions are not detected; the seeded bio has none | | | |

## Group D: work proposed as out of scope

From `plan/slice-plan.md`. The slice is not complete until the owner accepts these, or moves them
into scope.

| # | Proposed out of scope | Reason given | Accepted by | Date |
|---|---|---|---|---|
| D1 | Post embeds: images, video, external link cards, quote posts, record-with-media | The seed data has no embeds. Each embed type is a separate component set. | | |
| D2 | Long-press repost to quote | Needs the composer, which is out of scope. | | |
| D3 | Chat unread badge | Chat is out of scope. | | |
| D4 | Other profile tabs, and other users' profiles | The slice covers the own profile, Posts tab only. | | |
| D5 | Thread tree view (`lab_treeViewEnabled`) | The e2e account uses the default linear view. | | |
| D6 | Licensing substitutions: open icon set, neutral mark, code-drawn avatar, app name without "Bluesky" | Upstream `ASSETS.md` sections 2 and 3 do not license the icons and marks for redistribution. | | |

D6 is not a preference. If the owner rejects it, the showcase cannot be published with the upstream
icons and marks. See `NOTICE.md`.

## Group E: how the evidence was made

These are not screen differences. They are limits of the method. The owner accepts the method, or
asks for more evidence before any parity claim is published.

| # | Limit | Accepted by | Date |
|---|---|---|---|
| E1 | The RN event list on iOS is derived by reading the RN source, not captured from the running RN app. The port's 19 events are compared against that derived list. | | |
| E2 | Events are emitted only by the E2E build, which also differs from Release in its fault hook, service URL, AppView proxy DID and sign-in path. Event parity therefore describes the E2E configuration. | | |
| E3 | Masks cover 9% to 13.5% of each iOS image, all at or below the 15% limit. A mask hides a licensed substitution or a capture variant. `make_masks.py` checks that no native ink inside a mask lies outside the RN ink of that mask. | | |
| E4 | Five states on iOS have no RN counterpart (first-load, load-more, thread and profile errors) because RN has no fault control and the shared server must not be stopped. They are proven by unit tests, not by a pixel diff. | | |
| E5 | Loading skeletons, not-found, tombstones, load-more after 30 posts, pull to refresh and link long press are proven by unit tests only. A screenshot of each is either not deterministic or not reachable through Maestro. | | |
| E6 | Every capture is one device per platform: an iPhone simulator at 3x, and a Pixel 10 Pro emulator at density 480. No second device, scale or orientation is measured. | | |
| E7 | The iOS event claim, "ordered MATCH, 19 of 19", covers the **`base` state only**. One RN expected list is committed (`ios/parity/events/rn-expected-base.jsonl`). The other seven states have no event comparison. | | |
| E8 | The iOS event result **cannot be reproduced from this repository**. The native log it was measured against lives in `ios/parity/out/`, which is not committed. Android records the same class of problem as blocker A2, where it was treated as blocking. The Android logs for `base` and `dark` are now committed under `android/parity/evidence/`; the iOS logs are not. | | |

Both E7 and E8 were established on 2026-09-16, when the event comparator itself was found defective
and rebuilt (see below). The iOS match was re-measured with the corrected comparator and still
reports 19 of 19 for `base`, so the claim holds for the state it covers.

**The comparator that produced every event result in this repository had a defect.** In `--ordered`
mode it compared the two logs by index, so one absent event near the head shifted every later index
and manufactured differences that did not exist. On the Android capture it reported 14 difference
lines where 3 were real. It is fixed in the Pack (`events.mjs`, aligned with a longest common
subsequence) and re-run against the same Android logs gives 3 lines, matching the hand analysis.
Every event number in the reports predates that fix unless it says otherwise, and each is being
re-measured.

## Signature

I have reviewed each row above that carries my name. I did not write the port.

```
Name:
Role:
Date:
```

Unsigned rows keep their checkpoint open.
