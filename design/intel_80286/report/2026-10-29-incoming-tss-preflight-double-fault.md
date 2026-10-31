# Incoming TSS preflight and double-fault shutdown coverage

**Date:** 2026-10-29 02:28 UTC  
**Reference:** Intel 80286 Programmer's Reference Manual, order 210498-005,
Table 8-1 rows 1–3, printed page 8-6 (PDF page 156). The page was reviewed
and captured with `playwright-cli` at
`design/intel_80286/work/table_8_1_tss_preflight_double_fault_20261029_20/table-8-1-page156-playwright-cli.png`
(SHA-256 `bff7df44409cb863233728a4ad311e94667847c16f6b5b1f1be511b9302f1b91`).

Rows 1–3 validate the target TSS before transferring task state: the
descriptor must be present, available (idle), and at least `002B` bytes long.
The expected first faults are `#NP(selector)` for not-present, `#GP(selector)`
for busy, and `#TS(selector)` for a short available TSS. The direct TSS and
task-gate rejection matrix has 21 configurations in both READY modes (42
executions), including not-present and short together to check `#NP` priority.
It verifies exact exception packets, descriptor-read ordering, and no task
image, backlink, or busy-bit writes before rejection.

The #DF path now also checks failures while loading the vector-8 task's TSS.
Six executions cover busy, short available, and not-present-and-short TSS
descriptors with READY immediate and stalled. Each case enters sticky
shutdown with the original #DF context, reads exactly the vector-8 gate and
target descriptor, and performs no task-state or error-stack write. The
existing not-present #DF target test covers the remaining presence failure.

These cases separate pre-transfer descriptor faults from faults after an
incoming task has loaded. The row-13 DS/ES report separately records the
corrected `GDTR.limit=0187` fixture and row-13 post-transfer cases.

## Verification

- `scripts/preflight.py`: pass.
- Verilator 5.052 `-Wall` runner build: pass; fingerprint
  `d497f9b87aee9a8c8723d9351a7da73b23f1f82a638ca3c030a9a10f1042e220`.
- Runner binary SHA-256:
  `54aeedac5d3ff0545e0be61de4a4930a21539157c44d13c46ec76ddcf5b66a24`.
- Focused `Vintel_80286 --iopl-controls`: pass, including direct first-fault
  and nested #DF shutdown cases.
- Full `scripts/run_sim.sh`: exit 0 with 195 `PASS:` lines and no `FAIL:` or
  `ERROR:` lines.
- Protected-mode replay: manifest result `PASS`, 79 cases in both READY modes.
- Testbench SHA-256:
  `4ee6f5e85f2ba1a1a5b5f9b3b6f4e4d10724cc8ac1efbebf5bcb183806a3a65d`.
- Full-run log SHA-256:
  `5fb49bb3d5921ad7a35a1e6ee36b9cff6283a581481464107b5797f27b798041`.
- Replay manifest SHA-256:
  `68a8e1fc2bb436235216e123da833bc5d11f823422cda11551ac789423f1185b`.

Evidence is under
`design/intel_80286/work/table_8_1_tss_preflight_double_fault_20261029_20/`.
Only the testbench changed; RTL behavior and existing synthesis inputs are
unchanged. Current-source connected-core formal, authentic software execution
on the RTL, remaining task-switch cases and whole-CPU acceptance remain open.
The checkpoint was posted and read back in
[issue comment 6486238114](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6486238114).
