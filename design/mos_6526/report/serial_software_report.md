# Original serial hardware-table regression

`scripts/run_serial_software.sh` executes the unchanged
[cia-sdr-delay program and assembly](https://sourceforge.net/p/vice-emu/code/45953/tree/testprogs/CIA/shiftregister/)
from VICE SVN 45953. The fetcher pins SHA-256 for the original PRG, assembly
and provenance readme. Downloads remain ignored; no binary or reference
table is rebuilt, translated, patched or committed.

The archive attributes the test and its C64c/C128D measurements to
[VICE issue 1219](https://sourceforge.net/p/vice-emu/bugs/1219/).
The program varies the delay before SDR writes by one cycle across 21
transfers, reads Timer B after serial completion and compares the raw
results against its own hardware table. The documented seven-word pattern
repeats three times:

```
FCE6 FCE7 FCE8 FCE9 FCEA FCE4 FCE5
```

## Environment and exact checkpoints

The native CPU executes the original PRG at SYS 2061 (080D). The fixture
asserts exact entry A9 at 080D, next JSR at 080F, result store STY at 08CF,
post-store PC 08D2 and next executed BNE at 08D2. It also requires exactly
42 writes to the original result buffer at 2000-2029. A nonzero original
D7FF result fails immediately after validating the next instruction.

RAM and both actual CIAs are present. A declared PAL raster timing fixture
supplies D011 bit 7 and D012 from 312 lines of 63 PHI2 clocks. There is no
video DMA. An actual RTS at FFD2 supplies diagnostic console return; the
program compares raw timer samples, so no screen rendering or substituted
expected bytes are needed. This fixture is not a complete Commodore 64.

## Defect and corrected result

The previous implementation failed with result FF:

```
FCB5 FCB6 FCB7 FCB8 FCB9 FCBA FCBB
FFC5 FCB6 FCB7 FCB8 FCB9 FCBA FCBB
FFCC FCB6 FCB7 FCB8 FCB9 FCBA FCBB
```

It requested completion on the final rising CNT edge, one baud pulse too
late, and retained a just-read serial completion for the next transfer.
The corrected sampled profile requests completion four PHI2 clocks after
presentation of bit eight on the fifteenth baud pulse; the sixteenth pulse
still raises CNT. An ICR read consumes a currently visible serial source.
The latter remains an explicit source-specific assumption in the ledger.

On Verilator 5.052 the original program now passes in **64,250 PHI2 clocks**
with result 00 and all 21 words matching exactly. Isolated serial tests
also pass all 256 receive bytes, 65,536 buffered transmit byte pairs,
65,536 pre-underflow byte pairs and 256 late-write transfers in 6,239,264
clocks, including an exact four-clock request check. Four-state simulation
passes 39,918 checks. Serial BMC/PDR and eight reachable covers pass;
synthesis/check uses 273 generic cells. Both interrupt profiles pass
9,364 checks per simulator, BMC/PDR and respectively nine/six covers;
synthesis remains 72/67 generic cells.

This evidence qualifies the captured divider-50 case. It does not establish
all serial divider/revision races, adjacent-write/load races, direction
changes, or input synchronization. Those and additional TOD corner cases
remain open before system compatibility sign-off. See the
[escaped-defect analysis](../../../failure_notes/2026-10-20-mos6526-serial-completion-timing.md).
The [original TOD latch/stop programs](tod_software_report.md) separately
qualify 66 time samples without TOD RTL changes.

## Original SDR-load program and byte preservation

The same runner also executes unchanged `cia-sdr-load.prg` and hash-pins
its original `cia-sdr-load.a65` source. This program primes a transfer,
waits for SDR-empty, then writes AA and 55 six CPU clocks apart, before the
next Timer A underflow. The original implementation printed FCBA ten
times and failed its own screen table with result FF.

Idle preload alone repaired the lost first byte but retained the wrong
FCBA timing. The independent
[MAME serial_load/output implementation](https://github.com/mamedev/mame/blob/41a494b6ef80adc924ccb2bdba1ee69580276e0c/src/devices/machine/mos6526.cpp)
explains that a new load into the free shifter releases CNT high instead
of waiting out the previous byte's tail. The corrected sampled behavior
retains the previous final SP bit on that edge and prepares the next byte.
All ten logged measurements are now FCEB, and the program's own comparison
of the last five screen rows passes with result 00 after **61,004 clocks**.
The original delay program retains all 21 timing results and 64,250 clocks.

The fixture asserts entry A9 at 0820, next JSR at 0822, success STY at
08C9, post-store PC 08CC and next executed LDA at 08CC. Failure at 08D6
also has an exact next-instruction check. An executing RTS at FFD2 returns
from console calls. The declared console sink handles only clear-screen,
carriage return and ordinary character output, converting emitted PETSCII
to screen RAM. It inserts no expected timing text: the original program
prints its measured timer values, then compares its untouched table.
It is not a complete KERNAL screen editor or C64 system.

Wire tests separately decode both bytes for every possible pre-underflow
pair; the software's table alone cannot prove data preservation. Late-write
tests include the CNT rising edge caused by loading the free shifter.
The sampled preload boundary and MAME's two-clock physical load pipeline
remain distinct in the [assumption ledger](../spec/spec.md). See the
[escaped-defect note](../../../failure_notes/2026-10-20-mos6526-serial-shifter-preload.md).
