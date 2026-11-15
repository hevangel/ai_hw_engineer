# Am26123 test plan

Reference: AMD 1974 Data Book pages 4-87..4-92 (truth table page 4-91).

## Directed simulation (`tb/tb_top.sv`, Verilator + xezim)

1. Power-on quiescence on both channels.
2. Truth-table trigger rows per channel: B rises with A low; A falls
   with B high.
3. Non-trigger rows: A high steady forces the network low; A falls with
   B low produce no edge; B falls never triggers.
4. Pulse width: exactly PULSE_CYCLES (4) cycles; Q̄ complementary.
5. Retrigger mid-pulse re-arms the full width.
6. Asynchronous clear resets to the Q-LOW quiescent state immediately
   (off-edge check), suppresses spikes under held clear with toggling
   inputs, and consumes edges while held.
7. Channel independence: both channels run concurrently; channel 2
   cleared mid-run while channel 1 completes.

## Formal (`formal/am26123.sby`)

bmc/cover with per-channel reference-model equality and pulse-width
properties plus the full cover set; prove with the unbounded
complementarity and clear-dominance properties; every cover must be
reached.

## Acceptance

Lint clean (documented RTL waivers), both simulators pass, all formal
tasks PASS with every cover reached, Yosys `check -assert` clean.
