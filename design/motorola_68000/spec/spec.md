# Specification: Motorola MC68000 (work in progress)

## 1. Overview

The MC68000 (1979) is Motorola's 16-bit supercellar processor: sixteen
32-bit registers (eight data D0-D7, eight address A0-A7), a 24-bit
address space (16 MiB), user/supervisor separation with separate USP/SSP,
a 16-bit status register (T S I2-0 — X N Z V C), fourteen addressing
modes, and exception processing with a two-word supervisor-stack frame.
This design recreates the documented architectural behavior on a
functional transaction bus (one byte/word transfer per `clk`), verified
against the SingleStepTests 680x0 vector suite (1,000,060
single-instruction tests with full processor and memory state before and
after).

**Status: work in progress.** The verification harness is complete and
the RTL skeleton is established; instruction classes are landing
incrementally (see section 4 and report/final_report.md).

## 2. Features (target contract)

- Register file: D0-D7, A0-A7 (32-bit each; A7 doubles as SP, banked
  USP/SSP by SR.S).
- Instruction set per the suite's 124 opcode files: MOVE.B/W/L (all 14
  addressing modes), MOVEA, MOVEQ, ADD/ADDA/ADDQ/ADDX, SUB family, CMP/
  CMPA/CMPM, AND/OR/EOR + immediates (incl. to CCR/SR), NOT/NEG/NEGX/
  CLR/TST/EXT/SWAP, MULU/MULS/DIVU/DIVS, shifts/rotates (register and
  memory forms, ROX through X), bit ops (dynamic/static), Bcc/BSR/DBcc/
  Scc, JMP/JSR/RTS/RTR/RTE, LEA/PEA/LINK/UNLK, EXG, MOVEM, MOVEP, TAS,
  MOVE to/from CCR/SR/USP, TRAP/TRAPV/CHK, ILLEGAL, and exception
  framing for illegal/A-line/F-line/privilege/divide-by-zero/trace.
- Flags per the 68000 data sheet, including ADDX/SUBX/NEGX Z-unchanged-
  on-nonzero, X through rotates, and DIV overflow rules.

## 3. Interfaces

### 3.1 Port List

| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| `clk` | input | 1 | System clock (one bus transfer per edge) |
| `rst_n` | input | 1 | Active-low synchronous reset |
| `bus_addr` | output | 24 | Address bus |
| `bus_data_o` | output | 16 | Write data |
| `bus_data_i` | input | 16 | Read data |
| `bus_we` | output | 1 | Word write strobe (addr even) |
| `bus_bwe` | output | 1 | Byte write strobe |
| `vma_o` | output | 1 | Valid-memory-address strobe |
| `ipl_n` | input | 3 | Interrupt priority (TB ties 111) |
| `done_o` | output | 1 | Instruction-retired pulse (harness) |
| `halted_o` | output | 1 | STOP state |

### 3.2 Verification harness contract

The SingleStepTests vectors drive the design through the compiled test
stream (`scripts/make_68000_vectors.py` → work/sim/m68k_*.bin): the
harness seeds sparse memory with the test's initial RAM patches, injects
the opcode word at PC, pokes the 17 registers/SR/PC, runs one instruction
(until `done_o`), and compares all registers, SR, PC, and every
listed-final memory byte. Out of contract: the 68000's internal prefetch
queue, per-opcode cycle counts, and per-cycle bus-transaction traces
(the suite's `transactions` field) — final architectural state only.

## 4. Implementation status

| Item | State |
|------|-------|
| Vector harness (1,000,060 tests compiled) | complete |
| RTL skeleton: register file, USP/SSP, fetch, retire handshake | complete |
| MOVE group (all modes) | skeleton EA walk present, not yet verified |
| Remaining instruction classes | open |
| Exception framing | open |
| Formal properties | open |

## 5. Assumption Ledger

- `ASSUMPTION:` The suite's `initial.ram`/`final.ram` lists enumerate all
  non-zero bytes of the test's memory state; the opcode word arrives via
  the test name and is injected at PC by the harness (verified against
  the ADD.b/MOVE.l/TRAP test structures).
- `ASSUMPTION:` IPL is tied to no-interrupt; the suite does not exercise
  interrupt pin timing.
- `ASSUMPTION:` `transactions` (bus traces) are not compared; the 68000's
  prefetch queue makes per-cycle bus behavior implementation-specific.
