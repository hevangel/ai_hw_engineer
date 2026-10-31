# MOS 6502 specification

## Scope and sources

Target: original NMOS 6502 instruction behavior, reset, interrupts, and externally visible bus cycles, for an Apple II system. Primary sources are the [MOS programming manual](https://www.bitsavers.org/components/mosTechnology/6500-50A_MCS6500pgmManJan76.pdf) and [MOS hardware manual](https://archive.6502.org/books/mcs6500_family_hardware_manual.pdf). This is a staged implementation; the current RTL is only the first subset.

## Current interface

`clk` and synchronous active-low `rst_n`; 16-bit `bus_addr`; 8-bit combinational `bus_data_i`; 8-bit `bus_data_o`; high `bus_we` during write; `fetch_o` while fetching an opcode; `pc_o`, `status_o`, `x_o`, and `y_o` for verification; `fault_o` after an unsupported opcode. Reads are combinational in the current test harness. All transfers advance on rising clock edges.

## Current instruction subset

| Opcode | Instruction | Effect |
|---|---|---|
| EA | NOP | Advance PC one byte |
| A9/A2/A0 | LDA/LDX/LDY immediate | Load operand; set N and Z |
| 8D | STA absolute | Write A to the 16-bit operand address |
| 4C | JMP absolute | Load PC from the 16-bit operand |
| A5/A6/A4, AD/AE/AC | LDA/LDX/LDY zero page and absolute | Load memory; set N and Z |
| 24/2C | BIT zero page and absolute | Set N/V from memory and Z from A AND memory |
| 10/30/50/70/90/B0/D0/F0 | BPL/BMI/BVC/BVS/BCC/BCS/BNE/BEQ | Signed relative conditional branch |
| 18/38/58/78/B8/D8/F8 | CLC/SEC/CLI/SEI/CLV/CLD/SED | Change the selected status flag only |

Reset loads PC from `$FFFC` (low byte) and `$FFFD` (high byte). Unsupported opcodes enter `fault_o`; this is a development diagnostic, not 6502 behavior.

## ASSUMPTION ledger

- **ASSUMPTION: simplified read bus.** The first RTL uses a combinational read bus and omits NMOS dummy accesses. This must be replaced with manual-checked bus sequencing before hardware compatibility is claimed.
- **ASSUMPTION: synchronous project reset.** The project reset is synchronous active-low, while the physical NMOS reset pin has different electrical and timing behavior. System integration must model the resulting vector fetch and cycle sequence.

## Memory and branch milestone

Add zero-page and absolute LDA/LDX/LDY, zero-page/absolute BIT, all eight
conditional branches, and CLC/SEC/CLI/SEI/CLV/CLD/SED. Branch offsets are
signed relative to the address after the operand, with 16-bit wrapping.
BIT copies memory bits 7 and 6 to N/V and sets Z from A AND memory.
These semantics follow sections 3, 4, and 7 of the
[Synertek reprint of the MOS programming manual](https://syncopate.us/books/Synertek6502ProgrammingManual.html).
The implementation remains functionally sequenced, not bus-cycle accurate.
The integration acceptance test polls the Apple II keyboard through CPU
instructions and writes two injected characters to text RAM.

## Remaining completion gates

Implement all documented opcodes and addressing modes, decimal arithmetic, stack and interrupt behavior, page-cross timing, and NMOS bus side effects. Validate against an independent oracle derived from external artifacts. Add an authentic Apple II ROM/software regression to `run_all.sh` and require exact post-instruction PC and next instruction. Run lint, formal BMC/prove/cover, simulation, and synthesis before a sign-off PR.
