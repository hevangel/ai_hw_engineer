# Intel 3205

The Intel 3205 is a high-speed 1-of-8 binary decoder in Schottky bipolar
TTL: three address inputs select one of eight active-low, totem-pole
outputs (18 ns maximum address/enable-to-output delay over 0-75 °C), and
three chip enables (E̅1, E̅2 active low, E3 active high) qualify the decode
so that large memory systems can be decoded in levels — the datasheet
notes that 3205s cascade such that each decoder can drive eight others.

First introduced: **1973***, the earliest located dated Intel
documentation being the [November 1973 MCS-8 Users Manual](../../../references/intel_mcs8_users_manual_nov1973.pdf),
which prints the 3205 truth table on scan page 32; the manual's own
service note that SIM8-01 boards built prior to October 1972 require
modification shows the MCS-8 module was already in field use, so the
decoder's availability likely predates that document. The uncertainty is
retained rather than guessed; no month-level claim is made.

Why it matters here: the 3205 is the dedicated support chip of the MCS-8
(8008) chip set — on Intel's SIM8-01 module it decodes the 8008's state
lines S0-S2 (package A44, gated with clock and SYNC) and generates the
memory chip selects, letting the CPU control standard memory devices with
active-low select inputs. Together with the [3404 address latch](../intel_3404/README.md)
it completes the 8008 board beyond the CPU itself; the [8008 design](../intel_8008/README.md)
is the companion processor core in this repository.

Technical behavior follows the combined [Intel 3205/3404 data sheet](../../../references/intel_3205_3404_datasheet.pdf)
(16-pin DIP: A0-A2 pins 1-3, E̅1/E̅2/E3 pins 4-6, O̅7 pin 7, GRD pin 8,
O̅6-O̅0 pins 9-15, Vcc pin 16). This repository implements the digital
function as a synchronous-friendly combinational block; electrical
timing and the physical pin interface are out of scope.

**Verified.** Verilator lint, formal (bmc/prove/cover, non-vacuous),
exhaustive simulation in Verilator and xezim against the datasheet truth
table, two-level cascade check, code coverage, and Yosys synthesis all
pass — see the [validation report](report/final_report.md).

- [Specification](spec/spec.md)
- [Implementation plan](plans/implementation_plan.md)
- [Test plan](plans/testplan.md)
- [Formal plan](plans/formal_plan.md)
- [Source manifest](references/README.md)
