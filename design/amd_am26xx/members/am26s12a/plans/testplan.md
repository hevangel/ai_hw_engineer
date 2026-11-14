# Am26S12A test plan

Reference: 1979 Linear and Interface Data Book pages 4-62..4-66 (truth
table page 4-65; S12A threshold rows page 4-63).

## Directed simulation (`tb/tb_top.sv`, Verilator + xezim, REVISION 1)

Same stimulus as the am26s12 member, run against the REVISION 1
instance: exhaustive E1 × E2 × I0..I3 sweep with pull-up bias,
released-bus idle checks, and the directed party-line sequence.

## Formal (`formal/am26s12a.sby`)

Same properties as the am26s12 formal plan (dual-enable AND driver
contract, release, always-active receiver), evaluated on the REVISION 1
instance; covers per truth-table row class.

## Acceptance

Lint clean (documented TB waivers), both simulators pass, all formal
tasks PASS with every cover reached, Yosys `check -assert` clean at
REVISION 1.
