#!/usr/bin/env python3
"""Clean manufacturer fields that hold imported citation or family text."""
import json
import re
import sys
from pathlib import Path

TTL = Path(sys.argv[1]).resolve() / "design" / "ttl_74xx"

# part -> (label, provenance_gap or "")
FIX = {
    "74x16863": ("SN74ABT16863", ""),
    "74x162823": ("SN74ABT162823A", ""),
    "74x162827": ("SN74ABT162827A", ""),
    "74x162825": ("TI ABT data book SCYD013B, p. 782", ""),
    "74x25642": ("TI ABT data book SCYD013B, p. 715", ""),
    "74416": ("TTL Cookbook (Don Lancaster, 1974)",
              "The linked source is a third-party compilation, not a manufacturer "
              "datasheet; no device-level manufacturer document was located."),
    "74x742": ("TTL Pocket Reference, Part 3",
               "The linked source is a third-party compilation, not a manufacturer "
               "datasheet; no device-level manufacturer document was located."),
}

ANCHOR = {"datasheet_url": "datasheet", "provenance_gap": "datasheet_url"}


def rebuild(entry, updates):
    out = dict(entry)
    for key, value in updates.items():
        if key in out:
            out[key] = value
            continue
        rebuilt = {}
        for k, v in out.items():
            rebuilt[k] = v
            if k == ANCHOR[key]:
                rebuilt[key] = value
        out = rebuilt
    return out


def spec_line(label, url):
    if url:
        return f"**Manufacturer reference:** [{label}]({url})."
    return (f"**Manufacturer reference:** {label} — no accessible manufacturer "
            f"document located; see the provenance gap note.")


entries = json.loads((TTL / "manifest.json").read_text(encoding="utf-8"))
pattern = re.compile(r"^\*\*Manufacturer (?:reference|source):\*\*.*$", re.M)
done = []
for index, entry in enumerate(entries):
    part = entry["part_number"]
    if part not in FIX:
        continue
    label, gap = FIX[part]
    updates = {"datasheet": label}
    if gap:
        updates["provenance_gap"] = gap
    entries[index] = rebuild(entry, updates)
    spec = TTL / entry["specification"]
    text = spec.read_text(encoding="utf-8")
    new_text, count = pattern.subn(spec_line(label, entry.get("datasheet_url") or ""),
                                   text, count=1)
    if count != 1:
        raise SystemExit(f"{part}: expected one manufacturer line, replaced {count}")
    spec.write_text(new_text, encoding="utf-8", newline="\n")
    done.append(part)

(TTL / "manifest.json").write_text(
    json.dumps(entries, indent=2, sort_keys=False) + "\n", encoding="utf-8", newline="\n")
print(f"cleaned {len(done)} parts: {', '.join(done)}")
