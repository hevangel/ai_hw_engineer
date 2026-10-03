"""Summarize Xezim coverage, preserving raw data for inspection."""
import json
import sys

with open(sys.argv[1], encoding="utf-8") as stream:
    data = json.load(stream)
coverage = data["code_coverage"]
print("Coverage database:", sys.argv[1])
for kind in ("statement", "branch", "toggle"):
    metric = coverage[kind]
    print(f"{kind}: {metric['covered']}/{metric['total']} ({metric['percent']:.2f}%)")
for scope in coverage["scopes"]:
    print("Scope:", scope["scope"])
    missing = [entry["line"] for entry in scope.get("statements", []) if entry["count"] == 0]
    print("Uncovered statement lines:", missing)
