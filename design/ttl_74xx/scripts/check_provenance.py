#!/usr/bin/env python3
"""Fail when an implemented catalog entry has no traceable manufacturer source.

Every implemented part must either link a manufacturer document or carry an
explicit provenance_gap that says why no document was located. Two failure
modes this catches: a blank link left by an importer, and a datasheet field
that holds family or citation text instead of a device name.
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
entries = json.loads((ROOT / "manifest.json").read_text(encoding="utf-8"))

# Text that indicates an imported citation or a family name rather than a device.
SUSPECT = re.compile(r"(?i)(\|\s*title=|\|\s*trans-title=|\}\}|\bISBN\b|^\s*ABT\s*$)")
URL = re.compile(r"^https?://[^\s|]+$")

problems = []
for chip in entries:
    if chip["status"] != "implemented":
        continue
    part = chip["part_number"]
    label = (chip.get("datasheet") or "").strip()
    url = (chip.get("datasheet_url") or "").strip()
    gap = (chip.get("provenance_gap") or "").strip()
    if not label and not gap:
        problems.append(f"{part}: empty datasheet field with no provenance_gap")
    elif label and SUSPECT.search(label):
        problems.append(f"{part}: datasheet field holds citation or family text: {label[:60]!r}")
    if url:
        if not URL.match(url):
            problems.append(f"{part}: datasheet_url is not an http(s) URL: {url!r}")
    elif not gap:
        problems.append(f"{part}: no datasheet_url and no provenance_gap")

if problems:
    print(f"Provenance check failed for {len(problems)} entries:")
    for line in problems:
        print(f"  {line}")
    sys.exit(1)
print(f"Provenance OK: {sum(c['status'] == 'implemented' for c in entries)} implemented "
      f"entries each have a datasheet_url or a provenance_gap")
