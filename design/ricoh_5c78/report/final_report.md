# Ricoh 5C78 (S-PPU2) verification

## Contract and evidence

`ricoh_5c78.sv` is an original model of S-PPU2: NTSC and PAL video timing
with interlace and the short/long lines, CGRAM with its write latch,
the two windows and their logic per layer, main/sub screen designation and
window masking, layer priority for every mode including BG3 priority in
mode 1, colour math (add/subtract, halve, fixed colour, clip and prevent
regions), master brightness, the H/V counter latches and the status
registers. Pixels leave the chip at their hardware dot times, from a CGRAM
copy that receives writes one line late, so palette changes made by DMA
during display appear where hardware shows them. The
[specification](../spec/spec.md) lists sources and assumptions A1–A5.

The chip is verified on the [SNES board](../../../system/snes/) against
the reference screenshots of Peter Lemon's test ROMs (revision
`350b394e86ec5d62f600b5cbf64cdce3721bb6ef`); `scripts/run_test.sh` runs the
PPU subset.

## Results (2026-10-27)

Cloud container: Verilator 5.020, Yosys 0.33. Formal and coverage flows
were not run; the Docker image run of `scripts/run_all.sh` is still owed.

| Gate | Measured result |
|---|---|
| Strict lint | `verilator --lint-only -Wall` passes |
| Real software | 42 ROMs: 35 match their screenshot exactly, including the HiColor ROMs that rewrite the palette every line by DMA, the window and colour-math demos, and the high-resolution and interlaced pictures; 5 REF and 2 KNOWN (below) |
| Synthesis | Generic Yosys synthesis and `check -assert` pass: 43,888 cells (the 128-entry CGRAM write FIFO is flip-flops in the generic flow) |

## Known differences

- KNOWN: `HiColor64PerTileRowPseudoHiRes` and `mandrill64PerTileRowHiRes`
  differ from their screenshots only in column 0 on some lines (difference
  0.0005 of the picture). Column 0 is the first sub-screen half in
  pseudo-high resolution; with the palette rewritten by DMA every line, the
  hardware's choice of colour there is not yet understood. Blending it with
  the current main pixel, or with the previous line's last pixel, made
  other columns worse, so A5 keeps the first pixel blended with its own
  main pixel.
- REF: five screenshots cannot be compared pixel for pixel; see the
  [5C77 report](../../ricoh_5c77/report/final_report.md).

## Remaining gates

Window, colour-math and layer registers are captured once per line (A1).
CGRAM writes during display land at the written address instead of the
address being displayed (A3). No chip-level testbench, formal properties
or coverage closure exist yet.
