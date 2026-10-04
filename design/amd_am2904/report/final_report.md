# Am2904 verification report

Run on the repository `ai-hw-engineer:latest` image with Verilator5.052,
Yosys0.69, SymbiYosys, Z3 and ABC. Reproduce from repository root:

```sh
sh design/amd_am2904/scripts/run_all.sh
```

## Results

- Unsuppressed `verilator --lint-only -Wall`: PASS, no diagnostic waivers.
- Formal BMC depth8: PASS. ABC PDR unbounded proof: PASS. Cover depth8:
  PASS, all36 statements reachable (32 shift modes and four state/priority
  witnesses). No reset assumptions or restricted instruction inputs.
- Native simulation: **2,686,976 vectors / 26,874,382 pin and state checks**.
  All8192 instruction words across all256 U/M pre-states; all16 live status
  values across64 status operations and all pre-states; all64 CEU/CEM/per-bit
  enable combinations across64 operations and16 inputs; all32 shift modes,
  all16 serial pin patterns, both SE values and all pre-states, with normal
  machine enables forced disabled to check the documented shift exception.
- Original application procedures, PDF99: **256 two-load interrupt restores
  and256 one-level swap returns**. Explicit sticky-overflow and borrow-save/
  reinverted carry checks also passed. These are manufacturer's support-unit
  pin procedures, not an invented CPU program or instruction-set emulator.
- Yosys synthesis/check: PASS, **267 cells, eight enabled flip-flop bits**,
  no inferred latches and zero check problems. No Yosys warnings; ABC emits
  its informational combinational-network advisory during synthesis.

## Independence and limits

Golden functions are generated from separately authored manufacturer CSV
tables, not from RTL. Both pre-edge and post-edge combinational outputs are
checked; state is initialized and observed through native Y operations, with
no forced registers or debug ports. Interrupt/borrow/overflow tests separately
assert application semantics without consulting the golden functions.
The oracle generator has a staleness check in run_all.sh.

Specification assumptions are limited to settled digital pins and explicit
value/enable representation; electrical timing and bus contention are outside
the model. No exact commercial launch date has been established. There are no
known functional issues or unresolved implementation TODOs within this scope.
