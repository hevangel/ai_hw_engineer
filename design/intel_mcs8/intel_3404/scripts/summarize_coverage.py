"""Summarize Xezim coverage JSON from stdin, preserving raw data upstream."""
import json
import sys

if len(sys.argv) > 2:
    print("usage: summarize_coverage.py [display-label] < coverage.json", file=sys.stderr)
    sys.exit(2)
label = sys.argv[1] if len(sys.argv) == 2 else "<stdin>"
data = json.load(sys.stdin)
coverage = data["code_coverage"]
print("Coverage database:", label)
for kind in ("statement", "branch", "toggle"):
    metric = coverage[kind]
    print(f"{kind}: {metric['covered']}/{metric['total']} ({metric['percent']:.2f}%)")
for scope in coverage["scopes"]:
    print("Scope:", scope["scope"])
    missing = [entry["line"] for entry in scope.get("statements", []) if entry["count"] == 0]
    print("Uncovered statement lines:", missing)
