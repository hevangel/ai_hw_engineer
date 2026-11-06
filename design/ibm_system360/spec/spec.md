# IBM System/360 — M1 architecture specification

Status: **first functional increment**. This document fixes the architecture
that `src/` implements today, records every deliberate deviation, and lists the
assumptions that must be validated before any compatibility claim is made.
It is *not* the full S/360 specification: the instruction-set and model option
matrix is owned by
[ai_engineer#382](https://github.com/hevangel/ai_engineer/issues/382) and will
extend this document as models are added.

Primary reference: **IBM System/360 Principles of Operation**, form
A22-6821-7, eighth edition (September 1968 reprint of A22-6821-6 with
Technical Newsletter changes). Page numbers below refer to that printing.
Provenance and licensing: [sources.md](sources.md).

## 1. Scope of the M1 core

In scope:

- the byte-addressed storage model, general registers, instruction formats and
  length recording, the PSW, and 24-bit address arithmetic;
- the 23-instruction subset listed in §4, with the condition-code rules the
  manual states for them;
- a single-cycle-per-operation storage interface and a one-instruction-at-a-time
  sequencer.

Out of scope for M1 (each has its own issue or model milestone): halfword,
multiply/divide, shift, decimal and floating-point operations; SS-format
instructions; protection keys, storage protection and DAT; all interruptions
and PSW swapping; channel I/O; wait/problem state; `EXECUTE`; timing and
microarchitecture.

## 2. Architectural summary (as implemented)

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

### 2.1 Instruction formats (Figure 13, p. 13)

| Format | Length | Fields (bit positions within the instruction) |
|---|---|---|
| RR | 2 bytes | `op(0-7) R1(8-11) R2(12-15)` |
| RX | 4 bytes | `op(0-7) R1(8-11) X2(12-15) B2(16-19) D2(20-31)` |
| RS | 4 bytes | `op(0-7) R1(8-11) R3(12-15) B2(16-19) D2(20-31)` |
| SI | 4 bytes | `op(0-7) I2(8-15) B1(16-19) D1(20-31)` |
| SS | 6 bytes | `op(0-7) L(8-15) B1(16-19) D1(20-31) B2(32-35) D2(36-47)` |

The first two opcode bits select the format class: `00` RR, `01` RX, `10`
RS/SI, `11` SS (p. 13). The M1 core derives the instruction length from those
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

The M1 core writes only the instruction address, the ILC and the condition
code. It reads the system mask and program mask for nothing yet, because no
interruption can be taken. The PSW register has a whole-word load port that is
tied off in M1 and is intended for `LOAD PSW` and interruption entry.

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
the carry out of the high-order numeric bit position (p. 27); with the
fixed-point overflow mask set the manual requires a program interruption, which
M1 does not take — see §5.

Comparison is **algebraic on 32-bit signed integers** (p. 30) and must stay
exact when the difference overflows 32 bits; the arithmetic unit therefore uses
a 33-bit difference for comparisons rather than the 32-bit subtractor's
condition code.

### 2.5 Branching (pp. 73-74)

`BC`/`BCR` replace the updated instruction address with the branch address when
the condition code's mask bit is one. The mask nibble maps left to right onto
CC 0, 1, 2, 3 (manual bits 8-11), so the selected bit is `mask[3 - CC]`. In the
RR form a **zero R2 field means no branch**, which is the architectural no-op.
Branching instructions never change the condition code.

## 3. Storage interface

The core exposes a single storage port:

| Signal | Width | Meaning |
|---|---|---|
| `mem_addr` | 24 | byte address |
| `mem_we` | 1 | write strobe (one cycle) |
| `mem_wdata` | 32 | word-aligned write data |
| `mem_wbe` | 4 | byte write enables, lane 3 = byte at the lowest address |
| `mem_rdata` | 32 | aligned word containing `mem_addr`, read combinationally |

Byte order follows the architecture: the byte at the lowest address of a word
occupies bits 31-24. Reads are combinational in M1; the write port takes one
cycle. Storage timing, interleaving, protection and channel contention are not
modelled.

Because the read port returns an aligned word, a word operand must be aligned.
`LOAD`/`STORE`/arithmetic RX instructions with an unaligned second operand would
silently read the aligned word: this is a documented M1 deviation (§5), not
architecture.

## 4. Implemented instruction set (23 operations)

| Opcode | Mnemonic | Format | Operation | CC |
|---|---|---|---|---|
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
| `92` | MVI | SI | move immediate byte | unchanged |
| `95` | CLI | SI | compare logical immediate byte | set |

Encodings are from the instruction tables on pp. 26-32 (fixed point), 53-56
(logical) and 73-74 (branching). Every other operation code is decoded as an
*unimplemented* instruction of the correct length.

## 5. Deviations from the architecture in M1

These are deliberate and must not be presented as architectural behaviour.
Each is a precondition for a later milestone.

1. **No interruptions.** Fixed-point overflow sets CC 3 and a sticky
   `ovf_pending` flag instead of causing a program interruption with code
   `0x0C` when PSW bit 36 is one (p. 17, Figure 16). Program-mask bits are
   otherwise unused.
2. **Illegal operation code stops the machine.** The manual defines a
   *privileged-operation* / *operation* program interruption (code `0x01`,
   p. 17). M1 instead records `pc_check_pending`, stops fetching and never
   retires the instruction. No new PSW is loaded.
3. **No specification exceptions.** Halfword/word alignment, invalid register
   fields and other specification checks are not implemented; operands must be
   naturally aligned.
4. **No protection or DAT.** Protection keys in the PSW are inert; storage has
   no protection bits; no storage protection or translation check exists.
5. **No wait or problem state.** The `W` and `P` PSW bits are stored but never
   affect execution; all instructions execute in supervisor state.
6. **No timing.** Instruction execution takes one fetch cycle per instruction
   byte plus fixed decode/execute/commit cycles. No storage access timing,
   overlap, instruction prefetch or model-specific microarchitecture is
   modelled, and none may be inferred.
7. **No `EXECUTE`, `SVC`, `LPSW`, `SSM`, shift, halfword, multiply/divide,
   decimal or floating-point operations.** They decode as illegal in M1.

## 6. Assumption ledger

`ASSUMPTION` entries are behaviours the primary source does not state
explicitly, or that this implementation fixes by choice. Each must be
re-validated against historical software before sign-off (see the program's
escaped-defect rules in `AGENTS.md`).

| ID | Assumption | Why it is an assumption | Validation |
|---|---|---|---|
| A-1 | Storage reads are combinational; a byte is available in the cycle the address is presented. | The manual specifies program-visible behaviour, not access timing. | Later storage/timing milestone; not observable by programs. |
| A-2 | The reset PSW is all zero except the instruction address parameter (`RESET_IA`). | No architectural reset PSW exists; `IPL` reads the IPL PSW from storage. | Replaced by IPL (issue #386) before any OS boot claim. |
| A-3 | An unimplemented operation code halts and raises a sticky flag instead of taking an interruption. | M1 has no interruption mechanism. | Must be replaced by a program interruption with code `0x01` before any diagnostic runs. |
| A-4 | `MVI`/`CLI` require only their single byte operand; no alignment check is applied. | The manual requires no alignment for byte operands, but the M1 storage port returns an aligned word. | Covered by byte-lane tests; re-check with an interrupting implementation. |
| A-5 | Overflow is recorded (`ovf_pending`) but the instruction still completes with CC 3. | The manual's interruption depends on PSW bit 36 and on the interruption mechanism M1 lacks. | Re-check against real overflow-handling software. |

## 7. Model option matrix

The family issue requires model-specific deviations to be preserved. Only the
following are recorded here, and each still needs its primary source (the
model's own Functional Characteristics manual) in issue
[#381](https://github.com/hevangel/ai_engineer/issues/381)/[#382](https://github.com/hevangel/ai_engineer/issues/382):

| Model | Deviation to preserve | Status |
|---|---|---|
| 20 | Reduced instruction set; eight 16-bit general registers instead of sixteen 32-bit | secondary source only (see README); not implemented |
| 22 | Model 30 processor with reduced maximum storage and slower channels | not sourced |
| 25 | Reduced-cost model; pprogram-interrupt and I/O differences | not sourced |
| 44 | Storage-to-storage instructions and five other complex instructions removed; additional scientific instructions | secondary source only; not implemented |
| 67 | Dynamic address translation and virtual memory | not implemented |
| 85, 91, 95, 195 | Cache, out-of-order execution and hardwired control variants | not implemented |

No model may be declared reconstructed from this shared engine alone: the M1
core is the common subset, and model issues own their deviations, options and
microarchitecture.

## 8. Related documents

- [sources.md](sources.md) — provenance, hashes, licensing, coverage gaps
- [../plans/implementation_plan.md](../plans/implementation_plan.md)
- [../plans/testplan.md](../plans/testplan.md)
- [../plans/formal_plan.md](../plans/formal_plan.md)
- [../report/2026-11-05-m1-core.md](../report/2026-11-05-m1-core.md)
