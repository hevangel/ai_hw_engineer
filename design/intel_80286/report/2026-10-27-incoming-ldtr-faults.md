# 80286 incoming-LDTR task-switch faults

**Date:** 2026-10-27 12:06 UTC  
**Issue:** [hevangel/ai_hw_engineer#80](https://github.com/hevangel/ai_hw_engineer/issues/80)  
**Branch/worktree:** `design/intel-80286` in `B:\ai_hw_engineer\worktree\intel-80286`

## Scope implemented

Intel's [80286 and 80287 Programmer's Reference Manual, order 210498-005,
§8.3 and Table 8-1](https://bitsavers.org/components/intel/80286/210498-005_80286_and_80287_Programmers_Reference_Manual_1987.pdf)
places incoming-task segment checks after the task-state transfer point.
Invalid or absent incoming LDT descriptors raise #TS with the incoming LDTR
selector as the error code. The incoming task context is current when these
post-transfer checks fault.

The core now handles incoming LDTR validation after loading the 15 dynamic TSS
words:

- Null selectors (GDT index zero, TI clear) continue to the existing segment
  loading path.
- TI selectors and selectors whose eight-byte descriptor exceeds the GDT
  limit raise #TS(selector) without a descriptor read.
- A GDT descriptor that is not a present LDT descriptor (system type 2) raises
  #TS(selector). RPL bits are cleared in the error code; the selector's TI bit
  is retained.
- The fault path publishes the incoming GPRs, visible segment selectors,
  LDTR selector, FLAGS and TR before starting protected #TS delivery. For a
  nested task-gate switch, the incoming task's flags include NT. The second
  task gate can therefore save the transferred task image and push the
  selector error code on the handler task's stack.

A present, valid non-null LDT descriptor is recognized, but the existing
task-segment/code engines do not yet consume a loaded LDTR cache during task
entry. That path remains an explicit diagnostic stop.

## Directed evidence

The `--iopl-controls` test invokes a CPL3 program through a software task gate.
The incoming TSS contains one of five invalid LDTR selectors: TI set, a busy
TSS descriptor instead of an LDT, that wrong-type descriptor with RPL bits set,
a not-present LDT descriptor, or a selector beyond the GDT limit. Vector 10 is
another task gate. Each case checks the
restartable #TS packet and exact selector error, then verifies the nested task
switch saved all 15 incoming TSS words, set the task backlink and busy bits,
and pushed the error code at the incoming handler stack. All five cases pass
with immediate and stalled READY (10 cases total).

Strict Verilator 5.052 `-Wall` build, release preflight, focused
`--iopl-controls`, and the full default bootstrap pass. Commands run from
`design/intel_80286/`:

```sh
verilator --cc --exe --build -j 2 -Wall --top-module intel_80286 \
  --Mdir work/task_ldtr_fault_build src/*.sv tb/bootstrap.cpp
work/task_ldtr_fault_build/Vintel_80286 --iopl-controls
work/task_ldtr_fault_build/Vintel_80286
```

Logs and runner are retained under
`design/intel_80286/work/task_ldtr_fault_build/`.

| Artifact | SHA-256 / result |
| --- | --- |
| `src/intel_80286.sv` | `f897772d10e89a3c861a4dbc5fa6cd48c173e5c018065fb055945f35a1147c65` |
| `tb/bootstrap.cpp` | `ac0aaaabea11b5b33750d9900effb2e44362df821c976f139ad3e0b79837f0af` |
| Fresh runner | `2f2ce1f26c5ed262c2ba40018d87cd7c0fbec950acea8e8c7a5d096ba60ca5ba` |
| Focused suite | PASS; 10 incoming-LDTR #TS cases plus existing task/privilege scenarios |
| Full default bootstrap | PASS |
| Release preflight and strict lint | PASS |

## Limits and next work

Historical test correction: this snapshot called selector `0080` beyond the
GDT limit even though its configured limit was `0187`; `0080` was in-bounds.
The later selector-`0188` follow-up also initially used the wrong helper
argument: it set IDTR.limit to `0187` while GDTR.limit remained `007F`. The
shared incoming-task fixture now sets GDTR.limit to `0187`, and the full
regression re-runs the incoming-LDTR limit cases at that exact boundary. See
the [fixture audit and row-13 report](2026-10-29-incoming-ds-es-validity-double-fault.md).
Incoming CS/SS/DS/ES exception delivery was implemented and verified in the
follow-up [incoming task segment report](2026-10-27-incoming-segment-faults.md).

Present non-null LDTR task entry is recognized but not yet supported through
the segment/cache path. An exploratory LDTR selector `0003` case reached the
incoming `0030:0300` context but did not complete its HLT fetch; null-selector
RPL variants and the no-error software task-gate completion path need a
separate directed check. Nested-fault escalation, task-switch reset cuts and
current-source connected-core properties also remain open.

No connected-core formal run was started: the older `_21` cover/PDR jobs remain
active on earlier RTL/property snapshots, and the connected-core properties
were not changed. Full 80286 acceptance remains open. Issue checkpoint:
[comment 6441542853](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6441542853).
