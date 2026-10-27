# Specification: Ricoh 2C02 / 2C07 (NES Picture Processing Unit)

## 1. Overview

The Ricoh RP2C02 (NTSC) and RP2C07 (PAL) Picture Processing Units generate
the NES picture: a 256×240 scrolling tile background and up to 64 sprites
(eight per scanline) drawn from a 14-bit video address space (pattern
tables, name tables, palette). The CPU sees eight registers at
`$2000`–`$2007` (mirrored through `$3FFF`) and the vertical-blank NMI.

`REGION` = `0` builds the 2C02 timing (262 lines, odd-frame dot skip),
`1` the 2C07 timing (312 lines, no skip, vblank NMI on line 241).

This design reproduces the documented digital behavior at dot level:
register semantics (including the shared `t`/`v` scroll registers, the
`w` toggle and the `$2007` read buffer), the background fetch/shift
pipeline, cycle-sequenced sprite evaluation with its overflow-flag bug,
sprite fetches, sprite-zero hit, priority, left-column clipping, palette
mirroring, grayscale and emphasis bits. The analog composite encoder is out
of scope: the chip emits the 6-bit palette index plus three emphasis bits per
dot, which the host converts to RGB.

## 2. Interfaces

All state is clocked by the master oscillator `clk` (21.477272 MHz NTSC,
26.601712 MHz PAL); `dot_ce` advances one PPU dot (master ÷ 4 NTSC, ÷ 5 PAL)
and `cpu_ce` marks the master edge that ends a CPU bus cycle.

| Port | Dir | Width | Description |
|---|---|---|---|
| `clk`, `rst_n` | in | 1 | Master clock, synchronous active-low reset |
| `dot_ce` | in | 1 | One PPU dot per pulse |
| `cpu_ce` | in | 1 | Last master edge of the current CPU cycle |
| `cpu_cs` | in | 1 | CPU cycle addresses `$2000`–`$3FFF` |
| `cpu_we` | in | 1 | 1 = write cycle |
| `cpu_addr` | in | 3 | Register select (A2–A0) |
| `cpu_wdata` | in | 8 | Write data |
| `cpu_rdata` | out | 8 | Read data latched at `cpu_ce` (stable until the CPU samples) |
| `nmi_n` | out | 1 | /NMI = !(vblank flag ∧ PPUCTRL.7) |
| `vram_addr` | out | 14 | PPU address bus (PA13–PA0) |
| `vram_rd`, `vram_we` | out | 1 | Read / write strobe for the current access |
| `vram_wdata` | out | 8 | Write data |
| `vram_rdata` | in | 8 | Data from CIRAM / cartridge CHR (combinational) |
| `pixel`, `emphasis` | out | 6, 3 | Output colour index and PPUMASK.7–5 for the current dot |
| `pixel_valid` | out | 1 | Dot is one of the 256×240 visible pixels |
| `scanline`, `dot` | out | 9 | Raster position (observability, host timing) |
| `frame_odd` | out | 1 | Odd-frame flag |

The real chip multiplexes PA7–PA0 with data (ALE) and reads with /RD over
two dots. This design keeps a non-multiplexed bus: each fetch drives its
address for two dots and samples `vram_rdata` at the end of the second.
Mapper logic watching PA12/PA13 sees the same address sequence.

## 3. Register map

| Addr | Name | Access | Behaviour |
|---|---|---|---|
| `$2000` | PPUCTRL | W | VPHB SINN: NMI enable, (master/slave ignored), sprite 8×16, BG table, sprite table, increment 32, `t[11:10]` ← NN. Enabling NMI while the vblank flag is set asserts /NMI immediately |
| `$2001` | PPUMASK | W | BGRs bMmG: emphasis B/G/R, show sprites, show BG, left-8 sprite/BG, greyscale |
| `$2002` | PPUSTATUS | R | VSO + 5 open-bus bits; read clears vblank and `w`. A read on the dot the flag is set returns 0 and suppresses that frame's flag/NMI |
| `$2003` | OAMADDR | W | OAM pointer |
| `$2004` | OAMDATA | RW | Write: OAM[ptr++] (ignored during rendering except pointer glitch-free increment is not modelled); read: OAM[ptr] (`$FF` during secondary-OAM clear); attribute bits 4–2 read 0 |
| `$2005` | PPUSCROLL | W×2 | First: `t[4:0]` ← D7–3, fine x ← D2–0; second: `t[9:5]` ← D7–3, `t[14:12]` ← D2–0 |
| `$2006` | PPUADDR | W×2 | First: `t[13:8]` ← D5–0, `t[14]` ← 0; second: `t[7:0]` ← D, `v` ← `t` |
| `$2007` | PPUDATA | RW | Access at `v`, then `v` += 1 or 32 (during rendering: coarse-X and Y increments instead). Reads below `$3F00` return the buffer and refill it; palette reads return directly (upper bits open bus) and refill the buffer from `v`−`$1000` |

Writes and reads to any register refresh the 8-bit I/O latch (open bus).
Each latch bit decays to 0 when it has not been driven for 36 frames
(30 on the 2C07), about 600 ms. Writes drive all eight bits; reads drive
only the bits the register returns (`$2002`: 7–5, palette reads: 5–0).

## 4. Frame timing

| | 2C02 NTSC | 2C07 PAL |
|---|---|---|
| Dots / line | 341 | 341 |
| Lines | 262 (0–239 visible, 240 idle, 241–260 vblank, 261 pre-render) | 312 (0–239 visible, 240 idle, 241–310 vblank, 311 pre-render) |
| Vblank set / NMI | line 241 dot 1 | line 241 dot 1 |
| Flags cleared | pre-render dot 1 | pre-render dot 1 |
| Odd frame | dot 340 of pre-render skipped when rendering enabled | no skip |

Background: in each 8-dot group of dots 1–256 and 321–336, fetch name
table (dots 1–2), attribute (3–4), pattern low (5–6), pattern high (7–8);
reload shifters at dots 9, 17, …, 257 and 329/337; coarse-X increment at
dots 8, 16, …, 256, 328, 336; Y increment at dot 256; horizontal `t`→`v`
copy at dot 257; vertical copy at dots 280–304 of the pre-render line;
dummy name-table fetches at 337–340.

Sprites: secondary OAM cleared to `$FF` at dots 1–64; evaluation dots
65–256 (OAM read on odd dots, secondary write on even dots, the
documented `n`/`m` overflow-search bug); OAMADDR forced to 0 during
257–320; eight 8-dot sprite fetches at 257–320 (two garbage name-table
reads, pattern low, pattern high). Empty slots fetch tile `$FF` and load
transparent shifters.

Pixel: background from the 16-bit pattern and attribute shifters at fine
x; first opaque sprite of the eight; sprite-zero hit when sprite 0 and the
background are both opaque, both enabled, dot ≠ 256 and outside a clipped
left column; priority bit selects BG over sprite. Rendering disabled outputs
the backdrop, or the palette entry at `v` when `v` points into `$3F00`–`$3FFF`.
Greyscale ANDs the index with `$30`.

## 5. Sources

- [NESdev: PPU registers](https://www.nesdev.org/wiki/PPU_registers),
  [PPU rendering](https://www.nesdev.org/wiki/PPU_rendering),
  [PPU frame timing](https://www.nesdev.org/wiki/PPU_frame_timing),
  [PPU scrolling](https://www.nesdev.org/wiki/PPU_scrolling),
  [PPU sprite evaluation](https://www.nesdev.org/wiki/PPU_sprite_evaluation),
  [PPU OAM](https://www.nesdev.org/wiki/PPU_OAM), [PPU palettes](https://www.nesdev.org/wiki/PPU_palettes),
  [PPU memory map](https://www.nesdev.org/wiki/PPU_memory_map),
  [PPU sprite priority](https://www.nesdev.org/wiki/PPU_sprite_priority),
  [Open bus](https://www.nesdev.org/wiki/Open_bus_behavior) — compiled from
  Visual 2C02 die simulation and hardware tests; the primary authority here.
- Real-software validation: blargg's freely distributed PPU test ROMs
  (`ppu_vbl_nmi`, `sprite_hit_tests_2005.10.05`, `sprite_overflow_tests`,
  `oam_read`, `vbl_nmi_timing`, `blargg_ppu_tests_2005.09.15b`) and
  `nestest`, run in the [NES system](../../system/nes/).

## 6. Assumption ledger

| Assumption | Evidence | Status |
|---|---|---|
| ASSUMPTION: register side effects occur at the last master edge of the CPU cycle (`cpu_ce`); read data is latched there | Real PPU samples on M2/`/CS` timing within the cycle | Model choice; validated by vblank/NMI timing ROMs |
| Non-multiplexed VRAM bus, data sampled on the second dot of each fetch | Same address sequence as ALE/RD bus | Documented simplification |
| `$2007` access while rendering is disabled performs its bus cycle on the next two dots; during rendering the pending access replaces the next fetch slot | Hardware performs it over following PPU cycles | Approximation |
| ASSUMPTION: I/O latch bits decay after 36 (NTSC) / 30 (PAL) frames without being driven | NESdev open-bus notes (~600 ms); blargg `ppu_open_bus` | Implemented; frame-granular |
| OAM decay, `$2004` writes during rendering, PAL OAM refresh during vblank and the 2C07 sprite-evaluation start delay are not modelled | NESdev OAM/PAL pages | Out of scope; documented |
| Odd-frame skip is decided at pre-render dot 339 from the current rendering-enable state | NESdev frame timing | Implemented |
