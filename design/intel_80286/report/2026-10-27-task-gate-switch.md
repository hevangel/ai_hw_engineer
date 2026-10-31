# 80286 #DF task-gate entry checkpoint

**Date:** 2026-10-27 11:24 UTC  
**Issue:** [hevangel/ai_hw_engineer#80 checkpoint](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6440730446)  
**Branch/worktree:** `design/intel-80286` in `B:\ai_hw_engineer\worktree\intel-80286`

## Scope implemented

This checkpoint advances the earlier
[task-gate preflight](2026-10-27-task-gate-preflight.md) into one executable
successful task-entry path. The IDT gate must be type 5 with a zero offset and
reserved fields, select a non-null GDT descriptor within the GDT limit, and
resolve to a present available 286 TSS with limit at least `002Bh`. A valid
target descriptor is marked busy; the incoming TSS backlink receives the old
TR selector; the old task's 15 dynamic words are saved at TSS offset `000Eh`;
and the incoming task's 15 dynamic words are read from the same offsets.

For this first slice, a null incoming LDTR is supported. The implementation
validates the incoming SS, CS, DS and ES descriptors, stages their hidden
caches, checks the new stack span, and pushes the task-gate exception error
word. Registers, selectors, FLAGS, TR, TS, and all segment caches are
published together after validation and the error-code write. The interrupt
task switch sets NT in incoming FLAGS and TS in MSW, retains the outgoing
task's busy bit, and leaves the backlink in the new TSS.

This checkpoint covers a successful double-fault task-gate entry and exact
handler HLT. It does not implement task IRET/backlink return. Invalid task
gate/TSS descriptor conditions and faults during incoming LDTR/segment
validation still stop diagnostically instead of using the architectural
task-switch exception-priority and nested-delivery rules. Non-null incoming
LDTR, broader task-gate vectors, reset cuts, full #DF classification and
shutdown remain open.

## Directed evidence

The `--iopl-controls` regression creates the nested protected #GP that selects
vector 8, supplies a valid task gate to TSS selector `0050`, and seeds the
incoming TSS with distinct register values. It checks both immediate and
stalled READY policies. Assertions cover:

- all 15 outgoing dynamic TSS words, including exact saved CS:IP:FLAGS:SP;
- incoming AX/CX/DX/BX/SP/BP/SI/DI and ES/CS/SS/DS values;
- the hidden bases for all four loaded segments;
- the backlink to selector `0058`, target TSS busy access byte `83`, TS and NT;
- the null #DF error word at the new stack's exact push address; and
- execution of HLT at `0030:0300`, landing at `0030:0301`.

Both the focused suite and full default bootstrap pass from the fresh
Verilator 5.052 build. `scripts/preflight.py` and strict `--lint-only -Wall`
also pass. The exact commands were:

```sh
verilator --lint-only -Wall --top-module intel_80286 src/*.sv
python3 scripts/preflight.py
verilator --cc --exe --build -j 2 -Wall --top-module intel_80286 \
  --Mdir work/task_gate_switch_build src/*.sv tb/bootstrap.cpp
work/task_gate_switch_build/Vintel_80286 --iopl-controls
work/task_gate_switch_build/Vintel_80286
```

Logs and the executable are retained in the ignored
`design/intel_80286/work/task_gate_switch_build/` directory. The older shared
`work/sim` cache was not changed.

| Artifact | SHA-256 / result |
| --- | --- |
| `src/intel_80286.sv` | `effc3001a1ababb405e1f76653afb9076b950551a23351398c165296e143f9c3` |
| `tb/bootstrap.cpp` | `2fc4b8feb5c3e2356845a4d82d3c92b09a07e45b699438fa2e9c405236677bc7` |
| `formal/intel_80286_props.sv` | `d650dd7231a11b85b7737a9295afe0161a2cf87c235ae90fff6915f2688b28cb` |
| Fresh runner binary | `7b4785d58e4b2340fcd96f5d994619807cf23210154c0e1a11bd6f1c9c640843` |
| Verilator | `5.052 2026-09-05 rev v5.052` |
| Focused `--iopl-controls` | PASS, including two task-switch runs |
| Full default bootstrap | PASS |
| Release preflight | PASS |

## Formal and follow-up

No connected-core formal task covers this RTL snapshot. The older `_21`
connected-core cover and PDR jobs remain active on prior source/property
snapshots. At the last status read, cover was waiting at step 35 (log
11:12:25 UTC) and PDR had proved 366 outputs (log 11:22:28 UTC). No overlapping
connected-core run was started. Property SHA-256 remains the prior snapshot
`d650dd7231a11b85b7737a9295afe0161a2cf87c235ae90fff6915f2688b28cb` and must
not be treated as evidence for the new task-switch RTL.

Next, implement and test task IRET through the backlink, including outgoing
busy-bit clearing and exact restoration of the interrupted task. Then cover
invalid incoming TSS and segment cases with the 286-specific exception
priority, nested escalation, shutdown, reset behavior, and task-switch
properties before widening task-gate support. Full 80286 acceptance remains
open.
