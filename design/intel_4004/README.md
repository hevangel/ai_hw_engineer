# Intel 4004 Microprocessor

The Intel 4004 is the first commercially available microprocessor: a 4-bit
PMOS CPU sold as the central component of the MCS-4 four-chip family (4001
ROM, 4002 RAM, 4003 shift register). It executes 46 instructions on 4-bit
data, addresses 4K words of program ROM through a 12-bit program counter, and
multiplexes addresses, instructions, and data over a single 4-bit bus during
the eight clock periods of every instruction cycle.

## Historical context

The 4004 began as a custom chip for the Busicom 141-PF printing calculator.
Busicom's Masatoshi Shima worked with Intel's Federico Faggin (chip design),
Ted Hoff, and Stan Mazor (architecture) to replace a multi-chip hardwired
logic design with a general-purpose processor directed by ROM software. Intel
announced the 4004 on **November 15, 1971** in Electronic News, and regained
the right to sell it outside the calculator market as part of the Busicom
settlement the same year. The part integrates about 2,300 transistors on a
10 µm PMOS process in a 16-pin DIP, clocks at up to 740-750 kHz, and executes
an instruction in 10.8 µs (8 clock periods; two-word instructions take two
instruction cycles). It was the first CPU sold as a commercial product, and
it established the microprocessor as a component rather than a system.

The MCS-4 architecture is unusual by later standards: program memory (ROM) and
data memory (RAM) are separate spaces, the 4-bit bus carries 12-bit addresses
in three nibbles during A1-A3, the 8-bit instruction during M1-M2, and I/O
data during X2-X3; RAM banks are selected by the DCL command-line register and
RAM chip/register/character by the SRC pointer. Up to three subroutine levels
are supported by the four-register push-down address stack. These behaviors —
including the page-boundary quirks of JCN/JIN/FIN/ISZ that fall out of the
program counter incrementing once per instruction cycle — are reproduced by
this design.

## Repository implementation

This design implements the complete MCS-4 CPU programming model as a
single-clock, synthesizable functional reconstruction
(`src/intel_4004.sv`):

- all 45 instructions of the MCS-4 manual's repertoire plus WPM (the
  program-memory write documented for 4008/4009 systems), i.e., the commonly
  cited 46;
- 16 four-bit index registers (eight register pairs, pair 0 doubling as the
  FIN/JIN pointer), 4-bit accumulator with carry, BCD support (DAA, TCS);
- 12-bit program counter in a four-register circular push-down stack (3-level
  subroutine nesting with the documented deepest-entry-loss overflow);
- the A1-A3/M1-M2/X1-X3 bus protocol with `sync`, `cm_rom`, and the four
  bank-decoded `cm_ram` command lines;
- SRC register-control pointer, DCL command-line register, ROM I/O ports
  (WRR/RDR), and RAM main/status/output-port operations;
- undefined opcode combinations execute as NOPs.

The historical part uses two non-overlapping clock phases, an asynchronous
RESET, and analog pin behavior; this core samples everything on a single
`clk` with a synchronous active-low `rst_n` (the manual documents that a
sustained reset clears all registers, which the core reproduces in one
cycle). The bidirectional data bus appears as separate `data_i`, `data_o`,
and `data_oe` signals. This preserves functional ordering and bus-visible
behavior without claiming pin-level timing, NMOS electrical behavior, or
package compatibility. See `spec/spec.md` for the complete behavioral
contract and its sources.

## Verification summary

- Strict lint (Verilator `-Wall`, Verible) passes with zero warnings.
- A deterministic self-checking simulation runs a full MCS-4 microsystem
  (behavioral 4001/4002 models) against an independent instruction-set
  simulator: 20,192 instruction boundaries compared with zero mismatches,
  all 46 instructions exercised, plus a fixed-seed random stress phase.
- Formal verification proves the complete ISA transition function for every
  opcode encoding and start state (bounded and unbounded), all sequencer
  safety properties, and reachability covers for every instruction class.
- Yosys generic synthesis completes with zero structural problems.

## Documentation

- [Specification](spec/spec.md)
- [Implementation plan](plans/implementation_plan.md)
- [Simulation test plan](plans/testplan.md)
- [Formal verification plan](plans/formal_plan.md)
- [Coverage report](report/coverage_report.md)
- [Final report](report/final_report.md)

## Sources

- [MCS-4 Micro Computer Set user manual (scanned original, including the
  instruction repertoire, DCL/SRC command-line operation, stack description,
  and WPM)](http://codeabbey.github.io/heavy-data-1/msc4-manual.pdf)
- [Intel 4004 historical summary (launch date, architecture, instruction
  count)](https://en.wikipedia.org/wiki/Intel_4004)
- [The Intel 4004 project — Busicom 141-PF replica and historical
  documentation](https://www.4004.com/)
- [Intel 4004 instruction-set transcriptions and opcode
  matrices](http://e4004.szyc.org/iset.html) and
  [pastraiser opcode table](https://pastraiser.com/cpu/i4004/i4004_opcodes.html)
- [MAME MCS-40 CPU core — hardware-validated semantics cross-check for the
  subtract carry sense, JCN condition bits, and WPM bus
  behavior](https://github.com/mamedev/mame/blob/master/src/devices/cpu/mcs40/mcs40.cpp)

Source content is summarized and rephrased for licensing compliance; no
source text is reproduced verbatim beyond device names, signal names, and
instruction mnemonics.
