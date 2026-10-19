# Cassette byte-routine acceptance contract

The original Monitor's WRITE body at FED2 and WRBYTE at FEED must drive
the physical C020 decoder and J13 flip-flop. RDBYTE at FCEC must read
the actual K13 amplifier, H14 multiplexer, motherboard data path and CPU pins.
The F8 ROM is unmodified and hash-checked by the reference fetcher.

A project-authored exerciser replaces only the D0 ROM socket. The Monitor
boots normally; physical keyboard input `D000G` starts the exerciser. It
stores six diagnostic bytes in DRAM and invokes the original WRITE body,
including its XOR checksum and range increment. A separate waveform, derived
from the published format rather than recorded output, exercises RDBYTE.
Every received byte must be written through the CPU pins into real DRAM,
then read back through the motherboard buffers and copied to a second range.
Reject unknown opcodes and unknown received data. Run both waveform polarities.

The independent format oracle uses the original Monitor listing, printed
pp.85 and 88 of the [Apple II Reference Manual](https://apple2history.org/dl/Apple_II_Redbook.pdf),
and Winston Gayler, *The Apple II Circuit Description*, printed pp.94-96
([source](https://mirrors.apple2.org.za/Apple%20II%20Documentation%20Project/Books/W.%20Gayler%20-%20The%20Apple%20II%20Circuit%20Description.pdf)).
Bits are most significant first, zero/one half-cycles are approximately
250/500 microseconds, and the checksum is XOR of the data starting with FF.
Check both halves against exact cycle counts derived from the original
listing: zero second/first halves have 250/253 CPU clocks, with another
250 clocks for a one. The first half of a later data byte has 249 clocks;
the checksum starts with 258 clocks (plus 250 for a one). The first recorded
edge has no preceding tape transition, so its initial interval is excluded.
The book's rounded 250/500 microsecond figures cannot replace these counts:
the board's average CPU period is approximately 980 ns. Require the actual
timestamps to fit the 14-master-clock CPU cycle and extended scan-line cycle.

ASSUMPTION: input is an ideal 1.2 V peak-to-peak square waveform at the
Cap10 input boundary, with no recorder noise, loading, or speed variation.
This tests both signal polarities through the modeled AC coupling and 741.
The revision-0 manifest has no R30 input attenuator; the later-board 10%
divider described by Gayler must not be silently added to this board.

This bounded regression starts at FED2 and FCEC. It does not claim to test
the standard ten-second WRITE leader, READ's acquisition/delay, sync search,
or the complete READ command's checksum/error handling. Those remain a
separate extended historical-software requirement, as do analog measurement
and cassette jack output voltage/loading validation.

The pinned transistor reference can assert SYNC during reset recovery before
reading FFFC/FFFD. Its [upstream clock/memory schedule](https://github.com/mist64/perfect6502/blob/09fc542877a84318291aa42dab143a3e2c3db974/perfect6502.c)
reproduces this behavior with the same ROM. This SYNC precedes the pending
reset's dummy-stack and vector reads and is not counted as executed software.
Before counting executed opcodes, require those physical vector reads followed
by exactly FF59/20, within 100 microseconds. Unknown opcode rejection starts
with the completed vector sequence; it remains strict during all firmware
and exerciser execution. No CPU pin or internal register is overridden.
