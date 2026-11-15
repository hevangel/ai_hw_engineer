# Am29323 test plan

- Oracle: `generate_oracle.py` interprets the datasheet contract
  (Tables 1–3, FA figure slice geometry, SHIFT AND ACCUMULATE) and
  emits a lockstep drive stream; outputs are checked before each edge,
  the edge then updates the model's registers.
- Directed sweeps: three product corners (including −1 × −1 and the
  unsigned extremes) × TC mode × accumulator command, with full slice
  readbacks under both FA and RND; T-register captures for all four
  Table 2 selections; mixed modes (unsigned/TC per operand) with
  ACCUMULATE and SHIFT AND ACCUMULATE flows and slice readback after
  every operation; the multiprecision 64 × 64 sequence through the
  A/B register staging.
- Random: 6,000 full-space drives (all data, parity, command, enable,
  feedthrough, select, output-enable and slave pins) with interleaved
  readback windows; parity-error and HARDERR paths exercised by random
  pin mismatches.
- Formal: independently recomputed command decode, word slices and
  accumulator; per-register capture-discipline assertions for all seven
  register sets via anyconst watched register; output-enable, parity
  and HARDERR contracts every timestep; covers for all accumulator
  commands, all PSEL selections, FA, RND, FTP, slave mode, parity error
  and mixed mode.
- Synthesis: Yosys `synth; check -assert` with cell statistics.
