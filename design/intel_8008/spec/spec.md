# Intel 8008 specification

Primary source: [Intel MCS-8 Users Manual, November 1973](../../../references/intel_mcs8_users_manual_nov1973.pdf), especially the instruction section on scanned pages 11–17. Independent behavior cross-check: [SIMH i8008.c](../references/simh_i8008.c). Download URLs appear in the design README.

This synchronous functional core presents a 14-bit byte-addressed memory interface and a 5-bit I/O port interface. It does not recreate the 18-pin multiplexed bus, two-phase electrical timing, or READY timing. `ready=0` holds a memory or I/O transaction. `interrupt` substitutes `interrupt_opcode` for the next fetched opcode, including wake from HLT.

The programmer model contains A, B, C, D, E, H, L; carry, zero, sign, and even-parity flags; a 14-bit PC; and eight 14-bit PC stack entries with seven usable return levels. Reset clears the programmer model and begins at address zero. Instruction addresses wrap within 16 KiB. Effective data address is `{H[5:0], L}`.

The original octal opcode matrix defines `11dddsss` register/memory moves, `10ooosss` ALU operations, `00ddd110` immediate loads, `00ddd000/001` increments/decrements, `00ooo100` immediate ALU operations, four rotates, jump/call/return families, restart vectors, and I/O. HLT encodings are octal 000, 001, and 377. The core recognizes the documented aliases. Undefined encodings are treated as NOP.

Arithmetic carry is the ninth result bit, including subtraction borrow. Compare changes flags without changing A. Logical operations clear carry. Increment and decrement preserve carry. Rotates modify carry alone. Conditional branches use carry, zero, sign, or parity in that order, with true/false sense selected by the opcode. Jump and call always consume both address bytes. Restart pushes the following PC and branches to an eight-byte vector.

ASSUMPTION: Board-specific interrupt injection timing is outside the chip's programming specification. This core accepts the injected opcode at an instruction boundary and requires the controller to hold `interrupt` through one accepted cycle. A regression must exercise interrupt RST and return.

ASSUMPTION: Stack overflow/underflow wraps modulo eight, matching the independent SIMH model. Software may use seven nested calls safely.

ASSUMPTION: Undefined encodings have no architectural effect. Tests must not rely on those encodings.
