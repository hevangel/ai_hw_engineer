# Incoming task DS readability fault

**Checkpoint:** 2026-10-29 01:27 UTC  
**Issue:** [hevangel/ai_hw_engineer#80](https://github.com/hevangel/ai_hw_engineer/issues/80)  
**Branch/worktree:** `design/intel-80286`, `worktree/intel-80286`

The checkpoint was posted and read back in
[issue comment 6485340380](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6485340380).

## Source and behavior

Intel 210498-005 §8.4, Table 8-1 row 14 requires an incoming DS or ES code
descriptor to be readable. An execute-only descriptor at selector `0030`
therefore raises `#GP(0030)` when loaded as DS. The same descriptor remains
valid as CS, which isolates the readability failure. I reviewed the row in
Chrome using Playwright CLI on printed page 8-6 (PDF page 156) of the
[manufacturer's Programmer's Reference Manual scan](https://bitsavers.org/components/intel/80286/210498-005_80286_and_80287_Programmers_Reference_Manual_1987.pdf#page=156).
The capture is
[`table-8-1-row14-playwright-cli.png`](../work/incoming_ds_readability_double_fault_20261029_09/table-8-1-row14-playwright-cli.png)
(SHA-256 `4196cca01846781b19e29f55df7841c62070b4b31e3d29b93b94a980f2082e68`).

Four post-transfer first-fault executions use incoming CS=`0030` and
DS=`0030`. The malformed vector-13 handler gate selects null-error `#DF`;
the tests check invalid-vector-8 shutdown and valid #DF task-gate delivery in
both READY modes. They verify the failed descriptor access, exact #GP/#DF
gate lookups, transferred task state with DS=`0030`, backlink and busy bits,
null error push, shutdown quiescence, and the exact handler successor.

The direct incoming-selector fault matrix now also checks the first-fault
packet for DS=`0030` independently. This adds one configuration in both READY
modes, expanding the matrix from 25 configurations/50 executions to 26/52.
The matrix verifies `#GP(0030)`, the transferred TSS image, task backlink and
busy state, and the exact pushed error word. It retains the existing CS/SS/DS/
ES priority and GDT-limit cases.

## Verification evidence

- `scripts/preflight.py` passed. Log:
  `work/incoming_ds_readability_double_fault_20261029_09/preflight.log`
  (SHA-256 `620391f4b26b482a0626e56663440ca46d0547c4af1391112540bdc0575e28aa`).
- Exact-source Verilator 5.052 `-Wall` runner build passed. The runner
  manifest is `work/incoming_ds_readability_double_fault_20261029_09/sim/build_manifest.json`
  (SHA-256 `504fb47641d9fb4375b7415b1ef217c87a70185acc9d2736019c3a0263f04838`);
  its binary SHA-256 is
  `7fa750de45041389d765c67a3e4b7c9f1592ed4ee90e158e4ace66f70ae8bc8b`.
- Focused `--iopl-controls` passed, including the four DS readability
  escalation executions and the 52-execution incoming-selector matrix. Log:
  `work/incoming_ds_readability_double_fault_20261029_09/focused.log`
  (SHA-256 `540d695f0c713bac3b7f1908413cb5dc1391fd0ea5df38250939552bf8862bfc`).
- Full `scripts/run_sim.sh` exited 0 with 184 `PASS:` lines and zero
  `FAIL:`/`ERROR:` lines. Log:
  `work/incoming_ds_readability_double_fault_20261029_09/full_run.log`
  (SHA-256 `4ad6e7f4f32320c31c48b37120aaa2d8780094a139d6ce663b107aaf9a6d829e`).
- Protected replay manifest result is `PASS`: 79 cases in unstalled and READY-
  stall modes. The manifest is
  `work/incoming_ds_readability_double_fault_20261029_09/protected_mode_sim_20261029T012551Z/build_manifest.json`
  (SHA-256 `0a5ac65985dfbb99afac66495d7dbb9860c49f41e02d057c9f0dee2253a4fa64`);
  its replay log SHA-256 is
  `1d68741ffd6a53dba2b3bc30cb5fa0679ef542b42bd98fe6529b80ec12e02fb7`.
- `tb/bootstrap.cpp` SHA-256 is
  `976ff97a504a8920a19262b1e80e4004f2764b15bc1d18b77a90baca99575a9e`.
  RTL was unchanged; `src/intel_80286.sv` SHA-256 remains
  `4616be2d6c9d5bff4245e9964c92b8a26b45a3b67abca9ef4f56ab4b90dd6ee7`, so
  the existing 13-target Yosys synthesis remains applicable.

## Remaining limits

The preserved whole-core PDR remains active on its separate 21-file source
snapshot. Its latest observed log at 01:09 UTC reached frame 96 with 343/411
outputs proved and 48 timeout retries; 19/21 copied inputs match current
source, while `intel_80286.sv` and `intel_80286_code_load.sv` differ. It is not
current-source proof. Current-source connected-core formal, remaining
task-entry fault phases, authentic historical software, native timing
qualification and whole-CPU acceptance remain open.
