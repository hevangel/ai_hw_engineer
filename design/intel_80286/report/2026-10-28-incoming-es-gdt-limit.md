# Incoming ES GDT-limit fault

**Current follow-up:** the incoming segment fault matrix now covers 25
configurations (50 READY-mode executions), including SS RPL mismatch, ES
system-descriptor and ES execute-only-code cases. See the [ES readability report](2026-10-29-incoming-es-readability.md),
[ES system-descriptor report](2026-10-29-incoming-es-system-descriptor.md) and
[incoming SS RPL report](2026-10-28-incoming-ss-rpl-fault.md).

**Date:** 2026-10-28  
**Issue:** [hevangel/ai_hw_engineer#80](https://github.com/hevangel/ai_hw_engineer/issues/80)  
**Branch/worktree:** `design/intel-80286`, `worktree/intel-80286`

## Source and change

Intel 210498-005 §8.4, Table 8-1 (printed page 8-6, PDF page 156), maps an
invalid incoming DS/ES selector to `#GP`. The source page was visually checked
in Chrome with `playwright-cli`:
[Table 8-1](https://bitsavers.org/components/intel/80286/210498-005_80286_and_80287_Programmers_Reference_Manual_1987.pdf#page=156).

The incoming-task fault matrix now covers 22 selector-fault configurations
in both READY modes, for 44 executions. The new ES case places selector
`0x0188` beyond the configured GDT limit `0x0187`, after valid incoming
CS/SS/DS descriptors. It checks the exact `#GP(0x0188)` packet and confirms
the CPU does not read the rejected descriptor. Existing cases cover the same
GDT-bound fault for CS, SS and DS. The full matrix also checks task state,
selector error codes, task backlink/busy updates, handler error pushes and
Table 8-1 fault order.

## Verification evidence

- `scripts/preflight.py` passed.
- Strict Verilator 5.052 `-Wall` `scripts/run_sim.sh` exited 0 with 173
  `PASS:` lines and no `FAIL:` or `ERROR:` lines. Log:
  `work/incoming_task_selector_bounds_20261028_01/full_run.log` (SHA-256
  `792949db9621b71431d9527a5aacb7c437cb58cad9cc9677df420537ff89b232`).
- The same full run passes the 460-case valid incoming-LDT DPL/RPL matrix and
  the eight LDT-limit cases. The protected replay manifest passes 79 cases in
  both unstalled and READY-stall modes:
  `work/incoming_task_selector_bounds_20261028_01/protected_mode_sim_20261028T234615Z/build_manifest.json`
  (SHA-256
  `6c5405c8a739960976253d2d476f3e4754f320c6c06ed352532253bb1f622e3e`).
- Runner fingerprint:
  `3c2bd3c1ed8b3b4a20f9dbe2f5ea45ad07c60d13deed01b6f70b636729a67747`;
  build-manifest SHA-256
  `b10c70a0e4d39fb8e4104700145afd3fcf61bf6d174a5fdbb48850d1f7336547`;
  runner binary SHA-256
  `c5bab6f8ba4acd7f227dbe9431b6e1a5730732762fa33024745fe0582c2c7c35`.
- `tb/bootstrap.cpp` SHA-256:
  `e7ac78aeea52b9ab6d2b35720ff2f9a08047ab828860b573555b2dd161ee015a`;
  core `src/intel_80286.sv` SHA-256 remains
  `4616be2d6c9d5bff4245e9964c92b8a26b45a3b67abca9ef4f56ab4b90dd6ee7`.

No RTL behavior changed, so the previous 13-target Yosys 0.69 synthesis
remains applicable. Current-source connected-core formal, remaining
task-switch fault phases, authentic historical software, native timing and
the full release gate remain open. The preserved whole-core PDR still runs
against its separate earlier 21-file snapshot.

Issue #80 checkpoint:
[comment 6483734952](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6483734952).
