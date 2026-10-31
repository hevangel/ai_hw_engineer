# 80286 task-gate source audit — 2026-10-28

## Finding

A visual review of Intel order 210498-005 using `playwright-cli` corrected two
task-switch oracle assumptions in the direct far CALL/JMP slice:

- Section 8.5, printed page 8-8, says the offset part of a CALL/JMP destination
  through a task gate is ignored. Figure 8-3 labels that field unused and says
  zero is required for 80386 compatibility. This is not a 286 rule to raise
  #GP when the offset is nonzero.
- Table 8-1, printed page 8-6, says the incoming TSS must be idle; a busy
  incoming TSS raises #GP and uses that TSS selector as the error code. Section
  8.4/Table 8-2 confirms the busy-bit fault class.

Primary-source pages: [§8.3 and Table 8-1](https://bitsavers.org/components/intel/80286/210498-005_80286_and_80287_Programmers_Reference_Manual_1987.pdf#page=156),
[§8.4 and Table 8-2](https://bitsavers.org/components/intel/80286/210498-005_80286_and_80287_Programmers_Reference_Manual_1987.pdf#page=157),
and [§8.5, Figure 8-3](https://bitsavers.org/components/intel/80286/210498-005_80286_and_80287_Programmers_Reference_Manual_1987.pdf#page=158).
The review used Playwright CLI screenshots of the scanned PDF; no OCR or
search-result snippet was treated as source evidence.

## Correction

The far task-gate path now ignores the offset field. The successful transfer
fixture supplies a nonzero offset for task-gate CALL and JMP in both READY
modes and checks the exact successor reached through the incoming TSS. The
busy target TSS CALL/JMP cases now require #GP(0078), with no task-state image
reads or writes beyond the descriptor preflight. Out-of-GDT embedded TSS
selectors remain #TS(0078) before target descriptor access.

The negative matrix has 21 fault configurations (42 READY-mode executions).
A new 192-execution direct task-gate privilege matrix exhausts CPL 0–2,
selector RPL 0–3, gate DPL 0–3, CALL/JMP and both READY policies. It checks all
104 allowed transfers, all 88 #GP(selector) denials, exact successor/frame
state and that denied transfers do not read or change the incoming TSS. The
CPL0 frame checks omit the outer SS:SP words on same-level #GP/INT delivery.

The fresh strict Verilator 5.052 `-Wall` full `scripts/run_sim.sh` exits 0
with 170 `PASS:` lines and no `FAIL:` or `ERROR:` lines. The protected replay
manifest records PASS for 79 cases across both READY modes. Evidence is under
`design/intel_80286/work/task_gate_privilege_exhaustive_current_20261028/`;
its full-run log SHA-256 is
`012420bdd6f21c4b1ce091b617e41c3f66a73d31b0dacc93410c2dc6fc8889d3`, and the
protected-replay result manifest SHA-256 is
`7e47145e1f7b7dd3dcbd107af35095d23c30072bd708e152a31054a625c7da6b`.
Corrected-source Yosys 0.69 synthesis completed all 13 targets; each produced
a JSON netlist and terminal log, all `check -assert` checks report zero
problems, and no log contains an `ERROR:` line. Evidence is under
`design/intel_80286/work/task_gate_source_correction_synth_20261028/`.

Synthesis read RTL SHA-256
`998ab46aeafe75f51b3ed3788c562bc993dc5e49bee37d62c535b1aca8f800ee`,
`intel_80286_code_load.sv` SHA-256
`9adcb050b8b8911ac4e10a272d56696d73e554264ca36842ff5d363ebf8c3e57`, and
`tb/bootstrap.cpp` SHA-256
`1009f5d3057bea164d7311974b258d24cc61ff8e123eaf8b1187ea4688d55b90`. After
synthesis, the only RTL edit was the A26 inline assumption comment; current
RTL SHA-256 is
`4616be2d6c9d5bff4245e9964c92b8a26b45a3b67abca9ef4f56ab4b90dd6ee7`. A
fresh strict Verilator 5.052 `-Wall` runner was built from that annotated
source (fingerprint
`c572c51c32da6bdb6b7681eae5fa25b24498f58f49c665c41633364be49a80f2`, binary
SHA-256 `b5d1a9ac1433ac6d7d1e5222c93079eff530e25d6ee0003d6770c1422d9614ef`),
and the focused `--iopl-controls` regression passes with 21 `PASS:` lines.
The full simulation result above predates only that comment annotation.

## Remaining descriptor-field assumption

Figure 8-3 also labels additional task-gate descriptor fields unused and gives
a zero-value note for 80386 compatibility. It does not state the 80286
exception behavior for nonzero values in the fields checked by the current
direct far CALL/JMP path: `protected_call_descriptor_header[2:0]`,
`protected_call_parameter_count`, and `protected_call_descriptor_tail`. RTL
currently rejects those values with #GP(task-gate selector). This is
**ASSUMPTION A26**, recorded in
[`protected_privilege_transition.md`](../spec/protected_privilege_transition.md):
the behavior remains provisional until independent 286 evidence resolves
whether those fields fault or are ignored. The current direct-transfer matrix
keeps these fields zero and does not validate the behavior. Any future test
that encodes the provisional policy is regression evidence only, not
architectural acceptance.

This correction is an escaped oracle assumption found before commit. See the
[post-mortem](../../../failure_notes/2026-10-28-intel80286-task-gate-contract.md).
