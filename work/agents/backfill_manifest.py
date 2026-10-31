#!/usr/bin/env python3
"""Backfill manufacturer source data for the 24 implemented parts that lack it.

16 ABT devices resolve to a real TI datasheet, each verified with an HTTP HEAD
returning 200 application/pdf from https://www.ti.com/lit/gpn/<device>.
The remaining 8 have no accessible manufacturer document; they get the correct
device name where a secondary list identifies one, plus an explicit
provenance_gap note so the absence is recorded rather than hidden.
"""
import json
import re
import sys
from pathlib import Path

REPO = Path(sys.argv[1]).resolve()
TTL = REPO / "design" / "ttl_74xx"

# part -> (device label, TI literature key)
TI = {
    "74x16240": ("SN74ABT16240A", "sn74abt16240a"),
    "74x16244": ("SN74ABT16244A", "sn74abt16244a"),
    "74x16245": ("SN74ABT16245A", "sn74abt16245a"),
    "74x16373": ("SN74ABT16373A", "sn74abt16373a"),
    "74x16374": ("SN74ABT16374A", "sn74abt16374a"),
    "74x16540": ("SN74ABT16540A", "sn74abt16540a"),
    "74x16541": ("SN74ABT16541A", "sn74abt16541a"),
    "74x16543": ("SN74ABT16543", "sn74abt16543"),
    "74x16623": ("SN74ABT16623", "sn74abt16623"),
    "74x16640": ("SN74ABT16640", "sn74abt16640"),
    "74x16821": ("SN74ABT16821", "sn74abt16821"),
    "74x16823": ("SN74ABT16823", "sn74abt16823"),
    "74x16825": ("SN74ABT16825", "sn74abt16825"),
    "74x16827": ("SN74ABT16827", "sn74abt16827"),
    "74x16841": ("SN74ABT16841", "sn74abt16841"),
    "74x16843": ("SN74ABT16843", "sn74abt16843"),
}

# part -> (device label or "", gap note)
GAP = {
    "74116": ("SN74116",
              "Device name taken from the Wikipedia 7400-series list; no TI literature "
              "entry (sn74116, sn54ls116) returns a document and no archived databook page "
              "could be pinned, so no manufacturer URL is claimed."),
    "74119": ("TL74119N",
              "Device name taken from the Wikipedia 7400-series list; no TI literature "
              "entry returns a document and no archived databook page could be pinned, so "
              "no manufacturer URL is claimed."),
    "74418": ("MC74418",
              "Device name taken from the Wikipedia 7400-series list; the cited part is a "
              "Motorola device, and no accessible Motorola document or pinned archived page "
              "was located, so no manufacturer URL is claimed."),
    "74x515": ("74HCT515",
               "Device name taken from the Wikipedia 7400-series list; no TI or NXP "
               "literature entry returns a document, so no manufacturer URL is claimed."),
    "74x743": ("SN74ALS743",
               "Device name taken from the Wikipedia 7400-series list; no TI literature "
               "entry (sn74als743, sn74ls743) returns a document, so no manufacturer URL "
               "is claimed."),
    "74x16377": ("",
                 "The catalog source lists only the ABT family for this part, with no "
                 "example device. No TI literature entry (sn74abt16377, sn74abt16377a) "
                 "returns a document, so the exact device and its datasheet are unidentified."),
    "74x16826": ("",
                 "The catalog source lists only the ABT family for this part, with no "
                 "example device. No TI literature entry (sn74abt16826, sn74abt16826a) "
                 "returns a document, so the exact device and its datasheet are unidentified."),
    "74x16828": ("",
                 "The catalog source lists only the ABT family for this part, with no "
                 "example device. No TI literature entry (sn74abt16828, sn74abt16828a) "
                 "returns a document, so the exact device and its datasheet are unidentified."),
}

ANCHOR = {"datasheet_url": "datasheet", "provenance_gap": "datasheet_url"}


def rebuild(entry, updates):
    """Apply updates while keeping field order; new keys follow their anchor."""
    out = dict(entry)
    for key, value in updates.items():
        if key in out:
            out[key] = value
            continue
        anchor = ANCHOR[key]
        rebuilt = {}
        for k, v in out.items():
            rebuilt[k] = v
            if k == anchor:
                rebuilt[key] = value
        out = rebuilt
    return out


def spec_line(label, url):
    if url:
        return f"**Manufacturer reference:** [{label}]({url})."
    if label:
        return (f"**Manufacturer reference:** {label} — no accessible manufacturer "
                f"document located; see the provenance gap note.")
    return ("**Manufacturer reference:** not identified — no accessible manufacturer "
            "document located; see the provenance gap note.")


entries = json.loads((TTL / "manifest.json").read_text(encoding="utf-8"))
pattern = re.compile(r"^\*\*Manufacturer (?:reference|source):\*\*.*$", re.M)
done = []
for index, entry in enumerate(entries):
    part = entry["part_number"]
    if part in TI:
        label, key = TI[part]
        url = f"https://www.ti.com/lit/gpn/{key}"
        entries[index] = rebuild(entry, {"datasheet": label, "datasheet_url": url})
    elif part in GAP:
        label, note = GAP[part]
        url = ""
        entries[index] = rebuild(entry, {"datasheet": label,
                                         "datasheet_url": "",
                                         "provenance_gap": note})
    else:
        continue
    spec = TTL / entry["specification"]
    text = spec.read_text(encoding="utf-8")
    new_text, count = pattern.subn(spec_line(label, url), text, count=1)
    if count != 1:
        raise SystemExit(f"{part}: expected one manufacturer line, replaced {count}")
    spec.write_text(new_text, encoding="utf-8", newline="\n")
    done.append(part)

(TTL / "manifest.json").write_text(
    json.dumps(entries, indent=2, sort_keys=False) + "\n", encoding="utf-8", newline="\n")
print(f"updated {len(done)} parts: {', '.join(done)}")
