# Incoming task CS type fault and double-fault escalation

**Checkpoint:** 2026-10-29 01:32 UTC  
**Issue:** [hevangel/ai_hw_engineer#80](https://github.com/hevangel/ai_hw_engineer/issues/80)  
**Branch/worktree:** `design/intel-80286`, `worktree/intel-80286`

The checkpoint was posted and read back in
[issue comment 6485429155](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6485429155).

## Source and behavior

Intel 210498-005 Table 8-1 row 6 requires the incoming CS selector to name a
code segment. A selector naming a data descriptor therefore raises
`#TS(selector)`. The row is visible on printed page 8-6 (PDF page 156) in the
[manufacturer's Programmer's Reference Manual scan](https://bitsavers.org/components/intel/80286/210498-005_80286_and_80287_Programmers_Reference_Manual_1987.pdf#page=156).
I inspected it in Chrome using Playwright CLI. The full-page capture is
[`table-8-1-page156.png`](../work/incoming_cs_type_double_fault_20261029_10/table-8-1-page156.png)
(SHA-256 `bff7df44409cb863233728a4ad311e94667847c16f6b5b1f1be511b9302f1b91`).

The new case gives the incoming task CS=`0010`, which names a data descriptor.
The direct selector-fault matrix already checks the exact first-fault packet
`#TS(0010)`. Four escalation executions now check both a malformed vector-10
handler gate that leads to null-error `#DF` shutdown and a valid #DF task-gate
delivery, each with READY immediate and stalled. They verify the rejected CS
descriptor read, #TS and #DF gate lookups, faulting task TSS image with
CS=`0010`, backlink and busy bits, null error push, shutdown quiescence, and
the exact #DF-handler successor.

## Verification evidence

- `scripts/preflight.py` passed. Log:
  `work/incoming_cs_type_double_fault_20261029_10/preflight.log` (SHA-256
  `620391f4b26b482a0626e56663440ca46d0547c4af1391112540bdc0575e28aa`).
- Exact-source Verilator 5.052 `-Wall` runner build passed. Manifest:
  `work/incoming_cs_type_double_fault_20261029_10/sim/build_manifest.json`
  (SHA-256 `3e720bdb1d56b4da660464498bde67ab0a907ca95cb5be365cf0e6935103bf34`);
  runner binary SHA-256 is
  `907b9b0877683e2f576f6f415530ae6e0ddd81032c811ff59d1771e82732491d`.
- Focused `--iopl-controls` passed, including the four wrong-type CS cases and
  the 52-execution incoming-selector matrix. Log:
  `work/incoming_cs_type_double_fault_20261029_10/focused.log` (SHA-256
  `131b61d6f480332bcecc169c5192bbf7d1fbebab9ef546816458d601428e5b08`).
- Full `scripts/run_sim.sh` exited 0 with 185 `PASS:` lines and zero
  `FAIL:`/`ERROR:` lines. Log:
  `work/incoming_cs_type_double_fault_20261029_10/full_run.log` (SHA-256
  `dc3b72910baca4163660c31494d6d9e689ddcd786459a40408bfaa7968a7e7bc`).
- Protected replay manifest result is `PASS`: 79 cases in unstalled and READY-
  stall modes. Manifest:
  `work/incoming_cs_type_double_fault_20261029_10/protected_mode_sim_20261029T013152Z/build_manifest.json`
  (SHA-256 `53e62f1e5ccdcba20f7267d2a87ed503bc215a8e8d3d2e4f907deec93902d578`);
  replay log SHA-256 is
  `1d68741ffd6a53dba2b3bc30cb5fa0679ef542b42bd98fe6529b80ec12e02fb7`.
- `tb/bootstrap.cpp` SHA-256 is
  `dbf6d4ea8018cbe0a7ec86da921a142ae25622d05f209a4449467c65518104c0`.
  RTL was unchanged; `src/intel_80286.sv` remains SHA-256
  `4616be2d6c9d5bff4245e9964c92b8a26b45a3b67abca9ef4f56ab4b90dd6ee7`, so
  the existing 13-target Yosys synthesis remains applicable.

## Remaining limits

The preserved whole-core PDR remains active on its separate 21-file source
snapshot. Its latest observed log at 01:09 UTC reached frame 96 with 343/411
outputs proved and 48 timeout retries; 19/21 copied inputs match current
source, while `intel_80286.sv` and `intel_80286_code_load.sv` differ. It is not
current-source proof. Remaining Table 8-1 escalation cases, current-source
connected-core formal, authentic historical software, native timing
qualification and whole-CPU acceptance remain open.
