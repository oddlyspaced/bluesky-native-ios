# Parity report (iOS): RN app vs native SwiftUI port

Date: 2026-09-15. The device is the iPhone 17 Pro simulator on iOS 26.4 (`7F73AB4A-2709-4033-89D2-35CE10E650F4`) at 1206x2622 px, 3x scale. Light appearance, same region and time zone for both apps.

- **Baseline:** RN screenshots `ios-home.png`, `ios-thread.png` and `ios-profile.png`, captured by `capture-baseline.yml` from the same seeded server.
- **Native:** `ios/parity/shots/ios-*.png`, captured by `ios/parity/capture-native.yml`. It runs the same steps and the same seed, with appId `xyz.blueskyweb.app.native`.

## Commands

1. Seed and capture. The flow reseeds with `?users&follows&posts&feeds&thread` first.
   ```
   cd ios/parity
   maestro --device 7F73AB4A-2709-4033-89D2-35CE10E650F4 test -e PLATFORM=ios capture-native.yml
   ```
2. Compare:
   ```
   ./compare.sh <rn-baseline-shots-dir>
   ```

For each screen and mask set, `compare.sh` runs:

```
magick compare -metric AE -fuzz 5% rn.png native.png diff.png   # exit 1 = images differ, not an error
ratio = AE / 3162132                                               # 1206 x 2622 pixels
```

Masks are black rectangles painted on **both** images. Their coordinates are in `compare.sh`, measured on the RN baseline.

| Mask set | What it hides | Why |
|---|---|---|
| raw | nothing | - |
| dynamic | Status bar (clock). Relative timestamps ("· 10s" vs "· now"). Thread date line ("12:55 AM · Sep 15, 2026" vs capture time). Logo slots: the header mark, and the anchor butterfly that RN shows only in screenshots. | These change with capture time, or are licence substitutions of a trademark |
| icons | dynamic, plus every icon region: header icons, composer camera/image, post control rows, info icon, FAB glyph, thread header, globe, profile share/more, bottom bar icons | Licence substitution: upstream glyphs replaced by Lucide |

## Measured results

These are the final run's figures, printed by `./compare.sh` against the RN baseline shots:

| Screen | raw AE | raw ratio | dynamic AE | dynamic ratio | icons AE | icons ratio |
|---|---|---|---|---|---|---|
| home | 162043 | 0.0512 | 147063 | 0.0465 | 108159 | 0.0342 |
| thread | 67045 | 0.0212 | 53010 | 0.0168 | 34418 | 0.0109 |
| profile | 60409 | 0.0191 | 52276 | 0.0165 | 38737 | 0.0123 |

**Progress across iterations** (raw ratio, same commands):

| Run | Home | Thread | Profile |
|---|---|---|---|
| First capture | 0.0632 | 0.0218 | 0.0359 |
| Final | 0.0512 | 0.0212 | 0.0191 |

The first-capture fixes were:
- FAB positioned above the bar.
- App-language date locale.
- Profile type sizes.
- Border heights.
- Sub-point row offsets, measured with the text-row profile below.

**Text-row alignment check.** The ink rows of the left text column (x 48-650 px) were compared between the two images in the final run:
- Profile: the name, handle, metrics, bio, tabs and first post rows are within ±1 px.
- Thread: the header and the anchor rows are within ±2 px.
- Home: the header, tabs and composer prompt match at 0 px. The post meta rows are +2 px and the post text rows are ±1 px.

**What the remaining pixels are.** Read the `diff-*-icons.png` images:
- Anti-aliasing fringes around text: sub-pixel differences between RN's text rendering and SwiftUI `Text` with the same Inter variable font.
- 1-2 px row offsets.
- The default avatar silhouette, which differs by licence.

No region shows a missing or rearranged element.

**Not measured:** a same-build noise floor (two native captures compared with each other) and any threshold per screen. Treat the ratios above as measurements, not pass/fail gates.

## Accepted design differences

| # | Difference | RN | Native | Reason | Parity check |
|---|---|---|---|---|---|
| 1 | UI icons | Central icon system glyphs | Lucide equivalents with the same size, 2pt stroke and colour tokens | **Licensing:** upstream icons and marks are not licensed for redistribution (ASSETS.md sections 2 and 3) | "icons" mask set |
| 2 | Header logo, anchor logo | Butterfly mark | Neutral brand-blue diamond in the header; nothing in the anchor slot | **Licensing:** upstream icons and marks are not licensed for redistribution (ASSETS.md sections 2 and 3) | Logo regions masked in "dynamic" |
| 3 | Default avatar | Bluesky default avatar artwork | Generic circle-and-ellipse silhouette in the same blue | **Licensing:** upstream icons and marks are not licensed for redistribution (ASSETS.md sections 2 and 3) | Not masked (counted in all ratios) |
| 4 | Signed-out splash | Commissioned illustration and logotype | Mark, name and the two buttons, no art | **Licensing:** ASSETS.md sections 1 and 3 | Not captured (the flow only waits for "Sign in") |
| 5 | Filled icon variants (active Home tab, liked heart) | Dedicated filled glyphs | Lucide outline filled and stroked in the same colour | Follows from row 1 | Visual check: `shots/interactions-liked-reposted.png` |
| 6 | Relative timestamps and status bar clock | Capture time | Capture time | Dynamic | "dynamic" mask set |

## Behaviour differences

| # | Difference | RN behaviour | Native behaviour | Status |
|---|---|---|---|---|
| 1 | Thread API | `app.bsky.unspecced.getPostThreadV2` (linear, `sort: top`) | `app.bsky.feed.getPostThread` (depth 10), flattened to the same linear rows; reply order as returned by the server | Open: needs acceptance. Same output for the seeded data. |
| 2 | Rich text | Facets rendered (links, mentions, tags) | Plain text | Out of slice scope |
| 3 | Embeds, moderation, labels, translations | Supported | Not ported | Out of slice scope |
| 4 | Composer, bookmarks, share, menus, other tabs | Functional | "Not part of this showcase" sheet or view | Out of slice scope |
| 5 | Header and bottom bar hide on scroll | Minimal-shell transform | Always visible | Open |
| 6 | Swipe-back gesture | Native stack gesture | Back button only (navigation bar hidden) | Open |
| 7 | Discover fallback feed | Fetched in release; skipped in `__DEV__` | Never fetched; fallback header and end-of-feed shown | Matches the RN dev/e2e build |
| 8 | E2E controls | 12 working 1x1 controls | 3 working (`e2eSignInAlice`, `e2eSignInBob`, `e2eSignOut`); 9 inert slots keep the same red column | Accepted for the showcase |
| 9 | Avatar and name taps | Open the profile | No action | Out of slice scope |
| 10 | PostMeta line box and profile paddings | lineHeight 17; RN paddings | Same tokens plus measured sub-point offsets (commented in code) to match RN's iOS text layout | Documented in `PostViews.swift`, `ProfileScreen.swift`, `ThreadScreen.swift` |

## Interaction evidence

`ios/parity/interactions-native.yml` ran against the live dev server with exit 0. The steps were:
1. Like the first post.
2. Repost it through the "Repost" menu item.
3. Open the thread.
4. Go back.
5. Assert that the "Remove repost" menu item is visible, which requires the server-created repost state, and tap it.
6. Unlike.

**Screenshots:** `shots/interactions-liked-reposted.png` shows the green repost count 1 and the filled pink heart count 1. `shots/interactions-undone.png` shows the state after undo.

**Server check.** After the run, `app.bsky.feed.getTimeline` for alice.test returned `likeCount 0`, `repostCount 0` and no `viewer.like` or `viewer.repost` on every post. The undo reached the server.
