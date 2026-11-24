# IBM System/360 — architecture specification (M8)

Status: **eighth functional increment**. This document fixes the architecture
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
- the rest of the fixed-point group — halfword `LH`/`STH`/`AH`/`SH`/`CH`/`MH`,
  `MR`/`M`, `DR`/`D`, and the shifts `SLA`/`SRA`/`SLDA`/`SRDA` — and `SVC` with
  the supervisor-call interruption (M3);
- the character and SS-format logical group — `MVC`, `MVN`, `MVZ`, `NC`, `OC`,
  `XC`, `CLC`, `TM`, `IC`, `STC` (M4);
- `TR`, `TRT` and `EXECUTE`, completing the translate and instruction-stream
  control group (M5);
- **addressing exceptions** (code 5) for operands outside installed storage and
  the **external (timer) interruption** with the old/new PSWs at `0x18`/`0x58`
  and code `0x0080` (M6);
- **instruction-fetch addressing exceptions** (code 5) and the **odd
  instruction-address specification exception** (code 6), completing the
  addressing checks (M7);
- **storage protection keys** and the **protection exception** (code 4): a
  4-bit key and fetch-protection bit per 2 KiB block, compared with PSW bits
  8-11 (M8);
- **program interruptions** with the causes operation (1), privileged
  operation (2), specification (6) and fixed-point overflow (8), the program
  old PSW at storage `0x28`, the program new PSW at `0x68`, and problem-state
  enforcement (M2);
- the wait state as a state in which no instruction is fetched, and which an
  external interruption can end (M2, M6).

Out of scope (each has its own issue or milestone): decimal and floating-point
operations; `ED`, `EDMK`, `PACK`, `UNPK`, `MVO`, `CVB`, `CVD` and the decimal
arithmetic group.
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
| `0A` | SVC | RR | no | supervisor-call interruption with the instruction's bits 8-15 placed in old-PSW bits 24-31 and bits 16-23 zeroed; old/new PSWs at `0x20`/`0x60` |

`LPSW` is the only instruction that can enter the problem or wait state
(p. 73). The new PSW is not checked for exceptions during the load; the checks
happen when the next instruction is executed (p. 73 and p. 71).

### 2.7 Fixed-point group completed in M3 (pp. 26-34)

| Operation | Operand | Result | CC | Exceptions |
|---|---|---|---|---|
| LH | halfword in storage, sign-extended | R1 | unchanged | specification (odd address) |
| STH | R1 low halfword | storage halfword | unchanged | specification (odd address) |
| AH / SH | halfword, sign-extended | R1 | add/subtract rules | specification, overflow |
| CH | halfword, sign-extended | — | compare rules | specification |
| MH | halfword × R1 | low 32 bits of the product | unchanged | specification |
| MR / M | R1 pair (multiplicand in the odd register) × multiplier | 64-bit product replaces the pair | unchanged | specification (odd R1) |
| DR / D | R1 pair as a 64-bit dividend ÷ 32-bit divisor | **remainder in R1 (even), quotient in R1+1 (odd)** | unchanged | specification (odd R1), divide (code 9) |
| SLA / SLDA | shift count from the low six bits of the second-operand address | R1 (or the pair); sign bit fixed | 0/1/2, 3 on overflow | specification (SLDA odd R1), overflow |
| SRA / SRDA | same | R1 (or the pair) with sign fill | 0/1/2 | specification (SRDA odd R1) |

Notes that the implementation depends on:

- the second-operand address of a shift is **not** used to address storage and
  is not checked for addressing exceptions (p. 34);
- a halfword operand must lie on a 16-bit boundary and a 64-bit pair register
  must be even, otherwise the instruction is suppressed with code 6 (p. 34);
- `MR`/`M` cannot overflow, and `MH` gives no overflow indication (p. 32);
- a divide whose quotient does not fit 32 bits, including division by zero, is
  suppressed and leaves the dividend registers unchanged (pp. 31, 34);
- `SLDA`/`SLA` overflow when a bit unlike the sign leaves the integer field;
  the result is stored with the sign unchanged and CC is set to 3 (pp. 33-34).

### 2.8 Character and SS-format logical group (M4, pp. 53-57)

| Operation | Fields | Behaviour | CC |
|---|---|---|---|
| MVC | `L,B1,D1,B2,D2` | copy `L+1` bytes from operand 2 to operand 1, left to right, overlapping fields allowed | unchanged |
| MVN | same | low four bits of each source byte into the low four bits of the destination byte | unchanged |
| MVZ | same | high four bits of each source byte into the high four bits of the destination byte | unchanged |
| NC / OC / XC | same | AND / OR / exclusive OR of corresponding bytes into the first operand | unchanged |
| CLC | same | binary comparison, left to right, stops at the first inequality | 0 equal, 1 first low, 2 first high |
| TM | `I2,B1,D1` | tests the storage byte against the mask `I2` | 0 selected bits all zero or mask zero, 3 all selected bits one, 1 mixed |
| IC | `R1,X2,B2,D2` | byte into bits 24-31 of `R1`, other bits unchanged | unchanged |
| STC | same | bits 24-31 of `R1` into storage | unchanged |
| TR | `L,B1,D1,B2,D2` | each byte of operand 1 indexes the 256-byte table at the operand-2 address and is replaced by the function byte | unchanged |
| TRT | same | as `TR` but the field is not stored: a nonzero function byte stops the scan, puts the argument address in **general register 1** and the function byte in the low byte of **general register 2** | 0 all zero, 1 nonzero before the end, 2 nonzero on the last byte |
| EX | `R1,X2,B2,D2` | the instruction at the operand address is executed with bits 24-31 of **the register named by R1** ORed into its bits 8-15 (R1 = 0 means no modification); the PSW address advances by EXECUTE's own length and the stored ILC is 2; a successful branch of the subject still takes effect | set by the subject |

The length field is `L+1` bytes (1 to 256). The core executes one byte per three
cycles (read operand 1, read operand 2, merge and store), so a 256-byte `MVC`
takes about 770 cycles; this is a functional, not a timing, model.

`TRT` has no register fields in the SS format; the manual names "general
register 1" and "general register 2" literally, so the core uses GR1 and GR2
(assumption A-7). `DR`/`D` follow p. 31: "a 32-bit signed remainder and a
32-bit signed quotient replace the dividend in the even-numbered and
odd-numbered registers, respectively". `EX` follows p. 67: bits 8-15 of the
subject are OR'ed with bits 24-31 of the R1 register, and register 0 means no
modification. `EXECUTE` of `EXECUTE` raises the execute exception (code 3),
an odd subject address raises code 6, and an exception inside the subject
instruction stores an old PSW carrying EXECUTE's own address-plus-four and ILC 2
(p. 67).

### 2.9 Program interruptions (pp. 15-16, 71-72)

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

### 2.10 Addressing exceptions and external interruptions (M6)

| Item | Behaviour | Source |
|---|---|---|
| Installed storage | parameter `MEM_SIZE_BYTES`, default 64 KiB | p. 34 |
| Addressing exception | operand, field, `TR` table or instruction reference at or beyond installed storage raises code 5; for an operand the instruction is suppressed and the old PSW carries the updated address, for an unfetchable instruction the address and ILC 0 are stored | pp. 34, 72 |
| Odd instruction address | a PSW whose instruction address is odd raises code 6 before any fetch | p. 72 |
| External interruption | a latched timer request is taken between instructions when system-mask bit 7 is set; old/new PSWs at `0x18`/`0x58`; code `0x0080` (timer, bit 24) | pp. 16-17, Figure 17 |
| Wait state | ended by an external interruption | p. 17 |

Deviation A-8: an SS instruction whose *field* leaves installed storage is
suppressed before its first byte, whereas the manual lets such an operation be
terminated part way with unpredictable results (p. 34). Suppressing is the
stronger, deterministic choice, and is recorded rather than presented as
architecture.

Not implemented: `SET STORAGE KEY`/`INSERT STORAGE KEY`, I/O and machine-check
interruptions, instruction-fetch protection, and the remaining specification
checks (unaligned word operands, invalid register fields).

### 2.11 Storage protection (M8, pp. 68-70)

| Item | Value |
|---|---|
| Block size | 2 KiB (`key_index = address[16:11]`) |
| Block key | 4 bits, plus one fetch-protection bit |
| PSW key | bits 8-11 (`psw[55:52]`) |
| Reference permitted | block key = 0, or block key = PSW key |
| Fetch permitted | a permitted reference, or fetch-protection bit = 0 |
| Violation | program check **code 4**; a store is suppressed, a protected fetch is suppressed rather than terminated (deviation A-10) |

The key array resets to zero in hardware terms — every block unprotected — so
behaviour is unchanged until keys are loaded. `SET STORAGE KEY` and `INSERT
STORAGE KEY` are not implemented, so a **key load port** (`key_we`, `key_block`,
`key_data`, `key_fetch_protect`) is provided as a test aid; it is documented as
such rather than presented as an instruction.

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

## 4. Implemented instruction set (54 operations)

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
| `0A` | SVC | RR | supervisor call | unchanged |
| `42` | STC | RX | store character | unchanged |
| `44` | EX | RX | execute | subject |
| `43` | IC | RX | insert character | unchanged |
| `91` | TM | SI | test under mask | set |
| `D1` | MVN | SS | move numerics | unchanged |
| `D2` | MVC | SS | move characters | unchanged |
| `D3` | MVZ | SS | move zones | unchanged |
| `D4` | NC | SS | AND characters | unchanged |
| `D5` | CLC | SS | compare logical characters | set |
| `D6` | OC | SS | OR characters | unchanged |
| `D7` | XC | SS | exclusive OR characters | unchanged |
| `DC` | TR | SS | translate | unchanged |
| `DD` | TRT | SS | translate and test | set |
| `1C` | MR | RR | multiply | unchanged |
| `1D` | DR | RR | divide | unchanged |
| `40` | STH | RX | store halfword | unchanged |
| `48` | LH | RX | load halfword | unchanged |
| `49` | CH | RX | compare halfword | set |
| `4A` | AH | RX | add halfword | set |
| `4B` | SH | RX | subtract halfword | set |
| `4C` | MH | RX | multiply halfword | unchanged |
| `5C` | M | RX | multiply | unchanged |
| `5D` | D | RX | divide | unchanged |
| `8A` | SRA | RS | shift right single | set |
| `8B` | SLA | RS | shift left single | set |
| `8E` | SRDA | RS | shift right double | set |
| `8F` | SLDA | RS | shift left double | set |
| `92` | MVI | SI | move immediate byte | unchanged |
| `95` | CLI | SI | compare logical immediate byte | set |

Encodings are from the instruction tables on pp. 26-32 (fixed point), 53-56
(logical), 72-74 (status switching) and 73-74 (branching). Every other
operation code is decoded as an *unimplemented* instruction of the correct
length and raises interruption code 1.

## 5. Deviations from the architecture

These are deliberate and must not be presented as architectural behaviour.

1. **Assigned but unimplemented instructions raise code 1.** A real S/360
   executes `ED`/`EDMK`, `PACK`/`UNPK`/`MVO`, `CVB`/`CVD`, and decimal and
   floating-point operations; this core decodes them as an operation
   exception. This is an implementation gap, not
   architecture, and is the reason no compatibility claim may be made until
   the remaining instruction groups and the external oracle exist.
2. **Only program interruptions exist.** Supervisor call, external, I/O and
   machine-check interruptions are not implemented; their codes (3, 4, 5, 7
   and the other classes) are never generated. Storage protection and
   addressing exceptions are therefore also absent, since no storage limit or
   key is modelled.
3. **Specification exceptions are partial.** Checked: the `LPSW` doubleword
   alignment rule, an odd halfword operand address for `LH`/`STH`/`AH`/`SH`/
   `CH`/`MH`, and an odd `R1` for the 64-bit pair operations
   `MR`/`DR`/`SLDA`/`SRDA`. Not checked: odd instruction addresses, unaligned
   word operands, and invalid register fields outside those cases.
4. **No protection or DAT.** The protection key field is stored and inert.
5. **Wait state cannot be left.** With no I/O or external interruption, no new
   PSW can arrive, so `LPSW` with bit 14 set stops the machine permanently.
   This matches the architectural definition (p. 17) for a machine with no
   such interruption sources, but it is a limitation of this core.
6. **No timing.** Instruction execution takes one fetch cycle per instruction
   byte plus fixed decode/execute/commit cycles, and five cycles per
   interruption. No storage access timing, overlap, prefetch or model-specific
   microarchitecture is modelled.
7. **No `ED`/`EDMK`, decimal conversions, decimal arithmetic or floating
   point.** They raise code 1 as described above. The fixed-point group, the
   SS moves/compares/logical group, the translate group and `EXECUTE` are
   complete.
8. **Divide and supervisor-call old-PSW addresses.** For the divide exception
   and for `SVC` the core stores the *updated* instruction address and the ILC
   of the instruction, matching the suppressed-check rule of p. 72. The manual
   states the update rule explicitly only for the suppressed operation,
   protection, addressing and specification cases; this choice is recorded as
   assumption A-6.

## 6. Assumption ledger

| ID | Assumption | Why it is an assumption | Validation |
|---|---|---|---|
| A-1 | Storage reads are combinational; a byte is available in the cycle the address is presented. | The manual specifies program-visible behaviour, not access timing. | Later storage/timing milestone; not observable by programs. |
| A-2 | The reset PSW is all zero except the instruction address parameter (`RESET_IA`). | No architectural reset PSW exists; `IPL` reads the IPL PSW from storage. | Replaced by IPL (issue #386) before any OS boot claim. |
| A-3 | An implemented-length but unassigned/unimplemented operation raises code 1 with the instruction address advanced by the ILC. | The manual defines code 1 for *unassigned* opcodes (p. 16); it does not define how a partially implemented machine should report a missing instruction. | Must disappear as the instruction set is completed; tracked by #384. |
| A-4 | Byte operands are read from the aligned word and word operands must be aligned. | The storage port returns an aligned word. | Re-check when specification exceptions are complete. |
| A-5 | The interruption sequence is treated as atomic (no priority nesting). | The manual describes priority ordering between classes (p. 16); with only program interruptions there is no competing request. | Re-check when I/O and external interruptions exist. |
| A-10 | A fetch violation is suppressed (no register or storage change) instead of terminating the instruction. | The manual terminates a fetch-protected operation and calls the results unpredictable (pp. 34, 69); suppression is deterministic. | Revisit when partial-completion cases can be compared against the oracle. |
| A-9 | An unfetchable instruction (address outside storage, or an odd address) stores ILC 0 in the old PSW. | The manual updates the stored address by the ILC (p. 72) but no instruction length exists when nothing could be fetched. | Validate against the oracle's interrupt-entry mode when it exists. |
| A-8 | An SS operation whose field leaves installed storage is suppressed before its first byte. | The manual terminates such an operation part way, leaving results unpredictable (p. 34); a deterministic suppression is easier to verify. | Revisit when the oracle can compare partial-store cases. |
| A-7 | `TRT` writes general registers 1 and 2 (it has no register fields), and `EXECUTE` stores ILC 2 with the address advanced by four — including when the subject instruction raises an exception. | The manual names "general register 1/2" and states the EXECUTE address rule (p. 67), but OCR damage to the TRT format figure leaves the register encoding to be confirmed. | Validate against the independent oracle (#383). |
| A-6 | Divide-exception and supervisor-call interruptions store an old PSW whose instruction address is advanced by the instruction length. | The manual states that rule for suppressed program checks (p. 72) and says division is suppressed (p. 34), but does not spell out the address for these two classes. | Re-check against an independent emulator (#383) and IBM diagnostics (#441). |

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
- [../report/2026-11-17-m3-fixedpoint.md](../report/2026-11-17-m3-fixedpoint.md)
- [../report/2026-11-18-m4-character-ss.md](../report/2026-11-18-m4-character-ss.md)
- [../report/2026-11-20-m5-translate-execute.md](../report/2026-11-20-m5-translate-execute.md)
- [../report/2026-11-23-m6-addressing-external.md](../report/2026-11-23-m6-addressing-external.md)
- [../report/2026-11-24-m7-fetch-checks.md](../report/2026-11-24-m7-fetch-checks.md)
- [../report/2026-11-25-m8-protection-keys.md](../report/2026-11-25-m8-protection-keys.md)
