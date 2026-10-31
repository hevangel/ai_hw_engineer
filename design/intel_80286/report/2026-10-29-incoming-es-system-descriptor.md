# Incoming task ES system descriptor fault

**Current follow-up:** the selector-fault matrix now covers 25 configurations
(50 READY-mode executions), including the ES execute-only-code case for Table
8-1 row 14. See the [ES readability report](2026-10-29-incoming-es-readability.md).

**Date:** 2026-10-29 00:01 UTC  
**Issue:** [hevangel/ai_hw_engineer#80](https://github.com/hevangel/ai_hw_engineer/issues/80)  
**Branch/worktree:** `design/intel-80286`, `worktree/intel-80286`

## Source and case

Intel 210498-005 §8.4, Table 8-1 row 13 (“DS/ES selectors are valid”) maps an
invalid DS or ES selector to `#GP`, with the segment selector as the error
code. I visually checked the table at printed page 8-6 (PDF page 156) in
Chrome using `playwright-cli` against the
[manufacturer's Programmer's Reference Manual scan](https://bitsavers.org/components/intel/80286/210498-005_80286_and_80287_Programmers_Reference_Manual_1987.pdf#page=156).

The incoming-task selector matrix already exercised a system descriptor in
DS, but did not exercise the corresponding ES validation path. The new case
loads ES with selector `0x0050`, which names the TSS system descriptor in the
fixture GDT, while CS, SS and DS are valid. It checks exact `#GP(0x0050)` task-
gate delivery and the transferred TSS state in both READY modes.

The CS/SS/DS/ES fault matrix now covers 24 invalid-selector configurations,
or 48 executions across immediate and stalled READY. It also retains the
incoming SS RPL-mismatch case, corrected to `#SS(0x0028)` from Table 8-1 row 9.

## Verification evidence

- `scripts/preflight.py` passed.
- `scripts/run_sim.sh` completed with exit code 0 under strict Verilator 5.052
  `-Wall`: 173 `PASS:` lines, zero `FAIL:`/`ERROR:` lines, and the new
  48-execution incoming-selector matrix passed. Log:
  `work/incoming_task_es_type_20261028_01/full_run.log` (SHA-256
  `f46e08772751f4cdb36a05b613af9bd287fd5c68e2cb07016318d84e84fc69ef`).
- The protected-mode replay manifest records `PASS`, 79 cases in each of the
  unstalled and READY-stall modes:
  `work/incoming_task_es_type_20261028_01/protected_mode_sim_20261029T000105Z/build_manifest.json`
  (SHA-256
  `3e55e8ea5fa8444008266aa3100db63e15b9f638f6e074b273b5a3be74c307a2`).
- The testbench SHA-256 is
  `17c0a645206937aa05dc3568a5015e23afc370816c6830c02e21e348ec871be3`.
  RTL `src/intel_80286.sv` remains unchanged at SHA-256
  `4616be2d6c9d5bff4245e9964c92b8a26b45a3b67abca9ef4f56ab4b90dd6ee7`.
- The checkpoint was posted and read back in issue comment
  [6483988275](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6483988275).
  Project custom-field readback remains blocked by a GitHub GraphQL API rate
  limit; no project fields were changed.

The prior 13-target Yosys synthesis remains applicable because RTL did not
change. Current-source connected-core formal, other post-transfer task-switch
fault phases, authentic historical software, native timing qualification and
full CPU acceptance remain open. The older whole-core PDR is still running on
its separate 21-file snapshot and is not current-source evidence.
