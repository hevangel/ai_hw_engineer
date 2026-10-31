# Memory, I/O and stack execution specification

This extends the register execution specification toward the full 80286 target.
Intel 210498-005 Appendix B and sections 2.4, 3.2, 3.6 and 5 define behavior;
Unicorn supplies independent shared-ISA instruction/memory traces. These
requirements are written before implementation. Full protected mode, interrupt
and exception delivery, task switching and native bus timing remain required
later work rather than being excluded from the final chip objective.

## Transactions and addressing

Extend the existing byte handshake with bus_fetch_o, bus_write_o, bus_io_o and
bus_wdata_o. Accept only on a rising edge with request and ready. Address,
operation and write data remain stable while stalled. Reads sample rdata only
on acceptance. Reset cancels a pending request; accepted external writes remain
external effects. Physical memory addresses remain 24 bits. I/O uses 16-bit
port addresses. Byte decomposition is an A1 functional-interface abstraction.

Implement all 16-bit ModR/M address forms: BX+SI, BX+DI, BP+SI, BP+DI, SI, DI,
BP (or direct disp16 in mod00/rm6), BX; signed disp8 or disp16 added modulo
65536. BP-based forms default to SS and others to DS. Segment overrides select
ES/CS/SS/DS for the entire instruction. CS overrides use the hidden CS base,
including after reset. Prefix bytes belong to the retiring instruction's PC.

Extend existing ALU/MOV/TEST/XCHG/unary/shift operations to memory operands.
Store-only instructions perform no preliminary data read. Add C6/C7 immediate
MOV, A0..A3 moffs MOV, LEA and LES/LDS. Word operands at FFFF and dword pointers
above FFFC stop with diagnostic code 2 before any operand transaction. The
final architecture still requires real #GP/#SS exception delivery there.

## I/O and stack

Add IN/OUT E4..E7 and EC..EF, immediate-byte or DX port, byte/word operand;
word ports decompose into two byte transfers. IN merges AL or AX, preserving
other bits and flags. OUT preserves registers/flags.

Add PUSH/POP general and segment registers, PUSHF/POPF, 68/6A immediate PUSH,
FF /6 PUSH, 8F /0 POP, E8 and FF /2 near CALL, FF /4 near JMP, C2/C3 near RET.
PUSH SP uses its value before decrement on the 80286 (unlike the 8086).
Stack transfers always use SS, independent of segment override. PUSH commits
SP-2; POP commits SP+2 except POP SP ultimately loads the popped value. CALL
pushes the post-encoding IP and then transfers; RET pops IP and C2 additionally
adds its immediate stack adjustment. These operations must assert exact next
CS:IP and execute the instruction there. POPF reserved bits follow Intel's
real-mode flag image; NT/IOPL are preserved in real mode per B-86. Precise
privilege restrictions are part of protected mode.

Architectural flags/registers change only on retirement (or completed event
delivery or completed string elements in the subsequent extensions). Memory writes occur
before retirement; reset does not roll back already accepted bus writes. The
protocol tests distinguish those effects from partially committed registers.

ASSUMPTION A4: the functional byte-bus model emits an unchanged writeback for
zero-count memory shifts/rotates, matching the independent Unicorn RMW trace.
Intel specifies unchanged operands/flags for zero counts; the native timing
and external bus sequence still require verification against 286 hardware
documentation. This abstraction is not a claim about physical chip cycles.

## Verification gates

Retain register vectors, formal datapath proofs and reset/cache tests. Replace
old tests that rejected all memory ModR/M bytes with tests for the newly
supported addressing modes and genuinely invalid group encodings. Extend the
independent oracle with initialized memory, reads/writes, segment overrides,
word alignment, wraparound effective offsets, stack aliasing and exact return
landings. Add ready/valid stability properties for every bus field. Advance
unchanged IBM AT firmware using explicit board I/O responses and independently
derived traces; do not patch its bytes or equate partial execution with POST.

The subsequent [reference-routing integration](reference_integration.md) now
retains role/offset/span and permission kind for every segmented request,
validates before bus issuance and checks every fetched byte through CS. I/O
and bounded linear IDT reads retain separate paths. Whole-instruction protected
prechecks, architectural faults and protected descriptor commits remain required.
