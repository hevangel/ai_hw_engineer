# Am29338 test plan

- Oracle: `generate_oracle.py` implements the byte-stream contract with
  per-byte definedness tracking; outputs are checked before each clock
  event; RESET is transition-based with held-low re-assignment at clock
  edges (matching the RTL's async-reset semantics).
- Directed: the Figure 6 queue and Figure 7 dequeue examples; the BSW
  sweep queueing one byte from each reordering; fill-to-full with
  A-FULL/FULL transitions and drop-on-full; full drain; the Figure 5
  retransmit flow through RXMIT; POS quadrant behavior under RESET and
  RXMIT; simultaneous queue/dequeue at different pointers.
- Random: 12,000 full-space drives over all clocks, enables, byte
  counts, reorder, data, parity, position, reset and retransmit pins,
  with periodic resets/retransmits and interleaved output windows.
- Formal: status/count contracts and pointer-window equality every
  timestep; counts-saturate and reset-hold invariants; covers for all
  BQ/BDQ byte counts, BSW encodings, FULL/EMPTY/A-FULL/A-EMPTY, parity
  errors, RESET/RXMIT, simultaneous clocks and cascade quadrants (cover
  depth 40 to reach the filled queue).
- Synthesis: Yosys `synth; check -assert` with cell statistics.
