# Incoming task stack selector RPL fault

**Current follow-up:** the incoming segment selector matrix now covers 25
configurations (50 READY-mode executions), including ES system-descriptor and
execute-only-code checks. See the [ES readability report](2026-10-29-incoming-es-readability.md).

**Date:** 2026-10-28 23:55 UTC  
**Issue:** [hevangel/ai_hw_engineer#80](https://github.com/hevangel/ai_hw_engineer/issues/80)  
**Branch/worktree:** `design/intel-80286`, `worktree/intel-80286`

## Source and expected exception

Intel 210498-005 §7.4.1 and §8.4, Table 8-1 (printed page 8-6, PDF page 156)
define RPL-based selector validation and incoming-task stack checks. I checked
the [manual scan](https://bitsavers.org/components/intel/80286/210498-005_80286_and_80287_Programmers_Reference_Manual_1987.pdf#page=156)
in Chrome with `playwright-cli`. Table 8-1 row 9, “Stack
segment is valid,” maps an invalid incoming stack selector to `SF` (Stack
Fault), with the stack-segment selector as the error code; row 13 also maps a
stack DPL/CPL mismatch to `SF`.

The directed case gives the incoming CPL-0 task SS selector `0x002b`: it names
the writable DPL-0 stack descriptor at GDT offset `0x0028` but carries RPL 3.
The invalid selector therefore raises `#SS(0x0028)`. The first test draft
expected `#TS`; its diagnostic showed the task gate delivered vector 12 with
error `0x0028` and reached the handler. Rechecking Table 8-1 corrected the
test oracle to `#SS`; no RTL behavior was changed.

The existing CS/SS/DS/ES fault matrix now covers 23 invalid-selector
configurations, or 46 executions across both READY modes. It checks exact
task-gate exception packets, transferred task state and fault priority. The
new SS RPL case extends the earlier selector and GDT-limit coverage.

## Verification evidence

- `design/intel_80286/scripts/preflight.py` passed.
- The strict Verilator 5.052 `-Wall` `scripts/run_sim.sh` log contains 173
  `PASS:` lines and no `FAIL:` or `ERROR:` lines:
  `work/incoming_task_ss_rpl_20261028_02/full_run.log` (SHA-256
  `412fa704d3e36827f95f1d3b81eb90cc1f83f87f0c571eb4eb8b64be13622c4e`).
- The run includes the 46-case incoming segment fault matrix, the 460-case
  incoming-LDT DPL/RPL matrix and eight LDT-limit fault cases. Its protected
  replay manifest records `PASS`, 79 cases in each of the unstalled and READY
  stall modes:
  `work/incoming_task_ss_rpl_20261028_02/protected_mode_sim_20261028T235502Z/build_manifest.json`
  (SHA-256
  `7b191b9e8203f58dba81010dd9b7ca28d954d0b1d0fc5984a9e003a69ecb25ca`).
- `tb/bootstrap.cpp` SHA-256:
  `f29f317c53b035800b3ac76c7c8db7cbaacbcce43304b9fd0b8634a7f81fba66`.
  The unchanged `src/intel_80286.sv` SHA-256 is
  `4616be2d6c9d5bff4245e9964c92b8a26b45a3b67abca9ef4f56ab4b90dd6ee7`.
- The 23:55 UTC issue checkpoint records Open/Building, Agent Codex, Path
  `ai_hw_engineer/design/intel_80286`, and first Start date `2026-10-23`.
  Re-reading project custom fields was blocked by a GitHub GraphQL API rate
  limit; no project field was changed. The checkpoint was read back in comment
  [6483919626](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6483919626).

The existing 13-target Yosys synthesis remains applicable because the RTL is
unchanged. Current-source connected-core formal, the remaining task-switch
fault phases, authentic historical software, native timing qualification and
full CPU acceptance remain open. The older whole-core PDR continues against
its separate 21-file snapshot and is not current-source evidence.
