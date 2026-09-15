# Architecture review 2: CP-00 to CP-03, iOS

- Reviewer: `architecture-reviewer` agent (Nativestarter Migration Pack), run on 2026-09-15
- Code reviewed: `ios/` at commit `4e72ea8`, diff `6ef63e8..4e72ea8`
- Verdict: **Blockers found: 2** (A46, A59)
- Round-1 status: 31 fixed, 11 partially fixed, 1 not fixed (A30), 2 accepted with reason (A16 ZStack choice, A25)
- Paths are relative to `ios/BlueskyNative/` unless they start with `ios/`. Parity findings N1–N25 are in `parity-review-2.md` and are not repeated here.

## Round-1 verdicts

| # | Verdict | Note |
|---|---|---|
| A1 | Partially fixed | Generation and DID checks, `invalidate()`, server revoke added. Residual races in A46, A47 |
| A2–A15 | Fixed | Keychain actor with async restore; single-flight refresh; terminal auth failure signs out; corrupt-only delete; cancellation mapping; load generation; shadow base state; one AccountContainer per account; pixelLength; FeedRows; DSButton; Names helpers; formatter cache; image loader (defects in A55) |
| A16 | Partially fixed; ZStack choice accepted | TabRouter exists, but AppRouter hard-codes two tabs (A58). ZStack reason recorded at `Features/Shell/TabShell.swift:6-11` |
| A17 | Fixed | Theme environment; 0 direct Palette uses in Features |
| A18 | Partially fixed | 36 raw paddings and 27 raw frame sizes remain in Features |
| A19 | Partially fixed | Centralised in RNLineBox, still per-component 3x constants; one outside the type (`Features/Feed/PostFeedItemView.swift:22`); see A57 |
| A20 | Partially fixed | Untested: model-level cancellation, incomplete-thread rows, AppRouter, PreferencesModel failure, image loader |
| A21–A23 | Fixed | App icon and accent colour; privacy manifest; bundle id `io.nativestarter.showcase.bluesky`, name "Native showcase" |
| A24 | Partially fixed | One commit per checkpoint, but `baac0ef` does not build alone; the commits cannot be bisected |
| A25 | Accepted with reason | `NSAllowsLocalNetworking` in Release recorded in `ios/README.md:86-87`; localhost URL now E2E-only |
| A26–A29 | Fixed | Ephemeral URLSession; deleteSession on sign-out; queue removal; logged mutation failures |
| A30 | Not fixed | Unstructured `Task {}` in view callbacks: `HomeScreen.swift:55`, `ProfileScreen.swift:37,97`, `FeedRows.swift:22,46`, `ThreadScreen.swift:34,106`, `RootView.swift:201` |
| A31–A39 | Fixed | restore guard; cleanError; ProfileModel file; no SessionStore environment in Features; one model per route; tombstone not a button; cached rows; RN `_reactKey` slice ids; unfair lock and ISO8601FormatStyle |
| A40 | Partially fixed | Label tests restate `Plural.word`; `displayText` 29/30 boundary untested |
| A41–A45 | Fixed | Locked test helpers; parallel unread and profile load; guard instead of force unwraps; Release build step; Info.plist generated and ignored |

## Blockers

| # | Area | Finding | Evidence | Fix |
|---|---|---|---|---|
| A46 | Security, Keychain | Credential writes are not ordered. (a) A refresh for alice passes the generation check while bob's save is suspended; alice's save lands last and is restored on relaunch. (b) Sign-out's delayed `clear()` runs after a quick sign-in's `save()`, losing the new session. The existing test calls the stale callback only after the switch finishes | `Core/Session/SessionStore.swift:90-121,149-162`; `ios/BlueskyNativeTests/NetworkingTests.swift:372-384` | One ordered credential-write chain owned by SessionStore; generation check inside the chain just before the write; signIn bumps generation and awaits pending work; test with a gated `save` |
| A59 | Layering | A view reads `UIApplication.shared.applicationState`, reads and writes `UserDefaults` (`InAppBrowserPreference`), and holds link-open policy (proxy URL, analytics, preference); untested and not headless | `Features/Shell/TabShell.swift:101,164-189,202-212` | `PreferencesStore` and `AppActivity` protocols; move `openLink` and `handleFacet` into a testable `LinkRouter` with fakes |

## Major

| # | Area | Finding | Evidence | Fix |
|---|---|---|---|---|
| A47 | Concurrency, security | `invalidate()` runs in an unordered Task; a refresh can rotate the token after invalidation, so the revoke sends a stale refresh token and fails | `SessionStore.swift:28-29,149`; `Core/Networking/BlueskyAPI.swift:111-113,284` | Await `old.invalidate()` on sign-out; inside the actor await any running refresh and revoke with the newest token |
| A51 | Tests | Sleep-timed tests (`NetworkingTests.swift:246,366,382,393`); `signsInSavesRestoresAndSignsOut` asserts `invalidated` although it runs in an unordered Task | `NetworkingTests.swift:307-313` | Continuation gates in fakes; await invalidation explicitly |
| A54 | State | `PreferencesModel.load()` caches defaults after any failure, including cancellation, and never retries; a transient failure drops user feed preferences for the session | `Features/Feed/FeedModel.swift:20-35` | Do not cache failures; retry on next load; propagate cancellation; test |
| A57 | Design system | `lineSpacing(max(0, lineHeight - natural))` clamps while insets go negative, so wrapped text with lineHeight below natural height grows about 1.4 pt per extra line; per-component constants grow with every screen | `DesignSystem/Typography.swift:150-182,202-209`; `PostFeedItemView.swift:22` | Paragraph min and max line height; rules per text component type instead of per-component constants |
| A58 | Scale, navigation | Closed `Route` enum, two hard-coded routers and tokens, eager per-screen models, pushed `.profile` always uses the own profile model; a new tab needs about 5 coordinated edits | `Features/Shell/AccountContainer.swift:43-54,77-81,94-100,119-123,186-232`; `TabShell.swift:25-38,127-136` | `[ShellTab: TabRouter]`; route-type screen factory registry with lazy, route-scoped models; soft-reset tokens on TabRouter |
| A60 | Analytics, privacy | `JSONLinesEventLog` is used in every build, including Release: unbounded `Documents/events.jsonl` with post URIs, DIDs and visited link URLs; new encoder and file handle per event on the caller's thread | `App/App.swift:54-55`; `Core/Analytics/Analytics.swift:73-99`; `TabShell.swift:167-168` | JSON Lines sink under `#if E2E` only, no-op sink in Release; one encoder; one open handle on a queue |

## Minor

| # | Finding | Evidence |
|---|---|---|
| A48 | Each token callback starts its own main-actor Task; two refreshes can save out of order | `SessionStore.swift:132-134` |
| A49 | `signIn` has no generation or state guard after `await`; a sign-out during sign-in is overwritten | `SessionStore.swift:90-101` |
| A50 | `lastError` is never read; `acceptRefreshedTokens` is internal, not private | `SessionStore.swift:97,153,159,166` |
| A52 | `DebugFaults` and its `consume` calls ship in Release; `DEBUG` and `E2E` conditions differ | `Features/Shell/ShellSupport.swift:77-105`; `App/App.swift:39,44`; `AccountContainer.swift:182,207,214,223`; `FeedModel.swift:140-141,208`; `ThreadModel.swift:361`; `ProfileModel.swift:35`; `HomeScreen.swift:117` |
| A53 | Error-path tests prove the fault hook, not API error mapping | `ios/BlueskyNativeTests/ViewModelTests.swift:113-117,136-144,174-186,262-270` |
| A55 | Image loader ignores size changes, keeps a stale image on URL change, never cancels orphaned downloads; misleading actor comment | `Core/Images/ImageLoader.swift:13,33-42,85-87` |
| A56 | `reset(uris:)` has no caller; a mutation queue keeps the first screen's context and clout | `Features/Post/PostShadowStore.swift:77-82,254,275-307` |
| A61 | `model.items` allocates once per row in `body`; O(n²) on long threads | `Features/Thread/ThreadScreen.swift:91-92,114-116` |
| A62 | `pollTask` assigned after the first check; a stop during it leaves a loop running | `Features/Shell/UnreadNotificationsModel.swift:37-47` |

## Scale: seams that break before 74 more screens

1. Closed route enum, two routers and a destination switch; no URL-to-route parser for deep links.
2. AccountContainer holds eager stored models and prunes stacks by name.
3. Leaf views depend on the whole AccountContainer environment; inject narrow action handlers.
4. One `BlueskyAPI` protocol with 11 endpoints; split by domain.
5. No shared normalised cache; shadows cover only like and repost.
6. `ShellState` has one optional per sheet type; needs a presentation-route enum.
7. Per-component line-box constants tied to one 3x device (A57).
8. Single `account: "current"` Keychain slot blocks multi-account (`Core/Session/CredentialStore.swift:32`).
9. `DebugFaults` has one enum case per screen in production paths (A52).

## Test quality sample (13 of 92)

Nine prove behaviour. Weak: `staleRefreshFromAnotherAccountIsDropped` (misses the real race), `invalidatedAPIReportsNoTokens` (sleep-timed), `loadMoreFailureKeepsPagingAndOffersRetry` (fault hook only), `profileLoadsAndLabelsPluralise` (restates implementation). Missing: AppRouter, PreferencesModel failure, image loader, incomplete-thread collapse, sign-out during sign-in, RNLineBox multi-line height.

## Commands the reviewer ran

- `swiftc -parse` on all 48 Swift files: 45 pass; `RichText.swift`, `TabShell.swift`, `Names.swift` pass with `-enable-bare-slash-regex` (on by default in Swift 6).
- `git show --stat` per commit; `git grep` at `baac0ef` proving it does not build alone.
- Pattern searches: `Palette.`, `AsyncImage`, `UITraitCollection`, `try?`, `Task {`, `UserDefaults`, `consume(.`, `reset(uris`, `lastError`, raw numeric layout values, `@Test` count (92).
- Not run: xcodebuild, tests, Thread Sanitizer, Instruments, Android.
