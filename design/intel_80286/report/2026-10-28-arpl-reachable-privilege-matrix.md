# ARPL reachable CPL1–3 privilege matrix

**Date:** 2026-10-28 UTC  
**Issue:** [hevangel/ai_hw_engineer#80](https://github.com/hevangel/ai_hw_engineer/issues/80)  
**Scope:** Directed simulation for protected ARPL register and memory forms at reachable nonzero privilege levels.

## Result

The new 384-case regression passes. It covers CPL1, CPL2 and CPL3; every
source and destination RPL pair from 0 through 3; register and SS-based memory
destinations; initial ZF set and clear; and both READY policies. The test enters
each nonzero CPL through an outer IRET using actual code and stack descriptors.

Every case checks the exact ARPL encoding fetch, one retirement, no event or
fault, the destination's full 16-bit result, source preservation, and FLAGS
with only ZF allowed to change. Memory cases verify both byte reads in SS and
confirm that a write occurs only when the destination RPL is raised. Each case
executes the exact two following unprivileged NOPs.

The matrix supplements the existing ring-0 adjustment/no-change cases and the
Intel information-sheet null-source #GP(0) case. The semantics follow Intel
order 210498-005, Appendix B, ARPL (B-10); the null-source exception is sourced
to Intel's 1984 80286 B-2/B-3 information sheet. Links are in the
[protected execution contract](../spec/protected_execution.md).

## Reproduction

From the design directory, build with strict Verilator lint enabled and run:

```sh
INTEL_80286_WORK_DIR=work/arpl_reachable_privilege_20261028 \
  sh scripts/build_runner.sh
work/arpl_reachable_privilege_20261028/sim/Vintel_80286 --arpl
```

The focused output is retained in
`work/arpl_reachable_privilege_20261028/arpl.log`. The complete regression was
then run with:

```sh
INTEL_80286_WORK_DIR=work/arpl_reachable_privilege_20261028 \
PROTECTED_MODE_RUN_NAME=protected_mode_arpl_matrix_20261028 \
  sh scripts/run_sim.sh
```

The full command exits successfully with 171 `PASS:` lines and no `FAIL:` or
`ERROR:` lines. Its protected replay manifest records 79 passing cases in both
READY modes. The exact-source replay result is scoped to the protected fault,
reset-cut and string-restart suite; it is not evidence of whole-CPU completion.

## Source and tool identity

| Item | Identity |
|---|---|
| RTL SHA-256 | `4616be2d6c9d5bff4245e9964c92b8a26b45a3b67abca9ef4f56ab4b90dd6ee7` |
| `tb/bootstrap.cpp` SHA-256 | `4f798394e79109d7b67890a57cba941f726d737ea362fcf0da8700923f50bfe4` |
| Full runner binary SHA-256 | `6b57823969426faca168666e5612954644a47ecaa00af9ea4b258810597e5ae3` |
| Full runner fingerprint | `b1db302d23fb70e075e13bc330195b48fe058aaf8f3d35c62d0110893b131d4b` |
| Full runner manifest SHA-256 | `076793d46015313d400963302a233b90a31bf972c7443a277d65b33644e0b63e` |
| Protected replay binary SHA-256 | `219f399b6f1688ad7552a97f640a9e9af203ab8ffe912a61eee6a683587806cc` |
| Verilator | `5.052 2026-09-05 rev v5.052`, `-Wall` |
| Compiler | `g++ (Ubuntu 15.2.0-16ubuntu1) 15.2.0` |
| Focused `--arpl` log SHA-256 | `2b82e0d9f47d89fab64bc2435f7d78f97fd0a59958a4b0109d7e6185399f6c11` |
| Full simulation log SHA-256 | `88220fac9db2f02fd4d3990af8c0ab6cc3aac98b70c6f479082302159baf1847` |
| Protected replay manifest SHA-256 | `a4581a900090adb5dd9d73a8039b2f3cb9610efb5e389b776ac489218f0d7b9c` |
| Protected replay log SHA-256 | `1d68741ffd6a53dba2b3bc30cb5fa0679ef542b42bd98fe6529b80ec12e02fb7` |

The retained evidence root is
`design/intel_80286/work/arpl_reachable_privilege_20261028/`.

## Limits

This is directed simulation and does not provide whole-core formal proof,
independent stepping captures, segment-limit/fault-priority combinations or
historical software execution. Those release gates remain open. The 13-target
Yosys 0.69 synthesis result remains applicable because this change only added
testbench coverage and documentation; RTL behavior did not change.
