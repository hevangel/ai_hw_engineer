# LLDT/LTR privilege matrix checkpoint

**Date:** 2026-10-27 10:37 UTC  
**Issue:** [hevangel/ai_hw_engineer#80](https://github.com/hevangel/ai_hw_engineer/issues/80) · [checkpoint comment](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6439781875)  
**Scope:** Reachable protected CPL 1, 2 and 3 LLDT/LTR attempts

## Change

The existing `--selector-exec` fixture exercised nonzero-CPL LLDT/LTR only at
CPL 3. It now enters each of CPL 1, 2 and 3 through a validated outer IRET,
using code, stack and data descriptors at the matching DPL. A same-level #GP
interrupt gate delivers the fault and returns through IRET, so the case
checks the actual privilege context and recovery path without depending on a
ring-transition event.

## Evidence

The focused `--selector-exec` suite passes 24 LLDT/LTR privilege scenarios:
three CPLs × LLDT/LTR register and memory forms × immediate/stalled READY.
Every denied instruction raises restartable #GP(0) before retirement. The
checks verify exact saved CS:IP:FLAGS:SP and frame bus order, preserve the
selector register and LDTR/TR, suppress memory-operand reads and descriptor or
TSS traffic, then resume at the exact instruction successor after same-level
handler repair and IRET.

The existing 10 selector-descriptor #GP/#NP cases, two null-LDTR cases and 82
VERR/VERW/LAR/LSL checks also pass in the focused suite. The complete default
bootstrap passes with the expanded matrix, followed by release preflight.

Evidence and the exact Verilator 5.052 `-Wall` build manifest are under
`work/selector_privilege_cpl_20261027_01/`:

- `selector_exec.log`
- `full_bootstrap.log`
- `build_manifest.json`

| Artifact | SHA-256 / count |
|---|---|
| RTL `src/intel_80286.sv` | `12142e802f75351dc0a5eaff2e3094ee2b6d424d8f15d20b67505625f25406a4` |
| Testbench `tb/bootstrap.cpp` | `5448afc1e2fbaab2c7bfa8979bf079dbcd1c19587e0c2ff0cabbf9e9fe2dab0a` |
| Formal properties | 298 assertions, 1 assumption, 49 covers; SHA-256 `85b8d6f497c927d084f21da29b10fa0be1ea8438242e2de735ee655e20056f53` |
| Built runner | `8a38276cbda9199698d316ae4888e0dcd96c0feec80fce82f06ddf5adff0cee0` |
| Build fingerprint | `9dbaeac8b7ba50d432ddd9db9a3746151ab8720eea62e0ff754e023831b90ff1` |

## Remaining scope

This closes only the CPL dimension for the tested LLDT/LTR register and memory
forms. It does not establish all protected selector fault priorities, task
switching, broader descriptor/event behavior, native 80286 timing, or
whole-core formal correctness. The current RTL hash is unchanged from the
preceding system-instruction checkpoint; connected-core formal jobs still run
on older snapshots and are not evidence for this testbench update.
