## What this fixes

The socket test in `tb_rev0_wiring.sv` sampled read data at a fixed **+470 ns**
after the phi2 rising edge — 18 ns before the phase ends. Once the board carries
per-part datasheet delays (#94), the DRAM drives the bus at **+469 ns** (typical)
and **+472 ns** (maximum), so that sample landed **1–3 ns inside the valid
window**. The maximum-delay failure reported in #94 was therefore a harness
coincidence, not a board finding.

## Change

* Sample read data at the **phi2 falling edge**, which is where a 6502 latches
  it, instead of at an arbitrary early point.
* Print how long each DRAM bank took to drive the bus, so the margin is visible
  in the log rather than implied.
* `run_timing_sim.sh` now runs the socket test at **typical and maximum** delays,
  not typical only.

Phi2 high lasts 488.9 ns, so the measured margin is:

| Timing set | Data valid at | Margin |
|---|---|---|
| legacy (5 ns, checked in) | +429 ns | 60 ns |
| datasheet typical | +469 ns | 20 ns |
| datasheet maximum | +472 ns | 17 ns |

## Verification (Icarus 12.0-3, apple-ii image)

```
PASS revision-0 socket wiring at typ delays   (rows at +469 ns)
PASS historical Monitor boot at typ delays
PASS revision-0 socket wiring at max delays   (rows at +472 ns)
PASS historical Monitor boot at max delays
PASS datasheet timing gate: socket wiring and Monitor boot at typical and
     maximum delays; frame comparison stays on the legacy board
```

`run_board_sim.sh` with `SIMULATOR=iverilog` also passes on the legacy board
(arrivals +429 ns). `tb_rev0_boot.sv` is untouched, so the legacy pixel-exact
frame gate and the nine video diagnostics are unaffected.

## Still open, and now measured

The pixel-exact frame comparison stays on the legacy board. At datasheet delays
`composite_sync` is produced after a deeper gate chain than the counter outputs
the oracle derives it from, so comparing them at the same instant fails — and no
constant dot shift reconciles them (best agreement 70% of the frame across shifts
of −4…+4 samples). A delay-faithful video check needs an edge-time comparison,
not a per-dot sample. That is recorded in `report/final_report.md` and in the
gate's own summary line.

Refs #60 (P1). Follow-up to #94.
