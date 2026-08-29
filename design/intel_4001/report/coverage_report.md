# Functional Coverage Report: intel_4001

Generated: 2026-08-28

Source: one self-checking xezim run (directed + fixed-seed random).

## Enumeration achieved

| Dimension | Coverage |
|---|---|
| ROM addresses, chip 0 (mask A) | 256/256 (D2) |
| ROM addresses, chip 1 (mask B) | 256/256 (D3) |
| Addressed chips | 0, 1, 2 (absent) (D4) |
| SRC select targets | 0, 1, 2 + random 0-3 (D5-D9, random) |
| WRR data values | 0x0, 0x3, 0x5, 0xA, 0xC, 0xD, 0xF + random 0-F |
| RDR value sources | output latch bits + input pin bits (D8) |
| Reset | power-on, mid-fetch (M2), mid-WRR (X2) (D13) |
| CL clear | mid-run pulse after WRR (D14), CL through a full WRR cycle with the write suppressed (D15), random pulses |
| Ignored opcodes | NOP, WPM (idle and active), WRM, WMP, RDM, FF, 23 (D12) |

## Formal reachability covers

All 38 labeled reachability goals in
formal/intel_4001_cover.sv are reached by the SymbiYosys cover
task (smtbmc z3): 38 reached, 0 unreached. See
report/final_report.md for the recorded result.

## Result

4001 tb: 482958 checks, 2839 instruction cycles, 0 failures
TEST PASSED: 482958 checks, 2839 cycles
