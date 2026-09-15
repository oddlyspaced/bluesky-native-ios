#!/usr/bin/env python3
"""Normalises a native events.jsonl for the static RN comparison (see README.md).

- Drops state:foreground and state:background (launch-timing dependent in RN).
- Replaces DIDs inside feedDescriptor with <did> (every seed creates new DIDs).
"""
import json
import re
import sys

DROP = {"state:foreground", "state:background"}
DID = re.compile(r"did:plc:[a-z0-9]+")

for line in open(sys.argv[1], encoding="utf-8"):
    line = line.strip()
    if not line:
        continue
    event = json.loads(line)
    if event["name"] in DROP:
        continue
    props = event.get("props", {})
    if isinstance(props.get("feedDescriptor"), str):
        props["feedDescriptor"] = DID.sub("<did>", props["feedDescriptor"])
    print(json.dumps({"name": event["name"], "props": props}, sort_keys=True))
