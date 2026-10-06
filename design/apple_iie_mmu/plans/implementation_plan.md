# Apple IIe MMU implementation plan

1. **Spec** — pinout, switch map, mapping priority, interleave, reset state from TRM ch.4/6/7 plus AppleWin and the schematic-derived CC0 reimplementation (`spec/spec.md`).
2. **RTL** — one module `apple_iie_mmu` (`src/apple_iie_mmu.sv`): registered soft-switch state (C00x latch, C05x flags, C08x language-card register, C800 window, MPON shift register) updated on `clk`; combinational mapping (SELMB priority, PCASEN suppressions, ROM/window decode, CXXXOUT, KBD', MD7/MD7_OE, RW245) and the Table 7-9 RA row/column multiplexer with the `a[12] ^ bank1` bank remap.
3. **Formal** — `formal/apple_iie_mmu_props.sv` + cover setup included under `` `ifdef FORMAL ``: anyconst-address mapping agreement with the spec priority list, array mutual exclusion, no-RAM-in-$Cxxx, switch readback values, prewrite state machine, MPON sequence; bmc/prove/cover tasks in one `.sby`.
4. **Testbench** — `tb/tb_top.sv`: self-checking bench with an independent reference model written from the spec text; directed matrix over ranges x switch states, RA row/col checks, the language-card dances, MPON/6502 reset sequence, DMA and INH' cases, and historical switch sequences from the TRM Appendix I Monitor listing (reset init, AUXMOVE-style copy dance, slot-3 ROM test dance).
5. **Scripts** — lint (strict RTL + waived TB), formal (bmc/prove/cover), Verilator + xezim simulation with seeds, xezim code coverage with summarizer, Yosys synthesis, run_all.
6. **Report** — results, coverage gaps, assumption qualification (`report/`).

Verification order per AGENTS.md: lint → formal (bmc, prove, cover non-vacuity) → simulation → coverage → synthesis.
