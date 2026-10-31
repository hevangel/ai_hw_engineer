# MOS 6526 serial shifter preload and baud qualification

## Independent observations

The original SVN 45953 `CIA/shiftregister/cia-sdr-load.prg` printed FCBA
ten times on commit 89bd58e, while its unchanged screen table requires
FCEB. Its source and readme describe two SDR writes without waiting for
the first Timer A underflow. An external pin-decoding test confirmed
that the first byte was lost when both writes preceded any baud pulse.

The independently maintained
[MAME serial_load/serial_output reference](https://github.com/mamedev/mame/blob/41a494b6ef80adc924ccb2bdba1ee69580276e0c/src/devices/machine/mos6526.cpp)
also identifies two boundaries: a free-shifter load releases CNT rather
than waiting out the previous byte's tail, and a continuously asserted
latch-zero Timer A underflow level cannot supply repeated serial edges.
The integration suite incorrectly used latch zero as a working fast baud.

## Root causes and verification gap

The transmitter treated its pending SDR slot as the only storage before
the first underflow. A second write replaced the first byte, despite the
empty shift register. Existing exhaustive pairs wrote byte two only after
the first transfer had started, so all pairs passed this wrong boundary.

The same busy flag covered both the shifter and the final SP bit awaiting
its rising CNT edge. After the preceding completion request, a new SDR
write waited an extra underflow for that tail. The original software's
Timer B measurement exposed the resulting 51-clock delay. Merely adding
idle preload repaired byte preservation but did not repair the FCBA table.

The integrated baud path also treated each high underflow cycle as an edge.
The testbench agreed with this mistake instead of checking the independent
reference's sustained-level behavior.

## Correction and prevention

An idle SDR write now preloads the shifter independently of baud, leaving
a separate pending slot. Presenting bit eight frees the shifter while SP
holds that bit. A new free-shifter write releases CNT high, retaining SP
to complete the old byte, and prepares the new byte before the next baud
edge. Buffered continuation still loads on the final rising CNT edge.
The integrated serial baud input qualifies rising underflow levels.

Verification now decodes all 65,536 byte pairs with both writes before
the first baud pulse, retains the 65,536 in-flight buffered pairs, and
checks 256 late-write transfers including the write-generated CNT edge.
It also checks that a write coincident with final-bit presentation queues
the new byte without discarding the outgoing SP/CNT transition.
The same SV bench runs in Verilator and xezim. The original SDR-load
program and its screen table are hash-pinned and run by the aggregate
software flow, with exact entry/result/next-instruction PCs. Latch-zero
stall and latch-one complete transmission are explicit integration gates.

This is a sampled correction. MAME describes a two-clock physical load
pipeline; writes immediately adjacent to baud edges and silicon revision
captures remain required in the assumption ledger. The original polling
tables establish their measured cases, not every electrical transition.
See the [serial software report](../design/mos_6526/report/serial_software_report.md)
and [integration report](../design/mos_6526/report/integration_report.md).
