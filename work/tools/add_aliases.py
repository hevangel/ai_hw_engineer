import json
from pathlib import Path

p = Path("system/apple_ii/board/timing.json")
d = json.loads(p.read_text())
d["parts"]["8T97-AppleII"] = {"same_as": "8T97"}
d["parts"]["8T28-AppleII"] = {"same_as": "8T28"}
p.write_text(json.dumps(d, indent=2) + "\n")
print("ok")
