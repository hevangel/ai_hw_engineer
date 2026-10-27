# Specification: Ricoh 5A22 (SNES S-CPU)

## 1. Overview

The 5A22 contains a 65C816 core and the SNES system logic: bus cycle
generator, DRAM refresh, 8 DMA/HDMA channels, NMI and H/V IRQ timer,
multiply/divide unit, joypad ports with auto-read, programmable I/O port
and the B-bus ($21xx) interface. `PAL` selects 312-line timing.

## 2. Interfaces

| Port | Dir | Width | Description |
|---|---|---|---|
| `clk`, `rst_n` | in | 1 | Master clock (21.477272 MHz NTSC, 21.281370 MHz PAL), reset |
| `a_addr`, `a_rd`, `a_wr` | out | 24, 1, 1 | A bus; strobes held for the whole access |
| `a_data_i`, `a_hit` | in | 8, 1 | A-bus read data; `a_hit` = a device drove it (else open bus) |
| `b_addr`, `b_rd`, `b_wr` | out | 8, 1, 1 | B bus (`$21xx`) |
| `b_data_i`, `b_hit` | in | 8, 1 | B-bus read data and drive flag |
| `data_o` | out | 8 | Write data (A or B bus) |
| `bus_ce` | out | 1 | Last master clock of the current access |
| `refresh_o`, `dma_o` | out | 1 | Refresh in progress; DMA/HDMA owns the bus |
| `mdr_o` | out | 8 | Open-bus latch (last value on the data bus) |
| `irq_n` | in | 1 | Cartridge /IRQ |
| `interlace_i`, `overscan_i` | in | 1 | From S-PPU2 SETINI, for frame length and vblank line |
| `vcount_o`, `hcount_o`, `field_o` | out | | Raster position (hcount in master clocks) |
| `wrio_o`, `rdio_i` | out/in | 8 | Programmable I/O port (`$4201` / `$4213`) |
| `jp_latch_o`, `jp1_clk_o`, `jp2_clk_o`, `jp1_d_i`, `jp2_d_i` | | | Controller ports (data in as 1 = pressed) |
| `cpu_*` | out | | Core observation |

## 3. Timing

All positions are in master clocks within a 1364-clock line (1360 on NTSC
line 240 of an odd non-interlaced field; 1368 on PAL line 311 of an odd
interlaced field). 262/263 (NTSC) or 312/313 (PAL) lines.

| Event | Position |
|---|---|
| CPU cycle length | 6 (internal, `$4000`–`$41FF` excluded, FastROM with MEMSEL), 8 (slow ROM, WRAM, `$0000`–`$1FFF`, `$6000`–`$7FFF`), 12 (`$4000`–`$41FF`) |
| DRAM refresh | 40 clocks starting at hcount 538, taken at the next CPU cycle boundary |
| HDMA init | line 0, hcount 12 |
| HDMA transfer | hcount 1104 on visible lines |
| NMI flag (`$4210`) | vblank line, hcount 2; cleared at line 0 hcount 2 or by reading |
| H-IRQ | hcount = HTIME·4 + 14; V-IRQ (V only) at hcount 10 |
| Auto joypad read | starts at vblank line hcount 130, 4224 clocks |
| DMA | aligned to an 8-clock boundary, 8 clocks overhead, 8 clocks per channel setup and per byte |

Multiplication takes 8 and division 16 CPU cycles (one step per CPU
cycle, results readable as they form).

## 4. Registers

`$4016/$4017` (manual joypad), `$4200` NMITIMEN, `$4201` WRIO, `$4202`–
`$4206` multiply/divide operands, `$4207`–`$420A` HTIME/VTIME, `$420B`
MDMAEN, `$420C` HDMAEN, `$420D` MEMSEL, `$4210` RDNMI, `$4211` TIMEUP,
`$4212` HVBJOY, `$4213` RDIO, `$4214`–`$4217` results, `$4218`–`$421F`
auto-read joypad data, `$43x0`–`$43xB/F` channel registers (`$43xC`–
`$43xE` open bus). Unmapped reads return the open-bus latch.

## 5. Sources

- [fullsnes](https://problemkaputt.de/fullsnes.htm): CPU registers, DMA/HDMA,
  timing, joypad (primary).
- [SNESdev wiki: Timing](https://snes.nesdev.org/wiki/Timing),
  [DMA registers](https://snes.nesdev.org/wiki/DMA_registers).
- Real-software validation: Peter Lemon's test ROMs
  ([PeterLemon/SNES](https://github.com/PeterLemon/SNES), revision `350b394e`)
  compared against the author's reference screenshots in `system/snes`.

## 6. Assumption ledger

| Assumption | Evidence | Status |
|---|---|---|
| Single master clock; the CPU cycle ends on `bus_ce` | Board-level abstraction | Model choice |
| HDMA pre-empts a running DMA between bytes; the DMA restarts with a fresh channel setup period | fullsnes DMA notes | Approximation (8 clocks longer than hardware) |
| Refresh is only inserted at CPU cycle boundaries, so a long DMA delays it | fullsnes says refresh also pauses DMA | Approximation; affects only cycle counts during DMA |
| H/V IRQ comparisons see the counters with a fixed offset (HTIME·4 + 14) | SNESdev timing notes | Implemented |
| The DMA A-bus/B-bus WRAM-to-WRAM case and the 5A22 version-1 HDMA/DMA crash are not modelled | fullsnes | Out of scope |
