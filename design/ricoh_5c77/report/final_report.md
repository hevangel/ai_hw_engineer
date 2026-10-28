# Ricoh 5C77 (S-PPU1) verification

## Contract and evidence

`ricoh_5c77.sv` is an original model of S-PPU1: VRAM with its address
remapping, increment modes and read prefetch, OAM with the low/high table
write latch, the background scroll and tile registers, Mode 7 (matrix,
centre, flips, screen-over modes, EXTBG) and the signed 16×8 multiplier
read at `$2134-$2136`, the H/V latch, open bus, and pixel generation for
modes 0–7, offset-per-tile (modes 2, 4, 6), direct colour, high
resolution (modes 5 and 6, pseudo-hires), interlace, OBJ interlace,
mosaic and up to 32 sprites and 34 sprite slivers per line with the range
and time overflow flags. Each line is rendered into a line buffer while it
is scanned, from line-start copies of the scroll and Mode 7 registers; the
[5C78](../../ricoh_5c78/) composes it during the next line. The
[specification](../spec/spec.md) lists sources and assumptions A1–A7.

There is no chip-level testbench: the chip is verified on the
[SNES board](../../../system/snes/) against the reference screenshots that
ship with Peter Lemon's test ROMs (revision
`350b394e86ec5d62f600b5cbf64cdce3721bb6ef`). Every frame is compared with
the screenshot at the full 512×480 output resolution;
`scripts/run_test.sh` runs the PPU subset.

## Results (2026-10-27)

Cloud container: Verilator 5.020, Yosys 0.33. Formal and coverage flows
were not run; the Docker image run of `scripts/run_all.sh` is still owed.

| Gate | Measured result |
|---|---|
| Strict lint | `verilator --lint-only -Wall` passes |
| Real software | 44 ROMs: 37 match their screenshot exactly (BG maps in 2/4/8 bpp, tile flips, HiColor blends, 64/128-colour-per-tile-row HDMA, Mode 7 perspective, StarWars and HDMA, interlace with HDMA and OBJ interlace, mosaic in modes 3 and 5, windows, Rings, GreenSpace, plot demos); 5 REF and 2 KNOWN (below) |
| Synthesis | Generic Yosys synthesis and `check -assert` pass: 636,705 cells (VRAM, OAM and the line buffers are flattened into flip-flops by the generic flow) |

## Known differences

- REF: `InterlaceFont` and `InterlaceMoogle` screenshots were resampled or
  smoothed by the capture tool; `InterlaceScroll`, `RotZoom` and
  `WindowMultiHDMA` show a state the author reached with the joypad. They
  run without error but cannot be compared pixel for pixel.
- KNOWN: `HiColor64PerTileRowPseudoHiRes` and `mandrill64PerTileRowHiRes`
  differ only in column 0 on some lines (difference 0.0005); see the
  [5C78 report](../../ricoh_5c78/report/final_report.md).

## Remaining gates

Rendering is per line (A1), so register writes in the middle of a visible
line take effect on the next line instead of at the exact dot. OAM
corruption by writes during display is not modelled (A3). No chip-level
testbench, formal properties or coverage closure exist yet.
