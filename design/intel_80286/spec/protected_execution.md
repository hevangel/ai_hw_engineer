# Protected-mode implementation contract and evidence gates

Status: the core has a focused protected slice: sticky PE entry, ordinary GDT
and loaded-LDT operations, cached references, selector #GP/#NP delivery
through same-level gates, outer-level IRET to ring 3, same-level CALL gate,
ring-3-to-ring-0/1/2 CALL gates and a conforming target, outer RETF, and
ring-3-to-ring-0 interrupt/trap-gate delivery through the TSS stack. Software
INT gate-DPL rejection and interrupt/trap IF/TF behavior are covered. Strict
lint and the full bootstrap pass on the event-gate source. Earlier 79-case
protected replay, mutation, synthesis and component-formal evidence belong to
recorded prior snapshots. Current-source connected-core BMC is running; core
proof, reachable cover, PDR and the exact-source audit remain open. Task gates,
task switching, nested-fault escalation, full vector/fault coverage and full
protected software remain incomplete. See the [system-register contract](system_register_execution.md),
[ring-0 integration contract](protected_mode_integration.md) and
[protected privilege transition contract](protected_privilege_transition.md).
This document preserves the full CPU scope and does not treat the tested paths
as complete protected-mode support.

Primary source: Intel 210498-005, chapters 6-11 and the individual Appendix B
instruction entries, linked in the [README](../README.md). Existing functional
bus abstractions and A9/A10 unresolved interrupt edges remain explicit gates.

## Required architectural state

Implement GDTR/IDTR with 24-bit base and 16-bit limit, LDTR/TR with visible
selectors and hidden descriptors, CPL, and all four segment descriptor caches.
Each cache needs its base, limit, access/type/privilege information and validity
alongside its visible selector. Preserve the special reset CS base until a
documented reload; setting PE must not be used to synthesize a normal far jump.
Pin the exact transition/cache/reset rules before changing this behavior.
The [segment-load checker](segment_load_check.md) supplies ordinary DS/ES/SS
validation. The [transaction engine](segment_load_transaction.md) fetches
descriptors, completes accessed-byte writes and publishes load results; the
core now uses it for ordinary ring-0 MOV-to-DS/ES/SS and commits the selector
and cache after successful completion. Other selector classes and protected
fault delivery remain open.
The [ordinary CS checker](code_load_check.md) now supplies the source-backed
JMP/CALL decision, including code-type validation and CALL stack/target fault
priority. Its [transaction engine](code_load_transaction.md) snapshots requests,
reads all eight bytes and completes the accessed write before ordinary-code
publication. The core uses it for direct protected far JMP and CALL, and the integrated
gate path resolves valid same-level and ring-3-to-ring-0 CALL gates. Valid
outer-level IRET and RETF paths validate CS/SS and commit CS:IP/FLAGS/SS:SP
together. Invalid-transfer faults, LDT gates and other privilege levels remain
open; see [protected privilege transitions]
(protected_privilege_transition.md).
The [cached-access checker](access_check.md) supplies permission and complete
contiguous-span decisions. Its [bank frontend](cached_reference.md) now connects
to every CPU fetch/segmented operand path through [reference routing](reference_integration.md),
with explicit role/offset/span, RMW intent and validation before bus issuance.
The narrow ring-0 regression exercises cached data accesses and a denied DS
span. Whole-instruction stack/priority/restart rules and precise delivery still
require integration. The frontend separately preserves the inherited trusted
CS fetch role; the fixture checks its use through PE entry.
The [cache integration contract](cache_integration.md) records the next core
changes and the retained-real-CS/privilege edges that must not be guessed. For
the bounded first ring-0 path, transition sequencing and inherited CS state are
resolved in the [ring-0 integration contract](protected_mode_integration.md);
that scoped assumption does not settle other inherited RPL values or reset
and cache behavior outside the fixture.

Selectors contain a 13-bit index, TI and two-bit RPL. GDT/LDT selection and
descriptor-table bounds precede descriptor use. A complete descriptor occupies
eight bytes. Six-byte table transfers work, and the separate eight-byte
descriptor loader is integrated for the supported direct far JMP and segment-
load paths. Broader descriptor classes and transaction/reset combinations
remain to be checked against the complete architecture.

Intel figure 6-7 defines access byte P/DPL/S/type and code/data interpretations:
executable/conforming/readable/accessed versus expand-down/writable/accessed.
Decode 286 system and gate types separately; do not accept 386 descriptor flags,
granularity, 32-bit segments or extra gate types because a modern oracle does.
Pin ignored/reserved bytes and accessed/busy-bit memory updates from a 286
artifact before implementing them. A raw descriptor decoder alone is not a
segment-load, privilege-check or memory-protection implementation.

## Implementation order

1. Source and implement 0F decoding and system-register instructions: SMSW,
   LMSW, CLTS, SGDT/LGDT, SIDT/LIDT, SLDT/LLDT and STR/LTR. Each valid encoding
   must be separated from development diagnostics and invalid group fields.
   Intel 10.2 specifies CPL restrictions, six-byte GDTR/IDTR operands, the
   sticky PE bit, MP/EM/TS and LTR's busy-bit update. Resolve the unused sixth
   GDTR/IDTR byte and every real-mode legality rule before writing expectations.
2. Add source-backed descriptor decoding and cache loads. DS/ES permit the
   documented data/readable-code cases with type-specific privilege checks,
   including max(CPL,RPL) for data and non-conforming readable code;
   SS requires the stack-specific writable/type/privilege/presence checks.
   Audit null selectors and unusable caches. Preserve old architectural state
   on failed loads, with exact documented exception/error codes and priority.
3. Implement protected CS transfers and instruction/data access checking.
   Check each whole operand and fetched instruction against cached limits,
   including expand-down segments, code read/write restrictions, privilege,
   boundary wrapping, stack operations and partially completed REP. Extend
   access checks to every existing instruction path, not just MOV.
4. Extend IDT gate delivery beyond the tested same-level selector #GP/#NP and
   privilege-changing interrupt/trap-gate paths. The current event slice
   covers TSS stack selection, exact outer frames, software-INT DPL rejection,
   gate-specific IF/TF updates and outer IRET. Invalid gate/target/TSS/stack
   faults, nested delivery, double-fault escalation and shutdown remain open.
   Existing real-mode frames do not cover those protected cases.
5. Complete task switching, TSS busy/backlink/NT/TS behavior, LDT/cache reloads,
   and task-gate exception paths. Extend the tested ring-0 LAR/LSL/VERR/VERW
   slice to other privilege levels. Reachable LLDT/LTR #GP(0) checks now cover
   CPL1–3, and focused IOPL/IF/HLT checks cover the implemented control rules;
   broaden remaining privilege/exception-priority cases and coprocessor
   controls with exact restart behavior.

## ARPL protected-mode slice

Opcode `63 /r` has a bounded protected-mode implementation in the core.
Register and memory destinations compare their low two RPL bits against the
word-register source; a lower destination is raised to the source RPL and ZF
is set, otherwise the destination is unchanged and ZF is cleared. Other FLAGS
are preserved. A memory destination is checked as read-modify-write before its
read; it is written only when its RPL changes. Real Address Mode still raises
#UD. These semantics follow Appendix B's ARPL entry (B-10).

The Intel 80286(B-2/B-3) Information Sheet dated 1984-11-21 says on all 286
components that a null source selector also raises #GP(0). The implementation
checks this before accessing a memory destination. Focused tests cover the
null-source protected fault packet and a 384-case reachable CPL1/CPL2/CPL3
matrix: every source/destination RPL pair, register and SS-based memory forms,
both incoming ZF values and both READY policies. Each case reaches its ring
through outer IRET and checks exact fetch length, only-ZF flag changes,
conditional RMW traffic and unprivileged successor execution. ARPL's separate
segment-limit/fault-priority combinations, independent stepping captures and
whole-core formal proof remain open. See [the instruction entry](https://bitsavers.trailing-edge.com/components/intel/80286/210498-005_80286_and_80287_Programmers_Reference_Manual_1987.pdf)
and [the Intel information sheet](https://docs.pcjs.org/manuals/intel/80286/80286_B2_B3_Errata-1984-11-21.pdf).

No stage may silently execute a protected instruction using real-mode
selector-times-sixteen addressing. Do not implement a reversible PE bit as a
convenience: Intel table 10-1 permits clearing it only by reset. The current
core keeps PE sticky and constrains its supported entry/segment-load states;
extend those contracts as additional protected execution is implemented.

## Independent verification and historical software

Choose and pin an executable independent 286 artifact before creating protected
instruction/state expectations. PCjs/MAME/86Box sources can supply semantic
evidence, but the current shared-ISA Unicorn corpus does not establish 286
protected-mode behavior. Keep an explicit source for each changed RTL/oracle
semantic pair, and list primary-document ambiguities in the assumption ledger.

Tests must check descriptor reads and side effects, old/new cache state, exact
faulting and resumed PCs, complete frames/error codes, next executed opcode,
and all privilege/limit/presence combinations. Formal BMC/prove/cover must
include successful and failed cache loads, PE entry, privilege changes and
non-vacuous fault delivery. No fairness assumption may hide a stalled transfer.

Required integration evidence includes actual unchanged protected-mode
historical software, full real-mode firmware with its required AT devices,
independent per-instruction/exception traces and native-bus verification.
A hand-written ring-0 demo, a descriptor decoder, or green real-mode regression
does not close these full-chip requirements. Keep the
[completion ledger](../plans/completion_requirements.md) authoritative.

## Pinned system-register source findings

The independent [86Box group-0F01 handler](https://github.com/86Box/86Box/blob/1db9ae4cc910b0b7e6e9b49995910b0cc19747a0/src/cpu/x86_ops_pmode.h#L466)
has an explicit `is286` path: SGDT/SIDT write limit16, base24 and FF in the
sixth byte. LGDT/LIDT fetch six bytes and retain only the low 24 base bits.
SMSW reports reserved high bits as FFF0, while LMSW changes only the low four
bits and preserves an already-set PE bit. The primary manual calls the sixth
byte unused; the implemented FF policy is assumption A12, with focused tests.
The original BIOS self-test validates the five defined bytes; native sixth-byte
and undefined-reset evidence remain required before final sign-off. Sticky PE
and the narrow ring-0 execution prefix now have focused directed checks;
same-level selector-fault delivery and IRET pass their bounded cases.
Outer IRET now delivers and recovers from two bounded invalid-CS cases: a
non-present code selector via #NP(selector) and a system descriptor via
#GP(selector), with handler repair and exact retry/successor checks in both
READY modes. Invalid outer-SS faults, privilege-changing gates and broader
execution remain open. A valid ring-0-to-ring-3 outer IRET reaches and executes
its target in both READY modes.

The pinned 286-specific [flag handler](https://github.com/86Box/86Box/blob/1db9ae4cc910b0b7e6e9b49995910b0cc19747a0/src/cpu/x86_ops_flag_2386.h#L64)
and [IRET handler](https://github.com/86Box/86Box/blob/1db9ae4cc910b0b7e6e9b49995910b0cc19747a0/src/cpu/x86_ops_ret_2386.h#L147)
also corroborate the existing STI shadow and 286 real-mode flag-restoration
sources. Same-level protected IRET and selector-fault gate delivery pass their
bounded ring-0 cases, and a valid outer-level IRET reaches ring 3. Privilege-
changing event delivery remains open. The disabled POPF shadow experiment in
that artifact is not executable semantics and must not be treated as evidence
for an extra POPF INTR shadow.
