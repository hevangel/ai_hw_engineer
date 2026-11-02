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

1. **Differential harness.** One Verilator binary instantiating both cores, one
   shared vector source, comparison at each `fetch_o`. Start with the packed
   SingleStepTests vectors the cycle core already consumes; extend to the Klaus
   binary once the per-vector path is stable. Acceptance: identical
   architectural state for every vector, and a deliberate injected decoder
   fault is detected.
2. **Migrate the KIM-1 bench** (`design/mos_6530/tb/tb_kim_boot.sv`) to the
   cycle core. It is a single testbench, so this is the cheapest consumer to
   move and it exercises the real fixture path.
3. **Decide on `system/apple_iie`.** Only after 1 and 2: either migrate it to
   the cycle core or keep the functional core with the differential test as its
   standing cross-check. Record the decision in the family README.

## Acceptance criteria

- The differential test runs in both cores' `run_all.sh` and fails on
  architectural divergence.
- No consumer of a 6502 core lacks either the differential test or a real
  firmware regression.
- The family README states which core each system uses and why.
