# Apple IIe functional virtual platform

Target: the original January 1983 NTSC Apple IIe with NMOS 6502, MMU
341-0266, IOU 341-0267 and motherboard timing PAL. The chip specifications
remain authoritative: [MMU](../../../design/apple_iie_mmu/spec/spec.md),
[IOU](../../../design/apple_iie_iou/spec/spec.md),
[PAL](../../../design/apple_iie_pal/spec/spec.md), and
[CPU](../../../design/mos_6502_family/mos_6502/spec/spec_full_isa.md).

Primary sources: Apple IIe Technical Reference Manual, second edition,
Chapter 7, Tables 7-8/7-9/7-10 (timing, RA multiplexing, RAM/ROM selection),
and Jim Sather, Understanding the Apple IIe, Chapter 5. The chip specs cite
these and the independent CC0 frozen-signal MMU/IOU fixtures. The manual is
available at https://archive.org/details/Apple_IIe_Technical_Reference_Manual.

## Clock composition and reset

PAL runs at 14.31818 MHz, 14 master ticks per CPU bus cycle. The existing
CPU and IOU are cycle-level abstractions. The PAL establishes CPU and display phases.
CPU/RAM/MMU commit at the phi0 falling edge. IOU samples the same
stable transaction at phi0 rising, during PRAS-high, then exposes its
latched address during the column half. IOU receives normalized phi0=1/q3=0
at its edge, preserving its cycle-level switch contract. Its PRAS input
follows PAL for row/column video addresses. MMU row and column RA are
captured on clk14 falling edges in their respective PAL windows; both
halves are stable before CPU/RAM commit. Video uses
the IOU row/column pair during the display half of each PAL cycle.

A1 ASSUMPTION: this normalization adapts the chip models; it does not
reconstruct transparent latches, precise data setup/hold, or the CPU's
missing dummy/page-cross cycles. Firmware speed and tape timing are not
cycle accurate. PAL waveforms retain their separately documented limits.
A2 ASSUMPTION: power_n resets master timing independently of rst_n.
Hold rst_n low while releasing power_n and run at least two full PAL cycles
before releasing rst_n on clk14 low. PAL clocks keep running during CPU reset.
CPU fetches FFFC/FFFD, with IRQ/NMI tied inactive. MMU/IOU use their documented
reset states; MMU language-card bank 2/read-ROM/write-enable is preserved.

## Memory and I/O

64 KiB main RAM plus 64 KiB auxiliary RAM (extended 80-column card), 128 KiB
total. A base IIe has 64 KiB; the handoff's '64K combined main/aux' is not the
full auxiliary configuration (TRM auxiliary-memory discussion). MMU RAMEN/
EN80 select the actual arrays; both RA halves map physical RAM addresses,
including the D000 language-card bank remap. MMU ROMEN selects bytes from
an unmodified 16 KiB C000-FFFF original Apple2e ROM. C000-C0FF remains I/O.
Unpopulated slot ROMs return FF. No Disk II or slot card is invented.

Keyboard seven-bit data is board-latched; IOU supplies strobe/AKD and
C010 acknowledgement. MMU and IOU own their respective MD7 status ranges.
Other read bits retain the latest scanner byte. Speaker/cassette outputs
come from IOU pins; analog audio, paddles and tape electronics are deferred.
A3 ASSUMPTION: RAM starts zero in simulation for reproducible cold boot;
this is not a hardware power-on guarantee. Unpopulated inputs are inactive.
A4 ASSUMPTION: keyboard input is an encoded AY-3600 event, not a key-matrix
model. Hold the event for at least four bus cycles and wait for C010.
A5 ASSUMPTION: display is decoded digital monochrome. Text 40/80 columns
and scanner-address evidence are in scope; analog NTSC color and accurate
PAL video serialization are not. Character-ROM conversion/provenance must
be recorded separately; enhanced 65C02 system ROM is not compatible here.

## Acceptance

Strict RTL lint; directed bus tests covering main/aux, ALTZP, 80STORE,
language-card mapping/protection, keyboard and status, IOU scanner addressing
and 14-tick cadence; Verilator and xezim simulation; bounded/non-vacuous
formal checks for new control/address adapters; synthesis of RTL/memories.
Mandatory real-software gate: unchanged original IIe ROM boots and accepts
keyboard input, writes the text screen and executes a BASIC or Monitor
command with exact expected memory/readback. An undocumented-opcode fault
is a failure. A web panel displays actual scanner output and queues keys.
Every artifact stays checksum-pinned; downloaded firmware remains ignored.
