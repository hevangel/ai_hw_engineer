"""Assemble board/timing.json from the two datasheet research results."""
import json
import math
from pathlib import Path

ls = json.loads(Path("work/timing/ls_logic.json").read_text())
mem = json.loads(Path("work/timing/memory_transceivers.json").read_text())

parts = {}
for name, entry in ls["parts"].items():
    parts[name] = {
        "typ_ns": entry["tpd_typ_ns"],
        "max_ns": entry["tpd_max_ns"],
        "parameter": entry["parameter"],
        "source": entry["source"],
        "document": entry["document"],
        "page": str(entry["page"]),
    }
    if entry.get("notes"):
        parts[name]["note"] = entry["notes"]

parts["8T28"] = {
    "typ_ns": None,
    "max_ns": 17,
    "parameter": "tpd",
    "source": "National Semiconductor Interface Databook 1979, p. 2-26",
    "document": "National Interface Databook 1979",
    "page": "2-26",
    "note": "No typical value published; the typical run uses the maximum.",
}
parts["8T97"] = {
    "typ_ns": 8,
    "max_ns": 13,
    "parameter": "tpd",
    "source": "Signetics 8T95-8T98 datasheet, p. 6-53",
    "document": "Signetics 8T95-8T98",
    "page": "6-53",
}
parts["8T28-AppleII"] = {"same_as": "8T28"}
parts["8T97-AppleII"] = {"same_as": "8T97"}

# Memory parts keep the ideal placeholder: the models do not implement row
# access, output hold or refresh, so a datasheet delay breaks the video latch
# for model reasons, not hardware reasons (review item P3).
parts["4116"] = {
    "typ_ns": 5,
    "max_ns": 5,
    "idealized": True,
    "parameter": "tRAC/tCAC",
    "source": "Mostek MK4116-2/-3 datasheet, p. IV-19",
    "document": "Mostek MK4116",
    "page": "IV-19",
    "note": "Idealized 5 ns placeholder. Published: tRAC max 200 ns (-3), "
            "tCAC 135 ns, tRAS 200/tCAS 135/tRCD 25 ns minimum. The revision-0 "
            "schematic names no speed grade; a 200 ns part is inferred from "
            "later Apple II boards. Needs a tRAC/tCAC/hold model (review P3).",
}
parts["ROM_Chip"] = {
    "typ_ns": 5,
    "max_ns": 5,
    "idealized": True,
    "parameter": "tACC",
    "source": "Signetics 2616 (9316A/B equivalent) datasheet, p. 251",
    "document": "Signetics 2616",
    "page": "251",
    "note": "Idealized 5 ns placeholder. Published tACC 450 ns max, "
            "tCE 200 ns, tDESEL 200 ns.",
}
parts["2513"] = {
    "typ_ns": 5,
    "max_ns": 5,
    "idealized": True,
    "parameter": "tCA/tRA",
    "source": "Signetics 1977 Memory manual, p. 259",
    "document": "Signetics 1977 Memory",
    "page": "259",
    "note": "Idealized 5 ns placeholder. Published tCA 500/600 ns, "
            "tRA 450/500 ns, tCE 150 ns.",
}

document = {
    "schema": 2,
    "units": "ns",
    "conditions": "VCC=5V, CL=15pF, TA=25C, from the manufacturer switching table",
    "rounding": "generate_rev0.py rounds up to the integer T_PD the models accept",
    "typ_fallback": "parts without a published typical value use the maximum",
    "parts": dict(sorted(parts.items())),
}
Path("system/apple_ii/board/timing.json").write_text(json.dumps(document, indent=2) + "\n")
print("wrote", len(parts), "entries")
print("missing typ:", [k for k, v in parts.items() if v.get("typ_ns") is None and "same_as" not in v])
print("fractional:", [k for k, v in parts.items() if isinstance(v.get("typ_ns"), float) or isinstance(v.get("max_ns"), float)])
