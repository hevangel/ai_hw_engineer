# Ricoh RP2C02 / RP2C07 verification

## Contract and evidence

`ricoh_2c02.sv` is an original dot-level PPU model: background fetch
pipeline with shift registers, sprite evaluation including the hardware
overflow-flag bug, sprite-zero hit, loopy scroll registers, the `$2007`
read buffer, palette RAM, odd-frame dot skip (NTSC), vblank/NMI race
suppression and the per-bit I/O latch decay used
by open-bus reads. `REGION` selects 2C02 (262 lines, odd-frame skip) or
2C07 (312 lines, no skip). The [specification](../spec/spec.md) lists
sources and the assumption ledger.

## Results (2026-10-27)

Cloud container: Verilator 5.020, Yosys 0.33; formal through the same
local stand-in for SymbiYosys described in the 2A03 report, and no xezim.
The project Docker image run of `scripts/run_all.sh` is still owed.

| Gate | Measured result |
|---|---|
| Strict lint | `verilator --lint-only -Wall` passes for both regions |
| Directed testbench | 17 checks per region: frame and dot timing, odd-frame skip, vblank/NMI and the read-on-set-dot suppression, `$2005/$2006` latches, `$2007` buffer and palette mirroring, and a full scrolled frame with sprites (priority, flips, nine on a line) compared pixel for pixel against an independent reference renderer, plus sprite-zero hit and overflow |
| Formal | BMC and PDR proof at depth 16 PASS; 4/4 covers reached within 24 steps |
| Synthesis | Generic Yosys synthesis and `check` pass: 11,612 cells (NTSC), 11,574 cells (PAL) |
| Real software (NES system) | blargg `vbl_nmi_timing` (7), `ppu_vbl_nmi`, `sprite_hit_tests_2005` (11), `sprite_overflow_tests` (5), `oam_read`, `oam_stress`, `ppu_open_bus` and four of the five `blargg_ppu_tests_2005` pass; `nestest` renders its menu and results |

`ppu_open_bus` exposed the missing I/O latch decay; each latch bit now
decays after about 36 frames (NTSC) or 30 frames (PAL) unless refreshed,
writes drive all bits, `$2002` reads drive bits 7–5 and palette reads bits
5–0.

## Known differences

- `blargg_ppu_tests_2005/power_up_palette` compares palette RAM at power-up
  with the author's own console ("probably unique to my NES"); the model
  powers up with zeros.

## Remaining gates

Composite video generation (the host decodes palette indices in the
browser), colour emphasis signal levels, the EXT pins, and the RGB PPU
variants are not modelled.
