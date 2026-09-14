# Checkpoint plan: bsky.app

> Drafted by plan-checkpoints 1.0.0 from `bluesky-assessment.json` on 2026-09-15.
> Draft. Reorder, split, merge and edit checkpoints, then accept the plan. Acceptance is a SHA-256 hash of this file:
> any edit except `status:`, `note:` and gate check marks invalidates it.

```plan
app: bsky.app
assessment: bluesky-assessment.json
design: keep-design
```

## Design decision

`design: keep-design` (default): both native apps keep the app's existing design, identical on iOS and Android. Native code, not a native look.
`design: platform-conventions`: adopt SwiftUI and Material conventions per platform. Choose it only as an explicit, recorded product decision, and write here who decided and why.

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
status: planned
scope:
  - package.json
  - src/Navigation.tsx
  - app.config.js
  - patches/@formatjs__bigdecimal@0.2.5.patch
  - patches/@sentry__expo-upload-sourcemaps@8.18.0.patch
  - patches/expo-haptics@57.0.1.patch
  - patches/expo-modules-core@57.0.8.patch
  - patches/expo-updates@57.0.10.patch
  - patches/expo@57.0.8.patch
  - patches/react-native-dotenv@3.4.11.patch
  - patches/react-native-drawer-layout@4.2.3.patch
  - patches/react-native-pager-view@6.8.0.patch
  - patches/react-native-screens@4.26.2.patch
  - patches/react-native@0.86.0.patch
```

Build what every later checkpoint stands on, in both native apps:

- Design tokens (colour, typography, spacing, radii) and core components, taken from the running app.
- Navigation shell with every route declared explicitly, including deep links.
- API client and auth client (token storage, refresh, sign-out).
- CI that builds and tests the iOS and Android apps on every change.
- Reproduce local config plugin `./plugins/starterPackAppClipExtension/withStarterPackAppClip.js` in the Xcode and Gradle projects.
- Reproduce local config plugin `./plugins/withGradleJVMHeapSizeIncrease.js` in the Xcode and Gradle projects.
- Reproduce local config plugin `./plugins/withAndroidManifestLargeHeapPlugin.js` in the Xcode and Gradle projects.
- Reproduce local config plugin `./plugins/withAndroidManifestFCMIconPlugin.js` in the Xcode and Gradle projects.
- Reproduce local config plugin `./plugins/withAndroidManifestIntentQueriesPlugin.js` in the Xcode and Gradle projects.
- Reproduce local config plugin `./plugins/withAndroidStylesAccentColorPlugin.js` in the Xcode and Gradle projects.
- Reproduce local config plugin `./plugins/withAndroidNoJitpackPlugin.js` in the Xcode and Gradle projects.
- Reproduce local config plugin `./plugins/shareExtension/withShareExtensions.js` in the Xcode and Gradle projects.
- Reproduce local config plugin `./plugins/notificationsExtension/withNotificationsExtension.js` in the Xcode and Gradle projects.
- Absorb low-difficulty and navigation packages: `expo-linking`, `@react-navigation/bottom-tabs`, `@react-navigation/native`, `@react-navigation/native-stack`, `@sentry/react-native`, `expo-application`, `expo-blur`, `expo-build-properties`, `expo-dev-client`, `expo-device`, `expo-font`, `expo-haptics`, `expo-image-manipulator`, `expo-image-picker`, `expo-keep-awake`, `expo-localization`, `expo-sharing`, `expo-splash-screen`, `expo-system-ui`, `expo-web-browser`, `react-native-edge-to-edge`, `react-native-mmkv`, `react-native-pager-view`, `react-native-screens`, `react-native-webview`, `react-native-worklets`.
- Preserve the behaviour patched in `patches/@formatjs__bigdecimal@0.2.5.patch`.
- Preserve the behaviour patched in `patches/@sentry__expo-upload-sourcemaps@8.18.0.patch`.
- Preserve the behaviour patched in `patches/expo-haptics@57.0.1.patch`.
- Preserve the behaviour patched in `patches/expo-modules-core@57.0.8.patch`.
- Preserve the behaviour patched in `patches/expo-updates@57.0.10.patch`.
- Preserve the behaviour patched in `patches/expo@57.0.8.patch`.
- Preserve the behaviour patched in `patches/react-native-dotenv@3.4.11.patch`.
- Preserve the behaviour patched in `patches/react-native-drawer-layout@4.2.3.patch`.
- Preserve the behaviour patched in `patches/react-native-pager-view@6.8.0.patch`.
- Preserve the behaviour patched in `patches/react-native-screens@4.26.2.patch`.
- Preserve the behaviour patched in `patches/react-native@0.86.0.patch`.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-01: Screen PostThread

```checkpoint
id: CP-01
title: Screen PostThread
kind: screen
depends: CP-00
status: planned
scope:
  - src/view/screens/PostThread.tsx
  - src/Navigation.tsx
```

Port `PostThread` to SwiftUI and Compose. It must match the running app on both platforms (see Design decision).

- Lines: 17 (simple); native imports: none.
- Component `src/view/screens/PostThread.tsx` is registered in `src/Navigation.tsx`. Read the components it imports; the assessment measured only the component file.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-02: Screen Search

```checkpoint
id: CP-02
title: Screen Search
kind: screen
depends: CP-00
status: planned
scope:
  - src/screens/Search/index.tsx
  - src/Navigation.tsx
```

Port `Search` to SwiftUI and Compose. It must match the running app on both platforms (see Design decision).

- Lines: 17 (simple); native imports: none.
- Component `src/screens/Search/index.tsx` is registered in `src/Navigation.tsx`. Read the components it imports; the assessment measured only the component file.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-03: Screen LegacyNotificationSettings

```checkpoint
id: CP-03
title: Screen LegacyNotificationSettings
kind: screen
depends: CP-00
status: planned
scope:
  - src/screens/Settings/LegacyNotificationSettings.tsx
  - src/Navigation.tsx
```

Port `LegacyNotificationSettings` to SwiftUI and Compose. It must match the running app on both platforms (see Design decision).

- Lines: 18 (simple); native imports: `@react-navigation/native`.
- Component `src/screens/Settings/LegacyNotificationSettings.tsx` is registered in `src/Navigation.tsx`. Read the components it imports; the assessment measured only the component file.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-04: Screen Debug

```checkpoint
id: CP-04
title: Screen Debug
kind: screen
depends: CP-00
status: planned
scope:
  - src/view/screens/Storybook/index.tsx
  - src/Navigation.tsx
```

Port `Debug` to SwiftUI and Compose. It must match the running app on both platforms (see Design decision).

- Lines: 21 (simple); native imports: none.
- Component `src/view/screens/Storybook/index.tsx` is registered in `src/Navigation.tsx`. Read the components it imports; the assessment measured only the component file.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-05: Screen ProfileLabelerLikedBy

```checkpoint
id: CP-05
title: Screen ProfileLabelerLikedBy
kind: screen
depends: CP-00
status: planned
scope:
  - src/screens/Profile/ProfileLabelerLikedBy.tsx
  - src/Navigation.tsx
```

Port `ProfileLabelerLikedBy` to SwiftUI and Compose. It must match the running app on both platforms (see Design decision).

- Lines: 23 (simple); native imports: none.
- Component `src/screens/Profile/ProfileLabelerLikedBy.tsx` is registered in `src/Navigation.tsx`. Read the components it imports; the assessment measured only the component file.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-06: Screen CustomFeedLikedBy

```checkpoint
id: CP-06
title: Screen CustomFeedLikedBy
kind: screen
depends: CP-00
status: planned
scope:
  - src/screens/CustomFeed/CustomFeedLikedBy.tsx
  - src/Navigation.tsx
```

Port `CustomFeedLikedBy` to SwiftUI and Compose. It must match the running app on both platforms (see Design decision).

- Lines: 27 (simple); native imports: none.
- Component `src/screens/CustomFeed/CustomFeedLikedBy.tsx` is registered in `src/Navigation.tsx`. Read the components it imports; the assessment measured only the component file.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-07: Screen TermsOfService

```checkpoint
id: CP-07
title: Screen TermsOfService
kind: screen
depends: CP-00
status: planned
scope:
  - src/view/screens/TermsOfService.tsx
  - src/Navigation.tsx
```

Port `TermsOfService` to SwiftUI and Compose. It must match the running app on both platforms (see Design decision).

- Lines: 38 (simple); native imports: none.
- Component `src/view/screens/TermsOfService.tsx` is registered in `src/Navigation.tsx`. Read the components it imports; the assessment measured only the component file.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-08: Screen CopyrightPolicy

```checkpoint
id: CP-08
title: Screen CopyrightPolicy
kind: screen
depends: CP-00
status: planned
scope:
  - src/view/screens/CopyrightPolicy.tsx
  - src/Navigation.tsx
```

Port `CopyrightPolicy` to SwiftUI and Compose. It must match the running app on both platforms (see Design decision).

- Lines: 40 (simple); native imports: none.
- Component `src/view/screens/CopyrightPolicy.tsx` is registered in `src/Navigation.tsx`. Read the components it imports; the assessment measured only the component file.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-09: Screen PostLikedBy

```checkpoint
id: CP-09
title: Screen PostLikedBy
kind: screen
depends: CP-00
status: planned
scope:
  - src/screens/Post/PostLikedBy.tsx
  - src/Navigation.tsx
```

Port `PostLikedBy` to SwiftUI and Compose. It must match the running app on both platforms (see Design decision).

- Lines: 40 (simple); native imports: none.
- Component `src/screens/Post/PostLikedBy.tsx` is registered in `src/Navigation.tsx`. Read the components it imports; the assessment measured only the component file.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-10: Screen PrivacyPolicy

```checkpoint
id: CP-10
title: Screen PrivacyPolicy
kind: screen
depends: CP-00
status: planned
scope:
  - src/view/screens/PrivacyPolicy.tsx
  - src/Navigation.tsx
```

Port `PrivacyPolicy` to SwiftUI and Compose. It must match the running app on both platforms (see Design decision).

- Lines: 40 (simple); native imports: none.
- Component `src/view/screens/PrivacyPolicy.tsx` is registered in `src/Navigation.tsx`. Read the components it imports; the assessment measured only the component file.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-11: Screen ProfileSearch

```checkpoint
id: CP-11
title: Screen ProfileSearch
kind: screen
depends: CP-00
status: planned
scope:
  - src/screens/Profile/ProfileSearch.tsx
  - src/Navigation.tsx
```

Port `ProfileSearch` to SwiftUI and Compose. It must match the running app on both platforms (see Design decision).

- Lines: 40 (simple); native imports: none.
- Component `src/screens/Profile/ProfileSearch.tsx` is registered in `src/Navigation.tsx`. Read the components it imports; the assessment measured only the component file.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-12: Screen Support

```checkpoint
id: CP-12
title: Screen Support
kind: screen
depends: CP-00
status: planned
scope:
  - src/view/screens/Support.tsx
  - src/Navigation.tsx
```

Port `Support` to SwiftUI and Compose. It must match the running app on both platforms (see Design decision).

- Lines: 41 (simple); native imports: none.
- Component `src/view/screens/Support.tsx` is registered in `src/Navigation.tsx`. Read the components it imports; the assessment measured only the component file.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-13: Screen CommunityGuidelines

```checkpoint
id: CP-13
title: Screen CommunityGuidelines
kind: screen
depends: CP-00
status: planned
scope:
  - src/view/screens/CommunityGuidelines.tsx
  - src/Navigation.tsx
```

Port `CommunityGuidelines` to SwiftUI and Compose. It must match the running app on both platforms (see Design decision).

- Lines: 43 (simple); native imports: none.
- Component `src/view/screens/CommunityGuidelines.tsx` is registered in `src/Navigation.tsx`. Read the components it imports; the assessment measured only the component file.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-14: Screen ProfileFollowers

```checkpoint
id: CP-14
title: Screen ProfileFollowers
kind: screen
depends: CP-00
status: planned
scope:
  - src/screens/Profile/ProfileFollowers.tsx
  - src/Navigation.tsx
```

Port `ProfileFollowers` to SwiftUI and Compose. It must match the running app on both platforms (see Design decision).

- Lines: 43 (simple); native imports: none.
- Component `src/screens/Profile/ProfileFollowers.tsx` is registered in `src/Navigation.tsx`. Read the components it imports; the assessment measured only the component file.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-15: Screen ProfileFollows

```checkpoint
id: CP-15
title: Screen ProfileFollows
kind: screen
depends: CP-00
status: planned
scope:
  - src/screens/Profile/ProfileFollows.tsx
  - src/Navigation.tsx
```

Port `ProfileFollows` to SwiftUI and Compose. It must match the running app on both platforms (see Design decision).

- Lines: 43 (simple); native imports: none.
- Component `src/screens/Profile/ProfileFollows.tsx` is registered in `src/Navigation.tsx`. Read the components it imports; the assessment measured only the component file.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-16: Screen PostQuotes

```checkpoint
id: CP-16
title: Screen PostQuotes
kind: screen
depends: CP-00
status: planned
scope:
  - src/screens/Post/PostQuotes.tsx
  - src/Navigation.tsx
```

Port `PostQuotes` to SwiftUI and Compose. It must match the running app on both platforms (see Design decision).

- Lines: 44 (simple); native imports: none.
- Component `src/screens/Post/PostQuotes.tsx` is registered in `src/Navigation.tsx`. Read the components it imports; the assessment measured only the component file.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-17: Screen PostRepostedBy

```checkpoint
id: CP-17
title: Screen PostRepostedBy
kind: screen
depends: CP-00
status: planned
scope:
  - src/screens/Post/PostRepostedBy.tsx
  - src/Navigation.tsx
```

Port `PostRepostedBy` to SwiftUI and Compose. It must match the running app on both platforms (see Design decision).

- Lines: 44 (simple); native imports: none.
- Component `src/screens/Post/PostRepostedBy.tsx` is registered in `src/Navigation.tsx`. Read the components it imports; the assessment measured only the component file.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-18: Screen NotificationsActivityList

```checkpoint
id: CP-18
title: Screen NotificationsActivityList
kind: screen
depends: CP-00
status: planned
scope:
  - src/screens/Notifications/ActivityList.tsx
  - src/Navigation.tsx
```

Port `NotificationsActivityList` to SwiftUI and Compose. It must match the running app on both platforms (see Design decision).

- Lines: 47 (simple); native imports: `@react-navigation/native-stack`.
- Component `src/screens/Notifications/ActivityList.tsx` is registered in `src/Navigation.tsx`. Read the components it imports; the assessment measured only the component file.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-19: Screen NotFound

```checkpoint
id: CP-19
title: Screen NotFound
kind: screen
depends: CP-00
status: planned
scope:
  - src/view/screens/NotFound.tsx
  - src/Navigation.tsx
```

Port `NotFound` to SwiftUI and Compose. It must match the running app on both platforms (see Design decision).

- Lines: 59 (simple); native imports: `@react-navigation/native`.
- Component `src/view/screens/NotFound.tsx` is registered in `src/Navigation.tsx`. Read the components it imports; the assessment measured only the component file.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-20: Screen Lists

```checkpoint
id: CP-20
title: Screen Lists
kind: screen
depends: CP-00
status: planned
scope:
  - src/view/screens/Lists.tsx
  - src/Navigation.tsx
```

Port `Lists` to SwiftUI and Compose. It must match the running app on both platforms (see Design decision).

- Lines: 77 (simple); native imports: `@react-navigation/native`.
- Component `src/view/screens/Lists.tsx` is registered in `src/Navigation.tsx`. Read the components it imports; the assessment measured only the component file.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-21: Screen ModerationModlists

```checkpoint
id: CP-21
title: Screen ModerationModlists
kind: screen
depends: CP-00
status: planned
scope:
  - src/view/screens/ModerationModlists.tsx
  - src/Navigation.tsx
```

Port `ModerationModlists` to SwiftUI and Compose. It must match the running app on both platforms (see Design decision).

- Lines: 78 (simple); native imports: `@react-navigation/native`.
- Component `src/view/screens/ModerationModlists.tsx` is registered in `src/Navigation.tsx`. Read the components it imports; the assessment measured only the component file.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-22: Screen ModerationInboxSubjectDetails

```checkpoint
id: CP-22
title: Screen ModerationInboxSubjectDetails
kind: screen
depends: CP-00
status: planned
scope:
  - src/screens/ModerationInbox/Subject.tsx
  - src/Navigation.tsx
```

Port `ModerationInboxSubjectDetails` to SwiftUI and Compose. It must match the running app on both platforms (see Design decision).

- Lines: 84 (medium); native imports: none.
- Component `src/screens/ModerationInbox/Subject.tsx` is registered in `src/Navigation.tsx`. Read the components it imports; the assessment measured only the component file.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-23: Screen ModerationInboxReportDetails

```checkpoint
id: CP-23
title: Screen ModerationInboxReportDetails
kind: screen
depends: CP-00
status: planned
scope:
  - src/screens/ModerationInbox/Report.tsx
  - src/Navigation.tsx
```

Port `ModerationInboxReportDetails` to SwiftUI and Compose. It must match the running app on both platforms (see Design decision).

- Lines: 89 (medium); native imports: none.
- Component `src/screens/ModerationInbox/Report.tsx` is registered in `src/Navigation.tsx`. Read the components it imports; the assessment measured only the component file.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-24: Screen ModerationVerificationSettings

```checkpoint
id: CP-24
title: Screen ModerationVerificationSettings
kind: screen
depends: CP-00
status: planned
scope:
  - src/screens/Moderation/VerificationSettings.tsx
  - src/Navigation.tsx
```

Port `ModerationVerificationSettings` to SwiftUI and Compose. It must match the running app on both platforms (see Design decision).

- Lines: 98 (medium); native imports: none.
- Component `src/screens/Moderation/VerificationSettings.tsx` is registered in `src/Navigation.tsx`. Read the components it imports; the assessment measured only the component file.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-25: Screen AccessibilitySettings

```checkpoint
id: CP-25
title: Screen AccessibilitySettings
kind: screen
depends: CP-00
status: planned
scope:
  - src/screens/Settings/AccessibilitySettings.tsx
  - src/Navigation.tsx
```

Port `AccessibilitySettings` to SwiftUI and Compose. It must match the running app on both platforms (see Design decision).

- Lines: 102 (medium); native imports: `@react-navigation/native-stack`.
- Component `src/screens/Settings/AccessibilitySettings.tsx` is registered in `src/Navigation.tsx`. Read the components it imports; the assessment measured only the component file.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-26: Screen PreferencesThreads

```checkpoint
id: CP-26
title: Screen PreferencesThreads
kind: screen
depends: CP-00
status: planned
scope:
  - src/screens/Settings/ThreadPreferences.tsx
  - src/Navigation.tsx
```

Port `PreferencesThreads` to SwiftUI and Compose. It must match the running app on both platforms (see Design decision).

- Lines: 104 (medium); native imports: none.
- Component `src/screens/Settings/ThreadPreferences.tsx` is registered in `src/Navigation.tsx`. Read the components it imports; the assessment measured only the component file.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-27: Screen PreferencesExternalEmbeds

```checkpoint
id: CP-27
title: Screen PreferencesExternalEmbeds
kind: screen
depends: CP-00
status: planned
scope:
  - src/screens/Settings/ExternalMediaPreferences.tsx
  - src/Navigation.tsx
```

Port `PreferencesExternalEmbeds` to SwiftUI and Compose. It must match the running app on both platforms (see Design decision).

- Lines: 107 (medium); native imports: none.
- Component `src/screens/Settings/ExternalMediaPreferences.tsx` is registered in `src/Navigation.tsx`. Read the components it imports; the assessment measured only the component file.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-28: Screen SharedPreferencesTester

```checkpoint
id: CP-28
title: Screen SharedPreferencesTester
kind: screen
depends: CP-00
status: planned
scope:
  - src/screens/E2E/SharedPreferencesTesterScreen.tsx
  - src/Navigation.tsx
```

Port `SharedPreferencesTester` to SwiftUI and Compose. It must match the running app on both platforms (see Design decision).

- Lines: 113 (medium); native imports: none.
- Component `src/screens/E2E/SharedPreferencesTesterScreen.tsx` is registered in `src/Navigation.tsx`. Read the components it imports; the assessment measured only the component file.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-29: Screen ModerationInteractionSettings

```checkpoint
id: CP-29
title: Screen ModerationInteractionSettings
kind: screen
depends: CP-00
status: planned
scope:
  - src/screens/ModerationInteractionSettings/index.tsx
  - src/Navigation.tsx
```

Port `ModerationInteractionSettings` to SwiftUI and Compose. It must match the running app on both platforms (see Design decision).

- Lines: 120 (medium); native imports: none.
- Component `src/screens/ModerationInteractionSettings/index.tsx` is registered in `src/Navigation.tsx`. Read the components it imports; the assessment measured only the component file.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-30: Screen Log

```checkpoint
id: CP-30
title: Screen Log
kind: screen
depends: CP-00
status: planned
scope:
  - src/screens/Log.tsx
  - src/Navigation.tsx
```

Port `Log` to SwiftUI and Compose. It must match the running app on both platforms (see Design decision).

- Lines: 124 (medium); native imports: none.
- Component `src/screens/Log.tsx` is registered in `src/Navigation.tsx`. Read the components it imports; the assessment measured only the component file.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-31: Screen ProfileKnownFollowers

```checkpoint
id: CP-31
title: Screen ProfileKnownFollowers
kind: screen
depends: CP-00
status: planned
scope:
  - src/screens/Profile/KnownFollowers.tsx
  - src/Navigation.tsx
```

Port `ProfileKnownFollowers` to SwiftUI and Compose. It must match the running app on both platforms (see Design decision).

- Lines: 126 (medium); native imports: none.
- Component `src/screens/Profile/KnownFollowers.tsx` is registered in `src/Navigation.tsx`. Read the components it imports; the assessment measured only the component file.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-32: Screen ModerationInboxSettings

```checkpoint
id: CP-32
title: Screen ModerationInboxSettings
kind: screen
depends: CP-00
status: planned
scope:
  - src/screens/ModerationInbox/Settings.tsx
  - src/Navigation.tsx
```

Port `ModerationInboxSettings` to SwiftUI and Compose. It must match the running app on both platforms (see Design decision).

- Lines: 132 (medium); native imports: none.
- Component `src/screens/ModerationInbox/Settings.tsx` is registered in `src/Navigation.tsx`. Read the components it imports; the assessment measured only the component file.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-33: Screen ActivityPrivacySettings

```checkpoint
id: CP-33
title: Screen ActivityPrivacySettings
kind: screen
depends: CP-00
status: planned
scope:
  - src/screens/Settings/ActivityPrivacySettings.tsx
  - src/Navigation.tsx
```

Port `ActivityPrivacySettings` to SwiftUI and Compose. It must match the running app on both platforms (see Design decision).

- Lines: 135 (medium); native imports: none.
- Component `src/screens/Settings/ActivityPrivacySettings.tsx` is registered in `src/Navigation.tsx`. Read the components it imports; the assessment measured only the component file.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-34: Screen PreferencesFollowingFeed

```checkpoint
id: CP-34
title: Screen PreferencesFollowingFeed
kind: screen
depends: CP-00
status: planned
scope:
  - src/screens/Settings/FollowingFeedPreferences.tsx
  - src/Navigation.tsx
```

Port `PreferencesFollowingFeed` to SwiftUI and Compose. It must match the running app on both platforms (see Design decision).

- Lines: 146 (medium); native imports: none.
- Component `src/screens/Settings/FollowingFeedPreferences.tsx` is registered in `src/Navigation.tsx`. Read the components it imports; the assessment measured only the component file.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-35: Screen PrivacyAndSecuritySettings

```checkpoint
id: CP-35
title: Screen PrivacyAndSecuritySettings
kind: screen
depends: CP-00
status: planned
scope:
  - src/screens/Settings/PrivacyAndSecuritySettings.tsx
  - src/Navigation.tsx
```

Port `PrivacyAndSecuritySettings` to SwiftUI and Compose. It must match the running app on both platforms (see Design decision).

- Lines: 163 (medium); native imports: `@react-navigation/native-stack`.
- Component `src/screens/Settings/PrivacyAndSecuritySettings.tsx` is registered in `src/Navigation.tsx`. Read the components it imports; the assessment measured only the component file.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-36: Screen ContentAndMediaSettings

```checkpoint
id: CP-36
title: Screen ContentAndMediaSettings
kind: screen
depends: CP-00
status: planned
scope:
  - src/screens/Settings/ContentAndMediaSettings.tsx
  - src/Navigation.tsx
```

Port `ContentAndMediaSettings` to SwiftUI and Compose. It must match the running app on both platforms (see Design decision).

- Lines: 177 (medium); native imports: `@react-navigation/native-stack`.
- Component `src/screens/Settings/ContentAndMediaSettings.tsx` is registered in `src/Navigation.tsx`. Read the components it imports; the assessment measured only the component file.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-37: Screen ModerationBlockedAccounts

```checkpoint
id: CP-37
title: Screen ModerationBlockedAccounts
kind: screen
depends: CP-00
status: planned
scope:
  - src/view/screens/ModerationBlockedAccounts.tsx
  - src/Navigation.tsx
```

Port `ModerationBlockedAccounts` to SwiftUI and Compose. It must match the running app on both platforms (see Design decision).

- Lines: 178 (medium); native imports: `@react-navigation/native-stack`.
- Component `src/view/screens/ModerationBlockedAccounts.tsx` is registered in `src/Navigation.tsx`. Read the components it imports; the assessment measured only the component file.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-38: Screen Topic

```checkpoint
id: CP-38
title: Screen Topic
kind: screen
depends: CP-00
status: planned
scope:
  - src/screens/Topic.tsx
  - src/Navigation.tsx
```

Port `Topic` to SwiftUI and Compose. It must match the running app on both platforms (see Design decision).

- Lines: 178 (medium); native imports: `@react-navigation/native-stack`.
- Component `src/screens/Topic.tsx` is registered in `src/Navigation.tsx`. Read the components it imports; the assessment measured only the component file.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-39: Screen ModerationMutedAccounts

```checkpoint
id: CP-39
title: Screen ModerationMutedAccounts
kind: screen
depends: CP-00
status: planned
scope:
  - src/view/screens/ModerationMutedAccounts.tsx
  - src/Navigation.tsx
```

Port `ModerationMutedAccounts` to SwiftUI and Compose. It must match the running app on both platforms (see Design decision).

- Lines: 190 (medium); native imports: `@react-navigation/native-stack`.
- Component `src/view/screens/ModerationMutedAccounts.tsx` is registered in `src/Navigation.tsx`. Read the components it imports; the assessment measured only the component file.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-40: Screen AutomationLabelSettings

```checkpoint
id: CP-40
title: Screen AutomationLabelSettings
kind: screen
depends: CP-00
status: planned
scope:
  - src/screens/Settings/AutomationLabelSettings.tsx
  - src/Navigation.tsx
```

Port `AutomationLabelSettings` to SwiftUI and Compose. It must match the running app on both platforms (see Design decision).

- Lines: 198 (medium); native imports: `@react-navigation/native-stack`.
- Component `src/screens/Settings/AutomationLabelSettings.tsx` is registered in `src/Navigation.tsx`. Read the components it imports; the assessment measured only the component file.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-41: Screen AccountSettings

```checkpoint
id: CP-41
title: Screen AccountSettings
kind: screen
depends: CP-00
status: planned
scope:
  - src/screens/Settings/AccountSettings.tsx
  - src/Navigation.tsx
```

Port `AccountSettings` to SwiftUI and Compose. It must match the running app on both platforms (see Design decision).

- Lines: 206 (medium); native imports: `@react-navigation/native-stack`.
- Component `src/screens/Settings/AccountSettings.tsx` is registered in `src/Navigation.tsx`. Read the components it imports; the assessment measured only the component file.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-42: Screen ModerationInbox

```checkpoint
id: CP-42
title: Screen ModerationInbox
kind: screen
depends: CP-00
status: planned
scope:
  - src/screens/ModerationInbox/index.tsx
  - src/Navigation.tsx
```

Port `ModerationInbox` to SwiftUI and Compose. It must match the running app on both platforms (see Design decision).

- Lines: 207 (medium); native imports: none.
- Component `src/screens/ModerationInbox/index.tsx` is registered in `src/Navigation.tsx`. Read the components it imports; the assessment measured only the component file.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-43: Screen BetaFeaturesSettings

```checkpoint
id: CP-43
title: Screen BetaFeaturesSettings
kind: screen
depends: CP-00
status: planned
scope:
  - src/screens/Settings/BetaFeaturesSettings.tsx
  - src/Navigation.tsx
```

Port `BetaFeaturesSettings` to SwiftUI and Compose. It must match the running app on both platforms (see Design decision).

- Lines: 227 (medium); native imports: `@react-navigation/native-stack`.
- Component `src/screens/Settings/BetaFeaturesSettings.tsx` is registered in `src/Navigation.tsx`. Read the components it imports; the assessment measured only the component file.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-44: Screen InterestsSettings

```checkpoint
id: CP-44
title: Screen InterestsSettings
kind: screen
depends: CP-00
status: planned
scope:
  - src/screens/Settings/InterestsSettings.tsx
  - src/Navigation.tsx
```

Port `InterestsSettings` to SwiftUI and Compose. It must match the running app on both platforms (see Design decision).

- Lines: 232 (medium); native imports: `@react-navigation/native-stack`.
- Component `src/screens/Settings/InterestsSettings.tsx` is registered in `src/Navigation.tsx`. Read the components it imports; the assessment measured only the component file.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-45: Screen LanguageSettings

```checkpoint
id: CP-45
title: Screen LanguageSettings
kind: screen
depends: CP-00
status: planned
scope:
  - src/screens/Settings/LanguageSettings.tsx
  - src/Navigation.tsx
```

Port `LanguageSettings` to SwiftUI and Compose. It must match the running app on both platforms (see Design decision).

- Lines: 241 (medium); native imports: none.
- Component `src/screens/Settings/LanguageSettings.tsx` is registered in `src/Navigation.tsx`. Read the components it imports; the assessment measured only the component file.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-46: Screen ActivityNotificationSettings

```checkpoint
id: CP-46
title: Screen ActivityNotificationSettings
kind: screen
depends: CP-00
status: planned
scope:
  - src/screens/Settings/NotificationSettings/ActivityNotificationSettings.tsx
  - src/Navigation.tsx
```

Port `ActivityNotificationSettings` to SwiftUI and Compose. It must match the running app on both platforms (see Design decision).

- Lines: 251 (complex); native imports: none.
- Component `src/screens/Settings/NotificationSettings/ActivityNotificationSettings.tsx` is registered in `src/Navigation.tsx`. Read the components it imports; the assessment measured only the component file.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-47: Screen Hashtag

```checkpoint
id: CP-47
title: Screen Hashtag
kind: screen
depends: CP-00
status: planned
scope:
  - src/screens/Hashtag.tsx
  - src/Navigation.tsx
```

Port `Hashtag` to SwiftUI and Compose. It must match the running app on both platforms (see Design decision).

- Lines: 262 (complex); native imports: `@react-navigation/native-stack`.
- Component `src/screens/Hashtag.tsx` is registered in `src/Navigation.tsx`. Read the components it imports; the assessment measured only the component file.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-48: Screen Notifications

```checkpoint
id: CP-48
title: Screen Notifications
kind: screen
depends: CP-00
status: planned
scope:
  - src/view/screens/Notifications.tsx
  - src/Navigation.tsx
```

Port `Notifications` to SwiftUI and Compose. It must match the running app on both platforms (see Design decision).

- Lines: 290 (complex); native imports: `@react-navigation/native`.
- Component `src/view/screens/Notifications.tsx` is registered in `src/Navigation.tsx`. Read the components it imports; the assessment measured only the component file.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-49: Screen MessagesInbox

```checkpoint
id: CP-49
title: Screen MessagesInbox
kind: screen
depends: CP-00
status: planned
scope:
  - src/screens/Messages/Inbox.tsx
  - src/Navigation.tsx
```

Port `MessagesInbox` to SwiftUI and Compose. It must match the running app on both platforms (see Design decision).

- Lines: 299 (complex); native imports: `@react-navigation/native`.
- Component `src/screens/Messages/Inbox.tsx` is registered in `src/Navigation.tsx`. Read the components it imports; the assessment measured only the component file.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-50: Screen Bookmarks

```checkpoint
id: CP-50
title: Screen Bookmarks
kind: screen
depends: CP-00
status: planned
scope:
  - src/screens/Bookmarks.tsx
  - src/Navigation.tsx
```

Port `Bookmarks` to SwiftUI and Compose. It must match the running app on both platforms (see Design decision).

- Lines: 304 (complex); native imports: `@react-navigation/native`.
- Component `src/screens/Bookmarks.tsx` is registered in `src/Navigation.tsx`. Read the components it imports; the assessment measured only the component file.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-51: Screen MessagesSettings

```checkpoint
id: CP-51
title: Screen MessagesSettings
kind: screen
depends: CP-00
status: planned
scope:
  - src/screens/Messages/Settings.tsx
  - src/Navigation.tsx
```

Port `MessagesSettings` to SwiftUI and Compose. It must match the running app on both platforms (see Design decision).

- Lines: 364 (complex); native imports: `@react-navigation/native-stack`.
- Component `src/screens/Messages/Settings.tsx` is registered in `src/Navigation.tsx`. Read the components it imports; the assessment measured only the component file.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-52: Screen MessagesJoinRequests

```checkpoint
id: CP-52
title: Screen MessagesJoinRequests
kind: screen
depends: CP-00
status: planned
scope:
  - src/screens/Messages/JoinRequests.tsx
  - src/Navigation.tsx
```

Port `MessagesJoinRequests` to SwiftUI and Compose. It must match the running app on both platforms (see Design decision).

- Lines: 460 (complex); native imports: `@react-navigation/native`.
- Component `src/screens/Messages/JoinRequests.tsx` is registered in `src/Navigation.tsx`. Read the components it imports; the assessment measured only the component file.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-53: Screen Moderation

```checkpoint
id: CP-53
title: Screen Moderation
kind: screen
depends: CP-00
status: planned
scope:
  - src/screens/Moderation/index.tsx
  - src/Navigation.tsx
```

Port `Moderation` to SwiftUI and Compose. It must match the running app on both platforms (see Design decision).

- Lines: 587 (complex); native imports: none.
- Component `src/screens/Moderation/index.tsx` is registered in `src/Navigation.tsx`. Read the components it imports; the assessment measured only the component file.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-54: Screen Messages

```checkpoint
id: CP-54
title: Screen Messages
kind: screen
depends: CP-00
status: planned
scope:
  - src/screens/Messages/ChatList.tsx
  - src/Navigation.tsx
```

Port `Messages` to SwiftUI and Compose. It must match the running app on both platforms (see Design decision).

- Lines: 644 (complex); native imports: `@react-navigation/native`, `@react-navigation/native-stack`.
- Component `src/screens/Messages/ChatList.tsx` is registered in `src/Navigation.tsx`. Read the components it imports; the assessment measured only the component file.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-55: Screen MessagesConversationSettings

```checkpoint
id: CP-55
title: Screen MessagesConversationSettings
kind: screen
depends: CP-00
status: planned
scope:
  - src/screens/Messages/ConversationSettings/index.tsx
  - src/Navigation.tsx
```

Port `MessagesConversationSettings` to SwiftUI and Compose. It must match the running app on both platforms (see Design decision).

- Lines: 647 (complex); native imports: `@react-navigation/native`.
- Component `src/screens/Messages/ConversationSettings/index.tsx` is registered in `src/Navigation.tsx`. Read the components it imports; the assessment measured only the component file.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-56: Screen Feeds

```checkpoint
id: CP-56
title: Screen Feeds
kind: screen
depends: CP-00
status: planned
scope:
  - src/view/screens/Feeds.tsx
  - src/Navigation.tsx
```

Port `Feeds` to SwiftUI and Compose. It must match the running app on both platforms (see Design decision).

- Lines: 741 (complex); native imports: none.
- Component `src/view/screens/Feeds.tsx` is registered in `src/Navigation.tsx`. Read the components it imports; the assessment measured only the component file.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-57: Replace expo-camera

```checkpoint
id: CP-57
title: Replace expo-camera
kind: dependency
depends: CP-00
status: planned
scope:
  - package.json
  - node_modules/expo-camera/package.json
```

Category: camera. Difficulty: medium.

- iOS: AVFoundation AVCaptureSession (+ VisionKit DataScannerViewController for codes)
- Android: CameraX (+ ML Kit Barcode Scanning)
- Note: Preview, capture and code scanning are separate native wiring on each platform.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-58: Replace expo-media-library

```checkpoint
id: CP-58
title: Replace expo-media-library
kind: dependency
depends: CP-00
status: planned
scope:
  - package.json
  - node_modules/expo-media-library/package.json
  - patches/expo-media-library@57.0.3.patch
```

Category: media. Difficulty: medium.

- iOS: PhotoKit (PHPhotoLibrary / PHAsset)
- Android: MediaStore (READ_MEDIA_IMAGES / READ_MEDIA_VIDEO, partial access)
- Note: Limited-library access behaves differently per platform.
- Preserve the behaviour patched in `patches/expo-media-library@57.0.3.patch`.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-59: Replace expo-video

```checkpoint
id: CP-59
title: Replace expo-video
kind: dependency
depends: CP-00
status: planned
scope:
  - package.json
  - node_modules/expo-video/package.json
```

Category: media. Difficulty: medium.

- iOS: AVPlayer / VideoPlayer (AVKit), AVPictureInPictureController
- Android: Media3 ExoPlayer + media3-ui
- Note: Picture-in-picture, background audio and now-playing each need platform setup.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-60: Replace expo-image

```checkpoint
id: CP-60
title: Replace expo-image
kind: dependency
depends: CP-00
status: planned
scope:
  - package.json
  - node_modules/expo-image/package.json
```

Category: media. Difficulty: low.

- iOS: AsyncImage, or Nuke / Kingfisher for caching
- Android: Coil 3 (AsyncImage)
- Note: Blurhash/thumbhash placeholders need a small library.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-61: Screen StarterPack

```checkpoint
id: CP-61
title: Screen StarterPack
kind: screen
depends: CP-00, CP-60
status: planned
scope:
  - src/screens/StarterPack/StarterPackScreen.tsx
  - src/Navigation.tsx
```

Port `StarterPack` to SwiftUI and Compose. It must match the running app on both platforms (see Design decision).

- Lines: 844 (complex); native imports: `@react-navigation/native`, `@react-navigation/native-stack`, `expo-image`.
- Component `src/screens/StarterPack/StarterPackScreen.tsx` is registered in `src/Navigation.tsx`. Read the components it imports; the assessment measured only the component file.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-62: Screen StarterPackShort

```checkpoint
id: CP-62
title: Screen StarterPackShort
kind: screen
depends: CP-00, CP-60
status: planned
scope:
  - src/screens/StarterPack/StarterPackScreen.tsx
  - src/Navigation.tsx
```

Port `StarterPackShort` to SwiftUI and Compose. It must match the running app on both platforms (see Design decision).

- Lines: 844 (complex); native imports: `@react-navigation/native`, `@react-navigation/native-stack`, `expo-image`.
- Component `src/screens/StarterPack/StarterPackScreen.tsx` is registered in `src/Navigation.tsx`. Read the components it imports; the assessment measured only the component file.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-63: Replace expo-location

```checkpoint
id: CP-63
title: Replace expo-location
kind: dependency
depends: CP-00
status: planned
scope:
  - package.json
  - node_modules/expo-location/package.json
```

Category: maps. Difficulty: medium.

- iOS: CLLocationManager / CLLocationUpdate.liveUpdates, CLMonitor for geofences
- Android: FusedLocationProviderClient, GeofencingClient
- Note: Background location makes this high: Always authorisation on iOS, a location foreground service on Android.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-64: Replace expo-notifications

```checkpoint
id: CP-64
title: Replace expo-notifications
kind: dependency
depends: CP-00
status: planned
scope:
  - package.json
  - node_modules/expo-notifications/package.json
  - patches/expo-notifications@57.0.7.patch
```

Category: notifications. Difficulty: high.

- iOS: UNUserNotificationCenter + APNs (registerForRemoteNotifications)
- Android: FCM FirebaseMessagingService + NotificationCompat (POST_NOTIFICATIONS on Android 13+)
- Note: Expo push tokens become raw APNs/FCM tokens: the backend send path changes too. Test cold-start tap routing.
- Preserve the behaviour patched in `patches/expo-notifications@57.0.7.patch`.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-65: Screen NotificationSettings

```checkpoint
id: CP-65
title: Screen NotificationSettings
kind: screen
depends: CP-00, CP-64
status: planned
scope:
  - src/screens/Settings/NotificationSettings/index.tsx
  - src/Navigation.tsx
```

Port `NotificationSettings` to SwiftUI and Compose. It must match the running app on both platforms (see Design decision).

- Lines: 390 (complex); native imports: `expo-notifications`.
- Component `src/screens/Settings/NotificationSettings/index.tsx` is registered in `src/Navigation.tsx`. Read the components it imports; the assessment measured only the component file.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-66: Replace @react-native-async-storage/async-storage

```checkpoint
id: CP-66
title: Replace @react-native-async-storage/async-storage
kind: dependency
depends: CP-00
status: planned
scope:
  - package.json
  - node_modules/@react-native-async-storage/async-storage/package.json
```

Category: storage. Difficulty: medium.

- iOS: UserDefaults / file in Application Support
- Android: DataStore Preferences
- Note: Existing AsyncStorage data (manifest file on iOS, SQLite on Android) must be migrated on first launch.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-67: Replace expo-file-system

```checkpoint
id: CP-67
title: Replace expo-file-system
kind: dependency
depends: CP-00
status: planned
scope:
  - package.json
  - node_modules/expo-file-system/package.json
```

Category: storage. Difficulty: low.

- iOS: FileManager (Documents / Caches), URLSession downloads
- Android: Context.filesDir / cacheDir, WorkManager or DownloadManager for downloads
- Note: Check stored paths: Expo document directory locations must be preserved.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-68: Replace react-native-gesture-handler

```checkpoint
id: CP-68
title: Replace react-native-gesture-handler
kind: dependency
depends: CP-00
status: planned
scope:
  - package.json
  - node_modules/react-native-gesture-handler/package.json
```

Category: animation. Difficulty: medium.

- iOS: SwiftUI gestures (DragGesture, MagnifyGesture) / UIGestureRecognizer
- Android: Modifier.pointerInput / draggable / transformable
- Note: Composed gestures need re-tuning per platform.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-69: Replace react-native-reanimated

```checkpoint
id: CP-69
title: Replace react-native-reanimated
kind: dependency
depends: CP-00
status: planned
scope:
  - package.json
  - node_modules/react-native-reanimated/package.json
```

Category: animation. Difficulty: medium.

- iOS: withAnimation / PhaseAnimator / KeyframeAnimator / matchedGeometryEffect
- Android: animate*AsState / updateTransition / Animatable / SharedTransitionLayout
- Note: Gesture-driven worklet animations are the expensive ones; audit each use.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-70: Screen FindContactsFlow

```checkpoint
id: CP-70
title: Screen FindContactsFlow
kind: screen
depends: CP-00, CP-69
status: planned
scope:
  - src/screens/FindContactsFlowScreen.tsx
  - src/Navigation.tsx
```

Port `FindContactsFlow` to SwiftUI and Compose. It must match the running app on both platforms (see Design decision).

- Lines: 61 (simple); native imports: `react-native-reanimated`, `@react-navigation/native`.
- Component `src/screens/FindContactsFlowScreen.tsx` is registered in `src/Navigation.tsx`. Read the components it imports; the assessment measured only the component file.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-71: Screen CustomFeed

```checkpoint
id: CP-71
title: Screen CustomFeed
kind: screen
depends: CP-00, CP-69
status: planned
scope:
  - src/screens/CustomFeed/index.tsx
  - src/Navigation.tsx
```

Port `CustomFeed` to SwiftUI and Compose. It must match the running app on both platforms (see Design decision).

- Lines: 205 (medium); native imports: `react-native-reanimated`, `@react-navigation/native`, `@react-navigation/native-stack`.
- Component `src/screens/CustomFeed/index.tsx` is registered in `src/Navigation.tsx`. Read the components it imports; the assessment measured only the component file.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-72: Screen AppearanceSettings

```checkpoint
id: CP-72
title: Screen AppearanceSettings
kind: screen
depends: CP-00, CP-69
status: planned
scope:
  - src/screens/Settings/AppearanceSettings.tsx
  - src/Navigation.tsx
```

Port `AppearanceSettings` to SwiftUI and Compose. It must match the running app on both platforms (see Design decision).

- Lines: 220 (medium); native imports: `react-native-reanimated`.
- Component `src/screens/Settings/AppearanceSettings.tsx` is registered in `src/Navigation.tsx`. Read the components it imports; the assessment measured only the component file.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-73: Screen ProfileList

```checkpoint
id: CP-73
title: Screen ProfileList
kind: screen
depends: CP-00, CP-69
status: planned
scope:
  - src/screens/ProfileList/index.tsx
  - src/Navigation.tsx
```

Port `ProfileList` to SwiftUI and Compose. It must match the running app on both platforms (see Design decision).

- Lines: 275 (complex); native imports: `react-native-reanimated`, `@react-navigation/native`.
- Component `src/screens/ProfileList/index.tsx` is registered in `src/Navigation.tsx`. Read the components it imports; the assessment measured only the component file.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-74: Screen Home

```checkpoint
id: CP-74
title: Screen Home
kind: screen
depends: CP-00, CP-69
status: planned
scope:
  - src/view/screens/Home.tsx
  - src/Navigation.tsx
```

Port `Home` to SwiftUI and Compose. It must match the running app on both platforms (see Design decision).

- Lines: 349 (complex); native imports: `react-native-reanimated`, `@react-navigation/native`.
- Component `src/view/screens/Home.tsx` is registered in `src/Navigation.tsx`. Read the components it imports; the assessment measured only the component file.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-75: Screen Start

```checkpoint
id: CP-75
title: Screen Start
kind: screen
depends: CP-00, CP-69
status: planned
scope:
  - src/view/screens/Home.tsx
  - src/Navigation.tsx
```

Port `Start` to SwiftUI and Compose. It must match the running app on both platforms (see Design decision).

- Lines: 349 (complex); native imports: `react-native-reanimated`, `@react-navigation/native`.
- Component `src/view/screens/Home.tsx` is registered in `src/Navigation.tsx`. Read the components it imports; the assessment measured only the component file.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-76: Screen SavedFeeds

```checkpoint
id: CP-76
title: Screen SavedFeeds
kind: screen
depends: CP-00, CP-69
status: planned
scope:
  - src/screens/SavedFeeds.tsx
  - src/Navigation.tsx
```

Port `SavedFeeds` to SwiftUI and Compose. It must match the running app on both platforms (see Design decision).

- Lines: 588 (complex); native imports: `react-native-reanimated`, `@react-navigation/native`, `@react-navigation/native-stack`.
- Component `src/screens/SavedFeeds.tsx` is registered in `src/Navigation.tsx`. Read the components it imports; the assessment measured only the component file.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-77: Screen Settings

```checkpoint
id: CP-77
title: Screen Settings
kind: screen
depends: CP-00, CP-69
status: planned
scope:
  - src/screens/Settings/Settings.tsx
  - src/Navigation.tsx
```

Port `Settings` to SwiftUI and Compose. It must match the running app on both platforms (see Design decision).

- Lines: 672 (complex); native imports: `react-native-reanimated`, `@react-navigation/native`, `@react-navigation/native-stack`.
- Component `src/screens/Settings/Settings.tsx` is registered in `src/Navigation.tsx`. Read the components it imports; the assessment measured only the component file.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-78: Screen DebugMod

```checkpoint
id: CP-78
title: Screen DebugMod
kind: screen
depends: CP-00, CP-69
status: planned
scope:
  - src/view/screens/DebugMod.tsx
  - src/Navigation.tsx
```

Port `DebugMod` to SwiftUI and Compose. It must match the running app on both platforms (see Design decision).

- Lines: 1146 (complex); native imports: `react-native-reanimated`.
- Component `src/view/screens/DebugMod.tsx` is registered in `src/Navigation.tsx`. Read the components it imports; the assessment measured only the component file.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-79: Replace react-native-keyboard-controller

```checkpoint
id: CP-79
title: Replace react-native-keyboard-controller
kind: dependency
depends: CP-00
status: planned
scope:
  - package.json
  - node_modules/react-native-keyboard-controller/package.json
  - patches/react-native-keyboard-controller@1.21.9.patch
```

Category: ui. Difficulty: medium.

- iOS: Keyboard avoidance, .scrollDismissesKeyboard, keyboardLayoutGuide
- Android: Modifier.imePadding / WindowInsets.ime
- Note: Interactive keyboard animations behave differently per platform.
- Preserve the behaviour patched in `patches/react-native-keyboard-controller@1.21.9.patch`.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-80: Replace expo-clipboard

```checkpoint
id: CP-80
title: Replace expo-clipboard
kind: dependency
depends: CP-00
status: planned
scope:
  - package.json
  - node_modules/expo-clipboard/package.json
```

Category: ui. Difficulty: low.

- iOS: UIPasteboard / PasteButton
- Android: LocalClipboard / ClipboardManager
- Note: Straight replacement.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-81: Replace expo-linear-gradient

```checkpoint
id: CP-81
title: Replace expo-linear-gradient
kind: dependency
depends: CP-00
status: planned
scope:
  - package.json
  - node_modules/expo-linear-gradient/package.json
```

Category: ui. Difficulty: low.

- iOS: LinearGradient (SwiftUI) / CAGradientLayer
- Android: Brush.linearGradient
- Note: Straight replacement.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-82: Replace react-native-safe-area-context

```checkpoint
id: CP-82
title: Replace react-native-safe-area-context
kind: dependency
depends: CP-00
status: planned
scope:
  - package.json
  - node_modules/react-native-safe-area-context/package.json
```

Category: ui. Difficulty: low.

- iOS: Safe areas (.safeAreaInset / .safeAreaPadding)
- Android: WindowInsets (enableEdgeToEdge, Modifier.windowInsetsPadding)
- Note: Handled by the platform layout system.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-83: Replace react-native-svg

```checkpoint
id: CP-83
title: Replace react-native-svg
kind: dependency
depends: CP-00
status: planned
scope:
  - package.json
  - node_modules/react-native-svg/package.json
  - patches/react-native-svg@15.15.4.patch
```

Category: ui. Difficulty: low.

- iOS: SF Symbols, SwiftUI Shape/Path, vector PDF/SVG in the asset catalog
- Android: ImageVector / vector drawables, Compose Canvas
- Note: Static icons are low; generated SVG (charts, drawings) is medium.
- Preserve the behaviour patched in `patches/react-native-svg@15.15.4.patch`.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-84: Screen AboutSettings

```checkpoint
id: CP-84
title: Screen AboutSettings
kind: screen
depends: CP-00, CP-80, CP-67, CP-60
status: planned
scope:
  - src/screens/Settings/AboutSettings.tsx
  - src/Navigation.tsx
```

Port `AboutSettings` to SwiftUI and Compose. It must match the running app on both platforms (see Design decision).

- Lines: 203 (medium); native imports: `@react-navigation/native-stack`, `expo-clipboard`, `expo-file-system`, `expo-image`.
- Component `src/screens/Settings/AboutSettings.tsx` is registered in `src/Navigation.tsx`. Read the components it imports; the assessment measured only the component file.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-85: Screen InviteScanner

```checkpoint
id: CP-85
title: Screen InviteScanner
kind: screen
depends: CP-00, CP-57, CP-82, CP-83
status: planned
scope:
  - src/features/inviteFriends/InviteScannerScreen.tsx
  - src/Navigation.tsx
```

Port `InviteScanner` to SwiftUI and Compose. It must match the running app on both platforms (see Design decision).

- Lines: 246 (medium); native imports: `expo-camera`, `@react-navigation/native`, `react-native-safe-area-context`, `react-native-svg`.
- Component `src/features/inviteFriends/InviteScannerScreen.tsx` is registered in `src/Navigation.tsx`. Read the components it imports; the assessment measured only the component file.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-86: Screen StarterPackEdit

```checkpoint
id: CP-86
title: Screen StarterPackEdit
kind: screen
depends: CP-00, CP-79, CP-60, CP-82
status: planned
scope:
  - src/screens/StarterPack/Wizard/index.tsx
  - src/Navigation.tsx
```

Port `StarterPackEdit` to SwiftUI and Compose. It must match the running app on both platforms (see Design decision).

- Lines: 600 (complex); native imports: `react-native-keyboard-controller`, `@react-navigation/native`, `@react-navigation/native-stack`, `expo-image`, `react-native-safe-area-context`.
- Component `src/screens/StarterPack/Wizard/index.tsx` is registered in `src/Navigation.tsx`. Read the components it imports; the assessment measured only the component file.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-87: Screen StarterPackWizard

```checkpoint
id: CP-87
title: Screen StarterPackWizard
kind: screen
depends: CP-00, CP-79, CP-60, CP-82
status: planned
scope:
  - src/screens/StarterPack/Wizard/index.tsx
  - src/Navigation.tsx
```

Port `StarterPackWizard` to SwiftUI and Compose. It must match the running app on both platforms (see Design decision).

- Lines: 600 (complex); native imports: `react-native-keyboard-controller`, `@react-navigation/native`, `@react-navigation/native-stack`, `expo-image`, `react-native-safe-area-context`.
- Component `src/screens/StarterPack/Wizard/index.tsx` is registered in `src/Navigation.tsx`. Read the components it imports; the assessment measured only the component file.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-88: Screen Profile

```checkpoint
id: CP-88
title: Screen Profile
kind: screen
depends: CP-00, CP-82
status: planned
scope:
  - src/view/screens/Profile.tsx
  - src/Navigation.tsx
```

Port `Profile` to SwiftUI and Compose. It must match the running app on both platforms (see Design decision).

- Lines: 641 (complex); native imports: `@react-navigation/native`, `react-native-safe-area-context`.
- Component `src/view/screens/Profile.tsx` is registered in `src/Navigation.tsx`. Read the components it imports; the assessment measured only the component file.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-89: Screen VideoFeed

```checkpoint
id: CP-89
title: Screen VideoFeed
kind: screen
depends: CP-00, CP-59, CP-68, CP-69, CP-60, CP-81, CP-82
status: planned
scope:
  - src/screens/VideoFeed/index.tsx
  - src/Navigation.tsx
```

Port `VideoFeed` to SwiftUI and Compose. It must match the running app on both platforms (see Design decision).

- Lines: 1243 (complex); native imports: `expo-video`, `react-native-gesture-handler`, `react-native-reanimated`, `@react-navigation/native`, `@react-navigation/native-stack`, `expo-image`, `expo-linear-gradient`, `react-native-safe-area-context`.
- Component `src/screens/VideoFeed/index.tsx` is registered in `src/Navigation.tsx`. Read the components it imports; the assessment measured only the component file.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-90: Replace @bitdrift/react-native

```checkpoint
id: CP-90
title: Replace @bitdrift/react-native
kind: dependency
depends: CP-00
status: planned
scope:
  - package.json
  - node_modules/@bitdrift/react-native/package.json
```

Category: other. Difficulty: unknown.

- iOS: unknown — inspect
- Android: unknown — inspect
- Note: Unmapped package with native code (ios/, android/, *.podspec). Inspect what it does.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-91: Replace @bsky.app/expo-dynamic-app-icon

```checkpoint
id: CP-91
title: Replace @bsky.app/expo-dynamic-app-icon
kind: dependency
depends: CP-00
status: planned
scope:
  - package.json
  - node_modules/@bsky.app/expo-dynamic-app-icon/package.json
```

Category: other. Difficulty: unknown.

- iOS: unknown — inspect
- Android: unknown — inspect
- Note: Unmapped package with native code (ios/, android/, expo-module.config.json). Inspect what it does.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-92: Replace @bsky.app/expo-guess-language

```checkpoint
id: CP-92
title: Replace @bsky.app/expo-guess-language
kind: dependency
depends: CP-00
status: planned
scope:
  - package.json
  - node_modules/@bsky.app/expo-guess-language/package.json
```

Category: other. Difficulty: unknown.

- iOS: unknown — inspect
- Android: unknown — inspect
- Note: Unmapped package with native code (ios/, android/, expo-module.config.json). Inspect what it does.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-93: Replace @bsky.app/expo-image-crop-tool

```checkpoint
id: CP-93
title: Replace @bsky.app/expo-image-crop-tool
kind: dependency
depends: CP-00
status: planned
scope:
  - package.json
  - node_modules/@bsky.app/expo-image-crop-tool/package.json
```

Category: other. Difficulty: unknown.

- iOS: unknown — inspect
- Android: unknown — inspect
- Note: Unmapped package with native code (ios/, android/, expo-module.config.json). Inspect what it does.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-94: Replace @bsky.app/expo-scroll-edge-effect

```checkpoint
id: CP-94
title: Replace @bsky.app/expo-scroll-edge-effect
kind: dependency
depends: CP-00
status: planned
scope:
  - package.json
  - node_modules/@bsky.app/expo-scroll-edge-effect/package.json
```

Category: other. Difficulty: unknown.

- iOS: unknown — inspect
- Android: unknown — inspect
- Note: Unmapped package with native code (ios/, expo-module.config.json). Inspect what it does.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-95: Replace @bsky.app/expo-translate-text

```checkpoint
id: CP-95
title: Replace @bsky.app/expo-translate-text
kind: dependency
depends: CP-00
status: planned
scope:
  - package.json
  - node_modules/@bsky.app/expo-translate-text/package.json
```

Category: other. Difficulty: unknown.

- iOS: unknown — inspect
- Android: unknown — inspect
- Note: Unmapped package with native code (ios/, android/, expo-module.config.json). Inspect what it does.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-96: Replace @bsky.app/peek-menu

```checkpoint
id: CP-96
title: Replace @bsky.app/peek-menu
kind: dependency
depends: CP-00
status: planned
scope:
  - package.json
  - node_modules/@bsky.app/peek-menu/package.json
```

Category: other. Difficulty: unknown.

- iOS: unknown — inspect
- Android: unknown — inspect
- Note: Unmapped package with native code (ios/, expo-module.config.json). Inspect what it does.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-97: Replace @bsky.app/react-native-uitextview

```checkpoint
id: CP-97
title: Replace @bsky.app/react-native-uitextview
kind: dependency
depends: CP-00
status: planned
scope:
  - package.json
  - node_modules/@bsky.app/react-native-uitextview/package.json
```

Category: other. Difficulty: unknown.

- iOS: unknown — inspect
- Android: unknown — inspect
- Note: Unmapped package with native code (ios/, android/, *.podspec). Inspect what it does.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-98: Replace @bsky.app/sift

```checkpoint
id: CP-98
title: Replace @bsky.app/sift
kind: dependency
depends: CP-00
status: planned
scope:
  - package.json
  - node_modules/@bsky.app/sift/package.json
```

Category: other. Difficulty: unknown.

- iOS: unknown — inspect
- Android: unknown — inspect
- Note: Unmapped package with native code (expo-module.config.json). Inspect what it does.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-99: Replace @bsky.app/tapper

```checkpoint
id: CP-99
title: Replace @bsky.app/tapper
kind: dependency
depends: CP-00
status: planned
scope:
  - package.json
  - node_modules/@bsky.app/tapper/package.json
```

Category: other. Difficulty: unknown.

- iOS: unknown — inspect
- Android: unknown — inspect
- Note: Unmapped package with native code (expo-module.config.json). Inspect what it does.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-100: Replace @bsky.app/video

```checkpoint
id: CP-100
title: Replace @bsky.app/video
kind: dependency
depends: CP-00
status: planned
scope:
  - package.json
  - node_modules/@bsky.app/video/package.json
```

Category: other. Difficulty: unknown.

- iOS: unknown — inspect
- Android: unknown — inspect
- Note: Unmapped package with native code (ios/, android/, expo-module.config.json). Inspect what it does.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-101: Replace @bsky.app/video-compressor

```checkpoint
id: CP-101
title: Replace @bsky.app/video-compressor
kind: dependency
depends: CP-00
status: planned
scope:
  - package.json
  - node_modules/@bsky.app/video-compressor/package.json
```

Category: other. Difficulty: unknown.

- iOS: unknown — inspect
- Android: unknown — inspect
- Note: Unmapped package with native code (ios/, android/, expo-module.config.json). Inspect what it does.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-102: Replace expo-age-range

```checkpoint
id: CP-102
title: Replace expo-age-range
kind: dependency
depends: CP-00
status: planned
scope:
  - package.json
  - node_modules/expo-age-range/package.json
  - patches/expo-age-range@57.0.2.patch
```

Category: other. Difficulty: unknown.

- iOS: unknown — inspect
- Android: unknown — inspect
- Note: Unmapped package with native code (ios/, android/, expo-module.config.json). Inspect what it does.
- Preserve the behaviour patched in `patches/expo-age-range@57.0.2.patch`.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-103: Replace expo-asset

```checkpoint
id: CP-103
title: Replace expo-asset
kind: dependency
depends: CP-00
status: planned
scope:
  - package.json
  - node_modules/expo-asset/package.json
```

Category: other. Difficulty: unknown.

- iOS: unknown — inspect
- Android: unknown — inspect
- Note: Unmapped package with native code (ios/, android/, expo-module.config.json). Inspect what it does.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-104: Replace expo-glass-effect

```checkpoint
id: CP-104
title: Replace expo-glass-effect
kind: dependency
depends: CP-00
status: planned
scope:
  - package.json
  - node_modules/expo-glass-effect/package.json
```

Category: other. Difficulty: unknown.

- iOS: unknown — inspect
- Android: unknown — inspect
- Note: Unmapped package with native code (ios/, expo-module.config.json). Inspect what it does.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-105: Replace expo-intent-launcher

```checkpoint
id: CP-105
title: Replace expo-intent-launcher
kind: dependency
depends: CP-00
status: planned
scope:
  - package.json
  - node_modules/expo-intent-launcher/package.json
```

Category: other. Difficulty: unknown.

- iOS: unknown — inspect
- Android: unknown — inspect
- Note: Unmapped package with native code (android/, expo-module.config.json). Inspect what it does.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-106: Replace expo-paste-input

```checkpoint
id: CP-106
title: Replace expo-paste-input
kind: dependency
depends: CP-00
status: planned
scope:
  - package.json
  - node_modules/expo-paste-input/package.json
```

Category: other. Difficulty: unknown.

- iOS: unknown — inspect
- Android: unknown — inspect
- Note: Unmapped package with native code (ios/, android/, expo-module.config.json). Inspect what it does.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-107: Replace expo-privacy-sensitive

```checkpoint
id: CP-107
title: Replace expo-privacy-sensitive
kind: dependency
depends: CP-00
status: planned
scope:
  - package.json
  - node_modules/expo-privacy-sensitive/package.json
```

Category: other. Difficulty: unknown.

- iOS: unknown — inspect
- Android: unknown — inspect
- Note: Unmapped package with native code (ios/, expo-module.config.json). Inspect what it does.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-108: Replace expo-screen-orientation

```checkpoint
id: CP-108
title: Replace expo-screen-orientation
kind: dependency
depends: CP-00
status: planned
scope:
  - package.json
  - node_modules/expo-screen-orientation/package.json
```

Category: other. Difficulty: unknown.

- iOS: unknown — inspect
- Android: unknown — inspect
- Note: Unmapped package with native code (ios/, android/, expo-module.config.json). Inspect what it does.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-109: Replace expo-sms

```checkpoint
id: CP-109
title: Replace expo-sms
kind: dependency
depends: CP-00
status: planned
scope:
  - package.json
  - node_modules/expo-sms/package.json
```

Category: other. Difficulty: unknown.

- iOS: unknown — inspect
- Android: unknown — inspect
- Note: Unmapped package with native code (ios/, android/, expo-module.config.json). Inspect what it does.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-110: Replace expo-video-thumbnails

```checkpoint
id: CP-110
title: Replace expo-video-thumbnails
kind: dependency
depends: CP-00
status: planned
scope:
  - package.json
  - node_modules/expo-video-thumbnails/package.json
```

Category: other. Difficulty: unknown.

- iOS: unknown — inspect
- Android: unknown — inspect
- Note: Unmapped package with native code (ios/, android/, expo-module.config.json). Inspect what it does.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-111: Replace react-native-date-picker

```checkpoint
id: CP-111
title: Replace react-native-date-picker
kind: dependency
depends: CP-00
status: planned
scope:
  - package.json
  - node_modules/react-native-date-picker/package.json
  - patches/react-native-date-picker@5.0.13.patch
```

Category: other. Difficulty: unknown.

- iOS: unknown — inspect
- Android: unknown — inspect
- Note: Unmapped package with native code (ios/, android/, *.podspec). Inspect what it does.
- Preserve the behaviour patched in `patches/react-native-date-picker@5.0.13.patch`.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-112: Replace react-native-device-attest

```checkpoint
id: CP-112
title: Replace react-native-device-attest
kind: dependency
depends: CP-00
status: planned
scope:
  - package.json
  - node_modules/react-native-device-attest/package.json
```

Category: other. Difficulty: unknown.

- iOS: unknown — inspect
- Android: unknown — inspect
- Note: Unmapped package with native code (ios/, android/, expo-module.config.json). Inspect what it does.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-113: Replace react-native-view-shot

```checkpoint
id: CP-113
title: Replace react-native-view-shot
kind: dependency
depends: CP-00
status: planned
scope:
  - package.json
  - node_modules/react-native-view-shot/package.json
```

Category: other. Difficulty: unknown.

- iOS: unknown — inspect
- Android: unknown — inspect
- Note: Unmapped package with native code (ios/, android/, *.podspec). Inspect what it does.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-114: Replace expo-contacts

```checkpoint
id: CP-114
title: Replace expo-contacts
kind: dependency
depends: CP-00
status: planned
scope:
  - package.json
  - node_modules/expo-contacts/package.json
```

Category: other. Difficulty: medium.

- iOS: Contacts CNContactStore / ContactAccessButton (limited access)
- Android: ContactsContract via ContentResolver
- Note: Limited contact access on iOS 18+ changes the flow.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-115: Replace local module bottom-sheet

```checkpoint
id: CP-115
title: Replace local module bottom-sheet
kind: dependency
depends: CP-00
status: planned
scope:
  - modules/bottom-sheet
  - modules/bottom-sheet/expo-module.config.json
  - modules/bottom-sheet/android/src/main/java/expo/modules/bottomsheet/BottomSheetModule.kt
  - modules/bottom-sheet/android/src/main/java/expo/modules/bottomsheet/BottomSheetView.kt
  - modules/bottom-sheet/android/src/main/java/expo/modules/bottomsheet/DialogRootViewGroup.kt
  - modules/bottom-sheet/android/src/main/java/expo/modules/bottomsheet/SheetManager.kt
  - modules/bottom-sheet/ios/BottomSheetModule.swift
  - modules/bottom-sheet/ios/SheetManager.swift
  - modules/bottom-sheet/ios/SheetView.swift
  - modules/bottom-sheet/ios/SheetViewController.swift
  - modules/bottom-sheet/ios/Util.swift
```

Re-expose the existing native code (5 Swift, 4 Kotlin files) as a Swift API for SwiftUI and a Kotlin API for Compose. Remove the JS bridge.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-116: Replace local module expo-background-notification-handler

```checkpoint
id: CP-116
title: Replace local module expo-background-notification-handler
kind: dependency
depends: CP-00
status: planned
scope:
  - modules/expo-background-notification-handler
  - modules/expo-background-notification-handler/expo-module.config.json
  - modules/expo-background-notification-handler/android/src/main/java/expo/modules/backgroundnotificationhandler/BackgroundNotificationHandler.kt
  - modules/expo-background-notification-handler/android/src/main/java/expo/modules/backgroundnotificationhandler/BackgroundNotificationHandlerInterface.kt
  - modules/expo-background-notification-handler/android/src/main/java/expo/modules/backgroundnotificationhandler/ExpoBackgroundNotificationHandlerModule.kt
  - modules/expo-background-notification-handler/android/src/main/java/expo/modules/backgroundnotificationhandler/NotificationPrefs.kt
  - modules/expo-background-notification-handler/ios/ExpoBackgroundNotificationHandlerModule.swift
```

Re-expose the existing native code (1 Swift, 4 Kotlin files) as a Swift API for SwiftUI and a Kotlin API for Compose. Remove the JS bridge.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-117: Replace local module expo-bluesky-gif-view

```checkpoint
id: CP-117
title: Replace local module expo-bluesky-gif-view
kind: dependency
depends: CP-00
status: planned
scope:
  - modules/expo-bluesky-gif-view
  - modules/expo-bluesky-gif-view/expo-module.config.json
  - modules/expo-bluesky-gif-view/android/src/main/java/expo/modules/blueskygifview/AppCompatImageViewExtended.kt
  - modules/expo-bluesky-gif-view/android/src/main/java/expo/modules/blueskygifview/ExpoBlueskyGifViewModule.kt
  - modules/expo-bluesky-gif-view/android/src/main/java/expo/modules/blueskygifview/GifView.kt
  - modules/expo-bluesky-gif-view/ios/ExpoBlueskyGifViewModule.swift
  - modules/expo-bluesky-gif-view/ios/GifView.swift
  - modules/expo-bluesky-gif-view/ios/Util.swift
```

Re-expose the existing native code (3 Swift, 3 Kotlin files) as a Swift API for SwiftUI and a Kotlin API for Compose. Remove the JS bridge.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-118: Replace local module expo-bluesky-swiss-army

```checkpoint
id: CP-118
title: Replace local module expo-bluesky-swiss-army
kind: dependency
depends: CP-00
status: planned
scope:
  - modules/expo-bluesky-swiss-army
  - modules/expo-bluesky-swiss-army/expo-module.config.json
  - modules/expo-bluesky-swiss-army/android/src/main/java/expo/modules/blueskyswissarmy/platforminfo/ExpoPlatformInfoModule.kt
  - modules/expo-bluesky-swiss-army/android/src/main/java/expo/modules/blueskyswissarmy/referrer/ExpoBlueskyReferrerModule.kt
  - modules/expo-bluesky-swiss-army/android/src/main/java/expo/modules/blueskyswissarmy/sharedprefs/ExpoBlueskySharedPrefsModule.kt
  - modules/expo-bluesky-swiss-army/android/src/main/java/expo/modules/blueskyswissarmy/sharedprefs/SharedPrefs.kt
  - modules/expo-bluesky-swiss-army/android/src/main/java/expo/modules/blueskyswissarmy/visibilityview/ExpoBlueskyVisibilityViewModule.kt
  - modules/expo-bluesky-swiss-army/android/src/main/java/expo/modules/blueskyswissarmy/visibilityview/VisibilityView.kt
  - modules/expo-bluesky-swiss-army/android/src/main/java/expo/modules/blueskyswissarmy/visibilityview/VisibilityViewManager.kt
  - modules/expo-bluesky-swiss-army/ios/NotificationSettings/ExpoBlueskyNotificationSettingsModule.swift
  - modules/expo-bluesky-swiss-army/ios/PlatformInfo/ExpoPlatformInfoModule.swift
  - modules/expo-bluesky-swiss-army/ios/Referrer/ExpoBlueskyReferrerModule.swift
```

Re-expose the existing native code (8 Swift, 7 Kotlin files) as a Swift API for SwiftUI and a Kotlin API for Compose. Remove the JS bridge.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-119: Replace local module expo-emoji-picker

```checkpoint
id: CP-119
title: Replace local module expo-emoji-picker
kind: dependency
depends: CP-00
status: planned
scope:
  - modules/expo-emoji-picker
  - modules/expo-emoji-picker/expo-module.config.json
  - modules/expo-emoji-picker/android/src/main/java/expo/community/modules/emojipicker/EmojiPickerModule.kt
  - modules/expo-emoji-picker/android/src/main/java/expo/community/modules/emojipicker/EmojiPickerModuleView.kt
  - modules/expo-emoji-picker/ios/EmojiPickerModule.swift
  - modules/expo-emoji-picker/ios/EmojiPickerView.swift
```

Re-expose the existing native code (2 Swift, 2 Kotlin files) as a Swift API for SwiftUI and a Kotlin API for Compose. Remove the JS bridge.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-120: Replace local module expo-receive-android-intents

```checkpoint
id: CP-120
title: Replace local module expo-receive-android-intents
kind: dependency
depends: CP-00
status: planned
scope:
  - modules/expo-receive-android-intents
  - modules/expo-receive-android-intents/expo-module.config.json
  - modules/expo-receive-android-intents/android/src/main/java/xyz/blueskyweb/app/exporeceiveandroidintents/ExpoReceiveAndroidIntentsModule.kt
```

Re-expose the existing native code (0 Swift, 1 Kotlin files) as a Swift API for SwiftUI and a Kotlin API for Compose. Remove the JS bridge.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-121: Screen AppIconSettings

```checkpoint
id: CP-121
title: Screen AppIconSettings
kind: screen
depends: CP-00, CP-91
status: planned
scope:
  - src/screens/Settings/AppIconSettings/index.tsx
  - src/Navigation.tsx
```

Port `AppIconSettings` to SwiftUI and Compose. It must match the running app on both platforms (see Design decision).

- Lines: 234 (medium); native imports: `@bsky.app/expo-dynamic-app-icon`, `@react-navigation/native-stack`.
- Component `src/screens/Settings/AppIconSettings/index.tsx` is registered in `src/Navigation.tsx`. Read the components it imports; the assessment measured only the component file.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-122: Screen MessagesConversation

```checkpoint
id: CP-122
title: Screen MessagesConversation
kind: screen
depends: CP-00, CP-94, CP-82
status: planned
scope:
  - src/screens/Messages/Conversation.tsx
  - src/Navigation.tsx
```

Port `MessagesConversation` to SwiftUI and Compose. It must match the running app on both platforms (see Design decision).

- Lines: 279 (complex); native imports: `@bsky.app/expo-scroll-edge-effect`, `@react-navigation/native`, `@react-navigation/native-stack`, `react-native-safe-area-context`.
- Component `src/screens/Messages/Conversation.tsx` is registered in `src/Navigation.tsx`. Read the components it imports; the assessment measured only the component file.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-123: Screen FindContactsSettings

```checkpoint
id: CP-123
title: Screen FindContactsSettings
kind: screen
depends: CP-00, CP-114
status: planned
scope:
  - src/screens/Settings/FindContactsSettings.tsx
  - src/Navigation.tsx
```

Port `FindContactsSettings` to SwiftUI and Compose. It must match the running app on both platforms (see Design decision).

- Lines: 564 (complex); native imports: `expo-contacts`, `@react-navigation/native`.
- Component `src/screens/Settings/FindContactsSettings.tsx` is registered in `src/Navigation.tsx`. Read the components it imports; the assessment measured only the component file.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-124: Screen AppPasswords

```checkpoint
id: CP-124
title: Screen AppPasswords
kind: screen
depends: CP-00, CP-69
status: planned
scope:
  - src/screens/Settings/AppPasswords.tsx
  - src/Navigation.tsx
```

Port `AppPasswords` to SwiftUI and Compose. It must match the running app on both platforms (see Design decision).

- Lines: 210 (medium); native imports: `react-native-reanimated`, `@react-navigation/native-stack`.
- Component `src/screens/Settings/AppPasswords.tsx` is registered in `src/Navigation.tsx`. Read the components it imports; the assessment measured only the component file.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-125: Replace the OTA release flow

```checkpoint
id: CP-125
title: Replace the OTA release flow
kind: ota
depends: CP-00
status: planned
scope:
  - package.json
  - app.config.js
  - eas.json
```

Today: expo-updates active. Native apps cannot hot-fix code.

- Feature flags and remote config for every change that ships through OTA today.
- Phased release (App Store) and staged rollout (Play); Play In-App Updates where needed.
- A written hot-fix procedure that does not use OTA.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

### CP-126: Cutover

```checkpoint
id: CP-126
title: Cutover
kind: cutover
depends: CP-00, CP-01, CP-02, CP-03, CP-04, CP-05, CP-06, CP-07, CP-08, CP-09, CP-10, CP-11, CP-12, CP-13, CP-14, CP-15, CP-16, CP-17, CP-18, CP-19, CP-20, CP-21, CP-22, CP-23, CP-24, CP-25, CP-26, CP-27, CP-28, CP-29, CP-30, CP-31, CP-32, CP-33, CP-34, CP-35, CP-36, CP-37, CP-38, CP-39, CP-40, CP-41, CP-42, CP-43, CP-44, CP-45, CP-46, CP-47, CP-48, CP-49, CP-50, CP-51, CP-52, CP-53, CP-54, CP-55, CP-56, CP-57, CP-58, CP-59, CP-60, CP-61, CP-62, CP-63, CP-64, CP-65, CP-66, CP-67, CP-68, CP-69, CP-70, CP-71, CP-72, CP-73, CP-74, CP-75, CP-76, CP-77, CP-78, CP-79, CP-80, CP-81, CP-82, CP-83, CP-84, CP-85, CP-86, CP-87, CP-88, CP-89, CP-90, CP-91, CP-92, CP-93, CP-94, CP-95, CP-96, CP-97, CP-98, CP-99, CP-100, CP-101, CP-102, CP-103, CP-104, CP-105, CP-106, CP-107, CP-108, CP-109, CP-110, CP-111, CP-112, CP-113, CP-114, CP-115, CP-116, CP-117, CP-118, CP-119, CP-120, CP-121, CP-122, CP-123, CP-124, CP-125
status: planned
scope:
  - package.json
```

Ship the native apps and retire the React Native build.

- Store submission, phased rollout, crash and parity monitoring.
- Existing users keep their session, settings and purchases after the update.
- Rollback plan written and rehearsed.

Gates:

- [ ] Tests pass on iOS and Android
- [ ] Parity report passes, or every drift is accepted in writing
- [ ] parity-reviewer passes
- [ ] architecture-reviewer passes
- [ ] Human approval recorded

