# Incoming task segment faults after task transfer

**Current follow-up:** the matrix now covers 25 selector-fault configurations
(50 executions in both READY modes), including the ES GDT-limit, SS RPL
mismatch, ES system-descriptor and ES execute-only-code cases. See the
[ES readability report](2026-10-29-incoming-es-readability.md),
[ES system-descriptor report](2026-10-29-incoming-es-system-descriptor.md),
[SS RPL report](2026-10-28-incoming-ss-rpl-fault.md) and
[ES-limit report](2026-10-28-incoming-es-gdt-limit.md).

**Date:** 2026-10-27 12:28 UTC  
**Issue:** [hevangel/ai_hw_engineer#80](https://github.com/hevangel/ai_hw_engineer/issues/80)  
**Branch/worktree:** design/intel-80286 in B:\ai_hw_engineer\worktree\intel-80286

## Scope implemented

Intel's [80286 and 80287 Programmer's Reference Manual, order 210498-005,
§8.3 and Table 8-1](https://bitsavers.trailing-edge.com/components/intel/80286/210498-005_80286_and_80287_Programmers_Reference_Manual_1987.pdf)
defines incoming-task validation and its exception vectors. Task entry now
validates LDTR first, then CS, SS, DS and ES before publishing the validated
segment caches. A failed post-transfer check publishes the transferred
registers, selectors, FLAGS, TR and restartable exception packet before
delivering the exception through its task gate.

The incoming CS path now raises #TS(selector) for null, out-of-GDT, invalid
type and DPL/RPL mismatch, and #NP(selector) for a non-present code descriptor.
After CS, SS null/out-of-GDT/privilege failures raise #SS(selector), while a
present non-writable or non-data SS raises #GP(selector); absent SS raises
#SS(selector). DS/ES invalid type, table, or privilege cases raise
#GP(selector), and non-present data descriptors raise #NP(selector). Selector
error codes clear RPL bits.

Validation order is covered by pairwise fault-priority cases for CS before SS,
SS before DS, and DS before ES. Each exception is delivered through a nested
task gate. The tests verify the packet's vector, selector error, CS:IP:FLAGS:SP,
all 15 saved words of the transferred TSS, task backlink and busy bits, and
the error word pushed on the handler task's stack.

## Directed evidence

The --iopl-controls regression runs 21 invalid CS/SS/DS/ES cases under both
immediate and stalled READY (42 cases). It also reruns all five incoming-LDTR
fault cases (10 READY combinations) after correcting the GDT-limit selector:
the configured GDT limit is 0187, so the test now uses 0188, whose descriptor
exceeds the limit; the bus trace asserts no read of that descriptor. This
corrects the earlier LDTR checkpoint's 0080 fixture, which was within the
configured table limit and therefore did not test the claimed bound failure.
The segment-selector tests also assert no descriptor read for out-of-GDT
selectors. See the historical
[incoming-LDTR report](2026-10-27-incoming-ldtr-faults.md).

Strict Verilator 5.052 -Wall lint, release preflight, a fresh runner build,
focused --iopl-controls, and full default bootstrap all pass. Commands run
inside the mirrored container from design/intel_80286/:

    verilator --lint-only -Wall --top-module intel_80286 src/*.sv
    verilator --cc --exe --build -j 2 -Wall --top-module intel_80286 \
      --Mdir work/task_segment_fault_build src/*.sv tb/bootstrap.cpp
    work/task_segment_fault_build/Vintel_80286 --iopl-controls
    work/task_segment_fault_build/Vintel_80286

The focused and full logs are retained at
work/task_segment_fault_build/iopl_controls.log and
work/task_segment_fault_build/full_bootstrap.log.

## Exact-boundary fixture follow-up

The 2026-10-29 fixture audit found that `setup_incoming_ldtr` supplied
`0187` to the IDT-limit parameter and left the GDT limit at `007F`. Thus the
original selector-`0188` cases were out of range but were not one byte beyond
the stated GDT limit. The helper now sets both limits explicitly to `0187`;
the corrected focused and full regressions rerun the segment-fault matrix and
the CS, SS, DS, ES and LDTR selector-limit cases. The exact-boundary results
are recorded in the [DS/ES validity report](2026-10-29-incoming-ds-es-validity-double-fault.md).

| Artifact | SHA-256 / result |
| --- | --- |
| src/intel_80286.sv | 17362192f52c23fc28e03720c7531746f918d76f5645f63c5b06a5892a88b2fe |
| src/intel_80286_segment_check.sv | 53cef7c2a800b9c6d5ece1223e0ed7d0c18a67b607d918815465eaca0c998777 |
| tb/bootstrap.cpp | b4cea12a5b65fcb108a9de7e31d713cc548a995c25884d98763a41dbf8e0277e |
| Fresh runner | 9bc1dbd4e99d440b905e7da73a4070d916e3cd58163640ed4ab9ccd55a040373 |
| Focused suite | PASS; 42 incoming segment cases, 10 incoming-LDTR cases, and existing privilege/task cases |
| Full default bootstrap | PASS |
| Release preflight and strict lint | PASS |

No connected-core formal run covers this source snapshot. The older _21
cover/PDR jobs remain active against earlier RTL/property snapshots; no
overlapping formal job was started.

## Remaining limits

Valid non-null incoming LDTR execution still needs an LDTR cache path for task
segment and code lookup. The exploratory selector 0003 task-gate case reached
0030:0300 but did not fetch its HLT; no-error task-gate completion and
null-selector RPL variants remain to investigate. Nested task-fault escalation
beyond the directed paths, task-switch reset cuts, current-source connected-
core properties, shutdown behavior and full-chip acceptance remain open.

Issue checkpoint: [comment 6441881555](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6441881555).

