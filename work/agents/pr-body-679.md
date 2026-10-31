## What changed

One file: `design/ttl_74xx/tb/tb_ttl_74x679.sv`. The exhaustive 74x679 testbench
replaces its per-bit accumulator loop in `ref_y` with two masked comparisons.
**The RTL is untouched** — the design already matches the documented rule.

## Why

Re-running the library on a freshly built pinned image (`ai-hw-engineer:latest`,
Verilator 5.052, Yosys 0.69, SBY 0.69, xezim 0.11.3) returned **3482/3483**
checks with one failure:

```
FAIL sim   ttl_74x679
Mismatch v=4094: g_n=0 p=0000 a=111111111110 -> got 1 exp x
Mismatch v=4095: g_n=0 p=0000 a=111111111111 -> got 0 exp x
...
** Fatal: tb_ttl_74x679: 43 mismatches
```

The committed evidence for this part was produced with an older xezim and did not
show this. Investigating rather than assuming an RTL bug:

- The RTL and a hand-derived oracle agree on the failing vectors. For `v=4095`
  (`P=0`, all `A` high) the documented rule gives `match=1`, so `Y=0`, which is
  exactly what the RTL drives.
- The same `ref_y` called in a short run returns the correct value; only the full
  131072-vector loop returns `x` or a stale expectation. So the *oracle* is
  unstable, not the design.

## Why the fix is not a weakened test

The replacement is the same rule — `A1..Ak` low, `A(k+1)..A12` high, `k = P` —
written as two masked compares instead of a per-bit loop. It is still exhaustive
over all 131072 vectors and still checks both enable polarities and every
`P = 0..15` alias.

Equivalence was checked independently of the simulator, over the entire input
space (`work`-only script, not committed):

```
vectors=131072  rule_vs_mask_mismatches=0
```

The old form did not verify anything on the 43 vectors where it returned `x`,
so no real check was removed.

## Verification on this branch

All run in `ai-hw-engineer:latest` with the repository mounted at `/workspace`.

| Check | Command | Result |
|---|---|---|
| Inventory | `run_library.py inventory` | 1161 models, 165 pending, 67 exclusions |
| Per-part lint/sim/synth | `run_library.py all` | **3483/3483 passed** |
| Family formal | `run_library_formal.py` | **16/16 PASS** |
| 74181 formal | `run_74181_formal.sh all` | passed, all tasks |
| 74181 lint | `run_74181_lint.sh` | passed |
| 74181 synth | `run_74181_synth.sh` | passed |
| 74181 sim (exhaustive + UVM) | `run_74181_sim.sh all` | passed, `UVM_ERROR : 0` |

Baseline before the change on the same image was 3482/3483, so this is the only
delta.

## Known limits

- Pre-existing and **not** addressed here: `verilator --lint-only -Wall --timing`
  on the testbench reports `TIMESCALEMOD` because `src/ttl_74x679.sv` has no
  `timescale` directive. The same warning appears on unmodified `main`; the
  library lint gate does not use `--timing`, so it is outside that gate.
- The generator `run_all.sh` still fails at its final
  `inventory --require-complete` step because 165 catalog parts remain pending.
  That is expected and unrelated.
- `report/library_report.md` was not regenerated in this PR to keep the diff
  reviewable; counts are unchanged by this fix.

## Second commit: toolchain provenance

The report published 3483/3483 without naming the tools that produced it, so the number could not be reproduced or compared across a tool change. `write_library_report.py` now stamps Verilator, Yosys, SBY, xezim and Python versions plus the repository revision into `report/library_report.md` and `report/extended_report.md`, and both artifacts are regenerated from the passing sweep on this branch.

New section produced:

```
## Toolchain used for these results

| Tool | Version |
|---|---|
| Verilator | Verilator 5.052 2026-09-05 rev v5.052 |
| Yosys | Yosys 0.69 (git sha1 9f75ca1f9, Release, GNU /usr/bin/g++ 15.2.0) |
| SBY | SBY v0.69 |
| xezim | 0.11.3 |
| Python | 3.14.4 |
```

The generator still exits 0 on this branch (`Report: 3483/3483 checks; 165 pending digital parts`). The version lookups are best-effort: a missing tool prints `unavailable` and a missing git checkout omits the revision row rather than failing the report.
