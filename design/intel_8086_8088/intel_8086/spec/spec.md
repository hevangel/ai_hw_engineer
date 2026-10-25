# Intel 8086 specification

## Scope and authority

This chip implements the documented original Intel 8086 architecture and a native digital minimum/maximum-mode interface. Technical authority is Intel's [8086 Family User's Manual, October 1979](https://www.inf.pucrs.br/~calazans/undergrad/orgcomp_EC/mat_microproc/intel-8086_family_Users_Manual.pdf), chapters 2 and 4, and the [Intel 8086 datasheet](https://www.inf.pucrs.br/calazans/undergrad/orgcomp_EC/mat_microproc/intel-8086_datasheet.pdf), especially the pin descriptions, arbitration rules and bus timing diagrams. The initial specification and implementation plan preceded RTL; this specification supersedes the first milestone's subset contract.

The native top is `intel_8086_chip`; `intel_8086` remains its execution unit and an architectural transaction interface. Bidirectional pins have separate input, output and output-enable ports. RTL models complete clock phases, not analog voltages, transistor delays or sub-clock setup/hold timing. EU scheduling, instruction cycle counts, prefetch overlap and arbitration latency need not match every original-silicon clock. The supported bus phase, lane, wait, ownership and architectural contracts below must hold. This is a chip design and verification environment, without a board, operating system or front panel product.

## Architectural state and addresses

Eight 16-bit general registers use encoding order AX, CX, DX, BX, SP, BP, SI, DI. AL/CL/DL/BL and AH/CH/DH/BH alias halves of the first four. Segment order is ES, CS, SS, DS. IP wraps at 16 bits. Physical addresses are `(segment << 4) + offset`, truncated to 20 bits. A word crossing offset FFFFh transfers its high byte at offset 0000h in the same segment, including stack, string and far-pointer operations. Memory and I/O are little endian; port offsets wrap at 16 bits.

FLAGS implements CF[0], PF[2], AF[4], ZF[6], SF[7], TF[8], IF[9], DF[10], OF[11]. Reserved readback bits normalize to F002h. Defined flags follow Intel's instruction descriptions. Undefined flags have no architectural guarantee; comparisons use the external oracle's masks, including the undefined flag bytes pushed by divide errors.

EU reset is synchronous active-low `rst_n`; native reset is synchronous active-high `reset_i`. Reset sets CS=FFFFh, IP=0000h, ES/SS/DS=0, FLAGS=F002h and clears pending control state and the queue. General registers become zero as a deterministic implementation choice. The first fetch after reset is FFFF0h. Reset aborts in-flight transactions. Native inputs must satisfy their clocked interface requirements; `min_mode_i` is a constant mode strap. The physical datasheet's reset width and electrical requirements remain the integrator's responsibility.

## Complete documented instruction families

| Encoding | Behavior |
|---|---|
| 00–05, 08–0D, 10–15, 18–1D, 20–25, 28–2D, 30–35, 38–3D | ADD, OR, ADC, SBB, AND, SUB, XOR, CMP in every documented form |
| 06/07, 0E, 16/17, 1E/1F | PUSH/POP segment registers, including PUSH CS |
| 26/2E/36/3E | Segment overrides; last override wins |
| 27/2F/37/3F | DAA, DAS, AAA, AAS |
| 40–4F, 50–5F | INC/DEC and PUSH/POP word registers; original PUSH SP stores decremented SP |
| 70–7F, 80/81/83 | All conditional branches and immediate arithmetic groups |
| 84–8B, 8C/8E, 8D, 8F /0 | TEST/XCHG/MOV, segment MOV, LEA, POP r/m16 |
| 90–99, 9A, 9B, 9C–9F | NOP/XCHG AX, CBW/CWD, far CALL, WAIT, PUSHF/POPF/SAHF/LAHF |
| A0–AF | Accumulator memory transfers, MOVS/CMPS/STOS/LODS/SCAS, immediate TEST |
| B0–BF, C4/C5, C6/C7 /0 | Immediate MOV, LES/LDS, immediate r/m MOV |
| C2/C3/CA/CB, CC/CD/CE/CF | Near/far RET with optional adjustment; INT3/INT/INTO/IRET |
| D0–D3, D4/D5, D7, D8–DF | Shifts/rotates, AAM/AAD, XLAT and ESC |
| E0–E3, E4–E7/EC–EF, E8–EB | LOOP family/JCXZ, byte/word IN/OUT, near CALL and near/far/short JMP |
| F0, F2/F3, F4/F5, F8–FD | LOCK, REP/REPE/REPNE, HLT/CMC, CLC/STC/CLI/STI/CLD/STD |
| F6/F7, FE/FF | TEST/NOT/NEG/MUL/IMUL/DIV/IDIV, INC/DEC, indirect near/far CALL/JMP, PUSH |

All documented ModR/M addressing forms, signed disp8, disp16, byte aliases and segment defaults are implemented. BP-based addressing defaults to SS; other data addressing defaults to DS. Stack references use SS and string destinations use ES. LEA does not read memory. Far pointers read two segmented words, with offset wrapping.

CL shifts use all eight count bits, without a later-CPU count mask. Count zero preserves flags and operand. Original IDIV quotient range is -127..127 or -32767..32767; divide errors save the next IP, not a later-CPU fault restart IP. AAM/AAD accept a nonstandard immediate base, with zero-base AAM generating type 0. ESC emits its opcode/effective-address event and performs the original dummy memory read for memory operands; 8087 arithmetic belongs to the external coprocessor.

The 80h alias 82h is accepted and exercised by original DEBUG.COM. TEST group /1 and shift group /6 are accepted implementation extensions. REP-prefixed IDIV quotient negation is independently covered by physical vectors. These do not extend the documented contract to all undefined encodings. Undocumented POP CS, MOV CS, other undefined opcodes and invalid documented operand forms are outside the contract; rejected forms enter sticky `fault_o`. This signal is a diagnostic, not an original 8086 invalid-opcode exception. See the complete [encoding ledger](../report/encoding_coverage.md), including upstream classification disagreements.

## Interrupts and asynchronous control

Internal INT/INTO/divide events complete before external interrupt selection. At an instruction boundary, NMI has priority over enabled INTR, which has priority over a pending single-step trap. NMI is edge-latched, including during stalls and bus ownership loss, and may nest before IRET. INTR is level-sensitive and requires IF. Two locked INTA cycles fetch the vector from the second cycle; CODE prefetch is suspended across acknowledge and interrupt entry.

Interrupt entry reads the vector before pushing FLAGS, CS and return IP, matching the [original interrupt microcode](https://www.righto.com/2023/02/8086-interrupt.html). This ordering is observable if the stack aliases the vector table. IF/TF clear on entry. IRET restores IP, CS and FLAGS. TF is sampled at instruction start; POPF/IRET that set TF begin single stepping with the following instruction. A higher-priority interrupt can be followed by the pending trap at handler entry.

STI and IRET defer enabled INTR until after the following instruction. MOV/POP of the documented segment registers inhibit interrupts/traps through the following instruction, following Intel 1979 section 2.6. REP checks interrupt boundaries after each completed element, retaining partial SI/DI/CX state. Original RPTI backs IP up by two, losing earlier prefixes in a multi-prefix instruction; see the [die-derived string microcode](https://www.righto.com/2023/04/8086-microcode-string-operations.html). WAIT polls active-low TEST and can be interrupted with its own opcode as the return address. HLT retires and waits for NMI, enabled INTR or a pending trap.

LOCK inhibits ownership changes until the instruction completes; the native LOCK output follows decode/completion one clock later. Memory XCHG does not assert implicit LOCK on this original CPU: Intel's 1979 section 2.5 requires the prefix. An unlocked odd-address word also inhibits ownership changes between its two byte transfers, without asserting LOCK.

## EU transaction interface

| Port | Meaning |
|---|---|
| `bus_req_o`, `bus_ready_i` | Transfer completes on their joint rising edge |
| `bus_addr_o[19:0]`, `bus_be_o[1:0]` | Aligned physical address; lanes 01 low, 10 high, 11 whole aligned word |
| `bus_write_o`, `bus_wdata_o`, `bus_rdata_i` | Direction and lane-positioned 16-bit data |
| `bus_fetch_o`, `bus_first_o` | Instruction byte fetch and first-byte/prefix classification |
| `bus_io_o`, `bus_intack_o`, `bus_segment_o` | I/O/interrupt-acknowledge space and segment status |
| `intr_i`, `nmi_i`, `hold_i`, `test_n_i` | Interrupt, ownership and WAIT controls |
| `lock_o`, `hlda_o`, `redirect_o` | Lock, functional ownership acknowledgement and queue flush event |
| `prefetch_suspend_o`, `arbitration_inhibit_o` | Interrupt-entry prefetch suspension and atomic odd-word ownership guard |
| `esc_valid_o`, `esc_opcode_o`, `esc_address_o` | ESC observation for verification/integration |
| `retire_o`, `halted_o`, `fault_o` | Completed instruction pulse, HLT state and diagnostic stop |
| `regs_o`, `segs_o`, `ip_o`, `flags_o` | Architectural observation; lowest register index in least-significant bits |

Requests remain stable under arbitrary ready stalls. Aligned words use one transaction; odd words use two lane transfers. The functional core freezes while HLDA is asserted. The native top instead applies ownership at the BIU, allowing the EU to consume queued instructions while the bus is granted.

## Native BIU and pins

The six-byte queue fills with aligned words when two slots are free; an odd starting IP first fetches one byte. Taken transfers flush the queue and permanently discard an in-flight prefetch response from the abandoned stream, including repeated redirects before that response completes. Ordinary writes do not invalidate queued instructions. QS reports first byte, subsequent byte or flush during the following clock.

Bus phases are IDLE, T1, T2, T3, optional Tw, T4. T1 supplies the multiplexed address and BHE; T2 changes AD direction; READY sampled at T2 determines wait insertion and READY in Tw permits completion. Read data is captured at completion. Write data and data enable are held through T4. Maximum-mode status remains active across an extended wait until completion. S3/S4 encode the segment, S5 follows IF and S6 is zero. S7 has no defined functional meaning and is driven high.

Minimum mode produces ALE, M/IO, DT/R, DEN, RD, WR, INTA and HOLD/HLDA. Maximum mode produces S2:S0, QS, LOCK and bidirectional RQ/GT0/1. AD floats throughout INTA; BHE is low during the first INTA T1. Maximum-mode command strobes belong to an external 8288, while the chip exposes status and RD. Explicit output-enable ports represent floating AD, upper address/status, BHE and control pins during ownership loss.

Requests sampled by T2 may receive ownership at T4; later requests are handled at a subsequent idle boundary. RQ/GT0 wins simultaneous requests; a pending RQ/GT1 survives the first grant and release. Grant/release pulses occupy one clock. Two clocks separate release recognition from bus redriving. Ownership requests outrank pending INTR, cannot split INTA, locked instructions or odd words, and are honored before the reset-vector fetch when asserted at reset release. Native tests cover these rules independently of instruction vectors.

## Assumption ledger

| ID | Choice, source and validation |
|---|---|
| A1 | GPR reset values are unspecified by Intel; deterministic zero values are an implementation choice. Historical software initializes the registers it needs. |
| A2 | EU scheduling and overlap differ from silicon. Architectural vectors run through EU and both native modes; bus protocol has separate directed tests. No original instruction-cycle-count or electrical timing claim is made. |
| A3 | Segment-offset word wrap is required by physical fixture A1:1633 and Intel's [80386 compatibility notes, item 7](https://www.scs.stanford.edu/05au-cs240c/lab/i386/s14_07.htm). UVM/native tests validate wrap directly. |
| A4 | Undefined flags have no promised value; external metadata masks them. Division-error stack masks apply only to the two FLAGS bytes, never the return address or other writes. |
| A5 | `fault_o` is a diagnostic outside the native architecture; undefined/invalid encodings have no general behavioral promise. Historical software must complete without this signal. |
| A6 | Invalid-BCD DAA/DAS inputs follow physical P80C86 vectors: incoming AF changes the high-adjust threshold to 9Fh. Intel only documents valid packed-BCD use; original NMOS identity for invalid inputs is not asserted. All available DAA/DAS vectors pass. |

Sign-off evidence and practical limits are recorded in the [final report](../report/final_report.md). Passing finite tests and safety properties is not an exhaustive proof of every CPU state or electrical implementation.
## Coprocessor observation outputs

`esc_modrm_o` exports the captured ModR/M byte; `esc_instruction_o` exports
the physical CS:instruction-start address. `waiting_o` identifies WAITING.
The XT uses these alongside the existing ESC operand/opcode and TEST input
to connect the architectural 8087 interface. Native wrappers leave these
observation outputs unused.
