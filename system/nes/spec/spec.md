# NES specification

Status: implemented and verified at board level (see the
[final report](../report/final_report.md)).

## Historical sources and provenance

- The Family Computer launched in Japan on 15 July 1983 and the NES in North
  America in 1985 ([history](https://en.wikipedia.org/wiki/Nintendo_Entertainment_System#History)).
  Year-level claims only.
- Board behaviour follows the NESdev wiki: [CPU memory map](https://www.nesdev.org/wiki/CPU_memory_map),
  [PPU memory map](https://www.nesdev.org/wiki/PPU_memory_map),
  [Cycle reference chart](https://www.nesdev.org/wiki/Cycle_reference_chart),
  [Standard controller](https://www.nesdev.org/wiki/Standard_controller),
  [Open bus](https://www.nesdev.org/wiki/Open_bus_behavior),
  [iNES](https://www.nesdev.org/wiki/INES), [NROM](https://www.nesdev.org/wiki/NROM),
  [MMC1](https://www.nesdev.org/wiki/MMC1), [UxROM](https://www.nesdev.org/wiki/UxROM),
  [CNROM](https://www.nesdev.org/wiki/CNROM), [APU mixer](https://www.nesdev.org/wiki/APU_Mixer).
- Software: freely distributed test ROMs (kevtris nestest with its
  Nintendulator log, blargg's CPU/PPU/APU suites) from
  `christopherpow/nes-test-roms`, fetched at a pinned revision by
  `scripts/fetch_roms.py` and verified by git blob hash. ROM bytes live
  only in ignored `work/`. Commercial games are not fetched; any mapper
  0–3 iNES file the user owns can be dropped into `work/roms/`.

## Hardware and integration

| Block | Implementation |
|---|---|
| Master clock | One `clk` at 21.477272 MHz (NTSC) / 26.601712 MHz (PAL), `REGION` parameter |
| CPU | [Ricoh 2A03/2A07](../../../design/ricoh_2a03/) on `cpu_clk` = master ÷ 12 / ÷ 16, generated on the master falling edge so the CPU and master-domain logic never sample each other mid-update |
| PPU | [Ricoh 2C02/2C07](../../../design/ricoh_2c02/) on `clk` with `dot_ce` = master ÷ 4 / ÷ 5; register access completes at `cpu_tick`, the master edge just before the CPU edge |
| Work RAM | 2 KiB at `$0000-$1FFF` (mirrored) |
| PPU registers | `$2000-$3FFF` (mirrored every 8) |
| APU / I/O | `$4000-$4017` inside the 2A03; `$4016/$4017` reads return D0 from the pads with D7-D5 from the open-bus latch and D4-D1 = 0 |
| Open bus | A board latch holds the last value driven on the CPU data bus |
| CIRAM | 2 KiB, A10 from the cartridge (header mirroring, or MMC1 control) |
| Cartridge | NROM (0), MMC1/SxROM (1, including SUROM 512 KiB), UxROM (2), CNROM (3); PRG ROM up to 512 KiB, CHR ROM/RAM up to 256 KiB, 8 KiB PRG RAM at `$6000` |
| Controllers | Two standard pads (4021 shift registers behind the console's inverting buffers) |
| Reset | `por_n` (power) clears everything; `rst_n` alone is the reset button: CPU, PPU and APU reset, cartridge and controller state kept, RAM kept |

Storage is `nes_memory`, loaded from `$readmemh` images that
`scripts/prepare_rom.py` builds from the iNES file; it is the blackboxed
external interface in the synthesis check. It also offers a side-effect-free
host peek port (work RAM, raw CIRAM, PRG RAM).

## Host interface

`host/simulator.cpp` drives the Verilated board over a line protocol:
`RUN`/`FRAMES`/`CYCLES`, `RESET`, `PAD1`/`PAD2`, `PEEK`/`MEM`, `SCREEN` (the
last complete 256×240 frame of palette indices), `AUDIO` (the NESdev
non-linear mixer evaluated every CPU cycle, averaged to 44.1 kHz), `TRACE`
(registers and cycle count at each opcode fetch) and `CAPTURE` (FST of the
whole board for Surfer). `host/server.py` serves the web panel: television
canvas with a browser-side NTSC palette decode, controller 1 on the
keyboard, sound, cartridge selection with power cycle, board state,
blargg `$6004` text, and the waveform panel.

## Acceptance criteria

1. nestest in automation mode matches every line of `nestest.log`:
   PC, A, X, Y, P, S and the CPU cycle count.
2. blargg's CPU, APU, APU-reset, PAL APU and PPU test ROMs report pass,
   or are listed in the report with the reason they do not.
3. Board testbench: clock ratios, frame period, nestest end state.
4. Backend test: controls, validation, screen/audio payload, ROM loading,
   waveform capture.
5. Strict lint in both regions and a synthesis check.
