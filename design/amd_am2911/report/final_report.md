# Am2911 verification report

Verified October 3, 2026 with Verilator 5.052, Yosys 0.69, SBY/ABC/Z3 in
`ai-hw-engineer:latest`. Reproduce `sh design/amd_am2911/scripts/run_all.sh`.

- Verilator `--lint-only -Wall` wrapper/common engine and actual three-chip
  Am2911 fixture: pass without warnings or suppressions.
- 131,072 independently sourced Figure 6 transitions: 65,536 systematic
  PC/control/value cases and 65,536 stateful random cases. All 256 controls,
  source selection, disabled/active register load from D, four retained stack
  words, exact pre-edge-PC push, repeat, wrap, ZERO, OE and cascade carry pass.
  6,423,536 visible-state, control and address checks include focused tests
  distinguishing live D from the old held register before/after enabled edges.
- Original manufacturer Figures 7/8 microprogram sequences: 36 executed words
  across two address placements, exact executed and next-fetched addresses,
  visible next µPC and nested one-word subroutine return linkage pass. These
  are published sequence examples, not a recovered complete system ROM.
- All three formal tasks pass: depth-16 BMC, unbounded PDR and nine reachable
  covers. The proof's top is the actual Am2911 wrapper, with shared D and
  absent OR fixed by wiring. Only the ZERO cover is specialized to its
  physically available no-OR interface. No reset/state assumptions.
- Yosys synthesis and `check -assert` pass: 104 cells including the common
  state-engine hierarchy, no warnings/errors. The wrapper exposes neither
  independent R nor address-OR pins.

No RTL semantic counterexample was found. The digital stack is uninitialized
until actual writes and has no invented overflow flag. Original electrical
SRAM write timing and propagation delays remain outside the edge-based
functional interface. The history entry states May 1976 availability evidence
and leaves exact first shipment unestablished.
