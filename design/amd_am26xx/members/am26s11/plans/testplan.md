# Am26S11 test plan

Reference: AMD 1974 Data Book pages 4-39..4-44 (truth tables page
4-41); 1979 reprint pages 4-57..4-61.

## Directed simulation (`tb/tb_top.sv`, Verilator + xezim)

1. Exhaustive sweep of E × I0..I3 (32 checks) with pull-up bias:
   enabled rows assert B̄ = I (non-inverting) and Z̄ = !B̄; released
   rows idle the bus high.
2. Party line: two instances on one biased bus — drive low, release to
   pull-up, second unit takes the bus; receivers read the bus level
   throughout.

## Formal (`formal/am26s11.sby`)

Driver contract (=== I) and release (=== z); receiver contract with
harness-driven bus; covers for the truth-table rows, all-driven and
all-released states.

## Acceptance

Lint clean (documented TB waivers), both simulators pass, all formal
tasks PASS with every cover reached, Yosys `check -assert` clean.
