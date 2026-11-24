# IBM PC AT 5170 specification

Status: M1 (board skeleton) is merged: the unchanged BIOS ran 30
instructions and stopped at its first 8042 status read (`F000:00DE`); see
[the M1 report](../report/2026-11-13-m1-board-skeleton.md). M2 puts the
8042 and the MC146818 on the board: the BIOS then ran about 1.1 million
instructions, passed its own 8042 test and stopped at `F000:068B`, a write
to port F1h, the first hardware not on the board; see
[the M2 report](../report/2026-11-14-m2-8042-and-rtc.md). M3 adds the two
8259As, the coprocessor ports and the shutdown-to-reset path: the BIOS now
runs about 16.7 million instructions and stops at `F000:1453`, a read of
port 1F7h (fixed-disk status) at POST checkpoint 3Ch, because no
fixed-disk adapter is fitted; see
[the M3 report](../report/2026-11-15-m3-interrupts-and-protected-mode.md).
M4a adds an I/O channel and an IBM EGA in a slot: the same stop is reached
after 18.2 million instructions with the system BIOS and the card's BIOS,
and the display shows the BIOS's memory count and two error lines; see
[the M4a report](../report/2026-11-16-m4a-io-channel-and-ega.md).
M4b part 1 adds a second machine top with the IBM VGA card (`design/ibm_vga`)
instead of the EGA: the same stop is reached after 16.3 million instructions
and the 720 x 400 display shows the same three lines; see
[the M4b part 1 report](../report/2026-11-16-m4b-vga.md).
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
| PC DOS 3.00 Disk 1 | PCjs `pcx86/sys/dos/ibm/3.00/PCDOS300-DISK1.json` at commit `cd3433748b09837a4c60ca7066f3642772b2d711`; blob SHA-1 `db4c0627c37d8e7ecd33b56dcdb1960a0c4da4c1`, 368,640-byte image SHA-256 `b3682877c0db8e2757b3c4d0b4a30af69e3f3827782f0fe5a385b9a1bde7d93f` | Pinned by `scripts/get_dos.py`; downloaded into ignored `work/`, never committed |
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
- 28–29 (1-10, 1-11): system interrupt levels, in decreasing priority.
- 46 (1-28): system I/O address map.
- 47 (1-29) and 104–105 (2-4, 2-5): coprocessor busy latch, IRQ 13 and the
  F0h and F1h ports.
- 181 (5-43): the BIOS listing that initializes both 8259As; 184–185
  (5-46, 5-47): its memory-size routine for RAM above 1 MB.
- Logic diagrams, "System Board (Sheet N of 22)" is PDF page 78+N: sheet 1
  (U94, U129, 82284, Y2, the 80286 and 80287 pins), 2 (82288 U83, -INTA),
  3 (U51, U118, U130, U85, U109), 5 (J18), 11 (U86), 13 (U123, U113),
  16 (U114, U125, 8254 OUT0), 17 (8042 U126), 18 (U115), 19 and 20 (I/O
  channel interrupt request lines) and 22 (U84, U105, U106).

Still to cite before RTL that depends on them: the 8042 command set and
output port (system reset and gate A20 bits), the MC146818 CMOS map
including the shutdown byte, the CPU clock of the type-1 board, and the
port 80h manufacturing checkpoint convention.

## Hardware and integration

### Reused designs

| Function | Design | Notes |
|---|---|---|
| CPU | `design/intel_80286` | Native bus interface and 82288-style strobes already exist |
| Timer | `design/intel_8253_8254` (`IS_8254=1`) | Wired through `intel_80286_at_timer.sv` |
| DMA | 2× `design/intel_8237` | Cascade on controller 2 channel 0 |
| Interrupts | 2× `design/intel_8259` | Master (U114) at 20h, slave (U125) at A0h on IRQ 2; on the board since M3 |
| Keyboard controller | `design/intel_mcs48/intel_8042` (U126) | UPI-42 core running IBM firmware 1503033; on the board since M2 |
| Video | `design/ibm_ega` | IBM Enhanced Graphics Adapter with 256 KB, in an expansion slot of the machine `ibm_pc_at_5170_ega.sv` only; since M4a |
| Video (VGA) | `design/ibm_vga` | IBM PS/2 Display Adapter (VGA) with 256 KB, in an expansion slot of the machine `ibm_pc_at_5170_vga.sv` only, as an alternative to the EGA; since M4b part 1 |
| Floppy | `design/intel_8272` | Plus the AT diskette adapter logic |
| Real-time clock and CMOS RAM | `design/motorola_mc146818` (U117) | On the board since M2; starts from `tb/cmos_configured.hex` |
| Board logic | 286 AT fixture modules: page registers and refresh page map, refresh path, port 61h, RAS trigger (bank select not yet wired) | Reused in place from `design/intel_80286/tb/` by `src/ibm_pc_at_5170.sv` |

### Missing designs

| Function | Tracking |
|---|---|
| AT fixed-disk controller and drive (port 1F0h) | Not tracked yet; the display machines have only the idle task file of the combined adapter (AT37); the bare board's run still stops at its status read at 1F7h |
| Keyboard (a device on the 8042's keyboard connector) | Modeled in the web/batch host (`host/at_keyboard.hpp`, 2026-11-17); the POST runner has none, so its runs report error 301 (its `--f1-at-post=3F` bench stimulus gets past the prompt) |

The diskette adapter row is no longer missing: see "Diskette adapter"
(the 8272 on the IBM Fixed Disk and Diskette Drive Adapter, since the
diskette milestone; no separate issue exists for it).
| 80287 (optional) | ai_engineer#238 |

The video adapter rows are no longer missing: the EGA is in the machine
`ibm_pc_at_5170_ega.sv` and the VGA card in `ibm_pc_at_5170_vga.sv` (see
"I/O channel and EGA" and "VGA machine"). CGA and MDA are not
modeled in this system; the CGA exists only inside
`system/ibm_pc/src/ibm_pc.sv`.

### Memory map (24-bit physical)

- 000000–09FFFF: base RAM (512K on the board plus 128K expansion for
  640K).
- 0A0000–0BFFFF: video buffer. In the EGA machine the card owns it (the
  channel passes it to the card); on the bare board it is unpopulated.
- 0C0000–0DFFFF: adapter ROM space. In the EGA machine the card's 16 KB
  ROM (IBM 6277356) answers at 0C0000–0C3FFF; the rest is unpopulated. In
  the VGA machine the card owns the 32 KB window 0C0000–0C7FFF, of which
  24 KB is ROM (the adapter BIOS).
- 0E0000–0FFFFF and FE0000–FFFFFF: system ROM. The 64K REV1 image lives in
  the top 64K of each alias. The CPU's reset fetch at FFFFF0h uses the
  upper alias.
- 100000 and up: expansion RAM. OS/2 needs memory above 1 MB; the amount
  follows decision D1. No memory card is fitted as of M3, so this range and
  all other memory outside the 640K RAM and the ROM is unpopulated; see
  AT14.

### Clocks and reset

Reset comes from the 82284-style power-good path, from the 8042 output
port and, since M3, from an 80286 shutdown cycle. OS/2 and the BIOS use
the 8042 reset to return from protected mode, with the CMOS shutdown byte
choosing the restart path. Gate A20 comes from the 8042 output port. Clock
ratios between CPU, timer (1.19 MHz) and DMA follow the existing fixture
assumptions until the type-1 clock tree is cited. The 8042 wiring is in
the next section; the interrupt controllers, coprocessor ports, shutdown
path and I/O bus conversion follow the MC146818 section.

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
  and forces the board A20 low when it is low. It gates every processor
  memory cycle, instruction fetches included. PC DOS 1.00 programs that use
  the CP/M-style entry at PSP:0005 (`CALL F01D:FEF0`, address 1000C0h;
  BASICA does, `scripts/run_dos_8086.sh`) reach DOS at 000C0h only because
  the BIOS leaves A20 GATE low after POST, as the 8086 wraps at 1 MB.
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
  (sheet 16). Since M3 it is the slave 8259A's IR0.
- OSC1 is driven by a 32.768 kHz crystal oscillator (Y3 with U108). SQW
  and CKOUT are not connected. See assumption AT12.
- Power-on contents: assumption AT11.

### Interrupt controllers (U114, U125)

Sheet 16 (PDF page 94), with the selects on sheet 13 and -INTA on sheet 2.
The 8259 design reused is `design/intel_8259`.

- Master U114 has SP/-EN pulled up by RN5; slave U125 has SP/-EN grounded.
  CAS0–CAS2 are wired pin to pin. The slave's INT is on the master's IR2,
  and the master's INT goes straight to the 80286 INTR pin (sheet 1).
- Chip selects come from U123 (74ALS138, sheet 13): -INTR1 CS for I/O
  020h–03Fh (master) and -INTR 2 CS for 0A0h–0BFh (slave), from XA5–XA9.
  A0 of each chip is XA0, so each chip answers throughout its 32-address
  block, even addresses as A0 = 0 and odd as A0 = 1. Reads and writes are
  qualified by -XIOR and -XIOW.
- -INTA comes from the 82288 (U83, sheet 2) to both chips. The vector
  returns on the XD bus through U113 (74ALS245, sheet 13), whose direction
  input turns it toward SD during -INTA, and then through the ordinary
  read path to the CPU data bus (sheet 2). See AT13.
- Master requests: IR0 = 8254 OUT0 (a direct wire, sheet 16), IR1 =
  +OPT BUF FULL from the 8042, IR2 = slave INT, IR3–IR7 = I/O channel
  IRQ 3–7 (sheet 20). Slave requests: IR0 = IRQ 8 from the MC146818
  (through U107), IR1 = IRQ 9 (sheet 20), IR2–IR4 = IRQ 10–12 and IR6–IR7 =
  IRQ 14–15 (sheet 19), IR5 = IRQ 13 from the coprocessor PAL U130
  (sheet 3). The schematic draws no pull-ups on the I/O channel request
  lines; see AT16.
- The BIOS (listing PDF page 181, printed 5-43) programs the master with
  ICW1 11h, ICW2 08h, ICW3 04h, ICW4 01h and the slave with ICW1 11h,
  ICW2 70h, ICW3 02h, ICW4 01h, then masks both with FFh.

### Math-coprocessor ports

Sheet 3 (PDF page 81) and sheet 13. U123 output Y7 (-CS287) selects I/O
0E0h–0FFh. PAL16L8A U130 decodes it with XA3, XA0 and -XIOW into the
busy-latch clear (write to F0h), +RESET 287 (write to F1h), -NPCS, -BUSY 286
and IRQ 13. Only -XIOW enters the PAL, so reads of F0h–F7h are not
decoded. +RESET 287 goes to the 80287 only; the 80286 is not reset by it.
The Technical Reference describes the busy latch and the two ports on
printed pages 1-29, 2-4 and 2-5.

No 80287 is fitted. The 80287 BUSY input has a 10K pull-up (RN4) and the
80286 ERROR pin has only a 10K pull-up, so the 80286 sees a coprocessor
that is not busy and has no error; IRQ 13 stays inactive. Both writes
have no effect. See AT17.

### Shutdown to CPU reset

Sheet 22 (PDF page 100). U84 (74ALS27) decodes the 80286 shutdown cycle
(A1, S1 and S0 low) and clocks flip-flop U105 with M/-IO as its data. U105
and two further stages (U105b, U106) drive -SHT DWN, the same net that the
8042's RC line presets, and U94 ORs it with the 82284 RESET at the 80286
RESET pin (sheet 1). Only the 80286 is reset. See AT7.

### I/O bus conversion

Every device on the system board is 8 bits wide, while the 80286 runs a
word I/O instruction (`OUT 82h,AX`) as one 16-bit cycle. The board holds
the processor not ready during a word I/O cycle and gives the devices two
byte cycles: the even address with the low byte, then the odd address with
the high byte. The BIOS depends on this at `F000:0C9A`, where one word
write sets page registers 82h and 83h. See AT15.

### NMI

NMI is not connected to the processor. On sheet 3, NMI = (I/O-channel-check
latch U109 OR parity latch U86 on sheet 11) AND NOT the mask flip-flop U118;
U118 is preset by reset, so NMI is disabled at power-up, which agrees with
AT9. With no parity logic and no I/O channel check modeled, neither source
can be active.

### I/O channel and EGA

Added in M4a. Source: `src/at_io_channel.sv` and
`src/ibm_pc_at_5170_ega.sv`; the board gained the output `mem_cycle_o`.

- The channel (`at_io_channel`) runs 8-bit device cycles for the
  expansion slots (AT18). It owns memory A0000h–DFFFFh and I/O at 100h and
  above that no board device decodes. A word memory access is two byte
  cycles. An I/O read that no board device answers takes its data from the
  host or the channel instead of reading 0.
- Reused design: [`design/ibm_ega`](../../../design/ibm_ega/), the IBM
  Enhanced Graphics Adapter with 256 KB of display memory. Its ROM (IBM
  6277356, 9/13/84) is fetched and hash-checked by
  `design/ibm_ega/scripts/get_rom.py` into the ignored `work/` folder.
- Memory map in this machine: A0000h–BFFFFh video memory (the card's
  planes); C0000h–C3FFFh the card's BIOS ROM.
- Interrupt: the card's IRQ2 goes to the board's IRQ 9, which is the
  channel's IRQ 2 pin on the AT (sheet 16).
- Card switches in the bench: SW1 off, SW2 on, SW3 on, SW4 off, which is
  the Enhanced Color Display as primary display in 350-line mode.
- CMOS image `tb/cmos_ega.hex`: equipment byte 01h (display with its own
  BIOS, one diskette drive) and checksum 00A3h. The bare board keeps
  `tb/cmos_configured.hex` (AT11).
- Clocks: assumption AT19. Pixels are rebuilt by the runner from the
  card's direct-drive monitor connector, active area only; the six bits
  are read as the 350-line 64-colour interpretation, and 200-line modes
  are not converted.
- The channel's timing is not the real board's (AT18) and the video clock
  ratio is virtual (AT19).

### VGA machine

Added in M4b part 1. Source: `src/ibm_pc_at_5170_vga.sv`; the board and
the channel are those of the EGA machine.

- Reused design: [`design/ibm_vga`](../../../design/ibm_vga/), the IBM PS/2
  Display Adapter with 256 KB of video memory, a DAC and the adapter BIOS
  ROM, fetched and hash-checked by `design/ibm_vga/scripts/get_rom.py`
  into the ignored `work/` folder. The card is enabled by the ROM through
  ports 46E8h and 102h (see the card's specification).
- Memory map in this machine: A0000h–BFFFFh video memory; C0000h–C7FFFh the
  card's 32 KB window, of which 24 KB is ROM.
- Interrupt: the card's IRQ2 goes to the board's IRQ 9, as for the EGA.
- A colour analog monitor is attached (`load_i` = 111).
- CMOS image: the same `tb/cmos_ega.hex` (equipment byte 01h, display with
  its own BIOS).
- Clocks: an extension of assumption AT19. The card needs a clock at least
  as fast as its 28.322 MHz oscillator, so its clock is twice the
  processor clock and stands for 48 MHz on the AT19 time base. The
  25.175 MHz and 28.322 MHz oscillators are clock enables from phase
  accumulators.
- The runner builds the frame from the DAC's 6-bit codes scaled to 8 bits
  per gun (`-DAT_VGA`). The regression is `scripts/run_post_card.sh vga`
  (wrapper `scripts/run_post_vga.sh`); `scripts/check_frame.py` reads the
  720 x 400 text with 9 x 16 cells from the ROM's 8 x 16 font.
- Limits beyond those of the EGA machine: graphics modes and the DAC are
  not exercised by the POST run, and the VGA ROM image could not be
  cross-checked against an IBM listing (see the card's README).

### DMA

Added with the diskette adapter. Source: `src/ibm_pc_at_5170.sv` ("DMA
and pages"). The board's two 8237A-5 are `design/intel_8237` instances
that move data; before, the 286 design's register-only fixture
(`intel_80286_at_dma.sv`) stood there and every DMA request was inactive.
Wiring, from the logic diagrams:

- Sheet 14 (PDF page 92): U111 (controller 1) serves the 8-bit channels
  0-3 with A0-A3 = XA0-XA3; U122 (controller 2) serves channels 4-7 with
  A0-A3 = XA1-XA4. U111's HRQ goes to U122's DREQ0 (channel 4 is the
  cascade) and U122's -DACK0 (-DACK4), inverted by U121, is U111's HLDA.
  U122's HRQ is HRQ1, its HLDA is HLDA1 (sheet 21). U101 latches XA8-XA15
  from XD0-XD7 on U111's ADSTB; U94 makes -AEN1 from U111's AEN; U96 ORs
  the two controllers' -EOP into T/C (sheet 20). The select decode is the
  fixture's (controller 1 at 000h-00Fh, controller 2 at the even addresses
  0C0h-0DEh).
- Sheet 21: HRQ1 enters the refresh/DMA arbiter (U69, U90) beside the
  refresh request; the arbiter holds the 80286 (HOLD/HLDA) and gives the
  DMA grant HLDA1. This arbiter is the 286 design's
  `intel_80286_at_refresh_arbiter`, whose `dma_request_i`/`dma_hlda_o`
  were tied off until now.
- Sheets 13 and 15: the page map (74LS612) selects its register from the
  DACK lines and -REFRESH; during a controller-1 transfer -DACK4 is active,
  so channel 2 uses register 81h, channel 3 82h, channel 1 83h and channel
  0 87h, as the BIOS programs them. The register's bits drive XA16 (through
  U79, enabled by -AEN1) and LA17-LA23. The page map drives the address
  during HLDA, ahead of the A20 gate of sheet 1, so a DMA address is not
  gated by the 8042's A20 GATE.
- Sheet 20: DRQ1-DRQ3, -DACK1-3, T/C and AEN are on the I/O channel; DRQ2
  is the diskette adapter's (Technical Reference, Fixed Disk and Diskette
  Adapter, PDF 628: "DMA request is level 2").

Host interface of a DMA transfer (new ports of `ibm_pc_at_5170`):
`dma_drq_i[3:0]` (DRQ0-DRQ3), `dma_io_rdata_i[7:0]` (the byte a device
drives during a DMA -IOR), `dma_mem_o` and `dma_mem_write_o` (a memory
transfer commits at the next rising clock edge: `address_o` holds its
24-bit address, `data_o` the byte to store on both lanes, or the host
supplies the byte on `mem_rdata_i` as for a CPU read), and the channel
side `dma_ior_n_o`, `dma_iow_n_o`, `aen_o`, `tc_o`, `dack_n_o[3:0]`. The
host performs a DMA memory transfer exactly like a CPU byte access (same
RAM, ROM and 640 KB map, and expansion RAM when fitted). Timing:
assumption AT25; scope: AT26.

### Diskette adapter

Added with the DMA. Source: `src/at_diskette_adapter.sv`, the diskette
function of the IBM Personal Computer AT Fixed Disk and Diskette Drive
Adapter, in a slot of both display machines (`src/at_system_unit.sv`).
From the Technical Reference section "Fixed Disk and Diskette Adapter":

| Port | Read | Write | Source |
|---|---|---|---|
| 3F2h | (none) | Digital output register: bit 0 drive select (0 = A), bit 2 -diskette function reset, bit 3 enable diskette interrupts and DMA, bit 4/5 drive A/B motor; cleared by a channel reset | PDF 611 |
| 3F4h | NEC uPD765 / Intel 8272 main status | (none) | PDF 612-613 |
| 3F5h | controller data (results) | controller data (commands) | PDF 612 |
| 3F7h | digital input register: bit 7 diskette change; bits 6-0 fixed disk | diskette control register: data rate, 00 = 500, 01 = 300, 10 = 250 kbit/s | PDF 611-612, 628; rate codes from the BIOS listing, PDF 228 |

- Interrupt level 6 and DMA level 2 (PDF 628). On the board IRQ 6 is the
  master 8259A's IR6 through the I/O channel (sheet 20, sheet 16).
- The controller is `design/intel_8272` with its decoded-media interface
  brought out to the drives; the drives and media are the host's
  (`tb/at_diskette_media.hpp`, assumption AT34).
- The drive cable (PDF 633) carries drive selects, motor on, direction,
  step, write data/gate, track 0, write protect, read data, side select and
  diskette change; there is no Ready line (AT31).
- The fixed-disk function is not modeled beyond the task-file registers
  1F1h-1F7h of an idle controller with no drive (AT37). They are needed:
  at checkpoint 3Ch the REV1 BIOS (F000:1453-147C) reads 1F7h until busy
  clears and then writes and reads back 55h and AAh at 1F4h; only if that
  works does it set HF_CNTRL bit 0 ("dual", 40:8Fh), and only with that
  flag does the diskette BIOS select the data rate per medium and use the
  change line (DSKETTE listing PDF 228-229). A first version without the
  task file (as the brief for this work proposed) booted nothing: the BIOS
  took the card for the diskette-only adapter, read at 250 kbit/s and found
  no ID on the 1.2 MB diskette (ST0 40h, ST1 05h). The data register 1F0h,
  the fixed disk register 3F6h, commands and IRQ 14 are not modeled; the
  CMOS images declare no fixed disk.
- The REV1 BIOS supports 320/360 KB and 1.2 MB diskettes and drives only
  (DSKETTE listing, PDF 227: "320/360K DISKETTE DRIVES AND 1.2M DISKETTE
  DRIVES SUPPORTED"); 720 KB and 1.44 MB are not modeled.
- CMOS byte 10h of `tb/cmos_ega.hex` declares drive A as high capacity
  (1.2 MB) and no drive B; the drive configuration the runner fits must
  agree with it. `tb/cmos_vga_2fd.hex` (used by `scripts/run_dos_8086.sh`,
  built in with `AT_HOST_CMOS`) declares drive A high capacity and drive B
  a 360 KB (48 TPI double-sided) drive, byte 10h = 21h, and two drives in
  the equipment byte 14h (bits 7-6 = 01), Technical Reference printed
  pages 1-45 to 1-52 (AT39). The host fits drive B with `--fdb-type=360`.
- The 5150's single-sided media, 160 KB (PC DOS 1.00) and 180 KB (PC DOS
  2.00), are accepted in either drive type as images recorded on side 0
  only (AT38). The REV1 BIOS reads and writes them as 320/360 KB media: in
  the 1.2 MB drive at 300 kbit/s with double stepping, in the 360 KB drive
  at 250 kbit/s.

The display machines' top modules keep their names and ports and add the
DMA and drive ports (`dma_mem_o`, `dma_mem_write_o`, `fd_*`); the board,
the I/O channel and the adapter are instantiated once, in
`at_system_unit`.

## Host interface

Follow the PC/XT pattern: Verilator simulator, Python web server, browser
panel with video, keyboard, power/reset/pause/step, diskette mount and
export, and a CPU/bus waveform. Host code must never intercept BIOS or DOS
interrupts.

Two hosts exist. The POST runner (`tb/post_runner.cpp`) is the regression
host: it supplies RAM, ROM and the mapping of unpopulated memory, writes
the trace and device logs for the oracles, and rebuilds one video frame
(`--frame`). It has no keyboard.

The web and batch host (`host/`, VGA machine only) was added on
2026-11-17; see
[the report](../report/2026-11-17-web-front-end-and-keyboard.md):

- `host/ibm_pc_at_5170_vga_host.sv` instantiates `ibm_pc_at_5170_vga`
  unchanged and adds read-only taps (retirement, CS, IP, flags, read data,
  8042 port 2). It is the top of the simulator and the waveform scope.
- `host/simulator.cpp` clocks the machine exactly as `post_runner.cpp`
  clocks the VGA machine in `scripts/run_post_card.sh` (no added wait
  states, the 8254 clock from OSC / 12 on the AT19 time base, two video
  clocks per processor clock, the same refresh acknowledge, memory map and
  open-bus rules, readable empty slots). Instead of ending a run, a
  condition that stops the regression (an unclaimed I/O cycle below 100h,
  an undriven read, a protocol error, a fault, an 8042 illegal opcode or a
  fetch from unpopulated memory) stops the machine and is reported. It has
  a line protocol for the web server and a batch mode that runs a fixed
  number of clocks while saving the latest frame, the frames that changed,
  the screen text and a status file.
- Memory size is chosen at start: 640 KB of base RAM plus `--ext-kb=N` KB
  of host RAM from 100000h (1408 for a 2 MB machine). It stands for a
  memory expansion card; no card's timing or decoding is modeled, and the
  CMOS image still records 640 KB.
- A keyboard model (`host/at_keyboard.hpp`) is on the keyboard connector;
  see "Keyboard" and AT20-AT24.
- `host/server.py` serves the page (`host/web/`): the monitor, power,
  reset, run and pause, status and speed, keyboard input and a waveform
  capture shown in the self-hosted Surfer, and the progress and saved
  frames of a batch run.
- Integration point for the diskette adapter branch: `simulator.cpp`
  includes `tb/at_diskette_media.hpp` when built with `-DAT_DISKETTE`,
  calls its per-clock DMA host service after the memory cycle and passes
  it the `--fda`/`--fdb` options. Nothing of the diskette is implemented
  here.

The host never intercepts BIOS interrupts: key input enters only as
keyboard line activity, and everything else is the RTL.

### Keyboard

`host/at_keyboard.hpp`, header-only so that the POST runner can use it
later. Sources: the Technical Reference, Section 4 (printed pages 4-3 to
4-16, PDF pages 117-130), and two commented disassemblies by A. Tarpai in
`external/halicery/8042`: the AT keyboard's own 8048 firmware 1503099
(`8048_AT_INTERN.TEXT`) and the 8042 firmware 1503033
(`8042_1503033.TXT`), which shows the timing the 8042 expects on T0 and T1.

- 11-bit frames, keyboard-clocked: start 0, eight data bits LSB first, odd
  parity, stop 1. Keyboard to system: data changes while the clock is high
  and is read on the falling edge; the system can abort by holding the
  clock low before the rising edge of the tenth clock, and the byte is
  sent again later. System to keyboard: on a request-to-send (clock high,
  data low) the keyboard clocks ten bits in, sampling while the clock is
  high, then pulls data low for the eleventh clock as the acknowledge.
- Inhibit: nothing is sent while the system holds the clock low; codes
  wait in a 16-entry FIFO with the overrun code 00h in position 17.
- Commands, following the 8048 firmware's mode register: FFh Reset (ACK,
  then after the clock is released the BAT and AAh), FEh Resend (the last
  byte other than FEh), EEh Echo, EDh Set/Reset Mode Indicators (ACK,
  option byte, ACK), F3h Set Typematic Rate/Delay (ACK, parameter with bit
  7 clear, ACK), F4h Enable, F5h Default Disable, F6h Set Default, the
  NOPs EFh-F2h and F7h-FDh (ACK); a parity error or any other byte gets
  FEh. A pending reply is dropped when the system sends a new byte.
- Scan code set 2 make codes for the 84-key keyboard (one byte each; F7 is
  83h, SysRq 84h), F0h break prefix, typematic repeat of the last key
  pressed with delay (1 + bits 6-5) x 250 ms and period (8 + A) x 2^B x
  4.17 ms; a repeat is queued only when the FIFO is empty.
- The 8042 translates set 2 to set 1 for the BIOS (command byte XLAT),
  which the keyboard test checks at port 60h.

## Assumptions

- ASSUMPTION AT1: functional bus timing. The CPU, DMA and timer run on
  integration clocks with documented ratios, not qualified 6 MHz package
  timing. This is inherited from the 286 AT fixtures.
- ASSUMPTION AT2: static RAM without parity errors. Refresh is modeled up
  to the signals the BIOS observes. DRAM decay is not modeled.
- ASSUMPTION AT3: diskette and fixed-disk media are decoded sectors, as in
  the XT system (XT2).
- ASSUMPTION AT4 (retired with the diskette adapter): no DMA channel
  requested service, so every DACK was inactive and only refresh selected
  a page-map slot. The DACK lines now drive the page map (see "DMA").
- ASSUMPTION AT5: during a refresh grant the other bus masters release
  -MEMR/-MEMW and pull-ups hold them high (inherited from the 286 native
  BIOS fixture).
- ASSUMPTION AT6: RAM powers up as zero. Real DRAM contents are undefined.
- ASSUMPTION AT7: the CPU wrapper's two-stage RES synchronizer stands in for
  the U105/U106 flip-flop stages between RC and the 80286 RESET pin. The
  reset lasts while RC is low plus that delay. Since M3 the same flip-flop's
  capture of an 80286 shutdown cycle is wired: a shutdown resets the
  processor through the same path. The reset ends when the processor's reset
  clears its shutdown state; the real pulse length depends on SDCLK
  (sheet 15), which was not traced.
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
  (the BIOS writes 3B8h and 3D8h once each before the 8042 test, and later
  the other video and diskette ports). A read from such an address, and any
  unclaimed access below 100h, still stops the run; since M3 that is the
  stop, at the read of port 1F7h.
- ASSUMPTION AT11: the MC146818 powers up from `tb/cmos_configured.hex`, a
  battery-good configuration record written for this model from the
  Technical Reference CMOS map (printed pages 1-45 to 1-52): 12:00:00 on
  Tuesday 14 August 1984, one high-capacity diskette drive, no fixed disk,
  monochrome primary display, no math coprocessor, 640K base memory, no
  expansion memory, valid checksum. It is not a dump of any machine.
- ASSUMPTION AT12: the clock's 32.768 kHz oscillator (Y3) is derived from
  the processor clock as 32,768 periods per 6,000,000 processor clocks.
  The real oscillator is independent of the system clock.
- ASSUMPTION AT13: each interrupt-acknowledge cycle gets one wait state. The
  8259 model samples -INTA on the clock and needs one clock to put the
  vector on the bus; the real 8259A answers inside the cycle.
- ASSUMPTION AT14: no memory card is fitted, so memory outside the 640K RAM
  and the ROM is unpopulated. The schematic has no pull-ups or bus-hold on
  any data bus (sheets 1, 2, 6, 8–11, 13, 15–17, 19, 20), so an undriven
  read is electrically undefined; the runner returns FFh. A write there is
  ignored and counted; an instruction fetch from there stops the run. The
  BIOS's memory sizing only needs the value to differ from what it wrote.
- ASSUMPTION AT15: in the I/O bus conversion the two byte cycles are
  separated by one clock with no device selected; the conversion logic's
  own timing is not modeled.
- ASSUMPTION AT16: the I/O channel interrupt request lines have no pull-ups
  on the schematic (sheets 16, 19, 20); with no adapter they are taken as
  inactive (0).
- ASSUMPTION AT17: the equations of PAL U130 are not published; the
  coprocessor writes are decoded at F0h and F1h, and (since the diskette
  milestone, when the BIOS first runs past checkpoint 40h and executes
  FNINIT) -NPCS at F8h-FFh, the 80286's processor-extension ports, where an
  ESC instruction writes its opcode and operand pointer. No 80287 is
  fitted, so those writes reach nothing and no operand moves (PEREQ is
  never asserted); the BIOS's FNSTCW leaves its memory word unchanged and
  the BIOS finds no coprocessor. The Unicorn replay treats ESC instructions
  the same way (no_coprocessor; Unicorn's x87 is not used).
- ASSUMPTION AT18: I/O channel cycles for 8-bit cards (`at_io_channel.sv`)
  are one clock of address setup, four clocks of command and one clock of
  hold per byte; a word memory access to a card is two such byte cycles,
  low byte first. The board's real command timing and default wait states
  for 8-bit devices are not modeled clock for clock, and I/O CH RDY is not
  used. The channel owns memory A0000h-DFFFFh and unanswered I/O at 100h
  and above; a byte no card drives reads FFh (AT14).
- ASSUMPTION AT19: in the machine with a video card
  (`ibm_pc_at_5170_ega.sv`) the card's clock runs at the processor clock's
  rate and stands for 24 MHz; the channel's 14.31818 MHz OSC, the card's
  16.257 MHz crystal and the 8254 clock (OSC / 12) are derived from it, so
  video and the timer keep their real ratio to each other. The processor
  clock is therefore four times faster relative to them than the real
  6 MHz. Reason: the 80286 model is not cycle accurate (it needs about
  17 clocks per instruction in this BIOS, a real 80286 about a quarter of
  that), and the EGA BIOS's self-test counts display-enable pulses per
  frame by polling Input Status 1; at the real ratio the model polls too
  slowly and miscounts (224 of 350). The 8042 and the MC146818 keep the
  board's processor-clock ratios (AT1), so they run four times fast
  relative to video. Nothing here is IBM AT physical timing.
- ASSUMPTION AT20: the keyboard model's time base is the 8042's: 6
  processor clocks per microsecond, the board's real ratio (AT1). The
  keyboard talks only to the 8042, so their timing keeps its real
  relation; like the 8042 the keyboard runs four times fast relative to
  video and the 8254 (AT19). Typematic delay and rate use the same base.
- ASSUMPTION AT21: the Technical Reference gives no keyboard clock
  frequency. Each clock phase lasts 40 us (12.5 kHz). The lines must be
  idle (both high) for 100 us before the keyboard starts sending, and a
  request-to-send must be stable for 100 us before it clocks a byte in.
  The 8042 firmware allows a whole received byte 1,024 machine cycles
  from its first falling edge, each transmitted bit 160, and the first
  clock of a transmission 8,192, so these values are well inside its
  timeouts.
- ASSUMPTION AT22: power-on reset 300 ms and BAT 600 ms, the minimum of
  each range on printed page 4-4 (300 ms to 9 s and 600 to 900 ms); after
  a Reset command only the BAT runs. The keyboard treats its ACK of Reset
  as accepted once the clock line is released, as the 8048 firmware does
  (00B5-00BB), not after the 500 us of clock and data high that page 4-5
  asks of the system.
- ASSUMPTION AT23: a key change is sensed immediately: no matrix scan
  time, debounce, triple sensing or sense-amplifier test, so the keyboard
  never reports FDh. Key events from scripts and on-screen buttons are
  applied 30 ms apart (180,000 processor clocks on the AT20 base).
- ASSUMPTION AT24: if the system holds the clock low while the keyboard
  is clocking a byte in, the keyboard abandons that byte. The Technical
  Reference describes contention only for keyboard output.
- ASSUMPTION AT25: both 8237s are clocked by the processor clock, not the
  half-rate DMA CLK of sheet 3, and their READY (DMA RDY, sheet 15) is tied
  active, so a DMA transfer is the 8237 core's S1-S4 states (S1 only after a
  low-byte carry) plus arbitration, with no wait states; the board's I/O
  and memory command timing for DMA cycles is not modeled. A transfer
  commits in one clock (`dma_mem_o`), at which the host performs the
  memory side. The arbiter of sheet 21 is the existing model (AT5).
- ASSUMPTION AT26: only controller 1 moves data. No 16-bit DMA device is
  modeled, so DRQ5-DRQ7 are inactive and controller 2 only cascades;
  DRQ0, DRQ1 and DRQ3 have no device either. DMA to the I/O channel's
  memory (A0000h-DFFFFh) is not routed; a DMA transfer outside RAM is
  counted and ignored by the runner and rejected by the oracle.
- ASSUMPTION AT27: the diskette adapter's controller and the drives keep
  time on the board's 6 MHz processor-clock base, like the 8042 and the
  MC146818 (AT1, `CLK_HZ` = 6,000,000): a controller microsecond is six
  processor clocks, a 1.2 MB drive turns once per 1,000,000 clocks
  (360 rpm), a 360 KB drive once per 1,200,000 (300 rpm), and a byte at
  500, 300 and 250 kbit/s takes 96, 160 and 192 clocks. Against video
  (AT19) the diskette therefore runs four times fast, and the BIOS's
  software timing loops, which the slower processor model stretches, see a
  drive about four times faster than a real one. The controller's timers
  use the Intel 8 MHz values (CLOCK_SCALE 1) at every data rate; the
  Technical Reference's doubled HLT/HUT/SRT units for the 250 kbit/s drive
  (PDF 615) are not modeled.
- ASSUMPTION AT28: the adapter decodes SA0-SA9 with AEN low; its ports
  alias every 400h.
- ASSUMPTION AT29: RESET DRV also clears the data-rate register
  (500 kbit/s); bits 7-2 of a 3F7h write are ignored.
- ASSUMPTION AT30: a drive's select line on the cable is active when the
  DOR selects it and its motor enable bit is set (as on the IBM PC
  diskette adapter); the BIOS always sets both together.
- ASSUMPTION AT31: with no Ready line on the cable (PDF 633) the
  controller's READY input is always active, as on the IBM PC adapter; its
  two-side and fault inputs are inactive. The selected drive's track 0 and
  write-protect lines reach the controller for every unit number, and any
  unit's step pulse steps the selected drive.
- ASSUMPTION AT32: DRQ2 and IRQ 6 are the controller's DRQ and INT gated by
  DOR bit 3; a gated line is inactive (low, AT16). The controller's TC is
  the channel's T/C while -DACK2 is active. The adapter's logic diagrams
  (PDF 635-642) were not traced at a readable resolution.
- ASSUMPTION AT33: digital-input bit 7 reads 1 while the selected drive's
  change line is active; with no fixed-disk function, bits 6-0 read 1.
- ASSUMPTION AT34: the drives and media of `tb/at_diskette_media.hpp`:
  decoded sectors (AT3), IDs 1..SPT in order with N = 2 and no CRC
  errors, readable only at the medium's data rate (1.2 MB medium in a
  1.2 MB drive at 500 kbit/s, 360 KB medium in a 1.2 MB drive at 300, in
  a 360 KB drive at 250); a 360 KB medium in a 1.2 MB drive has its tracks
  at the even head positions; the disk is at speed as soon as its motor bit
  is set; the change line is active at power-on and after a medium change
  and is cleared by a step pulse to the selected drive while a medium is
  inserted.
- ASSUMPTION AT35: expansion RAM (runner option `--ext-kb`) is plain RAM
  from 100000h, served by the host like base RAM, powering up as zero
  (AT6); it stands for an IBM memory expansion card, whose own timing and
  parity are not modeled.
- ASSUMPTION AT36: the 80287 socket is empty. On sheet 1 (PDF page 79)
  the socket's ERROR (26), BUSY (25), PEACK (36) and PEREQ (24) pins are
  wired to the 80286's ERROR, BUSY, PEACK and PEREQ; -BUSY 286 comes from
  PAL U130 (sheet 3) and BUSY/ERROR have 10K pull-ups (AT17, RN4). No
  pull-down on PEREQ is legible on the scan, so with the socket empty
  PEREQ is taken as inactive (low): an ESC instruction's operand never
  moves. Reads of F8h-FFh return the undriven bus (FFh, AT14); the runner
  counts accesses to F8h-FFh (`npx_port_accesses`) instead of stopping.
- ASSUMPTION AT37: the fixed-disk function with no drive attached is an
  idle controller after its power-on diagnostics: status 1F7h reads 00h
  (not busy, drive not ready, no seek complete, no error), the error
  register 1F1h reads 01h (diagnostic code "no errors", PDF 602-603),
  1F2h-1F6h read back what was written, and commands, the
  write-precompensation register, the data register 1F0h, the fixed disk
  register 3F6h and IRQ 14 have no effect. The real controller's status
  with no drive cabled was not found in the documents.

- ASSUMPTION AT38: a single-sided image (163,840 bytes, 40 x 1 x 8 x 512;
  184,320 bytes, 40 x 1 x 9 x 512) is a diskette recorded on side 0 only.
  With head 1 selected no ID is found (the controller reports a missing
  address mark, as for an unrecorded side) and writes and format bytes for
  head 1 are dropped. A real single-sided diskette in a double-sided drive
  may have a usable second side; the DOS 1.00 and 2.00 workloads never
  select head 1 on these media (DOS treats them as one-sided by their FAT
  media byte), so this does not change what they do.
- ASSUMPTION AT39: the battery-backed CMOS image of a machine with two
  diskette drives is `tb/cmos_vga_2fd.hex`, the record SETUP would leave
  for that configuration (not a dump of a machine): drive B type 1 and two
  drives in the equipment byte, checksum 00E4h over 10h-2Dh.

## Strict decoding

The board answers an I/O read only from a modeled device. The POST runner
stops at the first I/O read no device claims and at any unclaimed I/O
access below 100h. A write to memory outside RAM and ROM is ignored and
counted, a data read there returns FFh and is counted, and only an
instruction fetch there stops the run (AT14). An unclaimed I/O write to
100h or above is accepted and counted (AT10). With `--empty-slots`, an
unclaimed I/O read at 100h or above returns FFh and is counted instead of
stopping the run; this is used for exploration only. In the EGA machine
the channel and the card answer first: a byte no card drives reads FFh
(AT14), and four I/O reads of the regression went unanswered by any card
(counted, not a stop). There is no catch-all port array. The
286 design's AT fixtures use such an array; on that fixture the BIOS's
cold-boot test of the 8042 system flag (port 64h bit 2, `F000:00DE`)
reads 0 by default. Zero is the cold-boot answer, but no device supplied
it. On this board the same read was the M1 stop; the 8042 now supplies it.
The board's "undriven read" flag fired during the wait states of a read
whose device had not yet driven data (an M1 defect); it is now checked when
the read completes.
Since the diskette milestone the board also claims F8h-FFh (the empty
80287 socket, AT17/AT36: writes have no effect, reads return the undriven
bus, and the runner counts them), and in the display machines the
diskette adapter answers 3F2h, 3F4h, 3F5h, 3F7h and the idle fixed-disk
task file 1F1h-1F7h (AT37). A DMA memory transfer outside RAM is counted
by the runner and rejected by the Unicorn replay.

## Open decisions

- D1: machine profile for OS/2 (REV1 at 6 MHz versus rev3 at 8 MHz; RAM
  size; video adapter). OS/2 1.0's minimum memory and supported displays
  must be cited before this is settled.
- D2: video adapter for the first POST milestone (CGA from the PC system or
  MDA). Settled in practice in M4a: the IBM EGA, which the AT BIOS probes
  through its own option ROM at C0000h. The VGA card (`design/ibm_vga`) is
  also in a machine since M4b part 1 (`ibm_pc_at_5170_vga.sv`); which card
  the OS/2 profile uses is still part of D1.
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
   README shows a real panel and waveform screenshot. Met so far: lint,
   the 8042 and MC146818 checks, system simulation of POST to checkpoint
   3Ch (bare board, EGA machine and VGA machine) and synthesis; a web panel
   with waveform capture exists for the VGA machine (2026-11-17). Not met:
   POST does not complete (no diskette or fixed disk; with the keyboard
   model it stops at the 80287 probe, port 0F8h), and no 86Box or PCjs
   comparison has been made.
