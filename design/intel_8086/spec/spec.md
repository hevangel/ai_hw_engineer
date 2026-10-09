# Intel 8086 specification — milestone 1

## Authority and scope

The architectural authority is Intel's [October 1979 8086 Family User's Manual](https://www.inf.pucrs.br/~calazans/undergrad/orgcomp_EC/mat_microproc/intel-8086_family_Users_Manual.pdf), chapter 2 (programming model, instruction descriptions, encoding tables and figure 2-63). This specification is written before RTL. It describes a functional, synthesizable CPU subset, not a pin-compatible replacement. Full instruction-set and native timing sign-off are later milestones.

## Architectural state

Eight 16-bit general registers use the instruction encoding order AX, CX, DX, BX, SP, BP, SI, DI. Byte registers AL/CL/DL/BL and AH/CH/DH/BH alias the low/high halves of the first four registers. Segment order is ES, CS, SS, DS. IP is 16 bits; physical addresses are `(segment << 4) + offset`, truncated to 20 bits. Instruction fetch increments IP with 16-bit wrap. Little-endian memory words transfer low byte first; the second byte wraps the offset at 16 bits within the same segment.

Reset is synchronous, active-low `rst_n`. CS becomes FFFFh, IP 0000h, ES/SS/DS zero, arithmetic/control flags clear (reserved readback bits normalized to F002h). The first fetch is physical FFFF0h. General registers reset to zero as a deterministic implementation choice; original silicon does not specify these values.

FLAGS implements CF[0], PF[2], AF[4], ZF[6], SF[7], TF[8], IF[9], DF[10], OF[11]. Reserved bits read as F002h. Undefined arithmetic flags are retained and excluded from independent comparisons using the upstream metadata masks. TF/IF can be stored but do not yet cause interrupts; enabling either is outside this milestone's executable scope.

## Supported encodings

| Encoding | Implemented behavior |
|---|---|
| 00–05, 08–0D, 10–15, 18–1D, 20–25, 28–2D, 30–35, 38–3D | ADD, OR, ADC, SBB, AND, SUB, XOR, CMP; all documented register/memory/accumulator forms |
| 06/07, 0E, 16/17, 1E/1F | PUSH/POP ES, PUSH CS, PUSH/POP SS, PUSH/POP DS |
| 26/2E/36/3E | Segment override prefixes; last override wins |
| 40–4F | INC/DEC word register, preserving CF |
| 50–5F | PUSH/POP word register; original 8086 PUSH SP stores decremented SP |
| 70–7F | All short conditional branches |
| 80/81/83 | Group 1 immediate arithmetic; 83 sign-extends imm8 |
| 84–8B | TEST, XCHG, MOV register/memory, byte/word |
| 8C/8E | MOV segment register; segment fields 0–3 only, MOV CS rejected |
| 8D | LEA, memory addressing forms only |
| 90–97 | NOP and XCHG AX, word register |
| 98/99, 9C–9F | CBW, CWD, PUSHF, POPF, SAHF, LAHF |
| A0–A3, A8/A9 | MOV accumulator/memory offset, TEST accumulator immediate |
| B0–BF | MOV immediate byte/word register |
| E9/EA/EB | Near relative word, far immediate and short relative JMP |
| F4/F5/F8/F9/FC/FD | HLT, CMC, CLC, STC, CLD, STD |

Other encodings, REP/LOCK prefixes, MOV CS and invalid operand forms assert sticky `fault_o` without retiring or executing a later instruction. Decoding can already have consumed instruction bytes; the reported IP is the decode position, not an architectural exception return address. Decimal adjust, strings, shifts, multiply/divide, calls/returns, I/O, interrupts, WAIT/ESC and undocumented aliases remain unimplemented. No 80186-or-later instructions are accepted.

ModR/M effective addresses implement BX+SI, BX+DI, BP+SI, BP+DI, SI, DI, BP and BX; mod=00/rm=110 is direct disp16. disp8 is sign-extended, disp16 added modulo 65536. BP-based operands default to SS, others to DS. Overrides select ES/CS/SS/DS. Stack accesses always use SS. LEA returns the effective offset without reading memory.

## Chip interface

| Port | Meaning |
|---|---|
| `clk`, `rst_n` | Clock and synchronous reset |
| `bus_req_o`, `bus_ready_i` | Transaction completes on their joint rising edge |
| `bus_addr_o[19:0]` | Aligned physical byte address; bit 0 is always zero |
| `bus_be_o[1:0]` | One active byte lane; 01 low, 10 high |
| `bus_write_o`, `bus_wdata_o[15:0]`, `bus_rdata_i[15:0]` | Memory transfer direction and lane-positioned data |
| `bus_fetch_o` | Transaction is an instruction byte fetch |
| `halted_o`, `fault_o` | Terminal HLT or unsupported-encoding stop; reset exits |
| `retire_o` | One-cycle pulse after a completed instruction (including HLT) |
| `regs_o[127:0]`, `segs_o[63:0]`, `ip_o[15:0]`, `flags_o[15:0]` | Architectural observation, lowest register index in least-significant bits |

Every word uses two byte transactions, including aligned words. Requests and their payload remain stable under arbitrary ready stalls. There are no combinational requests when reset is asserted. Internal decode cycles can be idle; there is no fixed instruction timing or frequency/area guarantee. Reset aborts an in-flight transaction and clears terminal states. No INTR/NMI/HOLD/TEST or maximum-mode arbitration is exposed until its semantics are implemented.

## Assumption ledger

These functional choices are explicitly outside original pin-level behavior. Corresponding RTL comments carry `ASSUMPTION:` identifiers.

| ID | Choice and evidence/validation |
|---|---|
| A1 | General registers reset to zero for deterministic tests; Intel specifies segment/IP/flags reset but no general-register reset value. Historical startup overwrites the registers it uses. |
| A2 | Unbuffered instruction fetch and serialized byte transactions replace native BIU timing/prefetch. Hardware vectors compare architectural effects, never queue/cycle counts. Self-modifying/prefetch-sensitive software is outside sign-off. |
| A3 | A word crossing offset FFFFh reads/writes its second byte at offset 0000h in the same segment. Pinned physical-chip fixture A1.json.gz:1633 explicitly requires this behavior (ES=04EEh, offsets FFFFh/0000h contain 74h/75h; AX becomes 7574h). Directed boundary tests also validate it. |
| A4 | Undefined logic AF is retained; compare only flags defined by Intel/upstream metadata. Software must not depend on undefined AF. |
| A5 | Unsupported encodings halt the implementation with `fault_o`. This diagnostic is not an original 8086 architectural exception. Historical startup must finish without it. |

No whole-CPU sign-off is claimed. Historical startup exercises a small documented software path, not the remaining instructions, interrupt behavior, CMOS/NMOS differences or prefetch behavior.
