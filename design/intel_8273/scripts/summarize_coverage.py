"""Report measured RTL coverage without excluding untested paths."""
import json
import sys
from pathlib import Path

data = json.loads(Path(sys.argv[1]).read_text())["code_coverage"]
for name in ("statement", "branch", "toggle"):
    metric = data[name]
    print(f"{name}: {metric['covered']}/{metric['total']} ({metric['percent']:.2f}%)")
