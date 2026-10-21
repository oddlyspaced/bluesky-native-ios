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

6 results are a `fail`. No signature makes one pass, and each keeps its checkpoint open.

| Platform | Screen | Measure | Cause |
|---|---|---|---|
| iOS | `home-api` | 0.0281 masked | A feed slice carrying both a "Reposted by" row and a "Replied to" row is 393 px in the port against React Native's 395 px, and every row below inherits the shift. |
| Android | `base home` | 2.36% masked | The placeholder mark, the Lucide glyphs, and React Native scroll indicator. |
| Android | `dark home` | 2.30% masked | The placeholder mark, the Lucide glyphs, and React Native scroll indicator. |
| Android | `font scale 2.0 home` | 2.32% masked | The placeholder mark, the Lucide glyphs, and React Native scroll indicator. |
| Android | `empty seed home` | 2.10% masked | The placeholder mark, the Lucide glyphs, and React Native scroll indicator. |
| Android | `error home` | 5.24% masked | A behaviour difference after a reseed; see android/PARITY.md. |

Four of the Android failures sit between 2.10% and 2.36%, against a 2% gate, and the same build
moves by up to 0.44 points between rounds. A verdict on those four is worth no more than that
spread. Their causes are the asset substitutions that Bluesky's own `ASSETS.md` requires of a fork,
so they cannot be closed in this repository.

## Group A: screens that drift

Every screen below is above 1% and at or below 2% after masks. Numbers come from
`ios/PARITY.md` and `android/PARITY.md`.

**These numbers were re-measured on 2026-10-21 and are current.** They come from `ios/PARITY.md`
and `android/PARITY.md`, both of which were rewritten on that date. Confirm the commit each number
came from before you ask for a signature.

Every ratio changed, because the comparator was corrected. `diff.mjs` had been reading its
differing-pixel count from `magick compare -metric AE`, which on ImageMagick 7.1.2-32 is a sum of
normalised per-channel magnitudes rather than a count of pixels. The Pack now counts the pixels
itself. The iOS ratios rose by 2 to 20% of their own value, and two screens crossed from pass into
drift and are now listed here for the first time: `thread-dark` (A4) at 0.0101 and `home-mergefeed`
(A11) at 0.0102. Nothing moved the other way.

This also replaces the earlier note about two over-wide mask bands. Those bands were narrowed, and
every row above is now measured in one pass from the committed masks, so no row is carried over from
an older measurement.

**Three Android states left this table.** `font scale 2.0`, `empty seed` and `error` are withdrawn,
not signed and not measured: the captures on disk for them predate the fixes they credited, so there
is no honest number to sign. They need a new capture. That is why the Android list is four screens
where it was seven.

### iOS, 17 screens that drift

| # | State | Screen | Masked ratio | Accepted by | Date | Notes |
|---|---|---|---|---|---|---|
| A1 | base | home | 0.0144 | | | |
| A2 | base | profile | 0.0113 | | | |
| A3 | dark | home-dark | 0.0148 | | | |
| A4 | dark | thread-dark | 0.0101 | | | |
| A5 | dark | profile-dark | 0.0113 | | | |
| A6 | largest Dynamic Type | home-xxxl | 0.0177 | | | |
| A7 | largest Dynamic Type | thread-xxxl | 0.0162 | | | |
| A8 | largest Dynamic Type | profile-xxxl | 0.0186 | | | |
| A9 | empty seed | home-empty | 0.0194 | | | |
| A10 | empty seed | profile-empty | 0.0120 | | | |
| A11 | mergefeed seed | home-mergefeed | 0.0102 | | | |
| A12 | after like and repost | home-liked-reposted | 0.0144 | | | |
| A13 | after like and repost | thread-liked-reposted | 0.0137 | | | |
| A14 | wrapped text | home-wrapped | 0.0134 | | | |
| A15 | wrapped text | thread-wrapped | 0.0173 | | | |
| A16 | wrapped text | profile-wrapped | 0.0163 | | | |
| A17 | API setup | profile-api | 0.0178 | | | |

### Android, 4 screens that drift

| # | State | Screen | Masked ratio | Accepted by | Date | Notes |
|---|---|---|---|---|---|---|
| A18 | font scale 2.0 | thread | 1.71% | | | |
| A19 | font scale 2.0 | profile | 1.66% | | | |
| A20 | after like and repost | home | 1.93% | | | |
| A21 | after like and repost | thread | 1.24% | | | |

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
| E8 | The iOS event result **cannot be reproduced from this repository**. The native log it was measured against lives in `ios/parity/out/`, which is not committed. Android records the same class of problem as blocker A2, where it was treated as blocking. The Android logs for `base` and `dark` are now committed under `android/parity/evidence/`; the iOS logs are not. This applies to event logs only. The RN screenshot baselines behind every pixel number **are** committed, 91 images under `parity/baseline/`. | | |
| E9 | **Android event parity is not claimed on any flow.** The readonly flow has three port defects, listed above. The interactions flow was reported in `android/PARITY.md` as "MATCH, 16 of 16"; that claim was withdrawn on 2026-09-16 because the result file written by the same run records `match: false`, and a re-measurement reports a mismatch. Neither flow may be cited as event parity until a fresh capture settles the interactions flow. | | |

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
