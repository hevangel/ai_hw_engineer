# SNES specification

Status: implemented and verified in the cloud container (see the
[final report](../report/final_report.md)); the Docker image run is still
owed.

## Historical sources and provenance

- The Super Famicom launched in Japan on 21 November 1990 and the Super NES
  in North America in 1991 ([history](https://en.wikipedia.org/wiki/Super_Nintendo_Entertainment_System#History)).
  Year-level claims only.
- Board behaviour follows [fullsnes](https://problemkaputt.de/fullsnes.htm)
  (memory map, B bus, controllers, APU) and the
  [SNESdev wiki](https://snes.nesdev.org/wiki/Memory_map) (memory map,
  [timing](https://snes.nesdev.org/wiki/Timing)).
- Software: Peter Lemon's public-domain SNES test ROMs and demos
  (`PeterLemon/SNES` at revision `350b394e86ec5d62f600b5cbf64cdce3721bb6ef`)
  with the author's reference screenshots, fetched by
  `scripts/fetch_roms.py` and verified by git blob hash. ROM bytes live only
  in ignored `work/`.
- The S-SMP IPL boot ROM (64 bytes, Sony) is copyrighted. It is taken from
  a pinned snes9x source file by `design/sony_s_smp/scripts/fetch_ipl.py`,
  checked by SHA-256, kept in `work/` and loaded by the host at start-up.

## Hardware and integration

| Block | Implementation |
|---|---|
| Master clock | One `clk` at 21.477272 MHz (NTSC) / 21.281370 MHz (PAL), `PAL` parameter |
| CPU | [Ricoh 5A22](../../../design/ricoh_5a22/) with the [WDC 65C816](../../../design/wdc_65c816/) core; 6/8/12-clock memory cycles, DRAM refresh, DMA/HDMA, multiplier/divider, auto-joypad read |
| PPUs | [5C77 S-PPU1](../../../design/ricoh_5c77/) and [5C78 S-PPU2](../../../design/ricoh_5c78/) on the B bus at `$2100-$213F`; 64 KiB VRAM as 32K×16 with a render port and a CPU port |
| Work RAM | 128 KiB at banks `$7E-$7F`, mirrored at `$0000-$1FFF` of banks `$00-$3F`/`$80-$BF`; B-bus port `$2180-$2183` |
| APU | [S-SMP](../../../design/sony_s_smp/) (with the [SPC700](../../../design/sony_spc700/)) and [S-DSP](../../../design/sony_s_dsp/) sharing 64 KiB audio RAM; ports `$2140-$217F`. The APU's 24.576 MHz crystal is replaced by a phase accumulator on the master clock that gives exactly 1.024 MHz on average |
| Cartridge | LoROM and HiROM maps chosen from the header score, ROM up to 4 MiB (mirrored to a power of two), battery SRAM up to 128 KiB |
| Controllers | Two standard pads (16-bit shift registers) on `$4016/$4017` and the 5A22 auto-read |
| Reset | `por_n` (power) clears everything; `rst_n` alone is the reset button: CPU and APU reset, PPU registers, VRAM, work RAM and SRAM kept |

Storage is `snes_memory`, loaded from a `$readmemh` image that
`scripts/prepare_rom.py` builds; it is the blackboxed external interface in
the synthesis check. Its side-effect-free host port reads work RAM
(`$00xxxxx`), audio RAM (`$10xxxx`), VRAM bytes (`$20xxxx`) and SRAM
(`$30xxxx`).

## Host interface

`host/simulator.cpp` drives the Verilated board over a line protocol:
`STATE`, `RUN`, `FRAMES`, `RESET`, `PAD1`/`PAD2` (12 button bits),
`PEEK`/`MEM`, `SCREEN` (the last complete frame as 512×480 BGR555:
low-resolution pixels doubled, interlaced fields woven into alternate
rows, progressive lines doubled), `AUDIO` (the S-DSP's 32 kHz stereo
samples), `TRACE` (65C816 registers at each opcode fetch) and `CAPTURE`
(FST of the board for Surfer). `host/server.py` serves the web panel:
television canvas, controller 1 on the keyboard, sound, cartridge selection
with power cycle, board state and the waveform panel.

## Acceptance criteria

- Lint clean for both regions with `verilator --lint-only -Wall`.
- Every Peter Lemon ROM that ships a reference screenshot reaches a frame
  that matches it (every frame is compared; per channel within 10 of 255;
  a 256-wide or 224/239-line screenshot is compared with the matching
  columns or rows of the 512×480 frame). Screenshots that cannot be
  matched pixel for pixel are listed with evidence as REF, and open model
  differences as KNOWN with a bound on the difference. CPU and SPC700
  instruction tests never print FAIL; sound demos without a screenshot
  produce non-silent output.
- The backend API test passes and the board synthesizes with Yosys.

## Assumption ledger

| # | Assumption | Reason / evidence |
|---|------------|-------------------|
| A1 | The APU clock is derived from the master clock (1.024 MHz average, one-master-clock jitter) instead of its own crystal. | Keeps one clock domain; software cannot see the jitter except through CPU/APU race timing, which is not deterministic on hardware either. |
| A2 | The reset button does not reset the PPUs. | CPUMSC's reference screen needs the text and BG setup drawn before STP to survive the reset. |
| A3 | A DMA between the A bus and the work-RAM B-bus port gives the A side. | Hardware does not transfer in that case; no test depends on it. |
| A4 | Expansion port, coprocessor cartridges (SuperFX, SA-1, DSP-n) and the multitap are not modelled. | Out of scope. |
