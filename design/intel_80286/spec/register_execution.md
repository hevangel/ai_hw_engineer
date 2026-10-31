# Register execution milestone (2a)

This baseline inventory is derived from Intel 210498-005, Appendix B and sections 3.3,
3.4, 3.6 and 3.8, not from the existing 8086 RTL. It extends the bootstrap
specification before implementing the added RTL. The later
[memory extension](memory_execution.md) now adds memory operands, segment
prefixes, near stack operations and I/O. The subsequent [procedure extension](procedure_execution.md)
adds multiply/divide, far transfers and real-mode event delivery; [BOUND/XLAT](bounds_translation.md)
adds bounds faults and table translation. General exception handling remains pending.

| Family | Encodings | Scope |
|---|---|---|
| Arithmetic/logic | 00..3D, low opcode bits 0..5; 80/81/83 | ADD/OR/ADC/SBB/AND/SUB/XOR/CMP, register ModR/M or accumulator immediate |
| TEST | 84/85, A8/A9, F6/F7 /0 | Register operands/immediate; no writeback |
| INC/DEC | 40..4F, FE/FF /0,/1 | Byte/word; carry preserved |
| NOT/NEG | F6/F7 /2,/3 | Register operand |
| MOV/XCHG | 88..8B, 86/87, 91..97 | Register operands; correct byte aliases |
| Segment moves | 8C/8E | Register operands; ES/SS/DS loads, CS readable; loading CS rejected |
| CBW/CWD | 98/99 | Signed extension, flags preserved |
| Flag transfer | 9E/9F | SAHF/LAHF, only documented flag bits are architectural |
| Conditional jumps | 70..7F | All 16 conditions and signed disp8 |
| Loops | E0..E3 | LOOPNE/LOOPE/LOOP/JCXZ, flags preserved |
| Shift/rotate | C0/C1, D0..D3, /0..5,/7 | Register operands, immediate/one/CL counts; count masked to five bits |

Every instruction retires once with exact post-state. Invalid group extensions
stop at the original IP. No operand read or
register change is permitted for unsupported instructions. Known lengths are
checked before fetching remaining bytes beyond FFFF. The diagnostic is still
a development stop, rather than architectural exception delivery.

## Defined/undefined flags

ADD/ADC/SUB/SBB/CMP/NEG define OF/SF/ZF/AF/PF/CF. INC/DEC preserve CF.
Logic and TEST define OF=CF=0 and SF/ZF/PF; AF is undefined. Shifts define
SF/ZF/PF and the last bit shifted into carry; AF is undefined and OF is only
defined for count one. Rotates
preserve SF/ZF/AF/PF and define OF only for count one. Count zero preserves
value and flags. Only low five count bits participate, unlike the 8086.

ASSUMPTION A3: the implementation preserves undefined AF/OF and emits a
canonical LAHF reserved-bit image (bit 1 set, bits 3/5 clear). These are
deterministic project choices, not promised Intel values. Differential tests
mask undefined outputs and never use them to decide later expected control
flow. Original IBM AT flags-test execution validates the defined dependencies;
full real-software sign-off remains pending.

## Independent tests

Use Unicorn 2.1.4 (QEMU-derived x86 engine) as a differential oracle for the
shared 16-bit register subset. It is not an 80286 emulator and cannot validate
286 protected mode, timing, reset caches or exception differences. Those
remain Intel-derived directed/formal checks. No golden arithmetic result is
computed by translating the RTL into Python/C++.

Generate reproducible vectors with a fixed seed, check every instruction's
exact PC, next PC, all registers and all defined flag bits, and exercise
both branch outcomes, byte aliases, ADC/SBB edge cases, all shift-count bytes,
and immediate forms. Mask undefined flag bits according to Intel, and clear
undefined register bits from LAHF expectations. Include unchanged IBM AT BIOS
execution through its flags-test success path, with a hard stop at I/O.

The modern oracle cannot settle large-count logical-shift CF semantics for
the 286: its architecture leaves CF undefined when SHL/SHR counts reach the
operand width. Mask CF for those oracle comparisons, and separately test all
256 count bytes, both widths/directions and four operand patterns against the
Intel B-97 repeated-shift contract, including the final shifted carry bit.
