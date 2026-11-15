# Am29334 test plan

- Oracle: `generate_oracle.py` interprets the datasheet functional model
  (per-byte definedness, write order, address mux, latch transparency)
  and emits a lockstep drive stream — every drive the testbench performs,
  including readback windows, is stepped through by the model.
- Directed sweeps: byte-enable combinations (common × low × high per
  side) across address corners {0, 1, 31, 32, 62, 63} × latch enable ×
  output enable; cross-port simultaneous writes to the same and different
  cells for all four byte-enable combinations; transparency windows
  (write window + open latch) checking the written value at the pins.
- Random: 20,000 full-space drives over all inputs and addresses with
  interleaved readback windows on both ports.
- Undefined handling: value checks are masked when the oracle's cell
  image is not fully defined; enable and address checks always apply.
- Formal: anyconst watched cells with write-shadow invariants (byte
  merge, A-then-B order), combinational mux/latch/enable contracts, and
  covers for byte/full writes, write windows, transparency, cross-port
  visibility and three-state outputs. BMC depth 16, ABC PDR, smtbmc z3
  cover.
- Synthesis: Yosys `synth; check -assert` with cell statistics recorded.
