# Intel 8080 functional specification

Primary sources are Intel's [September 1975 Microcomputer Systems User's
Manual](https://bitsavers.trailing-edge.com/components/intel/MCS80/98-153B_Intel_8080_Microcomputer_Systems_Users_Manual_197509.pdf),
chapters 2 and 4, and the [8080/8085 Assembly Language Programming
Manual](https://deramp.com/downloads/intel/8080-8085%20Programmers%20Manual.pdf),
especially the auxiliary-carry discussion on printed page 1-12. The later
manual resolves the early manual's misleading ANI auxiliary-carry description.
This design targets Intel 8080 instruction semantics, not AMD Am9080 or Intel
8085 flag behavior.

## Architecture and instruction scope

Seven 8-bit registers A, B, C, D, E, H, L; 16-bit pairs BC, DE, HL; 16-bit PC
and SP; 64 KiB memory and 256 separately addressed input/output ports.
Operands are little endian and address/pair arithmetic wraps at 16 bits.
PSW exposes sign at bit 7, zero at 6, auxiliary carry at 4, even parity at 2
and carry/borrow at 0. Bits 5 and 3 read zero and bit 1 reads one.

Implement all 244 documented opcode encodings: movement, immediate and
memory operations, all ALU operations, DAA, rotations, pair arithmetic,
conditional/unconditional jumps/calls/returns, RST, stack/PSW, XTHL/XCHG,
SPHL/PCHL, I/O, HALT and EI/DI. Conditional branches consume all operands
regardless of the condition. CMP preserves A; INR/DCR preserve CY; DAD changes
only CY; rotations change only CY; CMA preserves flags.

Intel ANA/ANI clears CY and sets AC to the OR of bit 3 of the original
operands. It does not use the AND result's bit 3. XRA/XRI/ORA/ORI clear both
CY and AC. This differs from AMD's AC=0 and the 8085's AC=1 for AND.

PUSH decrements SP, writes high, decrements SP again, then writes low. POP
reads low then high, incrementing SP twice. CALL pushes the address after
both operand bytes; RST pushes the address after its opcode. XTHL exchanges
L/H with memory at SP/SP+1 without changing SP. PUSH/POP PSW normalize
reserved bits. Exact post-instruction PC and next fetched instruction are
part of every instruction test.

## Implementation interface

`intel_8080` contains a combinational `intel_8080_alu` and a multi-step
controller. One rising edge is an implementation step. This initial milestone
is a functional reconstruction; native two-phase clocks, original T-state
counts, SYNC/DBIN/WR/WAIT pin waveforms and electrical behavior require
further chip work. Scope is the 8080 chip and its verification; a computer,
board, operating system or firmware product is outside this design's scope.

| Port | Direction | Meaning |
|---|---|---|
| `clk`, `rst_n` | in | Implementation clock, synchronous active-low reset |
| `bus_req_o`, `bus_ready_i` | out/in | Transfer on rising edge with both high |
| `bus_write_o` | out | Write when high, read when low |
| `bus_addr_o[15:0]` | out | Memory address; I/O port replicated into both bytes |
| `bus_wdata_o[7:0]`, `bus_rdata_i[7:0]` | out/in | Byte transfer data |
| `bus_io_o` | out | Separate I/O space |
| `bus_intack_o` | out | Instruction byte supplied by interrupting device |
| `bus_status_o[7:0]` | out | Logical Intel status word, chapter 2 table 2-1 |
| `int_i`, `hold_i` | in | Level interrupt and bus-hold requests |
| `inte_o`, `hlda_o`, `halted_o` | out | Enable, bus-hold acknowledgement, HALT |
| `retire_o`, `fault_o` | out | Completion pulse and sticky model-validity fault |
| `pc_o[15:0]`, `sp_o[15:0]` | out | Architectural observations |
| `regs_o[55:0]`, `flags_o[7:0]` | out | Registers ordered A,B,C,D,E,H,L; normalized PSW |

Keep request, address, direction, space, status and data stable while stalled.
Architectural state does not advance until READY. Each write happens once on
acknowledgement. HOLD completes an outstanding transfer before asserting
HLDA; while held, requests and architectural progress stop. Releasing HOLD
resumes the instruction. At boundaries HOLD precedes interrupt acceptance.
This is a functional arbitration contract, not native HOLD pin timing.

Reset clears PC and control state, INTE, HLDA, HALT and validity fault. It
retains A/general registers, SP and flags (systems manual 2-14). Power-up
values of retained registers are unspecified; software must initialize them.
The physical active-high RESET requires at least three clocks; an eventual
pin adapter must map that to `rst_n`.

INT is accepted only at an instruction boundary when enabled, exits HALT,
disables INTE and fetches an externally supplied opcode without advancing PC.
EI recognition waits through the following instruction (systems manual EI
entry); DI disables immediately. RST interrupt injection and return to the
exact interrupted PC are required. The inherited controller also supports
three-byte CALL injection with operands from the interrupt source and no PC
increment; the Intel-specific evidence gap is tracked below.

## Validity boundaries and assumption ledger

08,10,18,20,28,30,38,CB,D9,DD,ED,FD are outside the documented instruction
contract. They raise sticky `fault_o`, suppress further requests and do not
retire until reset. Undocumented silicon aliases are a future compatibility
milestone. Injected XTHL also faults as an explicit initial model limitation;
this is not a claim that Intel prohibits it. Normal memory-fetched XTHL is
implemented. The Intel manual says devices may supply any instruction, so this
restriction must remain visible until resolved.

| Assumption or evidence gap | Independent evidence and validation | Status |
|---|---|---|
| SUB/SBB/CMP AC is complemented-addition carry; DCR AC is inverse nibble borrow | Pinned external superzazu `i8080_sub`, `i8080_cmp`, `i8080_dcr`; exhaustive ALU and original diagnostics | Validated; observed counts in report |
| Reserved PSW bits 5/3=0, 1=1; POP ignores them | Pinned external `i8080_push_psw`/`i8080_pop_psw`; opcode sweep and original diagnostic stack paths | Validated in opcode sweep and historical diagnostics |
| Three-byte injected CALL uses interrupt-source operands without PC increments | Existing AMD handbook 2-7/2-14 and inherited UVM stream tests; Intel 1975 programming manual chapter 5 permits externally supplied instructions but does not fully specify subsequent bus cycles | Provisional; Intel-specific historical device/software validation remains open |

Mark unresolved behaviors with `ASSUMPTION:` at their RTL implementation.
The external emulator is immutable and is never reconstructed from this RTL.
Historical diagnostics run from `run_all.sh` with their original bytes and
verified hashes. Passing ordinary diagnostics does not sign off the
provisional multi-byte interrupt contract or excluded pin timing.
