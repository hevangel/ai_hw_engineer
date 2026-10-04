# Am9080A functional specification

Primary authority: AMD's [1977 8080A/9080A MOS Microprocessor Handbook](https://bitsavers.trailing-edge.com/components/amd/_dataBooks/1977_AMD_8080A_9080A_MOS_Microprocessor_Handbook.pdf),
chapter 2 (PDF pages 6-21), chapter 3 (22-83), instruction timing/data sheet
chapter 4 (84 onward) and instruction summary appendix A. The original Am9080
and commercial Am9080A name belong to the requested family; this core targets
the documented Am9080A binary contract, not an undocumented earlier revision.

## Architecture

Eight-bit A, B, C, D, E, H and L; pairs BC, DE and HL; 16-bit PC and SP;
64 KiB byte-addressed memory; 256 separate input/output ports. PSW has sign
bit 7, zero 6, auxiliary carry 4, even parity 2 and carry/borrow 0. All
documented 244 opcodes are required: data movement, immediate operations,
arithmetic/logical operations, rotations, decimal adjust, pair arithmetic,
conditional/unconditional branches, calls/returns/restarts, stack/PSW
operations, XTHL/XCHG, I/O, halt and interrupt control. Operands are little
endian. Address/pair/SP arithmetic wraps at 16 bits. No instruction subset.

AMD ANA/ANI clears CY and AC (3-10/3-11). This differs from Intel 8080
silicon's operand-dependent ANA AC. [Independent physical-chip testing](https://demin.ws/blog/english/2012/12/24/my-i8080-collection/)
confirms AMD clears AC. The contemporary [January 18, 1977 Electronic Design
report, printed 41-42](https://www.worldradiohistory.com/Archive-Electronic-Design/1977/Electronic-Design-V25-N02-1977-0118.pdf)
also records AMD's independently implemented flag behavior. The independent
Intel emulator requires a narrowly cited AMD adapter, not a wholesale rewrite.

PUSH decrements SP and writes high byte first, then decrements and writes low;
POP reads low then high and increments SP twice. This follows the detailed
PUSH instruction (3-42); the reversed general description on 2-2 is a source
error and is not followed. CALL saves the address after all operand bytes;
RST saves the address after its opcode. Conditional branches always consume
their operand bytes. XTHL exchanges [SP]/[SP+1] and L/H without changing SP.

Reset clears PC, instruction/control state, INTE, HOLD and HALT. It does not
clear A/general registers, SP or flags. A physical reset needs at least three
clock periods. The core uses synchronous active-low `rst_n`; a caller maps
the physical active-high RESET and supplies the required duration.

## Functional bus contract

One rising `clk` edge is an implementation step, not an original two-phase
T-state. This synthesizable core implements binary instruction and ordered
memory/I/O effects through a ready/valid transaction bus. It does not claim
native SYNC/DBIN/WR waveforms, original instruction cycle counts, two-phase
clock generation or electrical timing. Those require a separate physical
bus/clock adapter. This boundary is explicit for all test/report claims.

| Port | Contract |
|---|---|
| `clk`, `rst_n` | Implementation clock; synchronous active-low reset |
| `bus_req_o`, `bus_ready_i` | Transfer at rising edge with both HIGH |
| `bus_write_o` | Write direction; false means read |
| `bus_addr_o[15:0]` | Memory address; I/O port replicated into both bytes, per 2-3 |
| `bus_wdata_o[7:0]`, `bus_rdata_i[7:0]` | Byte transfer data |
| `bus_io_o` | Separate I/O space |
| `bus_intack_o` | Read from interrupting device instead of memory |
| `bus_status_o[7:0]` | Logical status byte from manufacturer table 2-1; not a SYNC pulse |
| `int_i`, `hold_i` | Level-sensitive interrupt and bus-hold requests |
| `inte_o`, `hlda_o`, `halted_o` | Interrupt enable, hold acknowledgement, halted state |
| `retire_o` | One-step completed-instruction pulse |
| `fault_o` | Model-validity fault for undocumented opcode/unsupported injected XTHL |
| `pc_o`, `sp_o`, `regs_o[55:0]`, `flags_o` | Verification observations; registers ordered A,B,C,D,E,H,L |

Outstanding transfers keep address, direction, space, status and write data
stable until READY, with no architectural progress while stalled. Writes
occur exactly once on acknowledgement. HOLD completes the outstanding
transfer, then suppresses bus requests and architectural progress while HLDA
is asserted; releasing HOLD resumes the interrupted instruction. At an idle
boundary HOLD has priority over interrupt acceptance, including during HALT.

INT is accepted only at an instruction boundary with INTE and its enabling
delay satisfied. It exits HALT, disables INTE and requests an externally
supplied opcode. PC is not incremented for that opcode or any following
operand bytes: multi-byte instructions request further bytes from the
interrupt source (NULL cycles, 2-7/2-14). CALL and RST injection are required,
including table 2-1's distinct 2B status for an acknowledge from HALT (23
otherwise; 02 for following NULL bytes).
Injected XTHL is explicitly unsupported by
the manufacturer (2-12); the model faults. DI disables interrupts; EI sets
INTE but recognition waits until the following instruction has completed.

## Unspecified opcodes and assumptions

The handbook 3-2 marks 08,10,18,20,28,30,38,CB,D9,DD,ED,FD unpredictable.
They are not invented Intel aliases here. The reconstruction raises sticky
`fault_o`, issues no more transfers and retires no undocumented instruction
until reset. This is a model-validity boundary, not claimed silicon behavior.

Behaviors not pinned explicitly by the primary handbook are tracked below
and marked `ASSUMPTION:` at their implementation. None is signed off merely
because a self-authored instruction test agrees.

| Assumption | External artifact and required validation | Status |
|---|---|---|
| Subtract/CMP AC is carry from complemented-operand addition; DCR AC is inverse low-nibble borrow | Pinned superzazu `i8080_sub`, `i8080_cmp`, `i8080_dcr`; physical-chip report says other instruction exerciser results agree; historical TST8080 subtract/CMP/DCR paths and exhaustive ALU/flag tests | Validated; report records counts |
| PUSH PSW reserved bits 5/3=0, bit 1=1; POP ignores them | Pinned oracle `i8080_push_psw`/`i8080_pop_psw`; original TST8080 PUSH/POP PSW paths and AMD handbook 15-2 ISR skeleton | Validated in historical diagnostics, opcode sweep and manufacturer ISR |
| EI recognition delayed through one following instruction | Pinned oracle interrupt-delay handling; actual AMD handbook 15-2 / Figure 15-3 EI/RET code with pending INT, and explicit EI/NOP/RST boundary tests | Validated in manufacturer historical code and UVM |

No flags/register reset values or undocumented alias instructions are assumed.
