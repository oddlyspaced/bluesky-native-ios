# Architecture review 3: CP-00 to CP-03, iOS

- Reviewer: `architecture-reviewer` agent (Nativestarter Migration Pack), run on 2026-09-16
- Code reviewed: `ios/` at `f3dda58`. Diff `44754fd..HEAD`, plus `4e72ea8..44754fd`, which carries the A46–A62 fixes and which no earlier architecture review covered
- Verdict: **Blockers found: 2** (A63, A64)
- Round-2 status: 14 fixed, 6 partially fixed, 3 not fixed (A55, A18, A24), 1 fixed with a residual
- Paths are relative to `ios/BlueskyNative/` unless they start with `ios/`

## Round-2 verdicts

| # | Verdict | Evidence |
|---|---|---|
| A46 | Fixed | One chain owned by SessionStore (`Core/Session/CredentialWriteChain.swift:12-58`; `SessionStore.swift:49,109-131,142-146`), generation checked inside the chain before the write. Both races tested with gated writes (`NetworkingTests.swift:412-433,437-459`) |
| A47 | Fixed | `invalidate()` awaits the in-flight refresh and keeps the rotated session; sign-out awaits it before the revoke. Test asserts the revoke sends the newest token |
| A48 | Fixed | Synchronous enqueue in call order (`CredentialWriteChain.swift:37-48`). Test is weak, see A85 |
| A49 | Fixed | `guard writes.isCurrent(start)` after the await; `signOutDuringSignInWins` |
| A50 | Fixed | `lastError` and `acceptRefreshedTokens` removed |
| A51 | Fixed | `Support/Gate.swift`; no `sleep` anywhere in the test target |
| A52 | Fixed | Fault storage and `arm` compile only under `#if E2E`; `consume` folds to false in Release |
| A53 | Partially fixed | The fake throws real errors and several tests inject `URLError`, but the cited tests still drive the fault hook |
| A54 | Fixed | Only successful preference loads are cached; failures rethrow and refetch (`FeedModel.swift:37-70`) |
| A55 | **Not fixed, not recorded** | `Core/Images/ImageLoader.swift` unchanged: task keyed on `url` only, stale image kept across a URL change, download never cancelled. No test references the loader |
| A56 | Partially fixed | `reset(uris:)` removed; queued-toggle context and clout unchanged |
| A57 | Partially fixed, residual recorded | Pitch is now a rule from the unrounded font height; the clamp at 0 remains and 9 per-component constants remain |
| A58 | Fixed, one residual | Open `ScreenRoute`, `routers: [ShellTab: TabRouter]`, `ScreenRegistry` factories, lazy route-scoped models, feature-owned registration. Residual: one hard-coded tab check (A71) |
| A59 | Fixed | `PreferencesStore`, `AppActivity`, `URLOpening`, and a headless-tested `LinkRouter`. No `UIApplication` state read or `UserDefaults` access in `Features/` |
| A60 | Fixed | The log type is entirely `#if E2E`; Release uses `NoopAnalytics`; one queue, one encoder, one handle. See A65 for the evidence cost |
| A61 | Fixed, residual | `items` precomputed and rebuilt only on input change. Residual O(n) scans (A70) |
| A62 | Fixed | Task stored before the first check, with a cancellation handler, and tested |
| A18 | Not fixed, not recorded | 36 raw paddings and 26 raw frame sizes remain in `Features/` |
| A19 | Partially fixed | Pitch is a rule; 9 per-component constants remain, plus two in `PostFeedItemView.swift:19-22` |
| A20 | Partially fixed | AppRouter and PreferencesModel failure now tested. Still untested: image loader, incomplete-thread collapse, model-level cancellation |
| A24 | Not fixed | History not rewritten; `baac0ef` is still reachable, so the commits cannot be bisected |
| A30 | Fixed | Every remaining `Task {}` is stored and cancellable, or a one-shot action whose model owns cancellation |
| A40 | Partially fixed | Error-copy tests assert real strings; `postsLabel` still restates `Plural.word`; no multi-line height or 29/30 boundary test |

## Blockers

| # | Area | Finding | Evidence | Fix |
|---|---|---|---|---|
| A63 | Platform API misuse | `override open func viewDidLoad`/`viewDidLayoutSubviews` in an **extension** on `UINavigationController` is unsupported Swift, with no guaranteed dispatch or `super` contract. The extension also declares `@retroactive UIGestureRecognizerDelegate` and sets `gesture.delegate = self` on **every** `UINavigationController` in the process, replacing UIKit's own delegate, including in system-presented stacks | `Core/Platform/InteractivePop.swift:15-23,33-41` | Scope it to this app's stacks through a representable that reaches its own `navigationController`. Keep UIKit's delegate or proxy to it. Never override from an extension |
| A64 | Tests, accessibility | The five screen ids added for F2 have no automated check: no test reads the accessibility tree and no capture flow asserts them. The only evidence is a hand-run `maestro hierarchy` whose output was not stored. Deleting the zero-size second child leaves every check passing | `HomeScreen.swift:24-40`; `ProfileScreen.swift:22-29,71-78`; `TabShell.swift:123-131`; `ios/parity/flows/capture.yml:44-47,85-88` | Assert each id in the capture flows, or add a UI test that reads the tree. Commit the hierarchy output as the recorded measurement |

## Major

| # | Area | Finding | Evidence |
|---|---|---|---|
| A65 | Analytics evidence | The E2E build is now the only one that emits events, and it also uses a different AppView proxy DID and service URL and has no sign-in path. Every event-parity claim therefore describes a configuration that differs from Release in analytics, faults, service URL and proxy header | `Core/Analytics/Analytics.swift:54,113`; `App/AppConfig.swift:4-13`; `ios/project.yml:46-49` |
| A66 | Duplication, tests | Two `openThread` entry points. `AppRouter.openThread` pushes without creating the model or reporting render events, so it cannot produce RN's event order. No production code calls it, but the router tests do | `Features/Shell/ShellRoutes.swift:16-19,35-43` |
| A67 | Correctness, environment leak | `handle.hasSuffix(".test")` is a capture accommodation in shipping detection code, with no recorded reason, so Release linkifies mentions the SDK leaves as plain text | `Features/Post/RichTextDetection.swift:40` |
| A68 | Performance | Mention handles resolve serially with no cache or cancellation, and the profile stays loading until the last returns | `Features/Post/RichTextDetection.swift:88-102`; `Features/Profile/ProfileModel.swift:42-48` |
| A69 | Accessibility | The zero-size spacers added for the screen ids each become their own unlabeled accessibility element: four on Home and Profile | `HomeScreen.swift:27,36`; `ProfileScreen.swift:25,74` |
| A70 | Performance, duplication | Thread viewability scans `items` linearly per row event, O(n²) over a long thread, although `FeedModel` already solved it with an index map | `Features/Thread/ThreadModel.swift:491-504`; `Features/Feed/FeedModel.swift:137,242-255` |
| A71 | Architectural drift | The shell hard-codes `if router.tab == .home` to attach the screen id, which is exactly what the A58 registry exists to remove | `Features/Shell/TabShell.swift:123-131` |
| A72 | State lifetime | `pruneRoutes()` runs only on a screen-name change, so PostThread pushed from PostThread leaks its model and full thread response on pop | `Features/Shell/TabShell.swift:99-106`; `AccountContainer.swift:320-323` |
| A73 | Parity tooling | `make_masks.py` has no automated caller: the documented capture flow never regenerates masks or checks its exit code, so committed masks can drift and the native-ink check need never run | `ios/parity/run-pair.sh:24-33`; `run-capture.sh:73-87` |
| A74 | Parity tooling, silent pass | The ink check compares ink inside a mask against RN ink inside the same mask, so an over-large hand-written band hides matching content in both apps with no error. `minw: 36` can also promote a wide count to a masked glyph slot | `ios/parity/make_masks.py:157-174`; `masks-spec.json` |
| A75 | Parity tooling, correctness | The row background is sampled at a single pixel `px[6, y]`, so any row whose left edge is not page background (profile banner, full-width media) judges ink against the wrong reference in both images | `ios/parity/make_masks.py:61-63` |
| A76 | Parity tooling, determinism | The reposted subject is the first record of a 100-record page with no ordering guarantee, and it feeds `home-api`, the one failing screen | `ios/parity/flows/setupApi.js:61-67,100-105` |
| A77 | Parity tooling, concurrency | The seed lock breaks a 20-minute-old lock without checking whether the holder lives, and the lock is shared with the Android captures | `ios/parity/run-capture.sh:29-36`; `run-pair.sh:16-22` |
| A78 | Security | An account switch awaits `invalidate()` but never revokes, so the previous account's refresh token stays valid on the server | `Core/Session/SessionStore.swift:92-131,147-157` |
| A79 | Scale, design system | Six per-glyph `inkFit` constants measured on one device, pinned by tests against hand-entered deltas rather than RN metrics | `DesignSystem/Icons/Icon.swift:40-50`; `IconFitTests.swift:25-33` |

## Minor

A80 chain deadlock invariant undocumented · A81 test-only helpers in production with spin loops · A82 `lastError` dead · A83 `ViewabilityTracker.cancel` has no caller · A84 overlapping preference guards · A85 order test asserts only the final token · A86 preferences committed before the cancellation check · A87 segments computed twice per row · A88 the generated TLD list has no generator · A89 a normaliser failure is swallowed and leaves a truncated file · A90 busy-wait poll during capture · A91 usage comment missing two states

## Parity tooling assessment

The native-ink check is real within its scope: masks come from the RN image or fixed slots, every mask kind and ink width is checked, and edge crossings need a matching RN cluster. Four ways it can still pass silently: no automated caller (A73), unbounded hand-written bands (A74), the `minw` promotion (A74), and the single-pixel background sample (A75). The capture scripts add a breakable lock (A77), a non-deterministic record selection feeding the failing screen (A76), a swallowed normaliser failure (A89) and a busy-wait poll (A90). The event normaliser is sound; its weakness is the RN side, already recorded as F8.

## Scale

A58 closed the three worst seams: a new screen needs one route type, one registration and one factory, with no shell edit except the outer id (A71). Remaining seams: the text primitive and its 9 constants (the binding constraint, and the one the recommended `UIViewRepresentable` would close, along with the `home-api` 2 px); per-glyph icon fits; one 12-endpoint API protocol; no normalised cache; one optional per sheet type; leaf views depending on the whole container; no URL-to-route parser; a single Keychain slot blocking multi-account; one fault case per screen; and about 2,150 lines of hand-written mask geometry for 20 screens.

## Test quality, 14 of 127 sampled

Prove behaviour: the two credential-race tests with gated writes, the revoke-token test, sign-out during sign-in, long-press share, stop during first check, facet detection ranges, bio facets resolved once, preferences failure keeps the placeholder, stale preferences comparison with an injected clock, failed preferences not cached, one JSON object per line.

Weak: the save-order test asserts only the final token (A85); the router test drives the dead path (A66); the icon fit test pins hand-entered deltas (A79); the plural label test restates the implementation; the load-more test still reaches the error through the fault hook (A53).

Missing: the five screen ids and the accessibility tree (A64); the image loader entirely (A55); incomplete-thread collapse rows; the real push path's placeholder and event ordering; `LinkRouter`'s mailto branch; a multi-line line-box height at a scale other than 3x; `ViewabilityTracker.cancel`.

## Not checked

xcodebuild, the test run, the Release build, Maestro, simctl, Thread Sanitizer and Instruments: forbidden by the brief, with the simulator and test server shared. The lead's independent result is used instead (127 tests in 19 suites pass, Release builds). `make_masks.py` was not executed, so its 8-state exit-0 claim is unverified here; the algorithm was reviewed instead. Android and visual parity are out of scope for this round.
