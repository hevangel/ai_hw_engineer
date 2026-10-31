import json
import sys

d = json.load(sys.stdin)
items = d.get("items", d)
for i in items:
    c = i.get("content", {}) or {}
    if str(c.get("number")) != "4":
        continue
    for k in ("id", "title", "status", "path", "start date", "workstream",
              "agent", "sprint", "repository"):
        print(f"{k:12}: {i.get(k)!r}")
    break
