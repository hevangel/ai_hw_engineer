# Specification: Ricoh 5C78 (S-PPU2)

## 1. Overview

S-PPU2 generates the video timing and composes each line from the layer
pixels of S-PPU1. Sources: [fullsnes](https://problemkaputt.de/fullsnes.htm)
and the [SNESdev wiki timing page](https://snes.nesdev.org/wiki/Timing).

## 2. Features

- Timing: 1364 master clocks per line (1360 on the short NTSC line of
  non-interlaced odd frames, 1368 on the long PAL line), 262 lines NTSC or
  312 PAL, plus one line on alternate fields when interlaced; overscan (239-line)
  display; `line_start`, `hcount`, `vblank` and `field` for the board.
- Registers: INIDISP brightness and forced blank, CGADD/CGDATA with the
  write latch and read flip-flop, W12SEL-WOBJSEL, WH0-WH3, WBGLOG/WOBJLOG,
  TM/TS/TMW/TSW, CGWSEL/CGADSUB, COLDATA, SETINI, the latched H/V counters
  ($2137, $213C/$213D with their flip-flops) and STAT78.
- Composition: per-mode priority order, BG3 priority in mode 1, direct
  colour, two windows with OR/AND/XOR/XNOR logic, main/sub screen with
  window masks, colour math add/subtract/half against the sub screen or
  fixed colour, clip-to-black and prevent-math regions, pseudo high
  resolution and true 512-wide modes, master brightness.

## 3. Interfaces

| Port | Dir | Width | Description |
|------|-----|-------|-------------|
| `clk`, `rst_n` | in | 1 | Master clock and reset |
| B-bus group | | | As S-PPU1 (`b_addr`, strobes, data, `rdata`, `hit`) |
| `cpu_mdr` | in | 8 | CPU open bus, returned by the $2137 read |
| `wrio7`, `ext_latch` | in | 1 | Counter latch sources (5A22 WRIO bit 7, light gun) |
| `line_start`, `line`, `hcount`, `vblank`, `field`, `interlace_o`, `overscan_o` | out | | Timing |
| `px_x`, `px_bank`, `bg_px`, `obj_px`, `bgmode`, `hires_mode` | | | Layer port to S-PPU1 |
| `pix_valid`, `pix_x`, `pix_y`, `pix_rgb`, `pix_hires`, `frame_o` | out | | Video output, BGR555, row 0 is display line 1 |

## 4. Functional description

S-PPU1 renders line *N* into a line buffer during line *N*. S-PPU2
composes it during line *N+1* at line *N*'s dot times: pixel *x* at `hcount`
88 + 4*x* (two half pixels 2 clocks apart in high resolution). It reads
pixel *x* from S-PPU1, decides the main and sub screen pixels with the
window and priority rules using the registers captured at the start of line
*N*, applies colour math and brightness, and emits the pixel. Palette
lookups use a display copy of CGRAM that receives every CGRAM write exactly
one line (1364 clocks) late, so each pixel sees the palette as it stood
when hardware drew it, including writes made by DMA during active display.

In high resolution the left half of each pixel shows the sub screen. A
transparent sub-screen pixel shows the backdrop (CGRAM 0), and when colour
math applies it is blended with the previous main-screen pixel.

## 5. Assumption ledger

| # | Assumption | Reason / evidence |
|---|------------|-------------------|
| A1 | Window, colour-math and layer registers are captured once per line; dot-exact mid-line changes of those registers are not reproduced. | Same rendering model as S-PPU1; HDMA changes them in horizontal blank. |
| A2 | CGRAM writes reach the display copy one line late, and pixels are composed at their hardware dot times. | Reproduces Peter Lemon's HiColor tests, which rewrite CGRAM by DMA from an H-IRQ during display. |
| A3 | CGRAM writes during active display land at the written address. | Hardware redirects them to the address being displayed; no test depends on it. |
| A4 | The short NTSC line and the PAL long line follow the SNESdev wiki timing page. | Documented behaviour. |
| A5 | High-resolution sub-screen half: backdrop when transparent, blended with the previous main pixel; the first pixel of a line uses its own main pixel. | Matches the pseudo-hires HiColor screenshots except column 0 on some lines of two of them. |
