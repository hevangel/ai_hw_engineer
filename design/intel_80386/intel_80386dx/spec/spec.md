# Specification: Intel 80386 execution core (386DX member, shared with 386SX)

## 1. Overview

`intel_80386_core` implements the original Intel 80386 instruction set architecture. The 386DX and 386SX share this core; each chip adds its own native bus unit (32-bit and 16-bit external data bus respectively). The reference is the Intel *80386 Programmer's Reference Manual*, order 230985, cited as "PRM".

This revision implements **milestone M1: real-address mode**, as follows.

- **Instruction set.** The complete real-mode general instruction set: every one-byte and 0F-prefixed opcode that the 386 defines in real mode, with 16- and 32-bit operand and address sizes (66h/67h prefixes), segment overrides, LOCK and REP/REPE/REPNE.
- **Addressing.** 16- and 32-bit ModR/M forms, including SIB.
- **Segments.** Real-mode limit checks against the cached segment limit, producing #GP(0), or #SS(0) for the stack.
- **Faults and traps.** Precise faults and traps: #DE, #DB (INT1/ICEBP), INT3, INTO, BOUND (#BR), #UD, #NM, #SS and #GP.
- **Interrupt delivery.** Real-mode delivery through the interrupt vector table at IDTR.base.
- **System instructions.** The system instructions usable in real mode: LGDT/LIDT/SGDT/SIDT, SMSW/LMSW, CLTS, and MOV to and from CR0/CR2/CR3/DR6/DR7.

The following are **not** implemented in M1 and are planned (see `plans/implementation_plan.md`):

- protected mode (descriptors, privilege, gates, task switching)
- paging
- virtual-8086 mode
- debug-register breakpoints and the single-step trap
- hardware interrupts (INTR/NMI)
- LOADALL
- coprocessor protocol
- the native DX bus unit and the SX bus unit

## 2. Interfaces

### 2.1 Port list

| Port | Dir | Width | Description |
| --- | --- | --- | --- |
| `clk` | in | 1 | Core clock |
| `rst_n` | in | 1 | Active-low synchronous reset |
| `req_o` | out | 1 | Transaction request (held until `ack_i`) |
| `we_o` | out | 1 | Write |
| `io_o` | out | 1 | I/O space (port in `addr_o[15:0]`) |
| `fetch_o` | out | 1 | Code fetch |
| `addr_o` | out | 32 | Byte address (linear = physical in M1) |
| `size_o` | out | 3 | 1, 2 or 4 bytes; any alignment |
| `wdata_o` | out | 32 | Write data, byte 0 in bits 7:0 |
| `ack_i` | in | 1 | Completes the request at the rising edge |
| `rdata_i` | in | 32 | Read data for the request |
| `load_i`, `load_idx_i`, `load_data_i` | in | 1/5/32 | State load port used by the test harness, one register per cycle. Index order: CR0 CR3 EAX EBX ECX EDX ESI EDI EBP ESP CS DS ES FS GS SS EIP EFLAGS DR6 DR7. A segment load sets selector and base (selector×16) and keeps the limit. |
| `state_o` | out | 640 | The same 20 registers, 32 bits each |
| `retire_o` | out | 1 | Pulses when an instruction (or an interrupt delivery) completes |
| `halted_o` | out | 1 | HLT executed |
| `shutdown_o` | out | 1 | Fault during interrupt delivery (M1 models double/triple fault as shutdown) |

### 2.2 Transaction protocol

Each request transfers 1, 2 or 4 bytes at any byte address. The core keeps `req_o` and the request fields stable until a rising edge with `ack_i` high. The DX and SX bus units will split misaligned and wide requests into native bus cycles. Read data for I/O requests is supplied the same way.

## 3. Functional description

### 3.1 Structure

- **Fetch.** Instruction bytes are fetched one per transaction from CS:EIP into a 16-byte window until the decoder's length is satisfied. A byte beyond the CS limit is not fetched. It is marked invalid, and #GP(0) is raised only if the instruction actually uses it.
- **Decode.** `intel_80386_decode` is combinational. It parses prefixes, the opcode, ModR/M, SIB, displacement and immediates (PRM 17.2). The core evaluates the effective address with the register values at the start of the instruction.
- **Execute.** A micro-sequenced state machine with a generic transaction step. Register state is committed after the last access that can fault, except where measured 386 behaviour commits earlier (POPA; see 3.3).
- **Divide.** `intel_80386_divider` is an iterative 64/32 restoring divider (64 cycles). The core applies the size-specific overflow rules.
- **Interrupt delivery.** Real mode: read the IVT entry at IDTR.base + 4×vector, then push FLAGS, CS and IP, clear IF and TF, and load CS:IP.

### 3.2 Real-mode segment model

A segment register load in real mode changes only the selector and the base (selector×16). The cached limit and attributes are kept (PRM chapter 14), so limits loaded by the harness or by a future LOADALL persist. Data accesses check `offset + size − 1 ≤ limit` without wrap-around. A word at offset FFFFh in a 64K segment therefore faults.

### 3.3 Behaviour measured on the reference captures

These behaviours are not stated, or are stated as undefined, in the PRM. Each was measured on the pinned 386EX captures and is implemented as measured.

| Behaviour | Evidence |
| --- | --- |
| A SIB byte with index 100b (none) and a nonzero scale scales the **base** register | 67-prefixed files, e.g. 6700 #20 (`67 00 9C E0 …`): the captured address equals DS.base + EAX×8 − 183Bh; also the upstream README |
| SHLD/SHRD r/m16 with count > 16: the source refills itself; result = top/bottom 16 bits of dest:src:src (SHLD) or src:src:dest (SHRD) | 0FA4/0FA5/0FAC/0FAD: about 1,000 records per file |
| Shift/rotate OF whenever the masked count ≠ 0: MSB(res)⊕CF for ROL/RCL/SHL/SAL; MSB(res)⊕MSB−1(res) for ROR/RCR/SHR/SAR. This includes RCL/RCR whose effective count (mod 9 or 17) is 0 | D2.x and D3.x register forms: every record |
| Byte SHL/SHR by 16 or 24 sets CF as a shift by 8 would (other counts > 8 give CF = 0) | D2.4, D2.5 |
| POPA writes each register as it is popped. A stack fault part-way leaves the earlier registers loaded, and ESP unchanged | 61 #681 |
| POPAD on a 16-bit stack loads ESP[31:16] from the skipped ESP slot | 66 61 (2,207 of 2,500 records fail otherwise) |
| PUSHA/PUSHAD write the frame from its lowest address upwards (DI first) | 66 60 #302, #704 (faulting frames) |
| PUSHFD pushes EFLAGS with VM, RF and bits 15, 18–31 clear | 66 9C |
| A 32-bit POP Sreg reads only the selector word (and checks only its 2-byte limit) but releases 4 bytes | 66 07/17/1F, 66 0F A1/A9 at SP = FFFEh |
| The interrupt vector is read **before** the frame is pushed | 62 #1752, F6.6 #1403, F7.6 #701 (frame overlapping the IVT entry) |
| DAS: CF from the low-nibble step is kept when the high adjust is not taken | 2F |
| An invalid LOCK prefix raises #UD in preference to the 15-byte length #GP | 16- and 17-byte LOCK forms in 67 66 69, 67 66 81.7, 67 66 C7 |
| LOCK is valid with opcode 82h (alias of 80h) | 82.x |
| MOV r32, Sreg zero-extends the selector | 66 8C register forms (253 records) |

### 3.4 Assumption ledger

These are behaviours that the PRM does not state and that the captures do not settle. Each has an `ASSUMPTION:` tag in the RTL.

| Id | Assumption | Validation status |
| --- | --- | --- |
| A1 | Instruction bytes are fetched one per transaction; the prefetch queue and its bus order are not modelled | Not observable in the register/memory replay; to be specified by the bus units |
| A2 | Clock counts differ from the original microcode | Out of the M1 contract |
| A3 | Logical operations clear AF | Captures mask AF for these opcodes (f_umask); not validated |
| A4 | A 32-bit PUSH Sreg writes the zero-extended selector as a dword | Captures cannot distinguish a write from no write of the upper word |
| A6 | Reset state: CS=F000h, base FFFF0000h, EIP=FFF0h, EFLAGS=2, CR0 = 0, DX=0303h | Not validated (captures start from a loaded state); check against the datasheet reset table and a reset trace in M2 |
| A7 | MOV r32, Sreg zero-extends | Validated by 253 capture records (3.3) |
| A8 | ESC (D8–DF) with EM = TS = 0 and no coprocessor completes as a no-op | No captures for D8–DF; must be checked against a physical no-387 trace |
| A9 | 16-bit SGDT/SIDT store the high base byte as zero | No captures for 0F01; unvalidated |
| A10 | LOCK with a register destination raises #UD | Captures only prefix LOCK to memory forms; unvalidated |

### 3.5 Capture-fixture properties

These belong to the test fixture, not to the core.

- I/O reads return FFh, except ports 22h/23h, which read 7Fh/42h. Those ports are the 386EX's internal remap register.
- HLT is injected at the first code fetch after the instruction under test, as the capture board does.

## 4. Error handling

Faults restore EIP to the first prefix byte of the faulting instruction and deliver the vector in real mode. A fault during delivery enters shutdown (`shutdown_o`). The double-fault vector is a protected-mode milestone.

## 5. Timing

Functional only: no clock-for-clock equivalence and no electrical timing.
