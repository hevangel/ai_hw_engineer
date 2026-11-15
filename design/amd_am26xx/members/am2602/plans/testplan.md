# Am2602 test plan

Reference: AMD 1974 Data Book pages 4-21..4-26 (Table I, operation
rules, switching characteristics).

## Directed simulation (`tb/tb_top.sv`, Verilator + xezim)

1. Power-on quiescence on both channels.
2. Table I row 1 per channel: Ī0 falls while I1 low.
3. Table I row 2 per channel: I1 rises while Ī0 high.
4. Non-trigger combinations: network held high produces no new edge; a
   falling network edge never triggers; I1 toggling under a held-high
   network produces no edge mid-run.
5. Pulse width: exactly PULSE_CYCLES (4) cycles; Q̄ complementary.
6. Retrigger mid-pulse re-arms the full width.
7. Asynchronous clear terminates immediately (off-edge check); no
   spikes while toggling inputs under a held clear; consumed edge does
   not fire on release; fresh edge after release triggers.
8. Channel independence: both channels run concurrently; channel 2
   cleared mid-run while channel 1 completes.

## Formal (`formal/am2602.sby`)

- bmc/cover: per-channel reference-model equality and exact pulse width,
  covers for every Table I path per channel, retrigger, async-clear
  termination, held-clear inhibit, completed pulses on both channels,
  and channel independence.
- prove: unbounded complementarity and clear dominance per channel.
- Non-vacuity: all covers reached.

## Acceptance

Lint clean (RTL waivers documented), both simulators pass, all formal
tasks PASS with every cover reached, Yosys `check -assert` clean.
