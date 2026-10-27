# Specification: Ricoh 5C77 (S-PPU1)

## 1. Overview

S-PPU1 holds the VRAM port, OAM and every background, sprite and Mode 7
register, and produces per-pixel layer data (four backgrounds plus sprites)
for S-PPU2. Sources: [fullsnes](https://problemkaputt.de/fullsnes.htm) PPU
chapters and the [SNESdev wiki PPU registers](https://snes.nesdev.org/wiki/PPU_registers).

## 2. Features

- B-bus registers $2101-$2133 (writes) and $2134-$213F (reads) owned by
  S-PPU1: OBSEL, OAM address/data, BGMODE, MOSAIC, BGnSC, BGnNBA, scroll
  registers with the shared previous-byte latch, VMAIN with address
  remapping, VRAM address/data with the prefetch read latch, Mode 7 matrix
  and centre, the signed 16×8 multiplier result ($2134-$2136), and STAT77.
- Background modes 0-7, 2/4/8 bits per pixel, 8×8 and 16×16 tiles, tile
  flips, priority bits, 32/64-tile maps, mosaic, offset-per-tile (modes 2, 4
  and 6), high resolution (modes 5 and 6) and Mode 7 with flips, wrap,
  transparent or tile-0 fill and EXTBG.
- Sprites: 128 entries, the eight OBSEL size pairs, name-table select and
  gap, flips, 32 sprites and 34 slivers per line with the range-over and
  time-over flags, OBJ interlace, and OAM priority rotation.
- CPU VRAM access only during vertical blank or forced blank.

## 3. Interfaces

| Port | Dir | Width | Description |
|------|-----|-------|-------------|
| `clk`, `rst_n` | in | 1 | Master clock (21.477 MHz NTSC), active-low reset |
| `b_addr`, `b_rd`, `b_wr`, `bus_ce` | in | 8,1,1,1 | B-bus address and strobes, valid for one clock at the end of the CPU cycle |
| `b_data_i` / `rdata`, `hit` | in/out | 8 | Write data; read data and "this chip drives the bus" |
| `vram_raddr` / `vram_rdata` | out/in | 15/16 | Render port into 32K×16 VRAM, one-clock registered read |
| `vram_caddr`, `vram_cwe_lo/hi`, `vram_cwdata`, `vram_cdata` | | | CPU port of the same VRAM |
| `line_start`, `line`, `vblank`, `field` | in | | Timing from S-PPU2 |
| `px_x`, `px_bank` | in | 10,1 | Pixel read address into the previous line's buffer |
| `bg_px` | out | 48 | Four 12-bit background pixels `{prio, pal[2:0], colour[7:0]}` |
| `obj_px` | out | 9 | Sprite pixel `{prio[1:0], pal[2:0], colour[3:0]}` |
| `mode_o`, `hires_o` | out | 8,1 | BGMODE and high-resolution flag for S-PPU2 |

## 4. Functional description

During line *N* S-PPU1 evaluates the sprites for that line, fetches the
sprite slivers, then each enabled background in turn (Mode 7 uses its
matrix per pixel), writing pixels into line-buffer bank `N & 1`. Mosaic
picks the source line here and the source column at the read port. S-PPU2
reads the other bank during line *N+1*. All fetches use the single render
port; a line's work completes well inside the 1364 master clocks of a line.

## 5. Assumption ledger

| # | Assumption | Reason / evidence |
|---|------------|-------------------|
| A1 | Rendering is line-based, not in lock-step with dot output. Register writes in the middle of a visible line take effect for the next rendered line, not at the exact dot. | HDMA writes during horizontal blank are the normal use and are reproduced; dot-exact mid-line effects are rare. |
| A2 | Scroll, tile-map and character registers are sampled at the start of the line being rendered. | Matches the effect of HDMA-driven scroll in Peter Lemon's HDMA tests. |
| A3 | OAM is not corrupted by writes during active display, and the OAM address reload at vblank start is modelled without the "OAM read during render" side effects. | Hardware corruption behaviour is poorly documented; no test software depends on it. |
| A4 | The VRAM read prefetch latch reloads one clock after the address write or the incrementing access. | fullsnes "VRAM read prefetch". |
| A5 | Open-bus bits of $2134-$213F come from the S-PPU1 data latch (`mdr`). | fullsnes "PPU1 open bus". |
