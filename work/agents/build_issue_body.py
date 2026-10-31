#!/usr/bin/env python3
"""Build the upstream issue body, inserting the testcase verbatim."""
from pathlib import Path

sv = Path("work/agents/xezim-repro/nonzero_formal_bitselect.sv").read_text(encoding="utf-8")

actual = """FAIL nonzero-p0-...110        p=0 a=111111111110 got=x expected=1
FAIL nonzero-p0-...111        p=0 a=111111111111 got=x expected=0
FAIL nonzero-p1-...100        p=1 a=111111111100 got=x expected=1
FAIL nonzero-p1-...101        p=1 a=111111111101 got=x expected=1
FAIL nonzero-p1-...110        p=1 a=111111111110 got=x expected=0
FAIL nonzero-p2-...000        p=2 a=111111111000 got=x expected=1
FAIL nonzero-p2-...100        p=2 a=111111111100 got=x expected=0
FAIL nonzero-p11-...000       p=11 a=100000000000 got=x expected=0
FAIL nonzero-p15-all-0        p=15 a=000000000000 got=x expected=0
FAIL nonzero-p15-one-1        p=15 a=000000000001 got=x expected=1
FAIL exhaustive               43 mismatches over 65536 vectors
RESULT: FAIL (11 failing checks)"""

expected = """PASS nonzero-p0-...110        p=0 a=111111111110 got=1
PASS nonzero-p0-...111        p=0 a=111111111111 got=0
PASS nonzero-p1-...100        p=1 a=111111111100 got=1
PASS nonzero-p1-...101        p=1 a=111111111101 got=1
PASS nonzero-p1-...110        p=1 a=111111111110 got=0
PASS nonzero-p2-...000        p=2 a=111111111000 got=1
PASS nonzero-p2-...100        p=2 a=111111111100 got=0
PASS nonzero-p11-...000       p=11 a=100000000000 got=0
PASS nonzero-p15-all-0        p=15 a=000000000000 got=0
PASS nonzero-p15-one-1        p=15 a=000000000001 got=1
PASS exhaustive               0 mismatches over 65536 vectors
RESULT: PASS"""

body = f"""## Summary

A function whose formal has a packed range that does not start at zero returns `x` when it bit-selects that formal with a loop variable. The function body is legal SystemVerilog and every index is inside the declared range.

`ref_direct` below reads `a[i]` from `input logic [12:1] a`. `ref_mask` is the same predicate written with masks over a `[11:0]` formal. They must agree on every input.

## Testcase

Save as `nonzero_formal_bitselect.sv`, then:

```
xezim --simulate --sv2017 -s nonzero_formal_bitselect nonzero_formal_bitselect.sv
```

```systemverilog
{sv}```

## Actual

```
{actual}
```

Every directed vector returns `x`, including ones where no bit is unknown and every index is in range.

## Expected

```
{expected}
```

Basis for the expected values: IEEE 1800-2017 §11.5.1 — a bit-select `a[i]` reads bit `i` of `a`, and the declared range `[12:1]` makes 1..12 the valid index set, so none of these selects is out of range. The two functions are the same predicate over the same 12 bits and agree arithmetically on all 131072 assignments, checked outside the simulator as well as here. The reference simulator (Verilator 5.052) reports `RESULT: PASS` on this exact file.

## Version

```
=== xezim 0.11.3 ===
git 058f2bba (2026-10-23T17:05:55-07:00)
```

Also reproduced on `main` at `0fca605f` (2026-10-29, 154 commits past the 0.11.3 tag): same 43 mismatches, so it is not already fixed there.

## Ruled out

Each of these still produces exactly 43 mismatches, so none is the trigger:

- `XEZIM_JIT=0` and `XEZIM_JIT=1` — not the Cranelift backend
- `XEZIM_NO_CACHE=1` — not the elaboration cache
- `--wave`, which the help text says forces loops onto the slower AST path
- with and without `--sv2017`

## What makes it go away

All three give 0 mismatches:

- copy the formal into a `logic [11:0]` local and index `b[i-1]`
- declare the formal `[11:0]` and index `bb[i-1]`
- use the mask form

## Scope and a caveat

The exhaustive cross-check fails on 43 of 65536 assignments, clustered at the `P`/`P+1` boundary: 32 return `x` and 11 return the wrong `0`/`1`.

One caveat that may matter for diagnosis: smaller standalone shapes sometimes pass. A bare `function automatic logic f(input logic [12:1] a); return a[1]; endfunction` passed in several contexts I tried, and adding a `$display` inside the callee made a failing case pass again. The testcase above is therefore kept as-is rather than shrunk further; the outcome appears to depend on how the call site is compiled.

No prior report: #413 and #352 cover bit-select and packed-local handling but not a formal's declared range.
"""

Path("work/agents/xezim-issue-body.md").write_text(body, encoding="utf-8")
print("body bytes:", len(body))
print("code block matches file:", sv in body)
