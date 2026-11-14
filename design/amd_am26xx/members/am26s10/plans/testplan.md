# Am26S10 test plan

Reference: AMD 1974 Data Book pages 4-39..4-44 (truth tables page
4-41); 1979 reprint pages 4-57..4-61.

## Directed simulation (`tb/tb_top.sv`, Verilator + xezim)

1. Exhaustive sweep of E × I0..I3 (32 checks) with pull-up bias on the
   bus nets: enabled rows assert B̄ = !I and Z̄ = !B̄; released rows
   idle the bus high (open-collector) and the receivers read it.
2. Party line: two instances tied on one biased bus net — unit 0
   drives low while unit 1's receiver reads it; release hands the bus
   to the pull-up; unit 1 takes the bus and unit 0's receiver reads
   it (the datasheet's Y/Ȳ rows).

## Formal (`formal/am26s10.sby`)

Driver contract (=== !I) and release (=== z) on the driver-role ports;
receiver contract (=== !B) with harness-driven bus; covers for the
truth-table rows, all-driven and all-released states. Scoping: the
bus-net tie and party-line resolution are simulation-directed (Yosys
formal has no pull-up primitive or inout directionality); recorded in
the formal plan and the spec.

## Acceptance

Lint clean (documented TB waivers), both simulators pass, all formal
tasks PASS with every cover reached, Yosys `check -assert` clean.
