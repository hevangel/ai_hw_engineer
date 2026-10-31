# Arithmetic, procedure and real-mode event extension

The full-chip target remains unchanged. This specification extends the current
memory core before implementing RTL. Sources: Intel 210498-005 Appendix B,
MUL/IMUL/DIV/IDIV, PUSHA/POPA, ENTER/LEAVE, CALL/RET, INT/INTO and IRET;
section 5.2 defines real-mode exception frames and saved PCs.

## Arithmetic

Implement F6/F7 /4,/5,/6,/7 as byte/word MUL, IMUL, DIV and IDIV, and 69/6B
three-operand word IMUL with word/sign-extended byte immediate. Single-operand
multiply returns AX or DX:AX; immediate IMUL writes only its named destination.
CF/OF report whether the high half is redundant (zero for MUL, sign extension
for IMUL). Other multiply flags and all divide flags are undefined; retain
old values under the existing A3 deterministic undefined-output policy.

Division uses AX or DX:AX, truncates signed quotient toward zero, and gives
remainder the dividend's sign. Divide by zero or a quotient outside the byte/
word signed/unsigned range raises real-mode vector 0 without writing AX/DX or
retiring the faulting instruction. The stacked return PC names the instruction
start including prefixes, rather than the post-encoding cursor. Byte division
returns AL quotient/AH remainder and preserves DX. All divisor aliases must
be sampled before modifying the implicit result registers.

## Procedures and stack

Add 60/61 PUSHA/POPA. Save the original SP in PUSHA, and discard the SP slot
in POPA. Registers commit only after the complete instruction; accepted external
writes can survive reset. Add C8 ENTER (imm16 allocation, low five nesting bits)
and C9 LEAVE using the manufacturer's frame-copy algorithm. Stack traffic uses
SS even with segment overrides. Instruction tests check exact saved memory,
final BP/SP, return IP and the next executed instruction.

Add 9A immediate far CALL, FF /3 memory far CALL, FF /5 memory far JMP, CA/CB
far RET, and CF IRET in real mode. Memory far pointers are four contiguous
bytes; register /3,/5 encodings are invalid. CALL saves the original CS and
post-encoding IP; RET loads the pointer and adds its optional stack adjustment.
Every real CS reload updates its hidden base even for the same selector.

## Real-mode events

Add CC/CD/CE software INT/INTO and internal divide fault entry. Read the four-
byte IVT entry at vector*4, save FLAGS, CS and IP in that order, clear TF/IF,
and transfer to the handler. IRET restores IP, CS and FLAGS and advances SP by
six. An event observation pulse exposes completed entry and vector number for
independent frame tests. Software INT retires once; faults do not retire.

This does not claim complete interrupt support: asynchronous INTR/NMI, debug
traps, interrupt shadows, limit-fault escalation, IDTR changes and protected-mode
gates remain required next work. Existing development diagnostics for other
unimplemented encodings/operand limits are not architectural #UD/#GP delivery.

## Verification

Use the existing pinned external oracle for normal multiply/divide, register
aliasing, stack data effects, ENTER levels and far control transfers. Mask only
manufacturer-undefined outputs. Real-mode INT/fault entry is checked against
independent manufacturer-derived frame expectations, not a model translated
from RTL. Keep the original ROM regression and all prior formal/bus checks.
Add exact divide-error saved-PC, unchanged operand registers, stack-image,
handler-entry and IRET restart checks. Preserve the full completion ledger;
none of these additions substitutes for protected mode or native chip pins.

## Oracle instrumentation and assumptions

Unicorn 2.1.4's x86 read hook corrupts RETF execution in a minimal far-CALL/
RETF reproducer: adding even an empty UC_HOOK_MEM_READ callback changes the
return landing. Far-transfer cases therefore execute with that hook disabled,
using continuous code hooks for actual next-instruction state and write hooks
for stores. Far-pointer and return-frame reads use explicit Intel Appendix B
CALL/JMP/RET/IRET contracts; their data comes from a mirrored fixture memory
updated by observed writes. They are not claimed as independent emulator read
callbacks. Other instruction families retain read callbacks. PUSHA write
callbacks are compared as an exact address/data multiset because Unicorn
batches them in a different order; a separate Intel-derived test asserts the
manufacturer's AX-through-DI push order and original-SP image.

ASSUMPTION A5: the functional event sequencer reads the IVT before writing the
stack frame. Intel's architectural frame definition does not establish this
native bus ordering. Directed INT/divide-fault/IRET programs validate frame
contents and control flow, but historical software with interrupts and native
bus evidence remain required before sign-off of this abstraction.
