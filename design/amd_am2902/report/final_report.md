# Am2902 verification report

Verified October 3, 2026 in `ai-hw-engineer:latest` with Verilator 5.052,
Yosys 0.69, SymbiYosys and Z3. Reproduce:

```sh
sh design/amd_am2902/scripts/run_all.sh
```

- Verilator `--lint-only -Wall` RTL and timed testbench: pass without warnings
  or lint suppressions.
- All 512 physical P/G/Cn combinations agree with the ripple-recurrence oracle,
  including propagate/generate asserted together.
- 49,344 sixteen-bit arithmetic cases on four **actual Am2901 ALU modules**
  plus Am2902 pass. Covers ADD/SUBR/SUBS, both input carry levels, directed
  bit-boundary chains and deterministic random operands. Checks full result,
  carry and signed overflow, each slice's flags, and predicted carry pins.
- 82,052 two-level network cases pass using five actual Am2902 instances:
  65,536 arbitrary sixteen-group P/G patterns and 16,516 full 64-bit arithmetic
  cases, including long propagation, generation and boundary cases.
- Formal depth-2 BMC, unbounded induction and all five covers pass. Properties
  compare against ripple recurrence, aggregate no-input generation, aggregate
  propagation and the external fourth-carry relation. No assumptions/reset
  needed, so the complete finite input space is proved.
- Yosys synthesis and `check -assert`: pass, 15 combinational cells,
  no storage, no warnings or errors.

The reconstructed contract is Am2902A's documented digital behavior. There
is no fabricated fourth carry-output pin, reset, or state. Actual analog
propagation delay and revision-specific electrical limits are outside scope.
The history date records 1975 public announcement; first-shipment month
remains unestablished rather than inferred from the later datasheet.
