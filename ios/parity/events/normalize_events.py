#!/usr/bin/env python3
"""Normalises a native events.jsonl for the comparison with the RN list (see README.md).

Run it right after the capture, while the seed that created the posts is still live: it reads
the local PDS (http://localhost:3000) without authentication.

- `authorDid` and DIDs inside `feedDescriptor` become handles (`com.atproto.repo.describeRepo`).
- A post `uri` becomes `<handle>|<post text>` (`com.atproto.repo.getRecord`), so the diff checks
  that each event names the right post instead of ignoring the URI (review finding N24).
- No event is dropped. `initMs` and `secondsActive` are timing values; events.mjs ignores them.

Exit 1 when a DID or a post cannot be resolved.
"""
import json
import re
import sys
import urllib.parse
import urllib.request

PDS = "http://localhost:3000/xrpc/"
DID = re.compile(r"did:plc:[a-z0-9]+")
POST = re.compile(r"^at://(did:plc:[a-z0-9]+)/app\.bsky\.feed\.post/([A-Za-z0-9]+)$")

handles = {}
texts = {}


def get(method, **params):
    url = PDS + method + "?" + urllib.parse.urlencode(params)
    with urllib.request.urlopen(url, timeout=10) as response:
        return json.load(response)


def handle(did):
    if did not in handles:
        handles[did] = get("com.atproto.repo.describeRepo", repo=did)["handle"]
    return handles[did]


def post(uri):
    match = POST.match(uri)
    if not match:
        return uri
    if uri not in texts:
        did, rkey = match.groups()
        record = get("com.atproto.repo.getRecord", repo=did, collection="app.bsky.feed.post", rkey=rkey)
        texts[uri] = f"{handle(did)}|{record['value'].get('text', '')}"
    return texts[uri]


def main():
    for line in open(sys.argv[1], encoding="utf-8"):
        line = line.strip()
        if not line:
            continue
        event = json.loads(line)
        props = event.get("props", {})
        if isinstance(props.get("authorDid"), str):
            props["authorDid"] = handle(props["authorDid"])
        if isinstance(props.get("uri"), str):
            props["uri"] = post(props["uri"])
        if isinstance(props.get("feedDescriptor"), str):
            props["feedDescriptor"] = DID.sub(lambda m: handle(m.group(0)), props["feedDescriptor"])
        print(json.dumps({"name": event["name"], "props": props}, sort_keys=True))


if __name__ == "__main__":
    try:
        main()
    except Exception as error:  # noqa: BLE001 - report any lookup failure and stop
        print(f"normalize_events: {error}", file=sys.stderr)
        sys.exit(1)
