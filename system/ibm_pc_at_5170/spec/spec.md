# IBM PC AT 5170 specification

Status: specification draft for milestone M0. No system RTL exists yet.
Tracking issue: https://github.com/hevangel/ai_hw_engineer/issues/254

## Target

A 1984 IBM Personal Computer AT (model 5170), type-1 system board, running
the unchanged IBM AT REV1 BIOS dated 1984-01-10 on the repository's
`intel_80286` RTL. The end goal is to boot PC DOS and then Microsoft OS/2 1.0
and run the OS/2 SDK 1.00 `CPGREP.EXE` sample, matching the independent PCjs
baseline in
[`design/intel_80286/report/2026-10-27-os2-cpgrep-pcjs-replay.md`](../../../design/intel_80286/report/2026-10-27-os2-cpgrep-pcjs-replay.md).

The type-1 board and REV1 BIOS are chosen because the existing 286 AT
fixtures already model type-1 schematic parts (U118, U68, U95, U72, U96)
and run the REV1 BIOS. The PCjs OS/2 baseline used a later profile
(rev3 BIOS, 8 MHz, 2 MB, EGA). Before the OS/2 milestone, either the
baseline is repeated on a REV1 machine or the profile difference is
recorded as an assumption; see open decision D1.

## Historical sources and provenance

| Item | Source | Status |
|---|---|---|
| Introduction | IBM's [personal computer history](https://www.ibm.com/history/personal-computer) timeline places the PC AT in August 1984. The exact day (14 August 1984) appears only in secondary sources so far. | Month confirmed; day to be confirmed from an IBM announcement letter |
| Technical reference | IBM [PC AT Technical Reference, March 1984](https://bitsavers.org/pdf/ibm/pc/at/1502494_PC_AT_Technical_Reference_Mar84.pdf), 1502494 | Primary hardware authority |
| Schematic | [IBM 5170 type-1 system board schematic](https://www.minuszerodegrees.net/misc/schematic_5170_motherboard_type_1.pdf) | Already cited by the 286 AT fixtures |
| BIOS | PCjs `machines/pcx86/ibm/5170/rom/bios/1984-01-10/ATBIOS-REV1.json5` at commit `1a91d38eb12e5fdf91116b21ad9ef1935710a496`; archive SHA-256 `3b1a6c8c…b2bde6`, extracted ROM SHA-256 `74e7b36b4ec0adc5ac3277a887579996c1d2aa755b9892ef3afe7485c10ce04f` | Pinned by `design/intel_80286/scripts/prepare_software.py`; downloaded into ignored `work/`, never committed |
| Keyboard controller firmware | IBM 8042 ROM for the 5170 | Not yet sourced |
| OS/2 media | MS OS/2 1.0 install image and OS/2 SDK 1.00 Samples disk used by the PCjs baseline | Provenance recorded in the PCjs report; stays outside tracked paths |

Technical reference pages confirmed so far (PDF page numbers):

- 26–28: system timers, 8254-2 channel use, block diagram.
- 29 (System Board 1-11): hardware interrupt levels for the two cascaded
  interrupt controllers, and the ROM subsystem (two 32K×8 or four 16K×8
  devices in a 32K×16 arrangement, mapped at the top of the first and last
  megabyte).
- 30 (1-12): RAM subsystem (256K or 512K on the board, refresh requested
  by timer channel 1 about every 15 µs) and the two 8237A-5 DMA controllers.
- 31 (1-13): DMA page register addresses and address generation.
- 33 (1-15): I/O channel features (I/O space 100h–3FFh for adapters, 24-bit
  memory addresses).

Still to cite before RTL that depends on them: the system I/O address map,
the 8042 command set and output port (system reset and gate A20 bits), the
MC146818 CMOS map including the shutdown byte, the NMI mask at port 70h,
the 80287 ports, the CPU clock of the type-1 board, and the port 80h
manufacturing checkpoint convention.

## Hardware and integration

### Reused designs

| Function | Design | Notes |
|---|---|---|
| CPU | `design/intel_80286` | Native bus interface and 82288-style strobes already exist |
| Timer | `design/intel_8253_8254` (`IS_8254=1`) | Wired through `intel_80286_at_timer.sv` |
| DMA | 2× `design/intel_8237` | Cascade on controller 2 channel 0 |
| Interrupts | 2× `design/intel_8259` | Master at 20h, slave at A0h on IRQ2 |
| Floppy | `design/intel_8272` | Plus the AT diskette adapter logic |
| Board logic | 286 AT fixture modules: page registers, refresh path, port 61h, bank select, RAS trigger | To be promoted from `design/intel_80286/tb/` into system `src/` |

### Missing designs

| Function | Tracking |
|---|---|
| 8042 keyboard controller (MCS-48 core) and IBM firmware | ai_engineer#120 |
| MC146818 real-time clock and CMOS RAM | ai_engineer#121 |
| AT fixed-disk controller (port 1F0h) | Not tracked yet |
| Video adapter: CGA or MDA first, EGA later (ai_engineer#224) | CGA exists only inside `system/ibm_pc/src/ibm_pc.sv` and needs extraction |
| 80287 (optional) | ai_engineer#238 |

### Memory map (24-bit physical)

- 000000–09FFFF: base RAM (512K on the board plus 128K expansion for
  640K).
- 0A0000–0BFFFF: video buffer.
- 0C0000–0DFFFF: adapter ROM space.
- 0E0000–0FFFFF and FE0000–FFFFFF: system ROM. The 64K REV1 image lives in
  the top 64K of each alias. The CPU's reset fetch at FFFFF0h uses the
  upper alias.
- 100000 and up: expansion RAM. OS/2 needs memory above 1 MB; the amount
  follows decision D1.

### Clocks and reset

Reset comes from the 82284-style power-good path and from the 8042 output
port. OS/2 and the BIOS use the 8042 reset to return from protected mode,
with the CMOS shutdown byte choosing the restart path. Gate A20 comes from
the 8042 output port. Clock ratios between CPU, timer (1.19 MHz) and DMA
follow the existing fixture assumptions until the type-1 clock tree is
cited.

## Host interface

Follow the PC/XT pattern: Verilator simulator, Python web server, browser
panel with video, keyboard, power/reset/pause/step, diskette mount and
export, and a CPU/bus waveform. Host code must never intercept BIOS or DOS
interrupts.

## Assumptions

- ASSUMPTION AT1: functional bus timing. The CPU, DMA and timer run on
  integration clocks with documented ratios, not qualified 6 MHz package
  timing. This is inherited from the 286 AT fixtures.
- ASSUMPTION AT2: static RAM without parity errors. Refresh is modeled up
  to the signals the BIOS observes. DRAM decay is not modeled.
- ASSUMPTION AT3: diskette and fixed-disk media are decoded sectors, as in
  the XT system (XT2).

## Open decisions

- D1: machine profile for OS/2 (REV1 at 6 MHz versus rev3 at 8 MHz; RAM
  size; video adapter). OS/2 1.0's minimum memory and supported displays
  must be cited before this is settled.
- D2: video adapter for the first POST milestone (CGA from the PC system or
  MDA).
- D3: whether to build the 8042 from an MCS-48 core running IBM's 8042
  firmware, or as a behavioral command model. The first keeps the
  firmware-authenticity rule; the second needs an independent oracle.

## Acceptance criteria

1. The unchanged REV1 BIOS completes POST with no error message. Its
   checkpoints and final screen agree with an independent machine (86Box
   `ibm_at`, run as a separate program, and PCjs).
2. PC DOS boots from diskette and runs DIR, file write and readback.
3. MS OS/2 1.0 reaches the command prompt and `CPGREP -yn fast ..\README`
   prints the same line as the PCjs baseline.
4. Lint, chip regressions, system simulation and synthesis pass, and the
   README shows a real panel and waveform screenshot.
