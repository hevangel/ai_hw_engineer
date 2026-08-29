# Intel 4002 — MCS-4 RAM and Output Port Chip

The Intel 4002 is the data-storage member of the four-chip Intel MCS-4
microcomputer set: the 4004 CPU, the 4001 ROM + I/O, the 4002 RAM + output
port, and the 4003 shift register. One 4002 provides 320 bits of MOS RAM —
organized as four registers of sixteen 4-bit main-memory characters plus four
registers of four 4-bit status characters — and a 4-bit latched output port
for driving peripherals. Up to four 4002s share one CM-RAM command line,
distinguished by a 2-bit chip number the CPU sends with every SRC select
code; the 4004 can drive up to four CM-RAM lines (banks), so a fully
populated MCS-4 system addresses 5120 RAM bits and 16 output ports.

## Historical context

The MCS-4 was created for the Busicom 141-PF desktop calculator, where the
4002 held the calculator's working registers and flag/status characters;
Intel subsequently bought back the design rights so it could sell the
chipset to other customers. The family's public introduction is the Intel
advertisement in the November 15, 1971 issue of *Electronic News*, which
industry history treats as the announcement of the first commercial
microprocessor set; the contemporaneous November 1971 MCS-4 data sheet
already describes the 4002 with its two metal options. The 1971 year is not
in dispute. As with the rest of the family, the November 15 date is
specifically the advertisement's publication date, and this record retains
that date as the announcement rather than guessing at a different day.

The 4002 mattered for two reasons. First, the 4004 has no on-chip data
storage beyond sixteen index registers, so every MCS-4 program kept its
working data in 4002s; the accumulator-style instruction set (WRM/RDM for
main memory, WR0-WR3/RD0-RD3 for status characters, ADM/SBM for
add/subtract-to-memory) makes the 4002 a direct extension of the CPU's
register file rather than a passive store. Second, the on-die 4-bit output
port — written with the WMP instruction and holding its value until the next
WMP — gave the set a latched peripheral interface without a separate
latching part, which was the economic point of a calculator chip set.

Two metal options shipped: a 4002-1 answers chip numbers 0 and 1 and a
4002-2 answers chip numbers 2 and 3, with a `P0` strap pin selecting which
of the two numbers an individual chip owns. This split is what lets four
4002s share one command line. The array is dynamic RAM with an internal
refresh counter (the CM-RAM lines are also pulsed at A3 of every cycle to
keep the array's power-share timing honest); the RESET pin clears the output
and control flip-flops and sweeps the array clear when held for at least 32
instruction cycles.

## Repository implementation

This design is a synchronous, synthesizable SystemVerilog reconstruction of
the 4002's digital behavior, timed to interoperate directly with this
repository's verified `intel_4004` reconstruction (branch
`design/add-intel-4004`):

- the full 8-period instruction cycle (A1 A2 A3 M1 M2 X1 X2 X3) with a
  self-synchronizing phase counter locked to the CPU's SYNC pulse;
- command decode by listening to the instruction word broadcast at M1/M2,
  exactly as the historical 4002s receive their OPA;
- SRC select-code latching at X2 (chip number + register) and X3
  (character), bank-line gated, with chip selection by the `Variant1`
  metal-option parameter and the `po_i` strap pin;
- write commit at the edge ending X3; read data driven during X2/X3 with an
  explicit `data_oe`; WRR/WPM/RDR encodings ignored;
- the 4-bit WMP output latch, and a synchronous active-low `rst_n`
  reconstruction addition (the historical RESET is asynchronous and its
  array-clear sweep needs 32 instruction cycles; the reconstruction models
  static storage and clears everything on one reset edge).

The dynamic cell array, refresh counter, electrical behavior, and
timing-level protocol are out of scope; `spec/spec.md` sections 9 and 11
list every reconstruction decision and exclusion.

## Folder guide

- [spec/spec.md](spec/spec.md) — sourced behavioral specification (chip
  selection, phase-by-phase protocol, command table, interpretations)
- [plans/implementation_plan.md](plans/implementation_plan.md) —
  architecture and phase plan
- [plans/formal_plan.md](plans/formal_plan.md) — formal strategy,
  assumptions, properties, and the cover-engine decomposition
- [plans/testplan.md](plans/testplan.md) — simulation plan
- [src/intel_4002.sv](src/intel_4002.sv) — the RTL
- [tb/tb_intel_4002.sv](tb/tb_intel_4002.sv) — self-checking two-DUT
  testbench with an independent golden model
- [formal/intel_4002.sby](formal/intel_4002.sby) — SymbiYosys tasks (bmc,
  prove, cover)
- [formal/intel_4002_props.sv](formal/intel_4002_props.sv) — golden-model
  equality and safety properties
- [formal/intel_4002_cover.sv](formal/intel_4002_cover.sv) — reachability
  cover set
- [scripts/](scripts/) — lint, simulation, formal, synthesis, and aggregate
  runners
- [report/final_report.md](report/final_report.md) — verification results
- [report/coverage_report.md](report/coverage_report.md) — coverage summary

## Sources

- MCS-4 Micro Computer Set Users Manual (Feb 1973 scan, bitsavers/archive.org):
  <https://archive.org/details/bitsavers_intelMCS4M_18342130> — 4002 chapter
  (320-bit organization, SRC select-code fields, chip-number/variant table,
  CM-RAM activation timing, WMP output-port behavior, RESET behavior) and
  the I/O/RAM instruction descriptions. Content is summarized and rephrased;
  no source text is reproduced verbatim beyond device, signal, and mnemonic
  names.
- MCS-4 Data Sheet, November 1971 (deramp.com scan):
  <https://deramp.com/downloads/mfe_archive/011-Other%20Computers%20and%20Boards/Intel/MCS-4/MCS4_Data_Sheet_Nov71.pdf>
  — the 4002's two metal options and the four-line CM-RAM bank architecture.
- MAME MCS-40 CPU core, `src/devices/cpu/mcs40/mcs40.cpp`
  (<https://github.com/mamedev/mame>) — behavioral cross-reference for
  CPU-side phase timing and the DCL command-line decode.
- Intel 4004 historical summary (announcement date November 15, 1971, family
  roles): <https://en.wikipedia.org/wiki/Intel_4004>.
