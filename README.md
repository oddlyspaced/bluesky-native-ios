# Bluesky, ported to SwiftUI

Three screens of the [Bluesky](https://github.com/bluesky-social/social-app) React Native app —
home feed, post thread and profile — rebuilt in SwiftUI, then measured against the running React
Native app on the same simulator, the same build and the same seeded data.

Built with the [Nativestarter](https://nativestarter.io) Migration Pack, one checkpoint at a time.
The Android half of the same slice is in
[bluesky-native-android](https://github.com/oddlyspaced/bluesky-native-android).

Not affiliated with, endorsed by, or officially connected to Bluesky Social PBC. See `NOTICE.md`.

## What was measured

20 screens across seven states, captured 2026-09-16 on an iPhone 17 Pro simulator (iOS 26.4),
re-measured 2026-10-21 after the comparator was corrected. Masked ratio is differing pixels after
masks, over 3,162,132 pixels per screen. Pass is at or below 1%, drift is 1% to 2% and needs a
human signature, above 2% is a fail.

**2 pass, 17 drift, 1 fail.**

| State | Screen | Raw | Masked | Status |
|---|---|---|---|---|
| base | home | 0.0275 | 0.0144 | drift |
| base | thread | 0.0171 | 0.0099 | pass |
| base | profile | 0.0179 | 0.0113 | drift |
| dark | home-dark | 0.0277 | 0.0148 | drift |
| dark | thread-dark | 0.0176 | 0.0101 | drift |
| dark | profile-dark | 0.0168 | 0.0113 | drift |
| largest Dynamic Type | home-xxxl | 0.0319 | 0.0177 | drift |
| largest Dynamic Type | thread-xxxl | 0.0238 | 0.0162 | drift |
| largest Dynamic Type | profile-xxxl | 0.0254 | 0.0186 | drift |
| empty seed | home-empty | 0.0260 | 0.0194 | drift |
| empty seed | profile-empty | 0.0200 | 0.0120 | drift |
| merged feed | home-mergefeed | 0.0232 | 0.0102 | drift |
| after like and repost | home-liked-reposted | 0.0273 | 0.0144 | drift |
| after like and repost | thread-liked-reposted | 0.0213 | 0.0137 | drift |
| wrapped text | home-wrapped | 0.0262 | 0.0134 | drift |
| wrapped text | thread-wrapped | 0.0236 | 0.0173 | drift |
| wrapped text | profile-wrapped | 0.0241 | 0.0163 | drift |
| API setup | **home-api** | 0.0416 | **0.0281** | **fail** |
| API setup | thread-api | 0.0125 | 0.0059 | pass |
| API setup | profile-api | 0.0254 | 0.0178 | drift |

Tests: 148 in 22 suites pass. Release build succeeds.

## The screen that fails, and why

`home-api` is above the 2% gate and the checkpoint stays open. The cause is measured, not guessed:
a feed slice carrying both a "Reposted by" reason row **and** a "Replied to" row is 393 px tall in
the port against React Native's 395 px, and every row below it inherits the two-pixel shift.

Row borders, React Native: 460, 645, 978, 1373, 1646, 1919, 2192. Native: 460, 645, 978, 1371,
1644, 1917, 2190.

Two fixes were tried and both reverted, because a reason row alone (185 px) and a "Replied to" row
alone (273 px) each match React Native exactly — so no constant closes the gap without regressing
them. `ios/PARITY.md` has the full account.

## Every screen has the same elements, in the same order

Measured 2026-10-22 with [parity-compare](https://github.com/oddlyspaced/parity-compare), which
reports structure, position and content separately instead of as one percentage:

**All 20 screens: every content band matched. Nothing missing, nothing extra.**

That is the claim a percentage could never make. The percentages above are dominated by three
things that are different on purpose and cannot be otherwise: the placeholder mark standing in for
Bluesky's logo, the Lucide glyphs standing in for the Central icon set, and the code-drawn fallback
avatar. Bluesky's `ASSETS.md` licenses none of those three for reuse, and the icon set is not
Bluesky's to license at all.

Two of those three are excluded by the masks. The avatar is not, and that is deliberate rather
than an oversight. On `home-api`, the one failing screen, the differing pixels inside the avatar
rects are 14,607 of 88,958, about a sixth of the difference; masking them would leave roughly
2.3%, which is still a fail. A `rect` band over each avatar was declared anyway and
`make_masks.py` refused it on three counts: the home masks would then cover 16.7 to 17.3% against
its 15% limit, the profile avatar builds a 273 px mask against its 160 px limit, and at the
largest Dynamic Type native ink falls outside the React Native ink box. That coverage limit is
what stands between a mask and a manufactured pass, so it stands and the avatar stays counted
against this port.

With the masks applied, what remains is position: vertical offsets of 1 to 6 px on most
screens, 21 to 39 px at the largest Dynamic Type. Each is reported once, at the band it starts
from, rather than multiplied into every row below it.

This is also why `home-api` fails. Its content is sound and its structure matches; a slice two
pixels short shifts everything under it, and a percentage counts that shift about forty thousand
times.

## What this does not claim

**No flow matches on events.** `ios/PARITY.md` records which, and why.

**Nothing is signed off.** Every drift needs a written acceptance from someone who did not write
the port. `plan/owner-signoff.md` is the form, and it is empty.

**Two review findings are unfixed**, recorded with the reason rather than quietly dropped: A69
needs a `maestro hierarchy` capture, and A84 arrived without a file or line to act on.

## The tooling was wrong more often than the code

Worth saying plainly, because it is the reason to trust the numbers rather than a reason not to.
`diff.mjs` read its pixel count from `magick compare -metric AE`, which in ImageMagick 7.1.2-32
is no longer a pixel count: a 40x40 red rectangle over white (1600 differing pixels) reports 800,
and the same rectangle in `rgb(254,254,254)` reports 4.71. Every ratio on this page was re-measured
after that was found and fixed. Two verdicts moved, both to the worse side: `thread-dark` and
`home-mergefeed` crossed from pass into drift.

Earlier, two mask bands were found to be hiding content that matched in both apps — a silent pass,
which is the worst kind. Narrowing them raised six thread ratios. That is recorded too.

## Build and run

No installable build is published: Apple does not allow one outside TestFlight or ad-hoc
provisioning. Build it from source.

1. Start the upstream e2e dev network from `bluesky-social/social-app` at commit `2bfb94d`:
   `pnpm e2e:mock-server`. Keep ports 2584 and 3000-3003 free; the AppView DID depends on them.
2. Seed: `curl -X POST "http://localhost:1986/?users&follows&posts&feeds&thread"`.
3. Open `ios/BlueskyNative.xcodeproj` and run the `NativeShowcase` scheme on an iOS 26 simulator.

Tests: `xcodebuild test -project ios/BlueskyNative.xcodeproj -scheme NativeShowcase -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`

## Reproduce the measurement

The capture and diff scripts under `ios/parity/` call the Migration Pack, which is a commercial
product and is not in this repository. The React Native baselines it measured against **are**
committed under `parity/baseline/rn/`, so the numbers can be checked against the images.

## Scope

The upstream app has 78 screens. This port covers the foundation — design tokens, XRPC client,
session, tab shell — and three screens. Tabs outside the slice show a labelled placeholder.
`plan/full-app-plan.md` is the 127-checkpoint plan for the whole app; `plan/slice-plan.md` is the
four checkpoints this showcase covers.

## Licence

MIT, see `LICENSE`. Portions derive from bluesky-social/social-app, also MIT. Bluesky's logo, icon
set and other marks are **not** in this repository and are not covered by that licence; `NOTICE.md`
lists each one and what replaced it.
