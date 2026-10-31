# 80286 task-return backlink faults

**Date:** 2026-10-27 11:44 UTC  
**Issue:** [hevangel/ai_hw_engineer#80](https://github.com/hevangel/ai_hw_engineer/issues/80)  
**Branch/worktree:** `design/intel-80286` in `B:\ai_hw_engineer\worktree\intel-80286`

## Scope implemented

Intel's [80286 and 80287 Programmer's Reference Manual, order 210498-005,
§§8.3–8.4 and Tables 8-1/8-2](https://bitsavers.org/components/intel/80286/210498-005_80286_and_80287_Programmers_Reference_Manual_1987.pdf)
defines task-return admission through the current TSS backlink. The
[80286 Operating Systems Writer's Guide](https://www.bitsavers.org/components/intel/80286/121960-001_iAPX_286_Operating_Systems_Writers_Guide_1983.pdf)
identifies an invalid backlink as #TS and a not-present backlink TSS as #NP;
the busy-bit requirements in Table 8-2 require #GP when IRET finds an available
rather than busy backlink task.

The core now reports pre-switch backlink failures through protected event
delivery in the current task:

- Null, LDT, out-of-GDT, wrong-type and undersized backlink TSS cases raise
  restartable #TS with the selector error code (RPL bits cleared).
- A not-present busy TSS raises #NP(selector).
- An available rather than busy TSS raises #GP(selector).

These checks happen before writing the outgoing task image or clearing its
busy bit. The existing valid backlink IRET path remains covered separately.

## Directed evidence

The `--iopl-controls` fixture first invokes a task through a valid #GP task
gate. After task entry, it corrupts only the active task's backlink or its
target descriptor, installs same-task gates for vectors 10, 11 and 13, and
executes IRET with NT set. The 14 cases cover seven descriptor failures in
immediate and stalled READY modes. Each checks the selected vector, exact
selector error code, restartable saved CS:IP:FLAGS:SP, successful delivery to
the same-task handler, no outgoing dynamic-TSS writes and no busy-bit clear.
The existing successful task IRET, nested #GP selection and 480 privilege
scenarios also pass in the focused suite.

Strict Verilator 5.052 `-Wall` lint, release preflight, the focused
`--iopl-controls` suite and the full default bootstrap pass. Logs and the
fresh runner are retained in
`design/intel_80286/work/task_return_fault_build/`.

| Artifact | SHA-256 / result |
| --- | --- |
| `src/intel_80286.sv` | `181bc652c484d183ade6d650d588c5e1b3c2b7918e5334f092c7451d2e1339aa` |
| `tb/bootstrap.cpp` | `5aecc413c2fe34ddba64b12af68e8d7e0781087a4f859d461317a166a2aae391` |
| `formal/intel_80286_props.sv` | `d650dd7231a11b85b7737a9295afe0161a2cf87c235ae90fff6915f2688b28cb` |
| Fresh runner | `c48c4edded9b78b8f9567748ffb4d59888831dab22663d1fefe1b5fd161dee94` |
| Focused privilege/task-return suite | PASS; 14 new backlink-fault cases across both READY modes |
| Full default bootstrap | PASS |
| Release preflight and strict lint | PASS |

## Limits and next work

This covers only backlink admission before the task state transfer. Invalid
current-TR state and faults while validating incoming LDTR, SS, CS, DS or ES
still stop diagnostically; the incoming task is not yet architecturally
published at the point required for post-switch exception delivery. The core
property file is unchanged, and the older connected-core cover/PDR jobs remain
active on earlier RTL/property snapshots. No current-source connected-core
formal result covers this change, and no overlapping core proof was started.

Next, implement the 286 task-switch point-of-transfer behavior and fault
delivery for invalid incoming LDTR/segment state, then cover nested-fault
escalation, reset cuts and task-switch properties. Full 80286 acceptance
remains open. Issue checkpoint: [comment 6441100122](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6441100122).
