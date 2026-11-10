# IBM System/360 — architecture specification (M2)

Status: **second functional increment**. This document fixes the architecture
that `src/` implements, records every deliberate deviation, and lists the
assumptions that must be validated before any compatibility claim. It is *not*
the full S/360 specification: the instruction-set and model option matrix is
owned by
[ai_engineer#382](https://github.com/hevangel/ai_engineer/issues/382) and will
extend this document as models are added.

Primary reference: **IBM System/360 Principles of Operation**, form
A22-6821-7, eighth edition (September 1968 reprint of A22-6821-6 with
Technical Newsletter changes). Page numbers below refer to that printing.
Provenance and licensing: [sources.md](sources.md).

## 1. Scope

In scope and implemented:

- the byte-addressed storage model, general registers, instruction formats and
  length recording, the PSW, and 24-bit address arithmetic (M1);
- 26 instructions: the M1 fixed-point/logical/branching subset plus
  `LPSW`, `SSM` and `SPM` (M2);
- **program interruptions** with the causes operation (1), privileged
  operation (2), specification (6) and fixed-point overflow (8), the program
  old PSW at storage `0x28`, the program new PSW at `0x68`, and problem-state
  enforcement (M2);
- the wait state as a state in which no instruction is fetched (M2).

Out of scope (each has its own issue or milestone): halfword, multiply/divide,
shift, decimal and floating-point operations; SS-format instructions;
protection keys, storage protection and DAT; supervisor-call, external, I/O and
machine-check interruptions; addressing exceptions; channel I/O; `EXECUTE`;
timing and microarchitecture.

## 2. Architectural summary

| Property | Value | Source |
|---|---|---|
| Storage unit | 8-bit byte, byte-addressable | pp. 8-9 |
| Storage operands | halfword (2), word (4), doubleword (8) | pp. 8-9 |
| Address size | 24 bits (`0x000000`-`0xFFFFFF`) | pp. 13-14 |
| General registers | 16 × 32 bits | pp. 9-10 |
| Instruction alignment | on halfword boundaries | p. 12 |
| Instruction formats | RR, RX, RS, SI, SS | p. 13, Figure 13 |
| Instruction length code | 1, 2 or 3 halfwords in PSW bits 32-33 | p. 13 |
| PSW size | 64 bits (doubleword) | p. 15, Figure 14 |
| Program old PSW | storage `0x28` (40) | p. 15, Figure 15 |
| Program new PSW | storage `0x68` (104) | p. 15, Figure 15 |

### 2.1 Instruction formats (Figure 13, p. 13)

| Format | Length | Fields (bit positions within the instruction) |
|---|---|---|
| RR | 2 bytes | `op(0-7) R1(8-11) R2(12-15)` |
| RX | 4 bytes | `op(0-7) R1(8-11) X2(12-15) B2(16-19) D2(20-31)` |
| RS | 4 bytes | `op(0-7) R1(8-11) R3(12-15) B2(16-19) D2(20-31)` |
| SI | 4 bytes | `op(0-7) I2(8-15) B1(16-19) D1(20-31)` |
| SS | 6 bytes | `op(0-7) L(8-15) B1(16-19) D1(20-31) B2(32-35) D2(36-47)` |

The first two opcode bits select the format class: `00` RR, `01` RX, `10`
RS/SI, `11` SS (p. 13). The core derives the instruction length from those
bits before decoding the operation, so an unimplemented instruction still has
the correct length.

### 2.2 Address generation (pp. 13-14)

The storage address is `B + X + D` computed as 24-bit binary numbers, with any
carry beyond bit 23 discarded. `B` and `X` are the low-order 24 bits of the
general registers named by the `B2`/`X2` fields; a **zero field means the
component is absent regardless of the register contents**. The 12-bit
displacement is treated as an unsigned integer. `LOAD ADDRESS` places the
address in bits 8-31 of the target register and zeroes bits 0-7 (p. 65).

### 2.3 Program status word (Figure 14, p. 15)

| Bits | Field |
|---|---|
| 0-7 | system mask (I/O channels, timer and external) |
| 8-11 | protection key |
| 12 | ASCII mode (A) |
| 13 | machine-check mask (M) |
| 14 | wait state (W) |
| 15 | problem state (P) |
| 16-31 | interruption code |
| 32-33 | instruction length code (ILC) |
| 34-35 | condition code (CC) |
| 36-39 | program mask (fixed-point overflow, decimal overflow, exponent underflow, significance) |
| 40-63 | instruction address |

Fields the core writes: instruction address, ILC, CC, program mask, system
mask. Fields it reads: problem state, wait state, system mask (stored, not yet
gating anything), program mask bit 36. The whole-word load path is used by
`LOAD PSW` and by interruption entry.

`LPSW` and interruption entry **do not retain** the interruption code or the
ILC of the loaded doubleword (p. 73); the core clears bits 16-33 on every load
and rewrites them when the PSW is next stored as an old PSW.

### 2.4 Condition codes

| Operation class | CC 0 | CC 1 | CC 2 | CC 3 | Source |
|---|---|---|---|---|---|
| Add, add halfword | sum zero | sum negative | sum positive | overflow | pp. 27-28 |
| Subtract, subtract halfword | difference zero | negative | positive | overflow | p. 29 |
| Compare, compare halfword | equal | first low | first high | not used | pp. 30, 55 |
| Compare logical | equal | first low | first high | not used | p. 55 |
| AND / OR / EXCLUSIVE OR | result zero | result nonzero | — | — | p. 55 |
| Load and test | zero | negative | positive | — | p. 27 |
| Add logical | sum zero, no carry | sum nonzero, no carry | sum zero, carry | sum nonzero, carry | pp. 29-30 |
| Compare logical (immediate) | equal | first low | first high | not used | pp. 54-55 |

Overflow is reported when the carry out of the sign-bit position disagrees with
the carry out of the high-order numeric bit position (p. 27). Comparison is
**algebraic on 32-bit signed integers** (p. 30) and must stay exact when the
difference overflows 32 bits; the arithmetic unit uses a 33-bit difference for
comparisons rather than the 32-bit subtractor's condition code.

### 2.5 Branching (pp. 73-74)

`BC`/`BCR` replace the updated instruction address with the branch address when
the condition code's mask bit is one. The mask nibble maps left to right onto
CC 0, 1, 2, 3 (manual bits 8-11), so the selected bit is `mask[3 - CC]`. In the
RR form a **zero R2 field means no branch**, which is the architectural no-op.
Branching instructions never change the condition code.

### 2.6 Status switching (pp. 72-74)

| Opcode | Mnemonic | Format | Privileged | Behaviour |
|---|---|---|---|---|
| `04` | SPM | RR | no | register bits 2-3 replace CC, bits 4-7 replace the program mask; other register bits are ignored and the register is unchanged |
| `80` | SSM | SI | yes | the byte at the operand address replaces PSW bits 0-7 (system mask); CC unchanged |
| `82` | LPSW | SI | yes | the doubleword at the operand address replaces the PSW; CC comes from its bits 34-35; problem and wait state come from bits 15 and 14; the operand address must have its three low-order bits zero |

`LPSW` is the only instruction that can enter the problem or wait state
(p. 73). The new PSW is not checked for exceptions during the load; the checks
happen when the next instruction is executed (p. 73 and p. 71).

### 2.7 Program interruptions (pp. 15-16, 71-72)

Every interruption stores the current PSW as an old PSW and makes the new PSW
current. The program old PSW is at `0x28`, the program new PSW at `0x68`
(Figure 15, p. 15). The interruption code occupies old-PSW bits 16-31.

Implemented causes (Figure 16, p. 16):

| Code | Cause | When taken | Old-PSW instruction address |
|---|---|---|---|
| 1 | Operation | the decoded opcode is not implemented | updated: instruction address + length |
| 2 | Privileged operation | `LPSW`/`SSM` executed with PSW bit 15 = 1 | updated |
| 6 | Specification | `LPSW` operand address not doubleword aligned | updated |
| 8 | Fixed-point overflow | `AR`/`A`/`SR`/`S` overflow with PSW bit 36 = 1 | the completed instruction's next address |

For the suppressed causes (1, 2, 6) the instruction is suppressed: the
condition code, the registers and storage are unchanged, and the instruction
address stored in the old PSW has been advanced by the number of halfwords in
the ILC (p. 72). For fixed-point overflow the instruction completes — result
and CC 3 are stored — and the interruption follows (pp. 27-28).

The interruption sequence takes five cycles on this core: two word stores for
the old PSW, two word reads for the new PSW, and the PSW load. It is not
interruptible by a second program interruption.

## 3. Storage interface

| Signal | Width | Meaning |
|---|---|---|
| `mem_addr` | 24 | byte address |
| `mem_we` | 1 | write strobe (one cycle) |
| `mem_wdata` | 32 | word-aligned write data |
| `mem_wbe` | 4 | byte write enables, lane 3 = byte at the lowest address |
| `mem_rdata` | 32 | aligned word containing `mem_addr`, read combinationally |

Byte order follows the architecture: the byte at the lowest address of a word
occupies bits 31-24. Reads are combinational; the write port takes one cycle.
Storage timing, interleaving, protection and channel contention are not
modelled. Word operands must be aligned; apart from the `LPSW` doubleword
check, unaligned operands are not detected.

## 4. Implemented instruction set (26 operations)

| Opcode | Mnemonic | Format | Operation | CC |
|---|---|---|---|---|
| `04` | SPM | RR | set program mask | set |
| `07` | BCR | RR | branch on condition | unchanged |
| `12` | LTR | RR | load and test | set |
| `14` | NR | RR | AND | set |
| `15` | CLR | RR | compare logical | set |
| `16` | OR | RR | OR | set |
| `17` | XR | RR | exclusive OR | set |
| `18` | LR | RR | load | unchanged |
| `19` | CR | RR | compare | set |
| `1A` | AR | RR | add | set |
| `1B` | SR | RR | subtract | set |
| `41` | LA | RX | load address | unchanged |
| `47` | BC | RX | branch on condition | unchanged |
| `50` | ST | RX | store | unchanged |
| `54` | N | RX | AND | set |
| `55` | CL | RX | compare logical | set |
| `56` | O | RX | OR | set |
| `57` | X | RX | exclusive OR | set |
| `58` | L | RX | load | unchanged |
| `59` | C | RX | compare | set |
| `5A` | A | RX | add | set |
| `5B` | S | RX | subtract | set |
| `80` | SSM | SI | set system mask | unchanged |
| `82` | LPSW | SI | load PSW | loaded |
| `92` | MVI | SI | move immediate byte | unchanged |
| `95` | CLI | SI | compare logical immediate byte | set |

Encodings are from the instruction tables on pp. 26-32 (fixed point), 53-56
(logical), 72-74 (status switching) and 73-74 (branching). Every other
operation code is decoded as an *unimplemented* instruction of the correct
length and raises interruption code 1.

## 5. Deviations from the architecture

These are deliberate and must not be presented as architectural behaviour.

1. **Assigned but unimplemented instructions raise code 1.** A real S/360
   executes, for example, `MR`, `SH`, `MVC`, `TR` and `SVC`; this core decodes
   them as an operation exception. This is an implementation gap, not
   architecture, and is the reason no compatibility claim may be made until
   the remaining instruction groups and the external oracle exist.
2. **Only program interruptions exist.** Supervisor call, external, I/O and
   machine-check interruptions are not implemented; their codes (3, 4, 5, 7
   and the other classes) are never generated. Storage protection and
   addressing exceptions are therefore also absent, since no storage limit or
   key is modelled.
3. **Specification exceptions are partial.** Only the `LPSW` doubleword
   alignment rule is checked. Odd instruction addresses, unaligned halfword or
   word operands, and invalid register fields are not detected.
4. **No protection or DAT.** The protection key field is stored and inert.
5. **Wait state cannot be left.** With no I/O or external interruption, no new
   PSW can arrive, so `LPSW` with bit 14 set stops the machine permanently.
   This matches the architectural definition (p. 17) for a machine with no
   such interruption sources, but it is a limitation of this core.
6. **No timing.** Instruction execution takes one fetch cycle per instruction
   byte plus fixed decode/execute/commit cycles, and five cycles per
   interruption. No storage access timing, overlap, prefetch or model-specific
   microarchitecture is modelled.
7. **No `EXECUTE`, `SVC`, halfword, multiply/divide, decimal, floating-point or
   SS operations.** They raise code 1 as described above.

## 6. Assumption ledger

| ID | Assumption | Why it is an assumption | Validation |
|---|---|---|---|
| A-1 | Storage reads are combinational; a byte is available in the cycle the address is presented. | The manual specifies program-visible behaviour, not access timing. | Later storage/timing milestone; not observable by programs. |
| A-2 | The reset PSW is all zero except the instruction address parameter (`RESET_IA`). | No architectural reset PSW exists; `IPL` reads the IPL PSW from storage. | Replaced by IPL (issue #386) before any OS boot claim. |
| A-3 | An implemented-length but unassigned/unimplemented operation raises code 1 with the instruction address advanced by the ILC. | The manual defines code 1 for *unassigned* opcodes (p. 16); it does not define how a partially implemented machine should report a missing instruction. | Must disappear as the instruction set is completed; tracked by #384. |
| A-4 | Byte operands are read from the aligned word and word operands must be aligned. | The storage port returns an aligned word. | Re-check when specification exceptions are complete. |
| A-5 | The interruption sequence is treated as atomic (no priority nesting). | The manual describes priority ordering between classes (p. 16); with only program interruptions there is no competing request. | Re-check when I/O and external interruptions exist. |

## 7. Model option matrix

The family issue requires model-specific deviations to be preserved. Only the
following are recorded here, and each still needs its primary source (the
model's own Functional Characteristics manual) in issue
[#381](https://github.com/hevangel/ai_engineer/issues/381)/[#382](https://github.com/hevangel/ai_engineer/issues/382):

| Model | Deviation to preserve | Status |
|---|---|---|
| 20 | Reduced instruction set; eight 16-bit general registers instead of sixteen 32-bit | secondary source only (see README); not implemented |
| 22 | Model 30 processor with reduced maximum storage and slower channels | not sourced |
| 25 | Reduced-cost model; program-interrupt and I/O differences | not sourced |
| 44 | Storage-to-storage instructions and five other complex instructions removed; additional scientific instructions | secondary source only; not implemented |
| 67 | Dynamic address translation and virtual memory | not implemented |
| 85, 91, 95, 195 | Cache, out-of-order execution and hardwired control variants | not implemented |

No model may be declared reconstructed from this shared engine alone: it is the
common subset, and each model issue owns its deviations, options and
microarchitecture.

## 8. Related documents

- [sources.md](sources.md) — provenance, hashes, licensing, coverage gaps
- [../plans/implementation_plan.md](../plans/implementation_plan.md)
- [../plans/testplan.md](../plans/testplan.md)
- [../plans/formal_plan.md](../plans/formal_plan.md)
- [../report/2026-11-05-m1-core.md](../report/2026-11-05-m1-core.md)
- [../report/2026-11-08-m2-status-switching.md](../report/2026-11-08-m2-status-switching.md)
