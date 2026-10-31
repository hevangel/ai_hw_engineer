# Architectural segment-cache integration contract

Status: explicit segment-cache state and the first protected ring-0 descriptor
loads are integrated. Direct far JMP commits CS/IP/cache through the code-load
engine; MOV-to-DS/ES/SS commits through the segment-load engine. The focused
regression checks exact cache values and cached-base references. Protected
gate delivery, IRET, broader descriptor classes and the full completion ledger
remain open.

Primary source: Intel 210498-005 sections 6.3, 7.2/7.4 and 10.4/10.4.2,
linked in the [README](../README.md). Independent transition evidence is pinned
[MAME i286.cpp](https://github.com/mamedev/mame/blob/fa9419ba91017064d30bc340b266620389f5d1c2/src/devices/cpu/i86/i286.cpp#L214)
and the existing pinned PCjs/86Box artifacts. Emulator-internal attributes are
not automatically silicon cache-bit observations.

## Real-mode cache state first

Replace selector-derived ES/SS/DS addressing with explicit cache bases, while
retaining the existing special CS reset base. Store per-segment limit, raw
access attributes and usability alongside visible selectors. Keep debug
packing aligned with ES/CS/SS/DS. Add source-backed reset and atomic-update
properties, and observe cache state in instruction tests rather than testing
only final visible selectors.

Reset bases/limits are the documented 0/FFFF for data/stack and FF0000/FFFF for
CS. Real-mode loads update the visible selector and base (selector<<4); loading
selector zero remains usable. Every load path must commit the corresponding
cache at the same architectural boundary: MOV Sreg, POP Sreg, LDS/LES, far
JMP/CALL/RET/IRET, software/fault/hardware event entry and reset. A same-selector
real far transfer still replaces the high-reset CS base. Preserve old cache
metadata during operand reads, stack writes and stalled instructions.

Assumption A14 is recorded in RTL and the global ledger for the real-mode
cache prelude: use raw reset attributes 93 and usable caches for all four roles,
following pinned MAME's reset. Intel 10.4 lists bases/limits but does not fully
specify these raw cache attributes. MAME's real data reload changes only
selector/base, while its real CS transfer sets 93/FFFF. PCjs likewise preserves
other real-load attributes. 86Box uses different internal real-mode encodings;
that is not independent agreement about the raw silicon byte. Native evidence
and historical protected-transition validation remain sign-off requirements.
LMSW now sets sticky PE, and the ring-0 fixture checks the retained-cache
prelude and subsequent validated CS/DS/ES/SS commits. Paths outside this
supported slice must remain visible and must not fall through to real-mode
selector-times-sixteen behavior.

The [cache-bank reference frontend](cached_reference.md) implements explicit
role selection, ordinary access checking and the narrow retained-CS fetch path.
Core memory/fetch routing and the trusted-CS lifecycle are connected and
exercised by the ring-0 fixture. Whole-instruction checks for broader stack,
string, gate and return paths remain open.

## Retained cache state across PE entry

Setting PE must not fetch descriptors, synthesize CS.base from the selector,
discard usable inherited data caches because their visible selector is zero,
or reinterpret an old real CS as a newly validated protected code descriptor.
Intel 10.4.2 prescribes an intra-segment JMP after setting PE, and its Appendix
A example says CPL is 0 while CS still addresses the prior real-mode physical
code. The focused fixture uses inherited `F000:0100` (RPL 0), retains its
real-mode CS base/limit for this JMP, and reloads CS only with the following
protected far JMP. It does not infer behavior for nonzero inherited RPL.

Pinned MAME initializes CS attributes to 93 (data-like) but its
[actual fetch path](https://github.com/mamedev/mame/blob/fa9419ba91017064d30bc340b266620389f5d1c2/src/devices/cpu/i86/i286.cpp#L1040)
checks the CS limit rather than re-running descriptor executable-type checks.
Do not fabricate a raw 9B cache just to satisfy the ordinary access checker's
execute input. Retained real CS needs an explicit trusted-role/range path until
a validated protected CS load, while CS overrides still use the retained raw
read/write attributes. Protected descriptor loads must still reject data as
new CS. The source-derived transition and exact fetch addresses are recorded
in the [focused fixture](../tb/protected_mode_fixture.h). Its Task 3 prefix now
executes through PE entry, direct far CS load, MOV-to-DS/ES/SS and in-bounds
memory operations. The directed regression checks exact descriptor reads,
accessed writes, caches and PC. The remaining #GP delivery and IRET path is a
separate integration gate.

CPL must be explicit, distinct from descriptor DPL and requested RPL. Normal
protected transfers normalize visible CS RPL to the resulting CPL; conforming
code does not make CPL equal its descriptor DPL. Entry from real CS values
with nonzero low bits remains outside this slice: MAME/PCjs keep separate
cached privilege state, while the primary describes CPL via CS low bits in
ordinary protected execution. Do not generalize A17 to that case; obtain native
or independently recovered transition evidence before final sign-off.

## Transaction and architectural commit

Integrate descriptor-engine bus ownership only at idle core boundaries; never
preempt a held request. Snapshot complete instruction context before delegating
MOV/POP/LDS/LES or CS loads. On a fault retain visible registers, cache fields,
SP and destination GPRs as required by the instruction's restart contract.
Successful completion commits visible selector, hidden cache and associated
instruction effects together. Null DS/ES commits an unusable cache only in
protected mode. SS shadow begins only on a successful SS commit.

For ordinary CS candidates, commit CS/IP/CPL and CALL frame effects only at
their documented boundary. A deferred system descriptor must enter its gate/
TSS resolver; it is neither an ordinary success nor an automatic #GP. The
caller must supply complete stack checks in primary fault-priority order.
Descriptor accessed writes are not architectural CS/segment commits.

## Remaining access and delivery work

Connect cached limits/permissions to every planned fetch, ModR/M/moffs,
stack/procedure/frame, string/REP, vector/gate and system-register operand path.
Do not infer the segment role from a physical address: cache bases can alias.
Carry segment identity and offset/span explicitly through the core memory
sequencer; I/O and descriptor-table traffic have distinct permission paths.
Whole-instruction stack checks, allocation/wrap, multi-access priority and
restart cannot be replaced by per-byte bus checks after writes have started.

The current integration is limited to a documented ring-0 transition, ordinary
GDT descriptors, supported far JMP and MOV segment loads, cached references,
and a visible protected fault packet. Add protected system/CLI/STI/HLT/I/O/flags
privileges, LDTR/TR state, additional transfers and precise gate/error-code
delivery with nested faults/shutdown. Do not route protected faults through
real-mode IVT frames or use selector-times-sixteen addresses. Required
historical protected software, native-bus/80287/UVM, independent instruction
traces and review gates remain part of the full goal.
