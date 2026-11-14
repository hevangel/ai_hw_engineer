# Am26S12 test plan

Reference: 1974 Data Book pages 4-39..4-44; 1979 sheet pages 4-62..4-66
(truth table page 4-65).

## Directed simulation (`tb/tb_top.sv`, Verilator + xezim, REVISION 0)

1. Exhaustive sweep of E1 × E2 × I0..I3 (64 checks) with pull-up bias:
   both-enables-low rows assert B̄ = !I; either-enable-high rows idle
   the bus high; receivers read the bus throughout.
2. Party line: two instances on one biased bus — drive low, release to
   pull-up, second unit takes the bus.

## Formal (`formal/am26s12.sby`)

Driver contract with the dual-enable AND, release (=== z), receiver
contract; covers per truth-table row class including the
single-enable-release rows.

## Acceptance

Lint clean (documented TB waivers), both simulators pass, all formal
tasks PASS with every cover reached, Yosys `check -assert` clean at
REVISION 0.
