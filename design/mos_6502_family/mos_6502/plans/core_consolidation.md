# 6502 core consolidation plan (review item C3)

## Problem

Two independent 6502 implementations live in this family folder:

| Core | Bus model | Used by |
|---|---|---|
| `mos_6502/` | functional, one transfer per clock | `system/apple_iie`, `design/mos_6530/tb/tb_kim_boot.sv` |
| `mos_6502/cycle/` | physical, NMOS cycle behaviour | `system/apple_ii`, SingleStepTests, perfect6502 pin sweep |

They share external oracles (py65, Klaus, SingleStepTests) but **no verification
result is transferred**. A decoder or ALU slip can exist in one core and not the
other, and only the cycle core is proved by the Apple II board.

## Options

1. **Retire the functional core.** Cheapest to reason about, but it is
   instantiated by the Apple IIe system and the KIM-1 bench. Those consumers
   must migrate first; the functional bus (one transfer per clock) is a
   different contract from the cycle core's phi1/phi2 timing.
2. **Re-base the functional core as a wrapper over the cycle core.** Keeps the
   consumer interface, but requires a scheduler that runs the cycle core to
   instruction completion and presents one transfer per clock. The bus
   semantics change for every consumer, so it needs its own equivalence tests.
3. **Prove agreement with a differential test, then migrate.** Run the same
   instruction vectors through both cores and compare architectural state
   (PC/A/X/Y/SP/P and writes) at instruction boundaries. Cycle sequences are
   expected to differ because the cycle core models dummy reads; the comparison
   must therefore be architectural, not per-clock.

## Recommended order

1. **Differential harness — done.** `mos_6502/compare/` instantiates both cores
   in one Verilator binary and compares PC/A/X/Y/SP/P plus memory contents at
   every `fetch_o`. The directed phase covers 15 instructions and the Klaus
   phase 30,646,183, both zero-divergence; `run.sh` runs in about 90 s and is
   part of the functional core's `run_all.sh`. `negative_control.sh` corrupts
   one read in core B and requires the comparison to fail, so the gate is
   demonstrably non-vacuous.
2. **Migrate the KIM-1 bench — done.** `design/mos_6530/tb/tb_kim_boot.sv`
   now defaults to the cycle core; Verilator and Xezim both boot the original
   monitor (scans=2, 12 segments, 8,533 cycles).
3. **Decide on `system/apple_iie` — done: keep the functional core.** Its bus
   contract is one transfer per clock, so migrating would change the IIe timing
   model and require re-verifying that system. The differential now guards the
   functional core, which removes the liability that motivated migration.
   Revisit if the IIe needs cycle-level fidelity. Recorded in the family README.

## Acceptance criteria

- The differential test runs in both cores' `run_all.sh` and fails on
  architectural divergence.
- No consumer of a 6502 core lacks either the differential test or a real
  firmware regression.
- The family README states which core each system uses and why.
