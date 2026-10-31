# Direct TSS CALL/JMP privilege matrix

**Date:** 2026-10-28  
**Scope:** Protected direct far CALL/JMP to available TSS descriptors

## Architectural rule

Intel's *80286 and 80287 Programmer's Reference Manual*, order 210498-005,
§8.3 (printed page 8-5; PDF page 155), requires the TSS descriptor DPL to be
greater than or equal to both the current privilege level (CPL) and the
selector RPL. The rule is therefore `max(CPL, RPL) <= TSS_DPL`. A denied
direct TSS access raises `#GP` with the TSS selector as its error code. The
source page was opened and visually checked in Chrome through `playwright-cli`:
[Intel 210498-005, §8.3](https://bitsavers.org/components/intel/80286/210498-005_80286_and_80287_Programmers_Reference_Manual_1987.pdf#page=155).

## Coverage and result

The directed matrix covers CPL 0–2, selector RPL 0–3, TSS DPL 0–3, CALL and
JMP, and both READY policies: 192 total executions. It includes 104 allowed
transfers and 88 denials. Allowed cases check the exact task successor and
incoming task state; CALL cases check the backlink, nested-task return and
stack frame, while JMP cases check non-nested busy-bit behavior. Denied cases
check the exact `#GP(selector)` frame, descriptor/TSS preflight and absence of
incoming task-image or busy-bit side effects.

The fixture initially reused selector `0x78` for the incoming TSS and the
CPL2 stack-segment descriptor. On nested task return, that collision made the
test's restored SS invalid. The matrix now uses the unused GDT selector
`0x50`; the architectural coverage is unchanged. This was a test-fixture
correction, not an RTL change.

## Verification evidence

- `python3 scripts/preflight.py` passed.
- The focused `--iopl-controls` run passed all 23 suite groups, including the
  direct-TSS matrix. Its retained log is
  `work/direct_tss_privilege_matrix_20261028/iopl_controls.log` (SHA-256
  `dd79ca84b4399ec9f1b33897721a66d0beb77e9e85b3204731aac47bde8b1ff4`).
- The strict Verilator 5.052 `-Wall` `scripts/run_sim.sh` run exited 0 with
  172 `PASS:` lines and no `FAIL:` or `ERROR:` lines. Its log is
  `work/direct_tss_privilege_matrix_20261028/full_run.log` (SHA-256
  `fa779d69af8c7d7731dbd5be97e6ca5b86a3f2dab6b654f3327cf261a386d247`).
- The protected replay manifest at
  `work/direct_tss_privilege_matrix_20261028/direct_tss_privilege_replay_20261028/build_manifest.json`
  passes 79 cases in both unstalled and READY stall modes. Its SHA-256 is
  `9132c728a6faa0383402fbdaf4274a729583338cb9ade83d26bfa5f64bdb77ae`; the
  replay binary SHA-256 is
  `219f399b6f1688ad7552a97f640a9e9af203ab8ffe912a61eee6a683587806cc`.
- The focused binary at `work/direct_tss_privilege_matrix_20261028/sim/Vintel_80286`
  has SHA-256
  `e998568a62e0b49492a43c8221342f9477178052fa87ecefab2a0bc5d4442bb2`;
  its build fingerprint is
  `d5c4d6ad05b40f1d635e1d93c3ca153079d85bebfb894f7ba0f9ca7cb86e1b7f` and
  `work/direct_tss_privilege_matrix_20261028/sim/build_manifest.json` has
  SHA-256
  `1759ee68c2176b1c560f85882d62f5e69ebaa3f8c2285ca25a918b7d93c6ce1f`.
  The testbench source SHA-256 is
  `b9745db056bde5517f0c8f002558b58e2a30e2d180c7c77613e6cb4ee1437403`; the
  primary RTL source `src/intel_80286.sv` is
  `4616be2d6c9d5bff4245e9964c92b8a26b45a3b67abca9ef4f56ab4b90dd6ee7`.

## Limits and next work

This is directed simulation evidence for the direct TSS descriptor privilege
boundary. It does not establish full task-switch or whole-CPU correctness.
No RTL behavior changed, so the previous 13-target Yosys 0.69 synthesis
result remains applicable. The current-source connected-core proof,
remaining task-switch fault phases, authentic historical software and full
release gate remain open. The preserved whole-core PDR is still running on a
different 21-file source snapshot and is not current-source evidence; do not
start an overlapping core proof.
