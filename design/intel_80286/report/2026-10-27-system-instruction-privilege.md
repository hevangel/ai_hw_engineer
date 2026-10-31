# Protected system-instruction privilege checkpoint

**Date:** 2026-10-27 10:31 UTC  
**Scope:** Nonzero-CPL checks for selected protected system instructions  
**Issue:** [hevangel/ai_hw_engineer#80](https://github.com/hevangel/ai_hw_engineer/issues/80) · [checkpoint comment](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6439651353)

## Architectural rule

Intel's [80286 Programmer's Reference Manual, order 210498-005, §§10.2–10.3](https://bitsavers.org/components/intel/80286/210498-005_80286_and_80287_Programmers_Reference_Manual_1987.pdf)
classifies LGDT, LIDT, LMSW and CLTS as privileged in protected mode. These
four now raise restartable #GP(0) at CPL 1–3. The implementation checks
privilege in `PREPARE`, before starting an r/m operand read. This matters for
LMSW [r/m16], LGDT and LIDT because a denied operation must not issue the
operand transaction. At this checkpoint's 10:31 UTC evidence cutoff, the
separate LLDT/LTR privilege regression covered CPL 3. The follow-up
[CPL 1–3 LLDT/LTR matrix](2026-10-27-lldt-ltr-privilege.md) was added and
verified at 10:37 UTC.

The check does not run in real mode. It does not add privilege checks to other
system encodings, claim full protected-mode exception priority, or close task
switching and descriptor-table behavior.

## Implementation and regression

The protected-mode gate in `src/intel_80286.sv` now covers 0F 00 /2–/3
(LLDT/LTR), 0F 01 /2–/3,/6 (LGDT/LIDT/LMSW), and 0F 06 (CLTS). It enters
vector 13 with error code zero and the original instruction IP before any
operand read or architectural update.

The `--iopl-controls` suite passes 480 protected privilege scenarios across
immediate and stalled READY policies:

- 120 new denials: CPL 1–3 × IOPL 0–3 × five forms (CLTS, LMSW AX,
  LMSW [0010], LGDT [0010], LIDT [0010]). Checks include exact saved
  CS:IP:FLAGS:SP, restartable #GP(0), no retirement, unchanged GPR/MSW state,
  and no denied memory operand read.
- 40 CPL-0 controls: the same five forms × all four IOPL values × both READY
  policies. Checks include successful retirement, operand width/data where
  applicable, LMSW state updates and the exact successor.
- The previous 320 IOPL, IF, CLI/STI, POPF/IRET and HLT scenarios remain in the
  combined count.

The test-first run failed as expected before the RTL fix: CPL 1 CLTS did not
raise restartable #GP(0). With the change, the focused matrix passes. The full
default bootstrap also passes; its log includes the 480-scenario result and
ends with the bootstrap PASS. Release preflight passes.

## Reproducible evidence

Evidence is retained under
`work/system_privilege_20261027_01/`:

- `build_manifest.json`: Verilator 5.052 (`-Wall`) build plan, source hashes,
  and runner fingerprint.
- `full_bootstrap.log`: complete default bootstrap output.
- `Vintel_80286`: the built regression runner.

The recorded identities are:

| Artifact | SHA-256 / count |
|---|---|
| RTL `src/intel_80286.sv` | `12142e802f75351dc0a5eaff2e3094ee2b6d424d8f15d20b67505625f25406a4` |
| Testbench `tb/bootstrap.cpp` | `7796ffe99c3e71d6a9d12ff7212c0abee924f5443dbc58a813d7b7f6f1e6bbfc` |
| Formal properties `formal/intel_80286_props.sv` | `85b8d6f497c927d084f21da29b10fa0be1ea8438242e2de735ee655e20056f53` |
| Built runner | `adbbc12e3ab2b1216e4b7b38d1641243d54d256e15b595fc4fc2bfa30ea38993` |
| Build fingerprint | `69bccb704a93683de2cb0b8b1696408d94c438b481ab5982c8b5d74c9b8bb8c0` |
| CPU formal properties | 298 assertions, 1 assumption, 49 covers |

## Remaining verification

No connected-core formal task has evaluated this RTL snapshot. The older
`protected_event_outer_20261027_21` cover job was waiting on the solver at
step 35 at 10:27:23 UTC. Its PDR job had reached frame 23 at 10:30:25 UTC,
with 366 outputs proved and 27 timeout retries. Both were still running when
checked; do not start overlapping formal jobs. The prior jobs are on older
source/property snapshots and are not evidence for this privilege change.

The matrix does not cover every privileged opcode, descriptor-table limit and
fault-priority interaction, task switching, native 80286 bus behavior, or
independent hardware replay. Full protected-mode and full-chip acceptance
remain open.
