# Incoming task SS privilege fault and double-fault escalation

**Checkpoint:** 2026-10-29 01:39 UTC  
**Issue:** [hevangel/ai_hw_engineer#80](https://github.com/hevangel/ai_hw_engineer/issues/80)  
**Branch/worktree:** `design/intel-80286`, `worktree/intel-80286`

## Source and behavior

Intel 210498-005 Table 8-1 row 12 requires the incoming stack-segment DPL to
equal the incoming CPL. The case uses incoming CPL 0 and SS selector `0040`,
which names a writable DPL-3 data segment with RPL 0. The mismatch raises
`#SS(0040)`. The row is visible on printed page 8-6 (PDF page 156) of the
[manufacturer's Programmer's Reference Manual scan](https://bitsavers.org/components/intel/80286/210498-005_80286_and_80287_Programmers_Reference_Manual_1987.pdf#page=156).
I reviewed it in Chrome using Playwright CLI. The capture is
[`table-8-1-page156-playwright-cli.png`](../work/incoming_ss_privilege_double_fault_20261029_12/table-8-1-page156-playwright-cli.png)
(SHA-256 `bff7df44409cb863233728a4ad311e94667847c16f6b5b1f1be511b9302f1b91`).

Four post-transfer executions route the first-fault #SS through an invalid
vector-12 gate, which selects null-error `#DF`, followed by either vector-8
shutdown or valid #DF task-gate delivery. Both outcomes pass in both READY
modes. The tests verify the rejected SS descriptor read, #SS/#DF gate reads,
the transferred TSS image with SS=`0040`, backlink and busy bits, null error
push, shutdown quiescence, and the exact handler successor. The direct
incoming-selector matrix independently checks the exact first-fault packet
`#SS(0040)`.

## Verification evidence

- `scripts/preflight.py` passed. Log:
  `work/incoming_ss_privilege_double_fault_20261029_12/preflight.log` (SHA-256
  `620391f4b26b482a0626e56663440ca46d0547c4af1391112540bdc0575e28aa`).
- Exact-source Verilator 5.052 `-Wall` runner build passed. Manifest:
  `work/incoming_ss_privilege_double_fault_20261029_12/sim/build_manifest.json`
  (SHA-256 `673c1a18650827d1ac1b7f498373109403d946df7e583329e6638504c7aa05d1`);
  runner binary SHA-256 is
  `5e54f8217411c1a548ed6fb4f1d608cbf11d7d53e49b369149c7512dc76f822f`.
- Focused `--iopl-controls` passed, including the four SS DPL-mismatch cases
  and the 52-execution incoming-selector matrix. Log:
  `work/incoming_ss_privilege_double_fault_20261029_12/focused.log` (SHA-256
  `b45fa027c5537913f9f9f2239e0fd4da27d77e9b79d93417cd118b4b01b98147`).
- Full `scripts/run_sim.sh` exited 0 with 187 `PASS:` lines and zero
  `FAIL:`/`ERROR:` lines. Log:
  `work/incoming_ss_privilege_double_fault_20261029_12/full_run.log` (SHA-256
  `09d0efd05753cf2d00b86240737b78404a491442103b494d16facf355584879f`).
- Protected replay manifest result is `PASS`: 79 cases in unstalled and READY-
  stall modes. Manifest:
  `work/incoming_ss_privilege_double_fault_20261029_12/protected_mode_sim_20261029T013957Z/build_manifest.json`
  (SHA-256 `f46e5fb1296418cb266d7106b5043bf56c79aa7555f4f0996c281c271281ca29`);
  replay log SHA-256 is
  `1d68741ffd6a53dba2b3bc30cb5fa0679ef542b42bd98fe6529b80ec12e02fb7`.
- `tb/bootstrap.cpp` SHA-256 is
  `530db486d88d97982d0c61a401d0b16e23da47896aa00530cd190e475eea8c41`.
  RTL was unchanged; `src/intel_80286.sv` remains SHA-256
  `4616be2d6c9d5bff4245e9964c92b8a26b45a3b67abca9ef4f56ab4b90dd6ee7`, so
  the existing 13-target Yosys synthesis remains applicable.

## Remaining limits

The preserved whole-core PDR remains active on its separate 21-file source
snapshot. Its latest observed log at 01:09 UTC reached frame 96 with 343/411
outputs proved and 48 timeout retries; 19/21 copied inputs match current
source, while `intel_80286.sv` and `intel_80286_code_load.sv` differ. It is not
current-source proof. The remaining incoming-SS selector-validity rule,
current-source connected-core formal, authentic historical software, native
timing qualification and whole-CPU acceptance remain open.
