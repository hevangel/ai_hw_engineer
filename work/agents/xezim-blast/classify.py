#!/usr/bin/env python3
"""Classify the oracle style of every testbench in design/ttl_74xx/tb/*.sv.

Categories (as requested by the xezim blast-radius brief):
  (a) a function containing a `for` loop AND a variable bit-select (x[i])
  (b) a function containing any `for` loop
  (c) an accumulator (`m &= ...` or `acc = acc & ...`) inside such a loop
  (d) an `if`/`else` inside such a loop

Also censuses the comparison operators used in checks (`!==` strict vs
`==` / `!=` 4-state-tolerant), and flags PASS markers that are not guarded by
an error count or a preceding $fatal.

Usage:
    python3 classify.py --root design/ttl_74xx/tb \
        --out work/agents/xezim-blast/inventory.generated.json

Exit code 0 on success. Pure stdlib; no dependencies.
"""

import argparse
import json
import re
from pathlib import Path

# ---------------------------------------------------------------- lexing aid
TOKEN_RE = re.compile(r'//[^\n]*|/\*.*?\*/|"(?:\\.|[^"\\])*"', re.S)


def blank_noise(text: str) -> str:
    """Blank comments and string literals, preserving newlines and length."""
    def repl(m):
        s = m.group(0)
        return "".join("\n" if ch == "\n" else " " for ch in s)
    return TOKEN_RE.sub(repl, text)


FUNC_RE = re.compile(r'\bfunction\b(.*?)\bendfunction\b', re.S)
FOR_RE = re.compile(r'\bfor\s*\(([^;]*);([^;]*);([^)]*)\)')
INDEX_RE = re.compile(r'\b([A-Za-z_]\w*)\s*\[\s*([A-Za-z_]\w*)\s*\]')
ACC_RE = re.compile(r'(?:&=|\|=|\^=|\b(\w+)\s*=\s*\1\s*[&|^])')
CHECK_RE = re.compile(r'\bif\s*\([^)]*\)')


def loop_var(init: str):
    m = re.search(r'\b([A-Za-z_]\w*)\s*=', init)
    return m.group(1) if m else None


def loop_body(text: str, start: int) -> str:
    """Body of a for loop whose header ends at `start`."""
    i = start
    n = len(text)
    while i < n and text[i] in " \t\r\n":
        i += 1
    if text.startswith("begin", i):
        depth = 0
        j = i
        for m in re.finditer(r'\b(begin|end)\b', text[i:]):
            depth += 1 if m.group(1) == "begin" else -1
            if depth == 0:
                j = i + m.end()
                break
        return text[i:j]
    semi = text.find(";", i)
    return text[i:semi + 1 if semi >= 0 else n]


def classify_file(path: Path) -> dict:
    raw = path.read_text(errors="replace")
    src = blank_noise(raw)
    rec = {
        "file": path.name,
        "has_function": False,
        "functions": [],
        "category_a": False,
        "category_b": False,
        "category_c": False,
        "category_d": False,
        "comparisons": {"!==": 0, "==": 0, "!=": 0},
        "pass_marker": None,
        "pass_guarded_by_error_count": False,
        "pass_fatal_before": False,
    }

    # ---- functions
    for fm in FUNC_RE.finditer(src):
        body = fm.group(1)
        head = body.split("\n")[0]
        name_m = re.search(r'([A-Za-z_]\w*)\s*\(', head)
        name = name_m.group(1) if name_m else "<anonymous>"
        rec["has_function"] = True
        frec = {"name": name, "has_for": False, "var_bitselect": False,
                "accumulator": False, "if_else": False}
        for lm in FOR_RE.finditer(body):
            frec["has_for"] = True
            var = loop_var(lm.group(1))
            inner = loop_body(body, lm.end())
            for im in INDEX_RE.finditer(inner):
                if var and im.group(2) == var:
                    frec["var_bitselect"] = True
            if ACC_RE.search(inner):
                frec["accumulator"] = True
            if re.search(r'\bif\b', inner) and re.search(r'\belse\b', inner):
                frec["if_else"] = True
        if frec["has_for"]:
            rec["category_b"] = True
            if frec["var_bitselect"]:
                rec["category_a"] = True
            if frec["accumulator"]:
                rec["category_c"] = True
            if frec["if_else"]:
                rec["category_d"] = True
        rec["functions"].append(frec)

    # ---- comparisons (whole file, noise removed)
    rec["comparisons"]["!=="] = len(re.findall(r'!==', src))
    rec["comparisons"]["=="] = len(re.findall(r'(?<![!<>=])==(?!=)', src))
    rec["comparisons"]["!="] = len(re.findall(r'(?<!!)!=(?!=)', src))

    # ---- x-tolerant check idiom: if (...) == / !=  followed by errors++/$fatal
    lines = src.split("\n")
    tolerant = []
    for idx, line in enumerate(lines):
        if re.search(r'\bif\s*\(', line) and re.search(r'(?<!!)!=(?!=)|(?<![!<>=])==(?!=)', line):
            tail = " ".join(lines[idx:idx + 3])
            if "errors++" in tail or "$fatal" in tail:
                tolerant.append(line.strip()[:120])
    rec["x_tolerant_checks"] = tolerant

    # ---- PASS marker discipline (must use raw text: the marker is a string)
    raw_lines = raw.split("\n")
    pass_idx = None
    for idx, line in enumerate(raw_lines):
        if "PASS" in line and "$display" in line:
            pass_idx = idx
            rec["pass_marker"] = line.strip()[:160]
            break
    if pass_idx is not None:
        before = "\n".join(raw_lines[max(0, pass_idx - 8):pass_idx])
        rec["pass_guarded_by_error_count"] = bool(
            re.search(r'\bif\s*\(\s*errors\s*!=\s*0\s*\)', before))
        rec["pass_fatal_before"] = "$fatal" in "\n".join(raw_lines[:pass_idx])
        rec["pass_unconditional_candidate"] = not (
            rec["pass_guarded_by_error_count"] or rec["pass_fatal_before"])
    else:
        rec["pass_unconditional_candidate"] = False

    return rec


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", default="design/ttl_74xx/tb")
    ap.add_argument("--out", default="work/agents/xezim-blast/inventory.generated.json")
    args = ap.parse_args()

    files = sorted(Path(args.root).glob("*.sv"))
    records = [classify_file(p) for p in files]

    def names(flag):
        return [r["file"] for r in records if r[flag]]

    summary = {
        "total_files": len(records),
        "category_a": names("category_a"),
        "category_b": names("category_b"),
        "category_c": names("category_c"),
        "category_d": names("category_d"),
        "with_function": names("has_function"),
        "strict_case_inequality_files": [r["file"] for r in records
                                         if r["comparisons"]["!=="] > 0],
        "x_tolerant_check_files": [r["file"] for r in records if r["x_tolerant_checks"]],
        "pass_unconditional_candidates": names("pass_unconditional_candidate"),
    }

    out = {"summary": summary, "files": records}
    Path(args.out).parent.mkdir(parents=True, exist_ok=True)
    Path(args.out).write_text(json.dumps(out, indent=2))
    print(json.dumps({k: (len(v) if isinstance(v, list) else v)
                      for k, v in summary.items()}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
