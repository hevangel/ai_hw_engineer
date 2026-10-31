# Incoming task execution through a non-null LDT

**Date:** 2026-10-27 12:50 UTC  
**Issue:** [hevangel/ai_hw_engineer#80](https://github.com/hevangel/ai_hw_engineer/issues/80)  
**Branch/worktree:** `design/intel-80286` in `B:\ai_hw_engineer\worktree\intel-80286`

Issue progress comment: [#6442330360](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6442330360).

## Result

Incoming task entry now stages the validated LDTR base, limit and valid bit
without publishing them early. While task validation is active, both the CS
code-load path and SS/DS/ES segment-load path use that staged cache. Successful
task entry publishes the LDTR cache with the validated segment caches at
`TASK_ENTRY_COMMIT`. A null incoming LDTR clears the staged cache, preserving
the existing null-selector behavior.

The regression installs a present GDT LDT descriptor at selector `0078`,
pointing to an LDT at `7000` with limit `0027`. The incoming task loads CS
`000C`, SS `0014`, DS `001C` and ES `0024` from LDT entries 1–4. Its program
executes `SLDT AX; MOV BX,DS; MOV CX,ES; HLT`. The test checks the visible
selectors, all four cache bases, the eight-byte read order for each descriptor,
the four accessed-byte writes, sequential code-byte fetches at
`0030:0300–0307`, the exact HLT successor, and task backlink/busy state. Both
immediate and stalled READY cases pass.

## Verification

Commands ran in the mirrored container from `/workspace/design/intel_80286/`
with Verilator 5.052:

```sh
verilator --lint-only -Wall --top-module intel_80286 src/*.sv
verilator --cc --exe --build -j 2 -Wall --top-module intel_80286 \
  --Mdir work/task_gate_nonnull_ldt_20261027_01 src/*.sv tb/bootstrap.cpp
work/task_gate_nonnull_ldt_20261027_01/Vintel_80286 --iopl-controls
work/task_gate_nonnull_ldt_20261027_01/Vintel_80286
python3 scripts/preflight.py
```

Strict lint, preflight, the focused `--iopl-controls` suite and the full default
bootstrap pass. The focused run also retains the eight null-selector task-gate
cases, 10 incoming LDTR fault cases, 42 incoming CS/SS/DS/ES fault and priority
cases, 14 task-return fault cases and 480 protected privilege scenarios. Logs
are in `work/task_gate_nonnull_ldt_20261027_01/`.

| Artifact | SHA-256 / result |
| --- | --- |
| `src/intel_80286.sv` | `37524595378713bb32b55ca62ac850d593ffe33f25ef23c10842a57d787e7135` |
| `tb/bootstrap.cpp` | `088ecc35e5572cda57b819ab8ce086d3bc15a3c7ce007a367d5dd19c142b0c4d` |
| Fresh runner | `84127b940d9c9c1e5cd849e00f062b897b197dde593376be9f8b23842101db34` |
| Strict lint | PASS, Verilator 5.052 `-Wall` |
| Focused `--iopl-controls` | PASS |
| Full default bootstrap | PASS |
| Release preflight | PASS |

No connected-core formal run covers this source snapshot. The older `_21`
cover/PDR jobs remain on earlier snapshots; no overlapping connected-core
formal job was started.

## Remaining work

Broader nested task-gate fault escalation, task-switch reset cuts and
current-source connected-core properties remain open, along with shutdown and
full-chip acceptance. Keep the existing incoming-LDTR and segment-fault
priority matrices separate from any untested escalation path.
