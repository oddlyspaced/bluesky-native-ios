# Checkpoint plan: Bluesky showcase slice

> Drafted with plan-checkpoints 1.0.0. Source: `full-app-plan.md` (127 checkpoints drafted from `bluesky-assessment.json`, bluesky-social/social-app at commit 2bfb94d).
> This showcase ports a slice of the app, not the full app. The slice takes the foundation and three screens from the full plan and splits the shared post components into their own scope.

```plan
app: bsky.app
assessment: bluesky-assessment.json
design: keep-design
```

## Design decision

`design: keep-design`. The SwiftUI and Compose apps keep the Bluesky design: ALF tokens, the Inter font and the Bluesky icon set. They do not adopt SF Symbols or Material defaults. Reason: the showcase proves the migration changes the code, not the product.

## Environment

- Server: the upstream e2e dev network (`dev-env/mock-server.ts`). PDS on `http://localhost:3000`, seeded with `POST http://localhost:1986/?users&follows&posts&feeds&thread`.
- Reference: the upstream React Native e2e build (`pnpm e2e:build`, `pnpm e2e:build-android`) on the same seed.
- Parity driver: one Maestro capture flow for both apps. React Native `testID` values are reused as `accessibilityIdentifier` (iOS) and `testTag` (Android).

## In scope for every screen in the slice

- Light, dark and dim themes, following the system setting, as in the React Native app.
- Dynamic Type (iOS) and font scale (Android), with the React Native app's multiplier and cap.
- Analytics events with the same names and properties as the React Native app, written to a local event log, and compared with an event diff.
- Rich text facets (links, mentions, tags) in post text.
- Loading, empty, error, load-more error and not-found states.
- Accessibility labels, roles and hints, and every React Native `testID` reused as `accessibilityIdentifier` and `testTag`.

## Out of scope

Search, chat, notifications, composer, feeds tab, onboarding, settings, moderation, push notifications, OTA and cutover. The full plan lists them.

## Proposed out of scope, awaiting owner acceptance

These differences are not accepted yet. The gate "Parity report passes, or every drift is accepted in writing" stays open until a named owner accepts each row here.

| Difference | Reason |
|---|---|
| Post embeds: images, video, external link cards, quote posts, record-with-media | The seed data has no embeds. Each embed type is a separate component set and fits a later checkpoint. |
| Long-press repost to quote | Needs the composer, which is out of scope. |
| Chat unread badge | Chat is out of scope. |
| Other profile tabs (Replies, Media, Videos, Likes, Feeds, Starter Packs) and other users' profiles | The slice covers the own profile, Posts tab only. |
| Thread tree view (labs preference `lab_treeViewEnabled`) | The e2e test account uses the default linear view. The tree view is a separate thread layout behind a labs setting. The native thread logs the view it shows, `linear`. |
| Licensing substitutions: open icon set, neutral logo mark, code-drawn default avatar, app name without "Bluesky" | Upstream `ASSETS.md` sections 2 and 3: upstream icons and marks are not licensed for redistribution. |

## Reviews

| Date | Platform | Review | Result |
|---|---|---|---|
| 2026-09-15 | iOS | `reviews/2026-09-15-ios-CP00-03-parity-review-1.md` | 14 blockers |
| 2026-09-15 | iOS | `reviews/2026-09-15-ios-CP00-03-architecture-review-1.md` | 2 blockers |
| 2026-09-15 | iOS | `reviews/2026-09-15-ios-CP00-03-parity-review-2.md` | 2 blockers (N1 extra event; N21 no human sign-off) |
| 2026-09-15 | iOS | `reviews/2026-09-15-ios-CP00-03-architecture-review-2.md` | 2 blockers (A46 credential write ordering; A59 storage and policy in a view) |
| 2026-09-16 | iOS | `reviews/2026-09-16-ios-CP00-03-parity-review-3.md` | 2 blockers (F1 no human sign-off; F2 screen testIDs) |
| 2026-09-16 | Android | `reviews/2026-09-16-android-CP00-03-architecture-review-1.md` | No blockers; 17 major, 20 minor |
| 2026-09-16 | Android | `reviews/2026-09-16-android-CP00-03-parity-review-1.md` | 5 blockers (A1 resume event; A2 numbers unreproducible; A3 mask hides the element under test; A4 error-home claim is a harness artefact; A5 no human sign-off) |
| 2026-09-16 | iOS | `reviews/2026-09-16-ios-CP00-03-architecture-review-3.md` | 2 blockers (A63 UIKit extension override and app-wide gesture delegate; A64 screen ids have no automated check) |

## Acceptance

```acceptance
state: not accepted
```

## Checkpoints

### CP-00: Foundation

```checkpoint
id: CP-00
title: Foundation
kind: foundation
depends: none
status: in-progress
scope:
  - src/alf/tokens.ts
  - src/alf/themes.ts
  - src/alf/atoms.ts
  - src/alf/fonts.ts
  - src/state/session/index.tsx
  - src/view/shell/bottom-bar/BottomBar.tsx
  - dev-env/constants.ts
```

Design tokens and Inter font, XRPC client with the AppView proxy header, session (create session, keep tokens), bottom tab shell, debug-only "Sign in as Alice" entry with id `e2eSignInAlice`.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-01: Screen Home

```checkpoint
id: CP-01
title: Screen Home
kind: screen
depends: CP-00
status: in-progress
scope:
  - src/view/screens/Home.tsx
  - src/view/com/posts/PostFeedItem.tsx
```

Following timeline: header, Following and Feeds tabs, composer prompt row, feed items with thread lines, like and repost with optimistic state, pull to refresh.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-02: Screen PostThread

```checkpoint
id: CP-02
title: Screen PostThread
kind: screen
depends: CP-01
status: in-progress
scope:
  - src/screens/PostThread/index.tsx
  - src/screens/PostThread/components/ThreadItemAnchor.tsx
  - src/screens/PostThread/components/ThreadItemPost.tsx
  - src/screens/PostThread/components/ThreadItemTreePost.tsx
```

Anchor post with full timestamp and reply setting, replies, like and repost, back navigation.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-03: Screen Profile

```checkpoint
id: CP-03
title: Screen Profile
kind: screen
depends: CP-01
status: in-progress
scope:
  - src/view/screens/Profile.tsx
  - src/screens/Profile/Header
```

Own profile: banner, avatar, actions, counts, bio, section tabs, Posts tab feed.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded
