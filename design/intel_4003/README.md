# Intel 4003 — MCS-4 I/O Expander

The Intel 4003 is a 10-bit static serial-in / parallel-out / serial-out
shift register with enable logic, announced in November 1971 as the fourth
member of the MCS-4 chip set alongside the 4004 CPU, 4001 ROM and 4002 RAM.
It exists because each MCS-4 memory chip exposes only a single 4-bit I/O
port: by streaming bits serially out of a port line and clocking them
through one or more 4003s, a program can turn that 4-bit port into an
unlimited number of output lines (the CPU data book notes "unlimited I/O
with 4003s" versus 128 I/O lines without them). Typical uses were keyboard
matrices, multiplexed displays and printers — most famously the printer and
keyboard of the Busicom 141-PF calculator, the product the whole MCS-4
family was originally designed for.

A chain of 4003s shares one clock line (CP) and one enable line; serial
data enters the first part's DATA IN and cascades through SERIAL OUT to the
next, giving register lengths that are multiples of ten. Data shifts on
each CP rising edge, and shifting continues even while the enable masks the
ten parallel outputs (the serial out line is unaffected) — the Users Manual
also notes the push-pull ratio outputs let up to three tied outputs be read
as a wired "any line active" for key-scanning. Unlike the other MCS-4
parts, the 4003 uses neither the two-phase system clocks nor SYNC; it is a
fully static, single-phase part clocked entirely under program control, and
its internal power-on-clear holds it cleared until the first CP pulse.

## First introduced

The MCS-4 family (4004/4001/4002/4003) was announced on **November 15,
1971** in Intel's advertisement in *Electronic News*; the November 1971
MCS-4 data catalog already contains the 4003 data sheet, so the 4003
shipped with the family from launch. The 4003 was not itself the headline
of the announcement — that was the 4004, "the first single-chip CPU" — and
secondary retellings vary in how prominently the support chips are
mentioned in the original ad; the data-catalog evidence that the 4003 was
part of the November 1971 launch is what this design records, and the
exact day the 4003 first shipped in volume is not established by the
sources below.

## Why it matters

The 4003 is the earliest example of the "serial I/O expander" pattern: a
tiny, cheap shift-register peripheral that multiplies a CPU's pin budget
under software control. It let a 4-bit calculator chip drive a 20-column
dot-field printer and a full keyboard matrix from a couple of port lines —
and the same trick (clock, data, enable lines feeding chained shift
registers) is still how countless board-level I/O expansions work today.

## In this repository

The RTL is a synchronous, synthesizable functional reconstruction: authentic
10-bit serial architecture with enable-gated parallel outputs and cascade
serial output, plus documented additions (`clk`, synchronous `rst_n`,
synchronous CP edge detection) that pin the datasheet's behavioral contract
to a single-clock model. The testbench drives it through a genuine 8-phase
MCS-4 port-write sequence and chains two parts to validate cascading.

- [Specification](spec/spec.md) — behavioral contract, interface, researched
  deviations (section 12), sources (section 13)
- [Implementation plan](plans/implementation_plan.md),
  [Formal plan](plans/formal_plan.md), [Test plan](plans/testplan.md)
- [RTL](src/intel_4003.sv) — module `intel_4003`
- [Formal](formal/) — `intel_4003.sby` (bmc/prove/cover), properties and
  33-cover non-vacuity set
- [Testbench](tb/tb_intel_4003.sv) — direct self-checking MCS-4
  microsystem, two chained instances
- [Final report](report/final_report.md) and
  [coverage report](report/coverage_report.md)
- Scripts: `scripts/run_all.sh` (lint → formal → sim → synth),
  `run_sim.sh`, `run_formal.sh`, `run_coverage.sh`, `run_synth.sh`

## Sources

- MCS-4 Micro Computer Set Users Manual, February 1973 — section VI is the
  4003 chapter (10-bit description, enable/serial-out rules, CP control,
  power-on clear, cascade, Fig. 8 block diagram, Fig. 9 four-chip system);
  scanned original and OCR text:
  <http://codeabbey.github.io/heavy-data-1/msc4-manual.pdf>,
  <https://archive.org/stream/bitsavers_intelMCS4M_18342130/MCS-4_UsersManual_Feb73_djvu.txt>
- MCS-4 data sheet, November 1971 (4003 page incl. power-on clear), scan:
  <https://deramp.com/downloads/mfe_archive/011-Other%20Computers%20and%20Boards/Intel/MCS-4/MCS4_Data_Sheet_Nov71.pdf>
- Announcement date and family context: EDN, "Intel 4004 is announced,
  November 15, 1971" <https://www.edn.com/intel-4004-is-announced-november-15-1971/>;
  Intel Virtual Vault,
  <https://www.intel.com/content/www/us/en/history/virtual-vault/articles/the-intel-4004.html>;
  [Wikipedia: Intel 4004](https://en.wikipedia.org/wiki/Intel_4004)
- MAME Busicom 141-PF driver (10-bit 4003 shifters clocked from a ROM I/O
  port bit with a shared serial-data bit):
  <https://github.com/mamedev/mame/blob/master/src/mame/skeleton/busicom.cpp>
- TAMS Hades i4003 applet notes (rising-edge shift, enable gates outputs
  only, cascade, port-driven clock/data):
  <https://tams.informatik.uni-hamburg.de/applets/hades/webdemos/80-mcs4/i4003/i4003-test.html>
- Faggin, Hoff, Mazor, Shima, "The History of the 4004", IEEE Micro, 1996
  (10-bit description): <https://www.computer.org/csdl/magazine/mi/1996/06/m6010/13rRUytWFdY>
- cpu-galaxy.at MCS-4 section (4003 as "10-bit Serial-in/Parallel-out,
  Serial-out MOS Shift Register"):
  <https://www.cpu-galaxy.at/CPU/Intel%20CPU/4001-4003/MCS-4%20Section.htm>

Source content is summarized and rephrased; device and signal names are
reproduced as historical identifiers.
