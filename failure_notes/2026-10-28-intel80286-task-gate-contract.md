# 80286 task-gate fields and task-switch fault oracle — 2026-10-28

## External evidence and failure

The Intel [80286 and 80287 Programmer's Reference Manual, order 210498-005,
§8.5, printed page 8-8](https://bitsavers.org/components/intel/80286/210498-005_80286_and_80287_Programmers_Reference_Manual_1987.pdf#page=158)
states that the offset portion of a far CALL/JMP through a task gate is
ignored. Figure 8-3 marks the field unused and says zero is required for
80386 compatibility; that compatibility note does not define a 286 #GP.
The same manual's [Table 8-1, printed page 8-6](https://bitsavers.org/components/intel/80286/210498-005_80286_and_80287_Programmers_Reference_Manual_1987.pdf#page=156)
maps a non-idle incoming TSS to #GP with the incoming TSS selector as the error
code. Section 8.4 and Table 8-2 also specify #GP(selector) for a violated busy
bit requirement.

The new direct-transfer matrix and RTL shared two incorrect rules: they
rejected a nonzero task-gate offset with #GP, and expected a busy task-gate
target TSS to raise #TS. A visual review of the scanned manual using
`playwright-cli` exposed both mismatches. The old directed tests passed because
their expected packets were derived from the same mistaken interpretation.
These edits were local and uncommitted; no release or upstream change occurred.

Visual captures are retained under
`design/intel_80286/work/task_gate_source_correction_sim_20261028/source_audit/`:
Table 8-1, the task-switch preflight order, and the task-gate layout/text.

## Cause and fix

The test treated “must be set to 0 for compatibility with the 80386” as an
exception rule for the 286. It also treated a busy TSS like an invalid TSS
selector, although Table 8-1 explicitly assigns #GP to the incoming busy
descriptor. This was an oracle error, not a failing simulator assertion: RTL
and expected results had been updated together.

The RTL no longer rejects the task-gate offset. Four CALL/JMP gate-transfer
executions now use a nonzero offset and must reach the exact task-program
successor. A busy incoming TSS now raises #GP with the incoming TSS selector;
the CALL/JMP rejection cases check the exact packet and prove that no task
image or busy-bit writes occur. The separate out-of-GDT embedded selector
cases remain #TS(target selector), before any target descriptor read.

## Verification and limits

The focused `--iopl-controls` matrix passes 42 rejected-transfer executions
(21 configurations across both READY modes), the eight successful direct/TSS
and task-gate transfers, and all 900 task-entry reset cuts. The full
`scripts/run_sim.sh` exits 0, including all 79 protected replay cases in both
READY modes. The corrected-source 13-target Yosys matrix is being rerun; its
result will be added to the report and issue checkpoint. Current-source
whole-core formal, authentic historical software and full release acceptance
remain open.

## Prevention

Keep descriptor field labels, compatibility notes, exception tables and
processor-generation scope separate in the spec and test oracle. For task
switching, tests must quote the exact Intel 210498-005 table row that supplies
the exception vector and error-code selector. The CPU-specific rule has been
added to `AGENTS.md`; the broader independent-oracle and assumption-ledger
rules remain mandatory.
