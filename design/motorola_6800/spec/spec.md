# Specification: Motorola MC6800

## 1. Overview

The MC6800 (1974) is Motorola's first general-purpose 8-bit microprocessor: six
16-bit-equivalent registers (two 8-bit accumulators, index register, stack
pointer, program counter) plus an 8-bit condition-code register, 72 documented
instructions, six addressing modes and a 64 KiB flat address space. This
design recreates the documented architectural behavior on a **functional
transaction bus** in the style of the project's other CPU cores
(`intel_8080`, `mos_6502`): every bus transfer takes exactly one `clk`.

Out of contract: the original two-phase (PHI1/PHI2) pin protocol, DBE/TSC bus
handshakes, per-opcode cycle counts and electrical timing. The 6800's
architectural register/flag semantics, including the documented DAA truth
table, interrupt stacking order and wait-for-interrupt state, are in contract.

## 2. Features

- Full documented instruction set (72 instructions, 197 opcodes).
- Six addressing modes: ACCX (inherent), immediate, direct, extended,
  indexed, relative.
- Registers: A, B, IX (16-bit), SP (16-bit), PC (16-bit), CC (H I N Z V C).
- Documented DAA BCD-adjust truth table.
- Interrupts: RESET, NMI (edge), IRQ (level, maskable) and SWI, each pushing
  the 7-byte frame PCL, PCH, IXL, IXH, ACCA, ACCB, CC in that order (each
  byte stored at SP, then SP decremented); the stacked CC has bits 7-6 set
  and the pre-interrupt I, and the live I is set after the push.
- WAI stacks the same 7 bytes and halts; RTI restores in reverse order
  (CC, ACCB, ACCA, IXH, IXL, PCH, PCL).
- Single-cycle bus transaction model (one read or write per `clk`).

## 3. Interfaces

### 3.1 Port List

| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| `clk` | input | 1 | System clock (one bus transaction per edge) |
| `rst_n` | input | 1 | Active-low synchronous reset |
| `bus_addr` | output | 16 | Address bus |
| `bus_data_i` | input | 8 | Read data (combinational) |
| `bus_data_o` | output | 8 | Write data |
| `bus_we` | output | 1 | 1 = write cycle, 0 = read cycle |
| `vma_o` | output | 1 | Valid-memory-address strobe (asserted every transaction) |
| `irq_n` | input | 1 | Level interrupt request, masked while CC.I = 1 |
| `nmi_n` | input | 1 | Non-maskable request, falling-edge detected |
| `halted_o` | output | 1 | In WAI wait state (no bus activity) |
| `sync_o` | output | 1 | Opcode fetch in progress (testbench instruction boundary) |
| `pc_o` | output | 16 | Program counter (debug) |
| `a_o`, `b_o` | output | 8 | Accumulators (debug) |
| `ix_o`, `sp_o` | output | 16 | Index register / stack pointer (debug) |
| `cc_o` | output | 8 | Condition codes (debug) |

### 3.2 Interface Protocols

Functional transaction bus: during each clocked state the core drives
`bus_addr`, `bus_we` and (`bus_we` ? `bus_data_o` : high-Z sense via
`bus_data_i`) and consumes the transfer in the same cycle, matching the
`mos_6502` functional-bus convention. `vma_o` is asserted on every
transaction, including interrupt-vector reads.

## 4. Functional Description

### 4.1 Registers and Condition Codes

| Register | Width | Notes |
|----------|-------|-------|
| A, B | 8 | Accumulators |
| IX | 16 | Index register; XH/XL pushed separately |
| SP | 16 | Stack pointer; pushes decrement before store |
| PC | 16 | Program counter |
| CC | 8 | `bit7..0 = 1 1 H I N Z V C` (TPA reads bits 7-6 as 1) |

- H: BCD carry from bit 3 (set by ADD/ADC/ABA only, per data sheet).
- I: IRQ mask (set automatically on any interrupt acknowledge).
- V: two's-complement overflow (set by ADD/ADC/SUB/SBC/ABA/SBA per data
  sheet rules; COM/CLR/NEG/INC/DEC/shifts have fixed documented rules).
- Z: zero result. C: carry/borrow (NOT-of-borrow for subtracts).

### 4.2 Addressing Modes

| Mode | Encoding | Effective address |
|------|----------|-------------------|
| ACCA/ACCB | inherent | register operand |
| IMM | operand byte follows opcode | pc+1 |
| DIR | 8-bit address byte | `00:addr8` |
| EXT | 16-bit address (hi, lo) | addr |
| IND | 8-bit offset byte | `(IX + off8) mod 2^16` |
| REL | signed 8-bit offset | `pc_after + off8` |

### 4.3 Instruction Set

Documented MC6800 instruction set (Motorola MC6800 Programming Reference
Manual, M68PRM(D) 1974/1976): loads/stores (LDA, STA, LDS, STS, LDX, STX),
transfers (TAB, TBA, TAP, TPA, TSX, TXS, DES, DEX, INS, INX), arithmetic
(ABA, ADD, ADC, SUB, SBC, SBA, NEG, DAA, INC, DEC), logic (AND, ORA, EOR,
COM), compares (CBA, CMP, BIT, TST), shifts (ASL, ASR, LSR, ROL, ROR),
jumps (JMP, JSR, RTS, Bcc, BRA, BSR, NOP), stack (PSH, PUL), status
(CLC, SEC, CLI, SEI, CLV, SEV), interrupt/wait (WAI, SWI, RTI).

Instruction semantics that must match the manual exactly:
- Subtract-family carry is the borrow itself: C is set when the operand's
  magnitude exceeds the accumulator's (M68PRM SUB: "set if the absolute
  value of the contents of memory are larger than the absolute value of
  the accumulator"); equal operands clear C. This differs from the 6502's
  inverted convention (an escaped-defect class caught by the third-party
  test suite).
- V rules per operation class as documented (sum-of-carries for adds,
  sign-change conditions for subtracts; COM/CLR/NEG/INC/DEC fixed values).
- DAA: documented truth table on (A, H, C) after ADD/ADC/ABA on BCD operands.
- TAP loads CC from A (interrupt mask from A bit 4); TPA returns CC with
  bits 7-6 set.
- TSX = IX := SP+1; TXS = SP := IX-1 (the manual's cross-increment pair).
- Pushes (PSHA/B, JSR, BSR, interrupts, WAI) decrement SP then store;
  pulls increment after load.

### 4.4 Interrupts and Control

- Reset: PC loaded from the $FFFE/$FFFF vector pair; I is set.
- IRQ (level, sampled while I=0) / NMI (falling edge) / SWI: push the
  7-byte frame (PCL, PCH, IXL, IXH, A, B, CC — CC stored with bits 7-6
  set and the pre-interrupt I value), then set live I=1, then load PC
  from the vector ($FFF8, $FFFC, $FFFA respectively).
- The saved PC is the address of the next unexecuted instruction (for
  SWI/WAI: the SWI/WAI address plus one).
- WAI: push the 7-byte frame, then halt with `halted_o`; IRQ (I clear)
  or NMI wakes the core: live I is set and the vector fetch follows
  directly (no second frame).
- RTI: pull CC, ACCB, ACCA, IXH, IXL, PCH, PCL.
- Pushes store at SP then decrement SP; pulls increment SP then read.

### 4.5 Control Logic

A single microsequenced state machine (`state_e`) walks per-instruction
sequences: fetch → mode/address-fetch states → operand read / write / RMW
states → execute. The ALU operates combinationally on operands held in
`data_q`/registers; results are registered at state exit.

## 5. Register Map

Not applicable (CPU core; the register-file view is section 4.1).

## 6. Timing Requirements

One bus transaction per `clk`. Cycle counts are not guaranteed to match the
original silicon (out of contract; see section 1).

## 7. Error Handling

- Undocumented opcodes execute as documented 2-byte no-ops (NOP-like with
  the immediate byte skipped) — see assumption ledger below.
- The core signals instruction boundaries on `sync_o` for testbench
  observation only.

## 8. Power Considerations

Not modeled (digital functional model).

## 9. Constraints

- Lint clean under `verilator --lint-only -Wall`.
- Yosys `synth` clean; formal BMC/cover for reset, interrupt-frame and
  sequencer progress properties.

## 10. Assumption Ledger

Any behavior not explicitly pinned by the Motorola programming manual is
listed here and cross-checked in verification:

- `ASSUMPTION:` Undocumented opcodes (not in the 197-opcode documented set)
  are treated as 2-byte no-ops (the addressing mode's first operand byte
  is consumed, then execution continues); the manual marks them unassigned
  and MIKBUG-era software does not rely on their side effects.
- `ASSUMPTION:` VMA is asserted on every bus transaction (the data sheet's
  VMA/DBE gating is a board-level detail out of the functional contract).
- `ASSUMPTION:` In the WAI wait state a concurrently-asserted NMI and IRQ
  resolve NMI-first (data sheet priority NMI > IRQ).
- `ASSUMPTION:` The stacked condition-code byte keeps the pre-interrupt I
  value; the live I is set after the push and before the vector fetch
  (M68PRM section 3.3.4: status saved first, "the interrupt mask bit is
  then set", then the pointer is loaded).
- `ASSUMPTION:` DAA is only documented after ADD/ADC/ABA on BCD operands;
  the RTL implements the manual's truth table independent of how A was
  produced (the table itself is total over (H, C, A) combinations).
