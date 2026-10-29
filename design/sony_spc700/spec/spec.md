# Specification: Sony SPC700 CPU core

## 1. Overview

8-bit CPU with registers A, X, Y, SP (stack in page 1), PC and PSW
(NVPBHIZC). The P flag moves the direct page between `$00xx` and `$01xx`.
All 256 opcodes are defined, including MUL (YA = Y·A), DIV (YA / X with the
hardware's overflow behaviour), DAA/DAS, the 1-bit operations (AND1, OR1,
EOR1, NOT1, MOV1), TSET1/TCLR1, CBNE/DBNZ, PCALL, TCALL n, BRK/RETI, SLEEP
and STOP.

## 2. Interfaces

| Port | Dir | Width | Description |
|---|---|---|---|
| `clk`, `rst_n` | in | 1 | Clock and synchronous active-low reset |
| `ce` | in | 1 | End of the current bus cycle (1.024 MHz in the S-SMP) |
| `addr_o` | out | 16 | Address of the current cycle |
| `data_i` | in | 8 | Read data, sampled at `ce` |
| `data_o` | out | 8 | Write data |
| `rd_o` | out | 1 | Read cycle (includes dummy reads) |
| `we_o` | out | 1 | Write cycle; neither = internal cycle |
| `fetch_o` | out | 1 | Opcode fetch (instruction boundary) |
| `halted_o` | out | 1 | SLEEP or STOP executed |
| `pc_o` … `psw_o` | out | | Register observation |

The bus request of each cycle is combinational from the registered state.

## 3. Behaviour

- Reset reads the vector at `$FFFE/$FFFF` (the IPL ROM in the S-SMP),
  with SP, A, X, Y and PSW cleared.
- Dummy reads appear on the bus exactly where the hardware performs them
  (they matter for the read-sensitive timer outputs in the S-SMP).
- SLEEP and STOP halt the core; the S-SMP has no interrupt sources, so
  only reset resumes it.

## 4. Sources

- [fullsnes: SNES APU SPC700 CPU](https://problemkaputt.de/fullsnes.htm#snesapucpuoverview)
  (instruction set, flags, cycle counts) — primary description.
- [SingleStepTests spc700](https://github.com/SingleStepTests/spc700) at
  revision `67d15f49`: 1,000 random cases per opcode with every bus cycle
  (read, write or wait, address, data) and the final state. Used as the
  independent oracle; expected values are never edited.

## 5. Assumption ledger

| Assumption | Evidence | Status |
|---|---|---|
| Reads recorded without a value are dummy reads; only the address is compared | SingleStepTests format | Implemented |
| SLEEP/STOP repeat internal cycles while halted | SingleStepTests records | Implemented; matches all cases |
| No interrupt inputs (the S-SMP leaves them unconnected) | fullsnes | Out of scope |
