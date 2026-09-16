# Event logs

The native app writes every analytics event to `Documents/events.jsonl` (one
`{"name", "props"}` object per line). This is the format of
`check-parity/scripts/events.mjs`.

## RN log: derived from source, not captured

`rn-expected-base.jsonl` is the RN event sequence for `flows/capture.yml` (base state). It is
**not a capture**. It was written by hand from the RN source at `2bfb94d`, with a file and line
for each event in `ios/PARITY.md`, "Event diff".

The RN events could not be captured without changing upstream:

- The e2e build tracks events and POSTs them to `https://events.bsky.app/t`. It prints them to
  the Metro log only at debug level for the `metric` context (`Logger.Context.Metric`,
  `src/analytics/metrics/client.ts:15,67`). The upstream `.env` sets
  `EXPO_PUBLIC_LOG_DEBUG=session`, which hides them (`src/logger/index.tsx:43-45,115-121`).
  Showing them needs an `.env` change and a Metro restart with `-c`.
- The Metro inspector WebSocket (`ws://localhost:8081/inspector/debug`) closed with code 1006
  right after it opened, from both Node's built-in `WebSocket` and the `ws` package, so the JS
  runtime could not be read.

### Second attempt: a throwaway checkout on its own Metro (review finding F8)

The upstream checkout was copied outside the repository (`cp -Rc`, no change to upstream). In the
copy, `.env` set `EXPO_PUBLIC_LOG_DEBUG=metric`, and its own Metro ran on port 8082 with the e2e
environment (`EXPO_PUBLIC_ENV=e2e NODE_ENV=development RN_SRC_EXT=e2e.ts,e2e.tsx expo start -c
--port 8082`, with `TMPDIR` set to a scratch directory so the running 8081 Metro kept its cache).
The iOS bundle built there (6504 modules).

The installed e2e app is an Expo dev client (`EXDevLauncher.bundle`, scheme `exp+bluesky`), so the
capture flow opened `exp+bluesky://expo-development-client/?url=http%3A%2F%2Flocalhost%3A8082`
after a clean launch. **The app did not switch:** the 8082 Metro log recorded no bundle request
during the run, and the flow then failed. The simulator kept only connections to 8081. Moving the
app to the other Metro needs the dev menu by hand, or an e2e app rebuilt against port 8082, which
is a native rebuild. The attempt stopped there, inside its time box.

The RN list therefore stays derived from source. `ios/PARITY.md` lists the entries whose **order**
is not observed at runtime, for owner acceptance.

## Normalisation

`normalize_events.py` prepares the native log for the comparison. It **drops no event** (review
finding N24):

- `authorDid` and the DIDs inside `feedDescriptor` become handles
  (`com.atproto.repo.describeRepo`).
- A post `uri` becomes `<handle>|<post text>` (`com.atproto.repo.getRecord`), so the diff checks
  that each event names the right post instead of ignoring the URI.

It reads the local PDS, so run it right after the capture, while that seed is still live.
`run-capture.sh` does this for every native run. The diff then ignores only `initMs` and
`secondsActive`, which are timing values.

```
python3 normalize_events.py ../out/base/native/ios/events.jsonl > ../out/base/native/ios/events.normalized.jsonl
node <pack>/skills/check-parity/scripts/events.mjs --rn rn-expected-base.jsonl \
  --native ../out/base/native/ios/events.normalized.jsonl --ignore initMs,secondsActive --ordered
```
