## Baseline re-verified on the current pinned image — 2026-10-28

Re-ran the committed library verification in a freshly built `ai-hw-engineer:latest`
rather than trusting the 2026-10-23 report. **No tests were inherited; every number
below is from a fresh run** with the repository mounted at `/workspace`.

Toolchain actually used (the committed report names Verilator 5.050 / Yosys 0.46 /
SBY `b1a1e98c`; the current image is newer):

```
Verilator 5.052 2026-09-05 rev v5.052
Yosys 0.69 (git sha1 9f75ca1f9)
SBY v0.69
xezim 0.11.3, git 058f2bba
```

### Result

| Run | Result |
|---|---|
| `run_library.py inventory` | 1161 models, 165 pending digital parts, 67 analog exclusions |
| `run_library.py all` (lint + sim + synth) — **before** any change | **3482/3483** |
| `run_library.py all` — **after** the fix below | **3483/3483** |
| `run_library_formal.py` | 16/16 PASS |
| `run_74181_formal.sh all` | passed, all tasks |
| `run_74181_lint.sh` | passed |
| `run_74181_synth.sh` | passed |
| `run_74181_sim.sh all` (exhaustive + UVM) | passed, `UVM_ERROR : 0` |

### The one failure, and what it actually was

`ttl_74x679` simulation: 43 mismatches out of 131072 vectors, all returning `x` or a
stale expectation from the testbench's reference model.

It was **not** an RTL defect. The RTL matches the documented rule (`A1..Ak` low,
`A(k+1)..A12` high, `k = P`) on every failing vector, and a mask-form oracle proved
equivalent to the documented per-bit rule on all 131072 vectors, independently of the
simulator:

```
vectors=131072  rule_vs_mask_mismatches=0
```

The per-bit accumulator loop returned `x` only inside the long run — the same input
evaluated in a short run gave the correct value. The oracle, not the design, was
unstable under xezim 0.11.3.

Fix: [PR #91](https://github.com/hevangel/ai_hw_engineer/pull/91) — rewrites the
oracle as two masked compares, RTL untouched, still exhaustive over the full input
space. The old form verified nothing on the 43 vectors where it returned `x`, so no
check was weakened.

### Findings that affect this issue's acceptance

1. **The 25 native member sub-issues have no implementation behind them.** Their
   profile links point at `design/ttl_74_series/ttl_74lsNN` on
   `codex/chip-family-roadmap`. On that branch **24 of the 25 folders contain exactly
   one file, `README.md`**; only `alu_74181` has a real design (20 files). `main`
   superseded that layout with the consolidated `design/ttl_74xx/` library, which is
   where all 1161 implemented functions actually live. The sub-issues are tracking an
   abandoned structure, not unfinished RTL.
2. **The 165 pending parts are source-blocked, not neglected.** They cluster into DRAM
   controllers, EDAC, JTAG/boundary-scan, NuBus, cache comparators, FPUs and clock
   synthesizers, and the recorded reasons are dominated by "datasheet not accessible"
   and "reference omits the advertised function". This is per-part research work, not
   a tooling gap.
3. **`report/library_report.md` records no tool versions.** The 3483/3483 claim cannot
   be reproduced without knowing which image produced it — which is exactly how the
   74x679 oracle drift went unnoticed between xezim 0.10.3 and 0.11.3. Proposed
   follow-up: have `write_library_report.py` stamp Verilator/Yosys/SBY/xezim versions
   and the image digest into the report.
4. **Provenance is incomplete for 24 implemented parts.** `manifest.json` does not
   require `datasheet_url`, and 24 implemented entries lack one. Five have a corrupted
   `datasheet` field that leaked Wikipedia `<ref>` text (`74116`, `74119`, `74418`,
   `74x515`, `74x743`); another 19 ABT widebus parts record the field as just `ABT`.
   This is mechanically checkable and blocks the "source-backed specification for
   every member" acceptance item.

### Deliberately not attempted here

- The 165 pending parts. Each needs a primary-source study, and starting them before
  the baseline existed would only have added unverified code.
- Regenerating `report/library_report.md`. The counts are unchanged by the fix, and a
  148 KB generated diff would obscure the review.

### Field update note

Status `Building`, Path `ai_hw_engineer/design/ttl_74xx`, Start `2026-08-25` and
Workstream `Chips` were already correct and were left untouched. **Agent was left
empty:** the live field offers `Codex, Claude, GLM, Muse, Kiro, Copilot, OpenCode,
KiloCode, Cursor, Antigravity`, none of which identifies the agent that ran this work,
and I will not guess an identity. Owner to select the correct option.
