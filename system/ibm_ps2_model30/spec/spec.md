# IBM Personal System/2 Model 30 specification

## Target and authority

Build the original 1987 **8530-021**: Intel 8086-2 at a nominal 8 MHz,
640 KiB planar RAM, 64 KiB ROM, MCGA with 64 KiB display RAM, one
720 KiB 3.5-inch drive, an integrated 20 MB fixed disk and a Model M keyboard.
The optional two-floppy 8530-002 configuration remains available for regression.
No 8087 is installed. This is the 8086 Model 30, not the later Model 30 286.

Primary authority is IBM's January 1987 [Technical Reference scan](../../../references/model30tr.pdf), [searchable text extraction](reference/model30tr.txt), and [IBM archive](https://www.ibmfiles.com/ibmfiles/ps2/25/model30tr.pdf):
system board pp. 1-3..1-24, video pp. 1-36..1-78, diskette pp. 1-79..1-105,
serial/parallel pp. 1-108..1-126, keyboard section 4, BIOS section 5.
IBM's [1989 sales advisor](https://bitsavers.org/pdf/ibm/pc/ps2/G320-9781-00_PS2_and_Printers_Sales_Advisor_198905.pdf)
also identifies the 8 MHz 8086, MCGA and two-diskette Model 30-002.
Use unchanged revision 2 ROMs (61X8940 even/61X8939 odd, February 5, 1987)
preserved by [Ardent Tool](https://ardent-tool.com/firmware/system.html).
Download archives into ignored `work/reference`, validate hashes, interleave
the ROM sockets and execute from the original reset vector. IBM's original
720 KiB Starter Disk and PC DOS 3.30 provide real-software tests.

## Execution and interfaces

Instantiate `intel_8086_chip`, including its native six-byte BIU, in maximum
mode. Model the planar's RQ/GT arbitration, 16-bit RAM/ROM transfers and
8-bit I/O conversion. CPU instructions and BIOS/DOS interrupts execute in
RTL. Host code supplies storage, decoded disk media and UI events only.
No patched BIOS, instruction interpreter or BIOS interrupt interception.

RAM occupies 00000h..9FFFFh, with the documented 6Bh remap/disable controls.
ROM occupies F0000h..FFFFFh and ignores CPU writes. MCGA maps its 64 KiB
store through A0000h and B8000h windows according to video mode. Preserve
loadable fonts, indexed CRTC registers, DAC RGB programming, CGA modes,
320x200x256 and 640x480x2 modes. The browser displays actual VRAM/DAC/font
state, including cursor and display enable.

Reuse verified 8237A, 8259-compatible interrupt logic, 8253 and 8272 RTL.
Model 30 refresh is a separate planar mechanism, not PC 5150 DMA channel 0;
PIT channel 1 receives refresh pulses for diagnostics. DMA runs at 4 MHz,
PIT channels 0/2 at nominal 1.19318 MHz, and FDC decoded bytes at 250 kbit/s.
DMA page mapping is 81h -> channel 2, 82h -> channel 3, 83h -> channel 1,
87h -> channel 0. IRQ1's internal keyboard/mouse/RTC vector is 71h.
Planar enable register 65h controls video/FDC/serial/parallel/fixed disk.
61h controls beeper and error enables; 62h reports installed devices.
Implement the keyboard/pointing-device gate-array registers, keyboard
command acknowledgements, MM58167 clock, serial and parallel registers.
Uninstalled expansion devices return the documented open-bus value.

## User interface

Provide a separate Model 30 browser panel and local server, preserving the
5150 server at port 8088. Default Model 30 port is 8530. Include power,
reset, run/pause, exact instruction step, physical/on-screen keyboard,
diskette mount/export and the same self-hosted Surfer CPU waveform viewer.
Capture must leave exactly the state produced by an ordinary run of the
same clock count. Nominal 8 MHz trace half-period is 62,500 ps.

## Verification and assumptions

Strict lint/build, board-level exact-PC tests, formal non-vacuity checks
where applicable, synthesis, backend/UI tests and unchanged firmware boot
are required. Test both native bus lanes and serialized word I/O, DMA
arbitration and disk geometry, ROM protection, 6Bh remapping, IRQ1 vector,
keyboard command responses, RTC and MCGA palette/font/mode operations.
Real software must boot through POST, read/write/format disk media and
exercise BASIC and MCGA graphics. Record actual results before sign-off.
Firmware-discovered chip bugs require failure notes and directed regression.

- A1: Instruction scheduling and digital bus timing follow the repository's
  CPU contract; they are not a claim of exact original instruction clocks.
- A2: External media provides decoded sectors, not magnetic flux. All FDC,
  DMA, IRQ and BIOS disk routines remain RTL.
- A3: Static RAM storage replaces DRAM charge decay; refresh arbitration and
  the diagnostic PIT input remain observable.
- A4: Keyboard and mouse enter at the completed serial-byte boundary. Their
  gate-array registers, interrupts and command protocol are RTL; connector
  electrical edges and the external device's MCU firmware are not modeled.
- A5: IBM omits some gate-array register details. Any inferred behavior must
  be labeled in RTL and tied to unchanged ROM disassembly and an independent
  implementation (86Box's `kbc_ps2_m25.c`, `m_ps2_isa.c`, `vid_mcga.c`,
  `isartc.c`), then validated with original software before sign-off.
- A6: The January manual p.1-13 prints 80h/81h/82h for channels 2/3/1.
  The unchanged February BIOS explicitly tests 81h/82h/83h/87h at F000:015D
  and programs disk DMA page 81h at F000:191B. The independent 86Box `dma.c`
  uses the latter map. Implement the ROM-compatible map; validate transfers
  into nonzero 64 KiB pages. This discrepancy is in the scanned original,
  not merely an OCR error.

- A7: The Model 30 keyboard starts in scan set 1 (TR p.4-4). F5/F6
  preserve an explicitly selected scan set: original BIOS LED handling at
  F000:E294 sends F5/ED/LED/F4 without selecting it again. Independent
  86Box `kbc_ps2_m25.c` explicitly preserves the selection. F6 enables
  scanning; F5 disables it. Validate the complete sequence and DOS input.

## User-requested fixed-disk extension

The target now includes the original 20 MB integrated fixed disk; see the
[controller specification](hard_disk.md). Preserve the two-floppy mode for
regression and support the factory 8530-021 front-panel configuration.

### A12: 720K drive identification

ASSUMPTION: port 6Ah bit 0 reads high for the installed stock 720K drives.
The original February 5, 1987 BIOS at F000:0F0E tests this input before
setting BDA 40:8F bit 1 (or bit 5 for B); that bit selects INT 13h AH=08
drive type 4 instead of 3. The January Model 30 TR specifies type 3/720K.
The exact gate-array input wiring is not established. Unchanged BIOS/DOS
FORMAT has validated the stock value: all 160 tracks format at 250 kbit/s,
with nine sectors per head and 730,112 usable FAT12 bytes. This input is not a writable BIOS configuration override.

The decoded physical 720K medium accepts data/header timing only when CCR
3F7h bit 1 selects 250 kbit/s (TR pp. 1-81/1-82). The spindle index still
rotates at a mismatched rate. Out-of-geometry format IDs cannot overwrite
an adjacent head in the flat canonical media representation. Custom floppy
ID layouts require a richer media format and are outside this boundary.

The CGA-compatible mode register follows IBM TR p.1-55: bit 4 alone selects
640x200 graphics; bit 1 selects 320x200 graphics. Mode status clears its
alpha bit and sets double-scan for either compatible graphics mode.
