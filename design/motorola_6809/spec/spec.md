# Specification: Motorola MC6809

## 1. Overview

The MC6809 (1978) is Motorola's flagship 8-bit processor: the 6800's
accumulators A/B (together D), two index registers (X, Y), separate user
(U) and system (S) stack pointers, a direct-page register (DP), 16-bit
index/indirect addressing through the postbyte, 16-bit arithmetic, MUL,
position-independent long branches, three software interrupts, FIRQ with
its minimal frame, CWAI and SYNC. This design recreates the documented
architectural behavior on a functional transaction bus (one bus transfer
per `clk`), like the project's other functional-bus CPU cores.

Out of contract: the original pin protocol and per-opcode cycle counts.
The 6809E/6809 distinction (early bus release) is not modeled.

## 2. Features

- Full documented instruction set (page 1, page 2 $10, page 3 $11).
- Registers: A, B, D, X, Y, U, S, DP, PC, CC (E F H I N Z V C).
- Addressing modes: inherent, immediate, direct (DP page), extended,
  extended-indirect, relative, and the full indexed postbyte set
  (,R+ ,R++ ,-R ,--R ,R n5/R n8/n16 A/B/D,R PCR offsets; indirect forms).
- TFR/EXG, PSHS/PULS/PSHU/PULU, LEAX/LEAY/LEAS/LEAU.
- MUL (unsigned 8×8→16, C = result bit 7), SEX, ABX (unsigned B), DAA.
- Interrupts: RESET, NMI (edge-latched, disarmed until the first LDS
  after reset), IRQ, FIRQ (PC/CC-only frame), SWI/SWI2/SWI3, CWAI, SYNC,
  RTI with E-bit-driven frame restore. Vectors FFF0-FFFA.
- Stack frame layout (bottom-up): CC, A, B, DP, X, Y, U/S, PC; PSHS/PSHU
  push PC first, CC last (same layout); FIRQ frame: CC, PC (E=0).

## 3. Interfaces

### 3.1 Port List

| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| `clk` | input | 1 | System clock (one bus transaction per edge) |
| `rst_n` | input | 1 | Active-low synchronous reset |
| `bus_addr` | output | 16 | Address bus |
| `bus_data_i` | input | 8 | Read data (combinational) |
| `bus_data_o` | output | 8 | Write data |
| `bus_we` | output | 1 | 1 = write cycle |
| `vma_o` | output | 1 | Valid-memory-address strobe |
| `irq_n` | input | 1 | Level IRQ request, masked by CC.I |
| `firq_n` | input | 1 | Level FIRQ request, masked by CC.F |
| `nmi_n` | input | 1 | NMI, falling-edge detected |
| `halted_o` | output | 1 | In CWAI/SYNC wait state |
| `sync_o` | output | 1 | Opcode fetch in progress (testbench boundary) |
| `pc_o`, `dp_o` | output | 16/8 | Debug outputs |
| `a_o`, `b_o`, `cc_o` | output | 8 | Debug outputs |
| `x_o`, `y_o`, `u_o`, `s_o` | output | 16 | Debug outputs |

### 3.2 Interface Protocols

Functional transaction bus as in `motorola_6800` (section 3.2 there).

## 4. Functional Description

### 4.1 Registers and Condition Codes

CC bit positions: C=0, V=1, Z=2, N=3, I=4, H=5, F=6, E=7.
- H is set by ADDA/ADDB/ADDD? (H from bit-3 carry on ADD/ADC/ABA-class
  ops only; per the data sheet H applies to the 8-bit adds; DAA relies on
  it). The reyco suite never checks H after subtracts or shifts.
- FIRQ clears E in its stacked CC and sets both F and I.
- IRQ stacks the entire frame (E=1) and sets I.
- SWI/SWI2/SWI3 stack the entire frame (E=1) and set I and F.
- NMI stacks the entire frame (E=1), sets no mask bits, is edge-latched
  and is not serviced until the first LDS after reset initializes S.

### 4.2 Addressing Modes

Direct: effective address = {DP, addr8}. Immediate, extended, relative
(short 8-bit, long 16-bit). Indexed postbyte decode (PB):

| PB[7] | Form |
|-------|------|
| 0 | 5-bit signed offset from PB[2:0], R = PB[6:5] |
| 1 | R = PB[6:5]; type = PB[4:0]: 0,R+ 1,R++ 2,-R 3,--R 4,,R; 8 A,R; 9 B,R; B D,R; 18 n8; 19 n16; 1B n8,PCR; 1D n16,PCR; 1F extended-indirect; bit0 set = indirect |

Reserved postbytes decode as offset-0 indexing (assumption ledger).

### 4.3 Instruction Set

Documented MC6809 instruction set per the Motorola MC6809 Microprocessor
Programming Manual / data sheet. Semantics pinned by the sources:
- MUL: Z from the 16-bit product, C = product bit 7.
- ABX: X + B with B unsigned (no sign extension).
- DAA: the 6800-family nibble-adjust table (V is left unchanged; the
  reyco suite never checks V after DAA).
- TFR/EXG: 8-bit class = {A, B, CC, DP}, 16-bit class = {D, X, Y, U, S,
  PC}; mixed-class transfers are data-sheet-undefined and implemented as
  zero-extend (8→16) / low-byte (16→8).
- Long branches are 16-bit signed; LBRA/LBSR are unconditional.
- CWAI: CC ← CC AND imm, then push the entire frame and wait; a waking
  interrupt does not push again.
- SYNC: stop; an unmasked pending interrupt is serviced, a masked pending
  interrupt resumes execution (poll loop).
- PSHS/PSHU push PC first, CC last; PULS/PULU pull in reverse; the U/S
  pair: PSHS pushes U, PSHU pushes S.

### 4.4 Interrupts and Control

Vectors: FFF2 SWI3, FFF4 SWI2, FFF6 FIRQ, FFF8 IRQ, FFFA SWI, FFFC NMI,
FFFE RESET (FFF0/FFF1 reserved; map per the M6809 Programming Manual,
cross-checked against MAME's m6809 and the reyco2000 suite's ROM tables).

### 4.5 Control Logic

One microsequenced state machine with prefix handling ($10/$11 pages),
indexed postbyte evaluation states (offset fetch, indirect pointer
fetch), and counter-driven push/pull loops.

## 5. Register Map

Not applicable (CPU core).

## 6. Timing Requirements

One bus transaction per `clk`; original cycle counts are out of contract.

## 7. Error Handling

Illegal opcodes on pages 2/3 execute as their documented set requires;
the reyco suite's coverage defines the trusted behavior envelope.

## 8. Power Considerations

Not modeled.

## 9. Constraints

- Lint clean under `verilator --lint-only -Wall`.
- Yosys `synth` clean; formal BMC/cover on the sequencer and frames.

## 10. Assumption Ledger

- `ASSUMPTION:` Reserved indexed postbytes decode as offset-0 indexing;
  real hardware treats them as undefined and the reyco suite never uses
  them.
- `ASSUMPTION:` Mixed-class TFR/EXG zero-extends 8→16 and truncates
  16→8; the data sheet marks these undefined and the reyco suite never
  checks them.
- `ASSUMPTION:` DAA leaves V unchanged (data sheet: undefined; never
  checked by the reyco suite).
- `ASSUMPTION:` The NMI disarm-after-reset is cleared by any LDS that
  writes S (the data sheet's "NMI disabled until stack pointer loaded").
- `ASSUMPTION:` DEV device registers ($FF00 lines, $FF0F exit) are a
  test-harness convention of the reyco suite, implemented in the
  testbench/ISS, not part of the RTL contract.
