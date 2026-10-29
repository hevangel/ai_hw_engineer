# VIC-II (6567/6569 family) specification

## Scope and evidence

`mos_6567` implements the digital VIC-II: 47 CPU registers, raster and
bad-line sequencing, matrix/character/bitmap/refresh/sprite fetches, BA and
AEC, raster/collision/light-pen interrupts, the graphics and sprite
sequencers, border unit, collision unit and pixel output. Behavior follows
the unchanged MAME model selected in the
[source review](../../../plans/mos_vicii_source_review.md); the C64
Programmer's Reference Guide (eighth printing, 1983, appendix N) is the
dated manufacturer description of registers, fetches and bus phases.

| `VARIANT` | Part | Clocks/line | Lines | Process traits |
|---:|---|---:|---:|---|
| 0 | 6569 PAL | 63 | 312 | NMOS |
| 1 | 6567R8 NTSC | 65 | 263 | NMOS |
| 2 | 6567R56A NTSC | 64 | 262 | NMOS, light pen raises no IRQ outside frame start |
| 3 | 8565 PAL | 63 | 312 | HMOS |
| 4 | 8562 NTSC | 65 | 263 | HMOS |

NMOS: BMM/ECM fall two dots after their rise, MCM fall one dot later in
ECM, character-ROM fetch glitch on BMM toggles, three-dot output lag,
light-pen X offset 2, idle fetch $38FF after a DMA delay. HMOS: CR1 mode
bits at phase two (rise) and one dot later (fall), sprite multicolor flop,
grey dot on color-register writes, four-dot output lag, offset 1, $3807.

## Clocking and interfaces

`clk` is the dot clock; eight edges form one system clock. After platform
initialization (`rst_n=0`) the first edge runs the cycle logic of cycle
14 on line 0. Each later system clock is: the *cycle edge*
(`cycle_edge_o`, `dot_o >= 7`), which draws the previous cycle's last dot
and then runs the new cycle's logic and fetches, followed by seven edges
drawing dots 0..6 of that cycle.

| Port | Meaning |
|---|---|
| `cs_i`, `rw_i`, `addr_i[5:0]`, `data_i` | CPU access for the current system clock; hold stable for its eight dots |
| `data_o` | Read data, valid from the fourth dot edge until the next cycle edge |
| `phi1_addr_o`, `phi1_data_i` | Phase-one fetch at every cycle edge (graphics, refresh, sprite pointer/data, idle) |
| `phi2_fetch_o`, `phi2_addr_o`, `phi2_data_i` | Phase-two matrix or sprite fetch while the VIC owns the bus (AEC low) |
| `color_fetch_o`, `color_addr_o`, `color_data_i` | 4-bit color RAM read with each bad-line matrix access, even while AEC is high |
| `ba_o`, `aec_o`, `irq_n_o` | Bus request, address-enable and interrupt outputs after the cycle edge |
| `lp_n_i` | Light-pen input sampled at the cycle edge |
| `rom_window_i` | Board: character ROM appears at VIC $1000-$1FFF (C64 banks 0 and 2) |
| `pixel_valid_o`, `pixel_o`, `pixel_row_o`, `pixel_col_o` | One 4-bit color index per dot after the output lag, with its raster row and dot column |

Write effects follow the reference: register state changes before dot 0
of the write cycle; display copies of each field change at the dot listed
by the reference (colors and CR1/CR2 low controls at dot 0, X positions at
dot 4, MDP/MXE at dot 2, MMC at dot 3 (NMOS) or 2 (HMOS), most others at
the next cycle's dot 0). Reads of $D019, $D01E and $D01F see the
collision/IRQ state after dot 3 and clear the collision register with a
twelve-dot suppression; other reads see the state after the cycle edge.

## Assumption ledger

- ASSUMPTION: `rst_n` is platform initialization equal to the reference's
  `device_start`/`device_reset` values; it is not the physical power-up
  state of a VIC-II, which has no reset pin.
- ASSUMPTION: a sampled per-cycle CPU access and per-cycle fetch ports
  stand for the multiplexed RAS/CAS address bus; both fetch data inputs
  are answered within the cycle edge.
- ASSUMPTION: the sub-cycle visibility dots, collision lag, output lag and
  NMOS/HMOS differences are taken from the pinned reference, which cites
  hardware test programs for some of them; they are not independently
  measured here.
- ASSUMPTION: unmapped fetches read whatever the board returns; open-bus
  and the CPU-visible last-fetch byte (`last_data_o`) follow the
  reference.
- Composite sync, luminance/chrominance, the palette and DRAM timing are
  analog/electrical and not modeled.
