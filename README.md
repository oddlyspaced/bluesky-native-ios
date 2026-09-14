# Bluesky native: showcase port

A native port of three Bluesky screens: home feed, post thread and profile. The iOS app uses SwiftUI and the Android app uses Jetpack Compose. The port was made with the Nativestarter Migration Pack, one checkpoint at a time, and each screen is checked against the running React Native app.

Not affiliated with, endorsed by, or officially connected to Bluesky Social PBC. See `NOTICE.md`.

## What is in this repository

| Path | Contents |
|---|---|
| `plan/bluesky-assessment.md`, `plan/bluesky-assessment.json` | The `assess-rn-app` output for the upstream app |
| `plan/full-app-plan.md` | The 127-checkpoint plan that `plan-checkpoints` drafted for the whole app from that assessment |
| `plan/slice-plan.md` | The four checkpoints this showcase covers (CP-00 to CP-03) |
| `ios/` | SwiftUI app. See `ios/README.md` and `ios/PARITY.md` |
| `android/` | Jetpack Compose app. See `android/README.md` and `android/PARITY.md` |
| `parity/flows/` | The read-only Maestro capture flow shared by the React Native and native apps |
| `parity/baseline/rn/` | Screenshots of the upstream React Native app on the same test data |

## Scope

This port covers part of the app, not all of it. The assessment finds 78 screens in the upstream app, and the full plan lists all of them. This showcase ports the foundation (design tokens, XRPC client, session, tab shell) and three screens. Tabs outside the slice show a labelled placeholder screen in the app.

## Run the reference setup

1. Start the upstream e2e dev network from `bluesky-social/social-app` at commit 2bfb94d: `pnpm e2e:mock-server`.
   - Keep ports 2584 and 3000 to 3003 free. The network takes the next free port for each service, and the AppView DID depends on those ports. If another process holds one of them, the mock server stops with "E2E AppView DID changed".
   - With free ports, the AppView DID is `did:plc:bw7ad3erl7btq6qwf66yqiov`. This is the value in upstream `dev-env/constants.ts`, and both native apps use it.
2. Seed the test data: `curl -X POST "http://localhost:1986/?users&follows&posts&feeds&thread"`.
3. Build the React Native e2e app: `pnpm e2e:build` (iOS) or `pnpm e2e:build-android` (Android). Start Metro with `pnpm e2e:start`.
4. On Android, forward the ports: `adb reverse tcp:3000 tcp:3000` and `adb reverse tcp:8081 tcp:8081`.
5. Capture the React Native baseline. Run the command from `parity/`, because Maestro resolves screenshot paths against the working directory:

   ```sh
   cd parity
   maestro --device <device-id> test -e PLATFORM=ios flows/capture-baseline.yml
   ```

## Build the native apps

See `ios/README.md` and `android/README.md`.
