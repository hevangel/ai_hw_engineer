import json
import sys

d = json.load(sys.stdin)
for f in d["fields"]:
    opts = f.get("options") or []
    names = [o["name"] for o in opts]
    print(f"{f['name']:18} id={f['id']:30} type={f['type']:12} opts={names[:14]}")
