# IBM PC AT 5170 specification

Status: M1 (board skeleton) is merged: the unchanged BIOS ran 30
instructions and stopped at its first 8042 status read (`F000:00DE`); see
[the M1 report](../report/2026-11-13-m1-board-skeleton.md). M2 puts the
8042 and the MC146818 on the board: the BIOS now runs about 1.1 million
instructions, passes its own 8042 test and stops at `F000:068B`, a write
to port F1h, the first hardware not on the board; see
[the M2 report](../report/2026-11-14-m2-8042-and-rtc.md).
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
| Technical reference | IBM [PC AT Technical Reference, March 1984](https://bitsavers.trailing-edge.com/pdf/ibm/pc/at/1502494_PC_AT_Technical_Reference_Mar84.pdf), 1502494; SHA-256 `5114d7d84f0e1e50c7ad3edc806e0e9231634be8eeec1a3702616ea2d14197cc` | Primary hardware authority |
| Schematic | [IBM 5170 type-1 system board schematic](https://www.minuszerodegrees.net/misc/schematic_5170_motherboard_type_1.pdf) | Already cited by the 286 AT fixtures |
| BIOS | PCjs `machines/pcx86/ibm/5170/rom/bios/1984-01-10/ATBIOS-REV1.json5` at commit `1a91d38eb12e5fdf91116b21ad9ef1935710a496`; archive SHA-256 `3b1a6c8c…b2bde6`, extracted ROM SHA-256 `74e7b36b4ec0adc5ac3277a887579996c1d2aa755b9892ef3afe7485c10ce04f` | Pinned by `design/intel_80286/scripts/prepare_software.py`; downloaded into ignored `work/`, never committed |
| Keyboard controller firmware | IBM 8042 firmware part 1503033 for the 5170, rebuilt by `design/intel_mcs48/intel_8042/scripts/rebuild_1503033.py`; SHA-1 `0100f8789fb4de74706ae7f9473a12ec2b9bd729`, matching MAME's `1503033.bin` | Hash-verified; the image is written to an ignored work folder, never committed |
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
- 62 (1-44): 8042 input port, output port and test input definitions.
- Logic diagrams, "System Board (Sheet N of 22)" is PDF page 78+N: sheet 1
  (U94, U129, 82284 and Y2), 3 (U51), 5 (J18), 13 (U123), 16 (8259A IR1),
  17 (8042 U126), 18 (U115) and 22 (U105, U106).

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
| Interrupts | 2× `design/intel_8259` | Planned: master at 20h, slave at A0h on IRQ2; not wired yet (M3) |
| Keyboard controller | `design/intel_mcs48/intel_8042` (U126) | UPI-42 core running IBM firmware 1503033; on the board since M2 |
| Floppy | `design/intel_8272` | Plus the AT diskette adapter logic |
| Real-time clock and CMOS RAM | `design/motorola_mc146818` (U117) | On the board since M2; starts from `tb/cmos_configured.hex` |
| Board logic | 286 AT fixture modules: page registers and refresh page map, refresh path, port 61h, RAS trigger (bank select not yet wired) | Reused in place from `design/intel_80286/tb/` by `src/ibm_pc_at_5170.sv` |

### Missing designs

| Function | Tracking |
|---|---|
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
cited. The 8042 wiring is in the next section.

The board top composes the native 80286 (`intel_80286_native_cpu`)
directly, not through the 286 design's `intel_80286_at_refresh_timer_native`
fixture wrapper, so the board owns CPU reset, INTR and NMI. The timer,
port 61h, DMA, page-register and refresh modules are still the 286
design's AT models, reused in place.

### 8042 keyboard controller (U126)

The 8042 runs IBM's firmware 1503033 (decision D3). Wiring, from the
Technical Reference logic diagrams:

- Host bus (sheet 17): data XD0–XD7, A0 = XA2, -RD = -XIOR, -WR = -XIOW.
- Chip select: U123 (74ALS138, sheet 13) makes -PPI CS for I/O
  060h–07Fh from XA5–XA9. U115 (74S288 PROM, sheet 18) splits it using XA4
  and XA0 into -8042 CS, the port B read and write strobes and -NMI CS.
  See assumption AT8.
- P20 = RC. It goes through the shutdown flip-flop U105 and two more
  flip-flop stages to -SHT DWN (sheet 22), which U94 ORs with the 82284
  RESET at the 80286 RESET pin (sheet 1). It resets only the 80286. See
  AT7.
- P21 = A20 GATE: U129 (74F257, sheet 1) passes CPU A20 when P21 is high
  and forces the board A20 low when it is low.
- P24 = +OPT BUF FULL, wired straight to master 8259A IR1 (sheet 16).
- Keyboard clock: P26 through U120 (74ALS00 as an inverter) and U116 (7407,
  open collector) to KBD CLK, read back on T0. Keyboard data: P27 through
  U116 (7407) to KBD DATA, read back on T1. RN5 10K pull-ups on both lines
  (sheet 17).
- Input port: P10–P13 are not connected. P14 = -RAM SEL, jumper J18 with
  10K pull-up RN4 (sheets 17 and 5). P15 goes to a manufacturing-jumper pad.
  P16 = display switch SW1 to ground. P17 = +KBD INH from the keyboard-lock
  connector J20. P15–P17 have no external pull-up and rely on the 8042's
  internal ones. P22, P23 and P25 are not connected.
- Clock: the 12 MHz crystal Y2 on the 82284 (sheet 1) is divided by two by
  U51 (sheet 3) to the 6 MHz PCLK that drives the 8042's XTAL pins
  (sheet 17). One UPI-42 machine cycle is 15 crystal clocks (Intel UPI-41A
  User's Manual p. 2-10), so the board steps the 8042 once per 15 processor
  clocks.

Input port values (Technical Reference printed page 1-44, PDF page 62):
bit 7 keyboard inhibit switch (1 = not inhibited), bit 6 display switch
(1 = monochrome, 0 = colour), bit 5 manufacturing jumper (0 = installed),
bit 4 RAM on the system board (1 = enable 2nd 256K), bits 3–0 undefined.
The POST runner's configuration is keyboard unlocked, monochrome, no
manufacturing jumper, 512K enabled and no keyboard attached; the firmware's
reply to command C0h is FFh.

A different BIOS revision, dated 03/08/85 (published by VileR at int10h.org
with its ROM images), reads input-port bit 3 as an undocumented "640/X"
memory flag and uses it only to choose which parity signal to expect. On the
type-1 board P13 is unconnected, so bit 3 reads 1. This system uses the REV1
BIOS (01/10/84), which masks bit 3 off (`AND AL,F0h` at `F000:0602`).

### NMI mask and MC146818 (U117)

Sheet 18. The chip's AD0–AD7 are XD0–XD7. Decode PROM U115 makes -NMI CS
(to the NMI-mask flip-flop, sheet 3) and the chip's DS and R/W; AS comes
from the PROM through U110 and U80. On this board a write to port 70h
latches the CMOS address from data bits 5–0 and loads the NMI mask from
bit 7 (1 = masked); port 71h reads or writes the addressed location. See
assumption AT9.

- CE is low while POWER GOOD (through U108, MC14069).
- RESET (pin 18) and PS (pin 22) are tied to the battery-backed supply
  through R28 and C85, so a system reset does not reach the chip's RESET
  pin. The board ties both high.
- IRQ (pin 19) has a 10K pull-up and goes through inverter U107 to IRQ 8
  (sheet 16). It is an output of the board until the 8259s exist.
- OSC1 is driven by a 32.768 kHz crystal oscillator (Y3 with U108). SQW
  and CKOUT are not connected. See assumption AT12.
- Power-on contents: assumption AT11.

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
- ASSUMPTION AT4: no DMA channel requests service yet, so every DACK is
  inactive and only refresh selects a page-map slot.
- ASSUMPTION AT5: during a refresh grant the other bus masters release
  -MEMR/-MEMW and pull-ups hold them high (inherited from the 286 native
  BIOS fixture).
- ASSUMPTION AT6: RAM powers up as zero. Real DRAM contents are undefined.
- ASSUMPTION AT7: the CPU wrapper's two-stage RES synchronizer stands in for
  the U105/U106 flip-flop stages between RC and the 80286 RESET pin. The
  reset lasts while RC is low plus that delay. The same flip-flop's capture
  of an 80286 shutdown cycle (shutdown to CPU reset) is not wired yet, so a
  shutdown stops the run.
- ASSUMPTION AT8: the contents of decode PROM U115 are not published. The
  8042 is taken to answer at every even address 060h–06Eh (XA4 = 0,
  XA0 = 0), which contains its documented ports 60h and 64h, and port B at
  the odd ones. Address bits above XA9 are not decoded for the 8042.
- ASSUMPTION AT9: decode PROM U115 also serves 070h–07Fh and its contents
  are not published. A write to an even address 070h–07Eh is taken to
  strobe the MC146818's AS and to load the NMI mask from data bit 7; an
  access to an odd address 071h–07Fh strobes DS. A read of an even address
  is unclaimed. NMI is masked at power-up.
- ASSUMPTION AT10: the expansion slots are empty. A write to an I/O address
  of 100h or above that no board device decodes is accepted and counted
  (the BIOS writes 3B8h and 3D8h once each before the 8042 test). A read
  from such an address, and any unclaimed access below 100h, still stops
  the run.
- ASSUMPTION AT11: the MC146818 powers up from `tb/cmos_configured.hex`, a
  battery-good configuration record written for this model from the
  Technical Reference CMOS map (printed pages 1-45 to 1-52): 12:00:00 on
  Tuesday 14 August 1984, one high-capacity diskette drive, no fixed disk,
  monochrome primary display, no math coprocessor, 640K base memory, no
  expansion memory, valid checksum. It is not a dump of any machine.
- ASSUMPTION AT12: the clock's 32.768 kHz oscillator (Y3) is derived from
  the processor clock as 32,768 periods per 6,000,000 processor clocks.
  The real oscillator is independent of the system clock.

## Strict decoding

The board answers an I/O read only from a modeled device. The POST runner
stops at the first I/O read no device claims, at any unclaimed I/O access
below 100h and at the first memory access outside RAM and ROM; an unclaimed
write to 100h or above is accepted and counted (AT10). There is no
catch-all port array. The
286 design's AT fixtures use such an array; on that fixture the BIOS's
cold-boot test of the 8042 system flag (port 64h bit 2, `F000:00DE`)
reads 0 by default. Zero is the cold-boot answer, but no device supplied
it. On this board the same read was the M1 stop; the 8042 now supplies it.
The board's "undriven read" flag fired during the wait states of a read
whose device had not yet driven data (an M1 defect); it is now checked when
the read completes.

## Open decisions

- D1: machine profile for OS/2 (REV1 at 6 MHz versus rev3 at 8 MHz; RAM
  size; video adapter). OS/2 1.0's minimum memory and supported displays
  must be cited before this is settled.
- D2: video adapter for the first POST milestone (CGA from the PC system or
  MDA).
- D3 (resolved in M2, Option A): the 8042 is an MCS-48/UPI-42 core running
  IBM's original firmware 1503033, not a behavioral command model. The ROM
  image is rebuilt and hash-verified by
  `design/intel_mcs48/intel_8042/scripts/rebuild_1503033.py` (SHA-1 above).
  The alternative, a behavioral model, would have needed an independent
  oracle.

## Acceptance criteria

1. The unchanged REV1 BIOS completes POST with no error message. Its
   checkpoints and final screen agree with an independent machine (86Box
   `ibm_at`, run as a separate program, and PCjs).
2. PC DOS boots from diskette and runs DIR, file write and readback.
3. MS OS/2 1.0 reaches the command prompt and `CPGREP -yn fast ..\README`
   prints the same line as the PCjs baseline.
4. Lint, chip regressions, system simulation and synthesis pass, and the
   README shows a real panel and waveform screenshot.
