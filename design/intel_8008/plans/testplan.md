# Test Plan: intel_8008

## Overview

Two complementary regressions verify the core: a directed exact-PC test
(`tb/tb_top.sv`) that pins every instruction's post-state, and a
200,000-instruction comparison against authentic SCELBAL object code using an
oracle derived from SIMH (`tb/tb_scelbal.sv`, vectors from
`scripts/make_scelbal_vectors.py`).

A UVM environment is deliberately not used, for the same rationale accepted
for the Intel 4004 design: the core has one clocked protocol and no register
interface, so a procedural bench with a reference model gives strictly
stronger checking per line of code.

## Reference Model

The oracle in `scripts/make_scelbal_vectors.py` is a translation of the
downloaded SIMH i8008 model (`references/simh_i8008.c`), not of the RTL. The
translation was written from SIMH's source, so RTL-vs-oracle agreement checks
the RTL against an external artifact. Two modeling choices are shared rather
than independently confirmed and are recorded in the spec as assumptions:

- stack wrap depth (eight entries beside a separate PC, wrapping one level
  later than the historical part);
- undefined INR/DCR M encodings (SIMH updates flags, the spec models a full
  NOP; the oracle follows the spec so the vector comparison stays exact).

## Directed Regression (tb_top)

Loads a fixed program and steps one instruction at a time, asserting the
exact post-instruction PC, accumulator, flags, memory writes, I/O port, and
halt behavior. No landing pads: an unexpected PC is a failure. Coverage:

- LAI/ADI/LBI/LAB/INB/LHI/LLI/LMI/LAM/CPI immediate and register ALU, with
  flag checks (ADI sign, CPI zero);
- memory write via LMI to an explicit address, verified by content and count;
- conditional jump (JTZ) taken, CAL/RET round trip, RLC carry, OUT port
  data;
- HLT entry and wake: RST 7 injected from HLT returns to the byte after the
  halted HLT and re-halts;
- RST 6 service rounds covering the undefined INR M/DCR M encodings (octal
  070/071): exact PC advance, unchanged flags, unchanged registers;
- conditional returns RFZ/RTZ in both senses (fall-through and return), with
  the flag state driven two ways (inherited zero=1, then CPI-driven zero=0);
- ALU with memory (ADM, CPM) against an LMI-written location;
- conditional calls CFc/CTc taken and not-taken.

## Real-Software Regression (tb_scelbal)

`make_scelbal_vectors.py` loads the authentic SCELBI SCELBAL binary at
0x0040 and runs the SIMH-derived oracle for exactly 200,000 instructions,
emitting per-instruction expected state (PC, all seven registers, four flags,
stack depth) and final memory. The testbench replays the same image through
the RTL and compares every instruction's full state and every final memory
byte. Measured profile: 396,409 memory reads, 63 memory writes, 475 input and
637 output transfers; all inputs return zero because the bench ties
`io_data_i` low, so the run spends most of its time in console-poll loops.

The script also emits `scelbal_opcount.txt` and a family coverage report
(review F3): the trace covers 15 of the 19 defined opcode families organically.
HLT, ALU-with-memory, conditional CAL, and RST are absent from the trace; the
directed regression covers all four, and `--strict-coverage` fails the vector
generation if the authentic-software coverage ever loses a family it had.
Feeding scripted console input so SCELBAL parses and runs a BASIC program
would deepen the trace further and remains future work.

## In Scope / Out of Scope

- In scope: the programming model (ISA, flags, stack, interrupts), the
  synchronous memory/I/O transaction protocol, reset behavior, ready
  freezing.
- Out of scope: original pin timing, READY analog behavior, and
  board-specific interrupt-acknowledge cycles; see the spec's assumptions.

## Exit Criteria

- Strict Verilator lint passes with zero warnings.
- Both regressions pass with the exact-check discipline above.
- SymbiYosys proves the properties in `formal_plan.md` and cover reaches
  every listed cover point.
- Opcode family coverage is reported and the union of directed plus
  authentic-software families is complete (19/19).
