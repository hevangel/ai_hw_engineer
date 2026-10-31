# Incoming task read-only SS fault and double-fault escalation

**Checkpoint:** 2026-10-29 01:37 UTC  
**Issue:** [hevangel/ai_hw_engineer#80](https://github.com/hevangel/ai_hw_engineer/issues/80)  
**Branch/worktree:** `design/intel-80286`, `worktree/intel-80286`

The checkpoint was posted and read back in
[issue comment 6485485955](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6485485955).

## Source and behavior

Intel 210498-005 Table 8-1 row 10 requires the incoming SS descriptor to be a
writable data segment. A present, read-only data descriptor at selector
`0010` therefore raises `#GP(0010)`. The row is visible on printed page 8-6
(PDF page 156) of the
[manufacturer's Programmer's Reference Manual scan](https://bitsavers.org/components/intel/80286/210498-005_80286_and_80287_Programmers_Reference_Manual_1987.pdf#page=156).
I checked it in Chrome using Playwright CLI. The capture is
[`table-8-1-page156-playwright-cli.png`](../work/incoming_ss_readonly_double_fault_20261029_11/table-8-1-page156-playwright-cli.png)
(SHA-256 `bff7df44409cb863233728a4ad311e94667847c16f6b5b1f1be511b9302f1b91`).

The new case sets incoming SS=`0010` and changes its descriptor access byte to
`0x90`, a present read-only DPL-0 data segment. Four post-transfer executions
check a malformed vector-13 gate selecting null-error `#DF`, followed by
either invalid-vector-8 shutdown or valid #DF task-gate delivery in both READY
modes. They verify the rejected descriptor access, #GP/#DF gate lookups, the
faulting TSS image with SS=`0010`, backlink and busy bits, null error push,
shutdown quiescence, and the exact handler successor. The direct
incoming-selector matrix separately checks the exact first-fault
`#GP(0010)` packet.

## Verification evidence

- `scripts/preflight.py` passed. Log:
  `work/incoming_ss_readonly_double_fault_20261029_11/preflight.log` (SHA-256
  `620391f4b26b482a0626e56663440ca46d0547c4af1391112540bdc0575e28aa`).
- Exact-source Verilator 5.052 `-Wall` runner build passed. Manifest:
  `work/incoming_ss_readonly_double_fault_20261029_11/sim/build_manifest.json`
  (SHA-256 `c94a5d23c6330082eb036982a51be2f841435bb8d353ffc1b7ad55b71d92b239`);
  runner binary SHA-256 is
  `00d678f2a960df00e562a0c89bc337a1e943938342fb919977c96a75ee0f336c`.
- Focused `--iopl-controls` passed, including four incoming read-only SS
  escalation cases and the 52-execution incoming-selector matrix. Log:
  `work/incoming_ss_readonly_double_fault_20261029_11/focused.log` (SHA-256
  `f7ac427d258b0ff70b46f995e2e9805d264bfc517d10bf3955e8a55d47a35642`).
- Full `scripts/run_sim.sh` exited 0 with 186 `PASS:` lines and zero
  `FAIL:`/`ERROR:` lines. Log:
  `work/incoming_ss_readonly_double_fault_20261029_11/full_run.log` (SHA-256
  `efb2f3c6b00ae74cfa51a675bf57d60ba41a2a00960b082c9032f758c4c42bd1`).
- Protected replay manifest result is `PASS`: 79 cases in unstalled and READY-
  stall modes. Manifest:
  `work/incoming_ss_readonly_double_fault_20261029_11/protected_mode_sim_20261029T013639Z/build_manifest.json`
  (SHA-256 `ac93a63063bef463ac721b087b70ecc86d2c4a43ae4f2b8e941e197b0a2b5a6a`);
  replay log SHA-256 is
  `1d68741ffd6a53dba2b3bc30cb5fa0679ef542b42bd98fe6529b80ec12e02fb7`.
- `tb/bootstrap.cpp` SHA-256 is
  `cba1f9ef33678e2bf4d25be239051a6fd4198cfe8314963b9abaa524188848cb`.
  RTL was unchanged; `src/intel_80286.sv` remains SHA-256
  `4616be2d6c9d5bff4245e9964c92b8a26b45a3b67abca9ef4f56ab4b90dd6ee7`, so
  the existing 13-target Yosys synthesis remains applicable.

## Remaining limits

The preserved whole-core PDR remains active on its separate 21-file source
snapshot. Its latest observed log at 01:09 UTC reached frame 96 with 343/411
outputs proved and 48 timeout retries; 19/21 copied inputs match current
source, while `intel_80286.sv` and `intel_80286_code_load.sv` differ. It is not
current-source proof. Other Table 8-1 escalation cases, current-source
connected-core formal, authentic historical software, native timing
qualification and whole-CPU acceptance remain open.
