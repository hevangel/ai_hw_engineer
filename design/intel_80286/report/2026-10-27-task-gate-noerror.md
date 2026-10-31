# No-error task-gate entry and null selectors

**Date:** 2026-10-27 12:45 UTC  
**Issue:** [hevangel/ai_hw_engineer#80](https://github.com/hevangel/ai_hw_engineer/issues/80)  
**Branch/worktree:** `design/intel-80286` in `B:\ai_hw_engineer\worktree\intel-80286`

Issue progress comment: [#6442211666](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6442211666).

## Result

Fixed event-bus ownership at successful task-entry commit. The CPU could own
the functional bus when `TASK_ENTRY_COMMIT` asserted the event release; the
still-active event claim then reassigned the bus owner to event delivery on the
same edge. The event path is now prevented from claiming while its release
signal is active, so the task's first code fetch proceeds.

The focused task-gate regression runs a no-error software task-gate switch
with null LDTR, DS and ES selector words whose RPL bits vary over 0–3. Each
case executes `SLDT AX; MOV BX,DS; MOV CX,ES; HLT`. It checks the visible
selector values, exactly one task-entry event, no error-valid packet or error
stack write, TSS backlink and busy bits, no GDT null-descriptor read, and
sequential instruction-byte fetches at `0030:0300–0307` before halting at
`0030:0308`. All four selector combinations pass under both immediate and
stalled READY (eight cases).

This test follows the repository's target stepping profile. Intel's 1984
B-2/B-3 information sheet documents an earlier-stepping DS/ES null-selector
erratum that clears those visible selectors to zero; those earlier-stepping
errata are not selected here. This result does not claim behavior for those
errata-bearing parts. The primary architectural reference is Intel's
[80286 and 80287 Programmer's Reference Manual, order 210498-005](https://bitsavers.trailing-edge.com/components/intel/80286/210498-005_80286_and_80287_Programmers_Reference_Manual_1987.pdf),
§§8.2–8.5 and Table 8-1. The stepping note is from the
[1984 B-2/B-3 information sheet](https://docs.pcjs.org/manuals/intel/80286/80286_B2_B3_Errata-1984-11-21.pdf).

## Verification

Commands ran in the mirrored container from `/workspace/design/intel_80286/`
with Verilator 5.052:

```sh
verilator --lint-only -Wall --top-module intel_80286 src/*.sv
verilator --cc --exe --build -j 2 -Wall --top-module intel_80286 \
  --Mdir work/task_gate_noerror_20261027_01 src/*.sv tb/bootstrap.cpp
work/task_gate_noerror_20261027_01/Vintel_80286 --iopl-controls
work/task_gate_noerror_20261027_01/Vintel_80286
python3 scripts/preflight.py
```

Strict lint and release preflight pass. The fresh runner's focused
`--iopl-controls` suite passes the eight no-error task-gate cases, 10 incoming
LDTR cases, 42 invalid incoming CS/SS/DS/ES cases, 14 task-return backlink
cases, and 480 protected privilege scenarios. The full default bootstrap also
passes, including cache reset cuts, reference routing, protected event
recovery, ARPL, and reset/diagnostic boundaries. Logs are in
`work/task_gate_noerror_20261027_01/` (`lint.log`, `build.log`,
`iopl_controls.log`, and `full_bootstrap.log`).

| Artifact | SHA-256 / result |
| --- | --- |
| `src/intel_80286.sv` | `61a8c78f38bb0712dc2d4586c1f0208d487e0e1f907fe08b84223d82630f46d9` |
| `tb/bootstrap.cpp` | `8dc63676e8191abecd382b8dd43c97c57fa530d73660615dcfab5962a026f8bc` |
| Fresh runner | `bdcae0d82eea8e83cb2c27b2f9909ce77cd67694a91bf4aa9d88623491693d3e` |
| Strict lint | PASS, Verilator 5.052 `-Wall` |
| Focused `--iopl-controls` | PASS |
| Full default bootstrap | PASS |
| Release preflight | PASS |

No connected-core formal run covers this source snapshot. The older `_21`
cover/PDR jobs remain on earlier snapshots, and no overlapping connected-core
formal job was started.

## Remaining work

Valid task entry through a non-null LDTR still needs the loaded-LDT cache path
for segment and code lookup. Nested-fault escalation, broader double-fault
classification, shutdown, task-switch reset cuts and current-source
connected-core properties remain open. Full-chip acceptance remains open.
