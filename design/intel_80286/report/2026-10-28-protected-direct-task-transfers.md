# Protected direct task transfers

**Date:** 2026-10-28  
**Status:** Partial task-transfer implementation; the full 80286 objective remains open.

## Change

Protected far CALL/JMP now recognizes available 286 TSS descriptors and task
gates. Direct CALL is nested: it writes the old TR selector to the destination
TSS backlink, sets NT in the incoming task, and leaves the outgoing TSS busy.
Direct JMP does not write a backlink or set NT; it saves the post-instruction
successor and clears the outgoing busy bit. Both forms leave the destination
TSS busy and reuse the existing incoming-task validation and commit path.

The code-load helper now returns the two reserved descriptor-tail bytes for a
system descriptor. Protected far JMP uses that result to classify TSS/task-gate
targets without refetching the descriptor. Ordinary protected far JMP remains
on the existing validated code-load path; a focused regression checks its
exact destination successor and descriptor transaction.

The first rejection matrix used a wrong task-gate oracle: it treated a nonzero
offset as #GP and an incoming busy TSS as #TS. A Playwright CLI visual review
of Intel 210498-005 §8.5/Table 8-1 corrected both assumptions before commit.
The 286 ignores the task-gate offset; busy incoming TSSs raise #GP with the
incoming TSS selector. The far task-gate path now follows that contract, and
the success matrix uses a nonzero offset on both CALL and JMP. See the
[source audit](2026-10-28-task-gate-source-audit.md) and
[post-mortem](../../../failure_notes/2026-10-28-intel80286-task-gate-contract.md).

The corrected negative matrix exercises direct TSS and task-gate
DPL/presence priority, busy or short descriptors, reserved TSS bytes,
null/out-of-GDT selectors, and invalid current-TR busy/presence state. All 21
fault configurations run in both READY modes (42 executions) and check exact
exception frames and packets, descriptor-read boundaries, and absence of
task-image, backlink and busy-bit writes. The busy target TSS behind a task
gate raises #GP(0078) for both far CALL and JMP before task-state access. Two
task-gate CALL/JMP cases put the gate descriptor at the end of the GDT but its
embedded TSS selector just beyond the limit; each raises #TS(0078) without
reading that target descriptor.

The direct task-gate privilege matrix now exhausts 192 combinations: CPL 0–2,
selector RPL 0–3, gate DPL 0–3, far CALL/JMP, and both READY policies. All 104
permitted transfers check exact target and caller successors, task state, and
the CALL return frame. All 88 denied transfers check the exact #GP(selector)
frame and verify that the incoming TSS descriptor and task image are not read
or changed. The frame checks account for same-level CPL0 delivery, which does
not push the outer SS:SP pair.

The implementation follows Intel 210498-005 §§8.2–8.5. The focused success
matrix covers direct TSS and task-gate descriptors, CALL and JMP, and both
READY policies; task-gate CALL/JMP use a nonzero offset to check the 286's
documented ignore behavior. The corrected negative matrix covers 21 selected
fault configurations (42 executions) in both READY modes. The separate
192-execution gate-DPL matrix checks every listed CPL/RPL/DPL combination for
CALL and JMP in both READY modes. Untested fault combinations, all
partial-write fault phases and current-source task-switch formal properties
remain open.

## Verification

The strict Verilator 5.052 `-Wall` runner build and full default simulation
pass. The task-gate slice reports eight protected far CALL/JMP
executions through available TSS descriptors and task gates, checking
backlink/NT return versus JMP busy clearing, exact successors and READY stalls.
The 42-execution rejection matrix checks direct TSS/task-gate #GP/#NP/#TS
priority and no task-state or busy-bit side effects. It includes paired
task-gate CALL/JMP cases for a busy target TSS and for an out-of-GDT embedded
TSS selector. The successful task-gate CALL/JMP matrix uses a nonzero offset
to verify that the 286 ignores it. The ordinary code-descriptor JMP case also
passes. A further 900
reset-cut executions stop after each accepted data
transfer and immediately after commit in direct TSS/task-gate CALL/JMP entry,
across both READY policies; RESET cancels the partial switch and reaches only
the exact reset-vector HLT.

The fresh full `scripts/run_sim.sh` exits 0 with 170 `PASS:` lines and no
`FAIL:` or `ERROR:` lines. This run includes the 192-case privilege matrix.
Protected replay passes all 79 cases in both unstalled and READY-stalled modes.
Evidence is under
`design/intel_80286/work/task_gate_privilege_exhaustive_current_20261028/`;
the protected replay manifest is
`protected_mode_sim_20261028T224037Z/build_manifest.json` (SHA-256
`7e47145e1f7b7dd3dcbd107af35095d23c30072bd708e152a31054a625c7da6b`). It
records PASS, 79 cases and both wait modes. The full-run log SHA-256 is
`012420bdd6f21c4b1ce091b617e41c3f66a73d31b0dacc93410c2dc6fc8889d3`.

Corrected-source Yosys 0.69 synthesis completed all 13 targets under
`design/intel_80286/work/task_gate_source_correction_synth_20261028/`. Each
target has a JSON netlist and terminal log; every `check -assert` reports zero
problems, with no `ERROR:` lines. The synthesizer read RTL SHA-256
`998ab46aeafe75f51b3ed3788c562bc993dc5e49bee37d62c535b1aca8f800ee`. After
that run, the only RTL change was the inline A26 assumption comment below;
current RTL SHA-256 is
`4616be2d6c9d5bff4245e9964c92b8a26b45a3b67abca9ef4f56ab4b90dd6ee7`. The
fresh strict Verilator 5.052 runner built from the annotated source passes
`--iopl-controls` with 21 `PASS:` lines, including all 8 successful task
transfers, 42 rejection executions and 900 reset cuts. Its evidence is under
`design/intel_80286/work/task_gate_assumption_comment_refresh_20261028/`.

Evidence identity: current `src/intel_80286.sv` SHA-256
`4616be2d6c9d5bff4245e9964c92b8a26b45a3b67abca9ef4f56ab4b90dd6ee7`,
`src/intel_80286_code_load.sv` SHA-256
`9adcb050b8b8911ac4e10a272d56696d73e554264ca36842ff5d363ebf8c3e57`, and
`tb/bootstrap.cpp` SHA-256
`5b935befc4859f467f132e26048779e9170a786330b72b6f3fc2a2215a3ee80c`. The
strict runner fingerprint is
`e4d9510f3aeb9865cbebd651f5eda383793efb36de0c0b989b3cdce1c7b3f155`; its
binary SHA-256 is
`d85abf1b80c93d432a4313e022c0fed1e9d4d5ab8bcde22b3e131551493ff3fd`. The
source/tool build manifest SHA-256 is
`35a7242443472cf5ecebd5ad8c89430c58f60d8dff63a353b135cd8186671538`. No RTL
behavior changed after synthesis; later RTL/test updates are the A26 inline
comment and this testbench-only matrix.

No current-source whole-core formal was started. The earlier PDR remains
active on a different 21-file snapshot: at 22:40 UTC the process was still
running and its latest log entry remained at frame 27 with 342 assertion
outputs proven and 31 timeout retries, without terminal PASS. It does not
verify this change. Keep it as the only active core formal job until it
terminates and its source epoch is reconciled.

## Remaining work

- Expand beyond the 21 checked direct-transfer fault configurations and the
  exhaustive gate-DPL matrix to cover remaining selector, descriptor and
  check-order combinations.
- Add current-source formal coverage for direct task entry, JMP busy clearing,
  CALL backlink creation and task IRET; directed reset cuts do not prove the
  task-switch state machine.
- Continue authentic historical-software, independent-oracle, full formal and
  release-gate work listed in the [completion ledger](../plans/completion_requirements.md).
