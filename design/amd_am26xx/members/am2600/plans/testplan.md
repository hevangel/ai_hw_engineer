# Am2600 test plan

Reference: AMD 1974 Data Book pages 4-15..4-20 (Table I truth table,
operation rules, switching characteristics).

## Directed simulation (`tb/tb_top.sv`, Verilator + xezim)

1. Power-on quiescence (Q low, Q̄ high) before any stimulus.
2. Table I trigger rows, each from the quiescent state: Ī0↓, Ī1↓, and
   I2/I3/I4 rises gated by an active-low input low.
3. Non-trigger combinations: active-high input rising with both active-low
   inputs high; network steady-high creates no second edge.
4. Pulse width: a clean trigger holds Q for exactly PULSE_CYCLES (4)
   reference cycles; Q̄ complementary throughout.
5. Retrigger mid-pulse re-arms the full width.
6. Asynchronous clear: either C̄O0 or C̄O1 terminates a running cycle
   immediately (checked off-edge); inputs toggled under a held clear
   produce no output spikes; releasing the clear does not fire a consumed
   edge; a fresh edge after release triggers.
7. Edge consumed during a held clear stays consumed after release; the
   network must fall and rise again to trigger.

## Formal (`formal/am2600.sby`)

- bmc/cover: DUT equals an independently written reference model in every
  explored state; completed runs last exactly PULSE_CYCLES; covers for
  every trigger path, retrigger extension, async-clear termination by
  either pin, held-clear inhibit, completed full-width pulse.
- prove: induction-stable safety properties unbounded (output
  complementarity, clear dominance). Scope note in the props header.
- Non-vacuity: every cover must be reached (cover task PASS).

## Acceptance

- Lint clean (RTL no waivers), both simulators report
  `am2600 TEST PASSED` with zero failures, all three formal tasks PASS
  with no unreached covers, Yosys `check -assert` clean.
