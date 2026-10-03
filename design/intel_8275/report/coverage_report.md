# Intel 8275 coverage

Measured by Xezim on `tb_top.dut`, seed 2026, full 80-column instance:

| Metric | Covered / total | Percentage |
|---|---:|---:|
| Statements | 245 / 245 | 100.00% |
| Branch arms | 144 / 146 | 98.63% |
| Toggle bins | 462 / 516 | 89.53% |

Run `sh design/intel_8275/scripts/run_coverage.sh` to regenerate `work/coverage/rtl.json`. Counts are unadjusted; no denominator exclusions are hidden.

Two uncovered branch arms remain: the implicit default of a fully enumerated three-bit command case, and the implicit else of the guarded ordinary row-buffer write. The command default is structurally unreachable. The second is ruled out by the proved invariant `ack && !stop_pending && !replacement -> fill_count < columns`. Neither arm contains an untested implemented operation.

Toggle gaps include counters, coordinates and memory data bits not driven through every possible transition by the legal fixtures. These are not formally excluded or described as fully covered. Seeded geometry covers width/height extremes, but three seeds are not exhaustive over the timing/data space.

The dedicated UVM collector samples all 8/8 command bins and 4/4 HRTC×VRTC cross combinations. UVM coverage is separate from RTL code coverage. The pin suite additionally sweeps all 64 field bit combinations in visible and invisible modes, the eleven defined graphics across three underline regions, four cursor forms, all eight burst spaces and four burst lengths. The independent graphics vector generator reads only the archived external table, never the RTL.
