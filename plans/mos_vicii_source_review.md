# MOS 6567/6569 VIC-II source review

Selects the reference for the [VIC-II design](../design/mos_6567/README.md)
and preserves disagreements between the two pinned implementations.
Written 2026-10-23 from unchanged sources; it is a reading of external
code, not a hardware measurement.

| Reference | Revision | Scope |
|---|---|---|
| MAME `src/devices/video/mos6566.cpp`/`.h` (BSD-3-Clause, Curt Coder) | `41a494b6ef80adc924ccb2bdba1ee69580276e0c` | 6566, 6567R56A, 6567R8, 8562, 8564, 6569, 8565, 8566: per-cycle bus/fetch logic and a per-dot display pipeline |
| floooh/chips `m6569.h` (zlib) | `9e88298ce56319953ac7a43213a1120359f7a3a6` | 6569 PAL only: per-tick fetch and eight-pixel decode |

Hashes are pinned by `design/mos_6567/scripts/fetch_vicii_reference.py`.

## Selection

MAME is the oracle. Its `execute_run()` performs one system clock of bus
work (refresh, matrix, character/bitmap, sprite pointer and data fetches,
BA/AEC, raster/light-pen interrupts), and `draw_until()` draws eight dots
per clock with explicit per-register visibility dots for CPU writes, an
NMOS/HMOS process table (mode-edge asymmetry, sprite multicolor flop,
grey dot, output lag, light-pen offset), an eight-dot collision lag, and
the variant raster tables (63 x 312 PAL, 65 x 263 6567R8, 64 x 262
6567R56A). The design compiles both MAME files unchanged against
project-authored framework stubs (`design/mos_6567/tb/mame_stubs`) and
compares every system clock and every pixel.

The [C64 Programmer's Reference Guide](https://archive.org/details/c64-programmer-ref)
(eighth printing, 1983) gives the manufacturer description of the
6566/6567: fourteen address outputs, character/bitmap fetches, refresh,
phase-two data access and the multiplexed address forms. It is the dated
primary description; it does not specify dot-level timing.

## Preserved disagreements (floooh/chips 6569, not implemented)

| Topic | MAME (implemented) | floooh/chips |
|---|---|---|
| Register write timing | Each register field becomes visible at a stated dot of the write cycle (colors at dot 0, CR1/CR2 mode bits with NMOS rise/fall asymmetry, X positions at phase two, many at cycle end) | Writes take effect immediately for the whole tick |
| Pixel pipeline | Per-dot sequencer, 3-dot (NMOS) / 4-dot (HMOS) output lag; color registers resolved at output | Eight pixels decoded per tick, no output lag |
| Collisions | Eight-dot lag ring; reads clear and suppress new collisions for twelve dots | Detected and latched in the decoded group |
| Sprites | Slot-relative halt/reload/resume dots, frozen hires pixel, MYE write merge at cycle 15 (sprite crunch) | Tick-based sprite units without slot-relative freezing |
| Mode changes | NMOS BMM/ECM fall lag and the character-ROM fetch-address glitch on BMM toggles | Not modeled |
| Variants | NTSC 6567R8/R56A and HMOS 8562/8565 tables | PAL 6569 only |
| Light pen | Process-dependent X offset; frame-start latch with $D1 | Not modeled in the same form |

## Requirements that remain open

- The physical chip multiplexes addresses (RAS/CAS) and drives DRAM
  refresh timing; the RTL exposes 14-bit phase-one and phase-two fetch
  addresses and the colour-RAM address instead.
- Composite luminance/chrominance and palette values are analog; the RTL
  outputs 4-bit color indices.
- VIC-IIe (8564/8566) extensions for the C128 (fast mode, keyboard lines)
  are excluded.
- Agreement with one emulator can hide shared misreadings. Original C64
  software with independently checked screen output, then hardware
  captures, are required before sign-off.
