# Am2909 verification report

Verified October 3, 2026 with Verilator 5.052, Yosys 0.69, SBY/ABC/Z3 in
`ai-hw-engineer:latest`. Reproduce `sh design/amd_am2909/scripts/run_all.sh`.

- Verilator `--lint-only -Wall` native chip and three-chip fixture: pass
  without warnings or lint suppressions.
- 131,072 control/state transitions pass on a real three-slice 12-bit
  sequencer: 65,536 systematic PC/control/value cases and 65,536 stateful
  deterministic random cases. Every 256-control combination is covered.
  6,423,408 visible-state, control and address checks pass. Checks include
  independent register load, exact pre-edge-PC push, all four stack words,
  wrap, repeat, OR/ZERO priority, OE release and carry through all slices.
- Actual manufacturer Figures 7/8 subroutine sequences execute 36 words
  over two independent address placements, including a one-word nested
  subroutine and return linkage crossing 00FF/0100 and 03FF/0400. Exact
  executed PCs, next fetches and post-edge µPC are checked against literal
  original traces; undefined microstore landings are poisoned. These are
  the published microprogram sequences, not a complete recovered system ROM.
- Depth-16 BMC, unbounded PDR and all nine formal covers pass. Arbitrary
  initial state; no reset assumptions. An anyconst stack slot proves
  pre-edge-PC write and unrelated retention, alongside register, counter,
  pointer and output/carry properties.
- Yosys synthesis and `check -assert` pass: 104 cells. Architectural
  storage is the four-bit PC, four-bit address register, two-bit pointer
  and sixteen-bit stack.
  No electrical write waveform is asserted by this edge-based digital model.

No RTL semantic counterexample was found by the independent table or original
microcode. The stack is uninitialized until actual writes; overflow does not
produce an invented flag. The public-introduction date is sourced to 1975
marketing, with first shipment unestablished.
