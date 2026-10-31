import json
import sys

d = json.load(sys.stdin)
for f in d["fields"]:
    if f["name"] in ("Agent", "Status"):
        print(f["name"], f["id"])
        for o in f.get("options") or []:
            print("   ", o["name"], o["id"])
