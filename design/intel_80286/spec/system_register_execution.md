# System-register instruction execution foundation

Status: real-mode system-register data flow and the first ring-0 PE-entry path
are integrated. LMSW sets sticky PE; the fixture preserves the inherited CS
cache through the queue-flush jump, then reloads CS through the code-load
engine. Protected SLDT/STR/LLDT/LTR and VERR/VERW/LAR/LSL, LDT-backed
data-segment loads, and same-level selector-error delivery have bounded ring-0
execution coverage. Protected-mode CPL checks cover CPL-3 LLDT/LTR and
CPL-1–3 LGDT/LIDT/LMSW/CLTS, plus ring-0 controls for the latter four. This is
a bounded privilege slice; broader nonzero-CPL execution, privilege-changing
event delivery and the rest of protected system execution remain open. See
[selector execution](selector_execution.md) and the
[system-instruction privilege report](../report/2026-10-27-system-instruction-privilege.md).

Sources: Intel 210498-005 sections 10.2/10.4 and Appendix B LGDT/LIDT/SGDT/SIDT/
SMSW/LMSW/CLTS plus sections 11.3 and Appendix B VERR/VERW/LAR/LSL; the
210498-001 protected-mode initialization example also exercises LAR on a TSS
selector. Independently pinned
[86Box group 0F01](https://github.com/86Box/86Box/blob/1db9ae4cc910b0b7e6e9b49995910b0cc19747a0/src/cpu/x86_ops_pmode.h#L466).

## Decode and data flow

Implement a second-opcode fetch after 0F. Count it, prefixes, ModR/M and
displacement within the 286 ten-byte/code-limit rules. Preserve the original
prefixed instruction PC and retire once with first opcode 0F. A segment prefix
applies to a system memory operand; a repeat prefix remains unsupported.

0F 01 /0 SGDT and /1 SIDT store six bytes; /2 LGDT and /3 LIDT load six bytes.
These four require memory operands. /4 SMSW stores a word to a register or
memory, and /6 LMSW reads a word from either. /5 and /7 are invalid for this
implemented 286 group. 0F 06 CLTS has no ModR/M.

The selector/system opcode group is decoded separately by mode. In real mode,
0F 00 (SLDT/STR/LLDT/LTR/VERR/VERW), 0F 02 (LAR) and 0F 03 (LSL) raise #UD.
In protected mode, 0F 00 /0–/5 and 0F 02/03 execute the bounded selector
operations specified in [selector_execution.md](selector_execution.md),
including register and memory selector operands for VERR/VERW/LAR/LSL. 0F 00
/6 and /7 remain invalid. Do not report valid protected forms as #UD merely
because broader privilege levels or descriptor-table behavior remain open.

Other valid but unimplemented 0F families keep a development stop, not a claim
of architectural #UD.

Add 24-bit GDTR/IDTR bases, 16-bit limits and mutable MSW. Six-byte images have
limit16 followed by base24 and an unused byte. Loads consume all six bytes and
ignore the unused byte. Stores issue no reads. Widen the existing write staging
buffer to six bytes; keep complete write data stable through ready stalls.
Commit loaded registers only after the complete operand read, and retire stores
only after every accepted write. Flags/GPRs remain unchanged except SMSW's
selected register destination. Reset cancels pending transfers; accepted writes
are not undone.

MSW resets to FFF0. SMSW reports its reserved high bits as ones. LMSW changes
MP/EM/TS, ignores upper input bits, and sets PE without clearing it; CLTS clears
TS only. The supported entry fixture runs the documented intra-segment jump
and then reloads CS with a protected direct far JMP. Protected paths outside
the supported ordinary ring-0 slice still stop visibly; this does not claim
complete protected-mode execution or exception delivery.

ASSUMPTION: A12. SGDT/SIDT's unused sixth store byte is FF on the 286-specific
external artifact. GDTR resets to deterministic base/limit zero because Intel
10.4 does not define those fields; the inspected MAME 286 also initializes them
to zero, while PCjs flags its own choice as unverified. These are project/source
policies, not Intel reset guarantees. Software must load GDTR before depending
on it. Native 286 evidence and historical system-register initialization remain
sign-off gates for these choices. IDTR reset base 0/limit 03FF is primary-defined.

## IDT use and incomplete exception boundaries

Real-mode INT/INTO/fault/INTR/NMI/TF entry must use the current IDTR base, with
four bytes per vector. Require the complete pointer within its loaded limit
before any vector/frame transfer. A limit violation remains development code 2
with no event/retirement, pending the precise real/protected delivery fault and
escalation implementation. Do not substitute a development stop for #GP/#DF
in a completion claim. Existing IVT/frame scheduling assumption A5 remains.

Six-byte system operands require offset<=FFFA. Reject limit-crossing operands
before reading or writing any operand byte using the existing diagnostic code 2.
Keep broader architectural exception/error-code completion open.

## Protected system-instruction privilege checks

Intel 210498-005 §§10.2–10.3 classifies LGDT, LIDT, LMSW and CLTS as
privileged operations. When PE is set and CPL is nonzero, these encodings
raise restartable #GP(0). The check runs in PREPARE before a memory-form
operand read, so LMSW [r/m16], LGDT [m16&24] and LIDT [m16&24] do not cause a
denied data-bus transaction. LLDT/LTR retain their existing nonzero-CPL
#GP(0) checks. The separate LLDT/LTR regression now covers CPL 1–3; see the
[selector privilege report](../report/2026-10-27-lldt-ltr-privilege.md). Real
mode remains unaffected by this protected-mode privilege gate; privileged
instructions outside this list still need source review.

Directed evidence covers CPL 1–3 at every IOPL with immediate and stalled
READY policies for CLTS, LMSW AX, LMSW [0010], LGDT [0010] and LIDT [0010].
It checks exact restart state, no retirement or state change, and no denied
memory read. Ring-0 controls cover the same forms at all IOPL values and both
READY policies. This does not establish descriptor-table limits, malformed
operand priority, privilege-changing delivery, or whole-core correctness.

## Verification requirements

Check exact fetched bytes, ten-byte and code boundaries, all addressing forms
and segment overrides, six-byte transfer order/data/stalls, upper-byte ignoring,
register/flag preservation, every reset cut and MSW low-bit combinations.
Exercise loaded IDTR through real handlers and exact IRET/successor PCs. Distinguish
invalid group encodings from the protected-event development stop at code 3.
Retain all independent
instruction, original BIOS, interrupt/debug, formal and synthesis regressions.
Pin external expected semantics before changing RTL and any oracle together;
modern shared-ISA SGDT's sixth byte is not an independent 286-byte oracle.

The current directed suite has 402 cases and nine compiled semantic mutants.
The historical regression also executes original IBM AT ROM F000:064F..0688
with four byte-repeated input patterns, then its exact return and the original
HLT at F000:0224 (164 original instruction states). The original comparison
loop checks all five defined bytes from both stored table images. This is a
routine-entry fixture with a separate high-reset bootstrap and RAM frame;
the entire low BIOS image is checked unchanged. It establishes actual software
use of the four table instructions without validating the unused byte or an
undefined reset choice, and without claiming a POST/protected-mode run.
