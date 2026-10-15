# IBM PC 5150 virtual-platform specification

## Machine and sources

Reconstruct the original 1981 IBM Personal Computer 5150: 64 KiB system RAM,
8088 architectural execution, CGA, two 160 KiB 5.25-inch diskette drives, the
original 1981-04-24 IBM BIOS and Cassette BASIC 1.00. The implementation lives
in `system/ibm_pc` and reuses the repository's processor/peripheral RTL.

Primary authority: IBM's [August 1981 Technical Reference](https://www.minuszerodegrees.net/manuals/IBM_5150_Technical_Reference_6025005_AUG81.pdf),
especially the motherboard schematics, I/O map, keyboard, CGA and diskette
adapter descriptions and original BIOS listing. Original ROMs and PC DOS 1.00
media are obtained from immutable PCjs archive revisions, hash checked and
cached outside Git. Their provenance and conversion will be recorded in the
reference manifest. IBM dates the PC introduction to 1981; no day-level date
is needed for this system's index entry.

## Hardware boundary

The verified `intel_8086` execution unit executes the shared original 8086/8088
instruction architecture. A system bus adapter supplies byte-wide transfers,
a four-byte instruction queue, explicit queue flushing on control transfers,
stale queued instructions after writes, and DMA bus ownership. It is not a
16-bit 8086 motherboard or a software instruction interpreter. Original EU
clock counts, analog pin timing and undocumented NMOS differences are outside
the virtual-platform contract.

Instantiate the existing Intel 8259A PIC, 8253 PIT (8254 features disabled),
8255 PPI, 8237A DMA and 8272 decoded-media FDC RTL. Wire actual INTA, IRQ0/1/6,
PIT channel 1 refresh requests, DMA channel 0 refresh and channel 2 diskette
transfers, DMA page latches, keyboard latch/acknowledge, speaker control and
the floppy digital-output register. An external media responder supplies
decoded track/sector IDs and bytes; BIOS/DOS disk interrupts execute in RTL.
No host interception of CPU BIOS/DOS interrupts is allowed.

Map RAM at 00000h..0FFFFh, CGA memory at B8000h..BBFFFh with adapter aliases,
Cassette BASIC at F6000h..FDFFFh and BIOS at FE000h..FFFFFh. Unmapped memory and
I/O return FFh. ROM writes from the CPU are ignored. Host loading is explicit
and only permitted during reset. CPU and DMA memory writes are mutually
exclusive. Disk modifications stay in the running machine's media image.

I/O: 8237 at 00h..0Fh, PIC at 20h..21h, PIT at 40h..43h, PPI at 60h..63h,
DMA pages at 80h..83h, NMI mask at A0h, CGA registers at 3D0h..3DFh and FDC
at 3F0h..3F7h. Absent serial, printer, game and expansion adapters use their
documented absent-device values. The web interface must not imply they exist.

CGA implements the 6845 register interface, video-mode/palette control, text
and graphics memory layout, cursor and changing display/retrace status.
The browser renders actual VRAM using the original CGA character ROM, including
40/80-column text and 320/640-pixel graphics. Composite color artifacts and
analog CRT behavior are not modeled.

## User interface and verification

A persistent Verilator process runs the RTL. A local HTTP server exposes its
state, display, keyboard scan codes, power/reset, run/pause/step and diskette
selection. Browser key events become original PC make/break scan codes; the
firmware handles keyboard interpretation. The server validates commands and
does not execute arbitrary shell requests. Ordinary boot and software execution
must work without architectural-state injection or patched firmware.

Embed local Surfer for genuine Verilator FST CPU captures. An explicit capture
records 1..65,536 clocks from the current machine, publishes the file only after
closing it and leaves execution paused at the end of that window. Trace both
clock phases, using nominal 4.772727 MHz timestamps at 1 ps resolution. Named
scalar register probes, instruction state, byte-bus/prefetch signals and DMA
ownership must be available. Repeated capture/download/poll operations are
serialized; stale files from a prior server session must not be advertised.
Serve the bundled WASM assets on the same origin and permit raw FST download.
Recording must produce exactly the same machine state as an ordinary run of
the same number of clocks, including CPU registers/PC, VRAM and peripherals.

The aggregate regression must boot unchanged IBM BIOS through POST, boot
unchanged PC DOS 1.00 through the actual FDC/DMA path, interact through keyboard
IRQs, verify command output and exercise original BASIC/application software.
It must also test ROM protection, memory/I/O decode, interrupt and DMA wiring,
queue behavior, reset, browser/server controls and rendered display. Run strict
RTL lint, appropriate formal/structural checks and record actual results and
limits before opening a PR. Any firmware-discovered chip defect requires a
failure note and a chip regression.

## Assumptions to validate

- A1: EU scheduling differs from original silicon; peripheral and video time
  derive from explicit simulated clock dividers. Do not patch BIOS to hide
  a timing or integration failure.
- A2: Floppy media uses decoded sectors with realistic command/byte handshakes,
  not flux transitions. Preserve the FDC's own result, IRQ, DRQ and DMA behavior.
- A3: Static digital RAM replaces refresh-dependent DRAM storage, but PIT/DMA
  refresh requests and acknowledgements remain observable and tested.
- A4: Keyboard input starts at the external serial keyboard's completed scan
  code boundary; board latch/IRQ/acknowledgement and power-on response are real
  RTL. Keyboard microcontroller firmware and electrical serial waveforms are
  outside this platform.
