# Intel 4001 — MCS-4 Mask ROM and I/O Port Chip

The Intel 4001 pairs a 2048-bit (256 words x 8 bits) mask-programmable ROM
with a 4-bit input/output port on a single 16-pin PMOS chip. It is the
program-memory and peripheral-I/O member of the four-chip Intel MCS-4
microcomputer set: the 4004 CPU, the 4001 ROM + I/O, the 4002 RAM + output
port, and the 4003 shift register. Up to sixteen 4001s share one 4-bit data
bus and one CM-ROM command line; each chip's 4-bit number, compared against
a nibble the CPU broadcasts during every address period, is a metal mask
option chosen at manufacture.

## Historical context

The MCS-4 was created for the Busicom 141-PF desktop calculator. Busicom's
contract with Intel produced the engineering silicon during 1971, and Intel
subsequently bought back the rights so it could sell the chipset to other
customers. The family's public introduction is the Intel advertisement in
the November 15, 1971 issue of *Electronic News*, which industry history
treats as the announcement of the first commercial microprocessor set; the
contemporaneous November 1971 MCS-4 data sheet (which describes the 4001 as
the set's custom-microprogram storage) is the earliest located Intel
document for the chip. The 1971 year is not in dispute. The November 15
date is specifically the advertisement's publication date, and some
accounts frame earlier, lesser-documented mentions of the parts; where
sources differ on that framing, this index retains the advertisement date
as the announcement rather than guessing at a different day.

The 4001 mattered for two reasons. First, the 4004 has no on-chip program
storage, so every MCS-4 system leaned on 4001s for its firmware; one 4001
holds exactly one 256-byte page of the 4-kiloword MCS-4 program space.
Second, folding the 4-bit I/O port into the ROM die — selected by the SRC
instruction and written/read with WRR/RDR — removed a separate interface
device from every configuration, which was the economic point of a
calculator chip set: mask-programmed ROM was cheap in Busicom-scale volume,
and each bonded I/O pin replaced a board-level peripheral. Programs were
committed at mask time, so the 4001 was ordered with the customer's truth
table already in metal; nothing on the part was field-programmable.

## Repository implementation

This design is a synchronous, synthesizable SystemVerilog reconstruction of
the 4001's digital behavior, timed to interoperate directly with this
repository's verified `intel_4004` reconstruction (branch
`design/add-intel-4004`):

- the full 8-period instruction cycle (A1 A2 A3 M1 M2 X1 X2 X3) with a
  self-synchronizing phase counter locked to the CPU's SYNC pulse;
- program fetch: word address latched from the A1/A2 nibbles, chip number
  compared at A3 under CM-ROM, selected chip driving the ROM word's high
  nibble at M1 and low nibble at M2;
- ROM-port I/O: SRC select capture (X2 nibble, X3 ignored), WRR port write
  latched at the end of X3, RDR port read driven during X2/X3, with the
  per-pin input/output direction as the `IO_DIR` mask option;
- historical RESET and CL pins modeled as synchronous active-low `rst_n`
  (clears the sequencer and selection flip-flops, inhibits the bus output)
  and `clr_n` (clears only the I/O output latch), per the manual's split of
  responsibilities between the two pins;
- the mask-programmed ROM contents loaded by `$readmemh` from the hex file
  named by the `ROM_FILE` parameter (`src/rom_4001_default.hex` ships the
  verification pattern; give each instance its own hex file), and the chip
  number as `CHIP_NO`, reproducing the part's metal options.

The original part's electrical behavior (PMOS levels, two-phase
non-overlapping clocks, the dynamic refreshed ROM array, per-pin
inversion/pull-up mask options) is out of scope; see the specification's
scope section.

## Documentation

- [Specification](spec/spec.md)
- [Implementation plan](plans/implementation_plan.md)
- [Simulation test plan](plans/testplan.md)
- [Formal verification plan](plans/formal_plan.md)
- [Coverage report](report/coverage_report.md)
- [Final report](report/final_report.md)

## Sources

- [MCS-4 Users Manual (February 1973), bitsavers/archive.org scan](https://archive.org/details/bitsavers_intelMCS4M_18342130)
  — Section IV documents the 4001's address/chip-number protocol, SRC
  select flip-flop, MTC output enable, and the RESET vs CL pin split.
- [MCS-4 Micro Computer Set data sheet, November 1971 scan](https://deramp.com/downloads/mfe_archive/011-Other%20Computers%20and%20Boards/Intel/MCS-4/MCS4_Data_Sheet_Nov71.pdf)
- [EDN: Intel 4004 announced November 15, 1971](https://www.edn.com/intel-4004-is-announced-november-15-1971/)
- [Computer History Museum, this-day-in-history: first microprocessor ad](https://www.computerhistory.org/tdih/november/15/)
- [4004.com, the 50th Anniversary Project: MCS-4 family composition](http://www.4004.com/)
- [Intel 4004 historical summary (Busicom contract and rights buy-back)](https://en.wikipedia.org/wiki/Intel_4004)
- [MAME mcs40.cpp behavioral reference (address nibble order, I/O timing)](https://github.com/mamedev/mame/blob/master/src/devices/cpu/mcs40/mcs40.cpp)

Source content is summarized and rephrased for licensing compliance; no
source text is reproduced verbatim beyond device names and signal
terminology.
