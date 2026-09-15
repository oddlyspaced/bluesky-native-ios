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
  the Metro log only at debug level for the `metric` context. The upstream `.env` sets
  `EXPO_PUBLIC_LOG_DEBUG=session`, which hides them (`src/logger/index.tsx:43-45,115-121`).
  Showing them needs an `.env` change and a Metro restart with `-c`.
- The Metro inspector WebSocket (`ws://localhost:8081/inspector/debug`) closed with code 1006
  right after it opened, from both Node's built-in `WebSocket` and the `ws` package, so the JS
  runtime could not be read.

## Normalisation

`normalize_events.py` prepares the native log for the comparison:

- It drops `state:foreground` and `state:background`. RN registers its AppState listener after
  the JS bundle loads, so whether it sees the launch activation depends on timing and cannot be
  derived from source.
- It replaces DIDs inside `feedDescriptor` with `<did>`, because every seed creates new DIDs.

The diff then ignores `uri`, `authorDid` (new per seed), `initMs` and `secondsActive` (timing).

```
python3 normalize_events.py ../out/base/native/events.jsonl > ../out/base/native/events.normalized.jsonl
node <pack>/skills/check-parity/scripts/events.mjs --rn rn-expected-base.jsonl \
  --native ../out/base/native/events.normalized.jsonl --ignore uri,authorDid,initMs,secondsActive
```
