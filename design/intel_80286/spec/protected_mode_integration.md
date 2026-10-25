# First protected-mode integration slice: ring 0 with a GDT

Status: the Task 4 bounded ring-0 path is implemented in the recovered CPU
source. The source-controlled `tb/protected_mode_replay.cpp`, built by
`scripts/run_protected_mode_replay.sh`, now reproduces the core path in both
wait modes: a restartable DS word-limit #GP goes through a same-level IDT
interrupt gate, writes the exact four-word protected frame, loads a wider DS
in the handler, returns through IRET, and retries the faulting instruction at
its exact PC. The test checks retired PCs and successors, descriptor/gate
byte reads, accessed-byte writes, the fault packet/frame, handler state, the
denied operand request, retry data, and the final HLT checkpoint. Its captured
log is ignored at `work/protected_mode_replay_results/replay.log`; the
adjacent `build_manifest.json` records source hashes, tool versions and binary
identity. The regression also asserts reset after the handler code-descriptor
read, first protected frame byte and IRET CS accessed-byte write, then checks
that execution restarts through the exact protected recovery path. The
accepted frame byte remains in external memory across reset.

The older full development runner also passed this path on the original
checkout; its binary was replayed here with a manifest matching all 14 RTL
sources. The old runner's C++ sources are incomplete in this recovery, so that
replay is not a source-audited rebuild. The full prior reset-cut matrix and
four strict mutation checks are not yet reproduced by the new focused test.

Task 3 retry44's matching BMC and induction passed, but its cover stopped
before `PASS` with 44 witnesses while checking step 41. Task 4 retry1 depth-24
BMC passed, while induction exposed an invariant that omitted protected gate
and frame bus returns. Retry2 BMC passed in 26m13s, but induction then found a
false fixed-address assertion: it ignored the accepted-byte offset and a
request cancelled by reset. The property was corrected to track
`memory_index` with reset and active-request guards. The retry3 depth-24 BMC
using that corrected property passed in 30m26s with no counterexample; its
evidence is now in this worktree at
`work/task4_protected_event_retry3/intel_80286_bmc`. The standard depth-12
prove passed its base case but k-induction failed at property line 43 from a
non-reset event-gate state with PE clear. ABC PDR proved the corresponding
assertion output 252 in frame 7; the full PDR assertion set remains active.
The 21-file formal RTL/property source audit passes across BMC, prove, PDR and
cover snapshots. The depth-64 cover run is active. The slice is limited to one privilege
level, the
specified vector-13 gate and ordinary GDT descriptors; it does not complete
the 80286 protected-mode architecture.

The primary source is Intel 210498-005: descriptor tables and cached segment
state in sections 6.3, 6.5 and 6.6; descriptor access and privilege rules in
sections 7.3–7.5; interrupt gates and exception frames in sections 9.1–9.6;
sticky PE in section 10.2.2; and initialization order in section 10.4.2. The
manual is linked from the [chip README](../README.md). The local OCR mirror
used during review is an ignored workspace cache; durable references here use
manual sections and pages.
This contract also builds on the [segment-load checker](segment_load_check.md),
[segment-load transaction](segment_load_transaction.md),
[CS checker](code_load_check.md), [CS transaction](code_load_transaction.md),
[cached-access checker](access_check.md),
[core reference routing](reference_integration.md), and
[cache integration](cache_integration.md).

## Included behavior

The first end-to-end slice must execute one ring-0 program using GDT entries
for ordinary non-conforming code and writable data/stack segments. The LDTR is
null; no selector uses the LDT. The protected CS, DS, ES and SS selectors all
refer to present GDT entries with DPL 0. Accessed-bit writes must be possible,
so the table storage used by this fixture is writable. Interrupts stay disabled
outside the controlled fault test.

The supported path is:

1. In real mode, load GDTR and IDTR with the fixture tables. The IDT provides a
   present ring-0 interrupt gate for vector 13 whose destination is ordinary
   GDT code. Establish ring-0 code/data/stack descriptors and the protected
   instruction/data bytes before setting PE.
2. Set PE with LMSW. Preserve the inherited real-mode CS cache and perform the
   intra-segment JMP that Intel section 10.4.2 requires to clear the processor
   queues. Do not derive a new CS base from the visible selector at this step.
3. Use a direct far JMP to an ordinary, non-conforming DPL-0 GDT code
   descriptor. The existing CS transaction must read and validate the whole
   descriptor, complete its accessed-byte update, and only then commit CS cache,
   visible CS and target IP together.
4. Load DS, ES and SS from ordinary DPL-0 GDT data descriptors. Each successful
   load commits the visible selector and its complete hidden cache only after
   validation and the accessed-byte write. A failed load leaves the old
   selector/cache intact. This slice uses no null data selector.
5. Execute near control flow and byte/word MOV data references through the
   committed caches. This demonstrates that a selector is a table index and
   that physical addresses come from the cached base plus the checked offset,
   not selector-times-sixteen arithmetic.
6. Trigger one restartable #GP(0) by reading a word through DS whose complete
   span exceeds the cached segment limit. The faulting instruction retires
   neither its destination register nor its flags and issues no operand-bus
   request. Deliver vector 13 through the configured same-level interrupt
   gate, record the exact faulting CS:IP, and push the error code after the
   return address as Intel specifies.
7. In the handler, discard the error-code word, load a wider present DPL-0 DS
   descriptor, and execute IRET. The replay must resume at the exact first byte
   of the faulting instruction, complete the load, and reach its exact checked
   successor. Use an instruction without a read-only write/RMW side effect so
   this test stays within Intel's restartable #GP cases.

The manual identifies #GP as restartable except for specified writes into
read-only segments, defines error code zero for limit violations, and says the
saved return address normally points to the failing instruction including
prefixes (sections 9.6 and 9.6.7). An interrupt gate clears live IF; an
exception's access to the IDT is not rejected by the gate's DPL check. The
chosen same-level ring-0 handler avoids privilege-changing stack selection.
Do not generalize these facts into support for other vectors, gate types or
privilege levels.

## Resolved source decisions for the first slice

Intel 210498-005 section 10.4.2 (page 10-5) prescribes setting PE, then an
intra-segment JMP to clear the prefetch queue. Its Appendix A initialization
example states that after this sequence CPL is 0 and CS still addresses the
old real-mode physical code location. Section 7.3.2 defines CPL from CS bits
1:0. The fixture therefore enters from `F000:0100` with RPL 0, retains the
real-mode CS base/limit through `LMSW` and `JMP $+2`, then uses the direct far
JMP to load selector 0008 and its validated protected cache. Nonzero inherited
CS RPL values are outside this slice. PE remains set until reset, per section
10.2.2 and table 10-1.

The general protected-mode initialization sequence in section 10.4.2 includes
a valid TSS for the initial task. This fixture uses only a same-level ring-0
interrupt gate. Section 9.4 requires a TSS stack only when the gate changes
privilege level; it does not select a new stack at CPL 0. The pinned 86Box
286 path corroborates that same-level gate entry and an IRET with NT clear do
not read TR. See the pinned [86Box protected interrupt path](https://github.com/86Box/86Box/blob/1db9ae4cc910b0b7e6e9b49995910b0cc19747a0/src/cpu/x86seg.c#L1729)
and [protected IRET path](https://github.com/86Box/86Box/blob/1db9ae4cc910b0b7e6e9b49995910b0cc19747a0/src/cpu/x86seg.c#L2076),
selected for its explicit 286 behavior. **ASSUMPTION A18:** the first slice may leave TR uninitialized
because it performs no task switch or privilege-changing transfer. This is a
bounded inference from the primary gate rules and independent emulator code;
it does not relax the full system-initialization or task-switch requirements.

For the segment-limit read at `DS:000F`, the fault packet is vector 13,
error-code-present, error value 0000, external-event bit clear, and restartable.
The saved CS:IP points to the first byte of the faulting instruction, including
any prefixes. Intel sections 7.4.1 and 9.6.7 require the access check before
the reference begins and define this limit violation as #GP(0). For an
exception, the IDT gate DPL check is ignored (section 9.4). The ring-0 target
has DPL 0, so entry uses the current SS:SP. The 16-bit stack layout from low
to high addresses at handler entry is error code, return IP, return CS, saved
FLAGS. The error code is pushed last; the handler removes its word before
IRET. IRET then reads and validates IP, CS and FLAGS for a same-level return.

Intel specifies architectural results but not atomicity for this project's
byte bus. **ASSUMPTION A19:** the functional model reads and validates the IDT
gate and target CS descriptor, including its accessed-byte update, then
prechecks the complete event frame before its first stack write. It publishes
CS:IP/FLAGS/SP only after all frame writes are accepted, and reset cancels
pending state. A write already accepted by external memory cannot be rolled
back. This pins functional transaction order for the fixture; native bus
ordering and partial-delivery escalation remain out of scope.

The externally sourced program bytes and expected table, accessed-byte,
frame, memory and PC trace are frozen in the
[protected-mode test fixture](../tb/protected_mode_fixture.h). The primary
expectations use Intel sections 7.4.1, 9.4, 9.6.7 and 10.4.2. The 286-specific
86Box source at commit `1db9ae4cc910b0b7e6e9b49995910b0cc19747a0` is
independent corroboration for same-level gate/IRET behavior, not silicon or
cycle evidence.

## Fault, commit and bus ownership prerequisites

The core captures a fault/commit packet with the vector, error-code
validity/value, saved instruction CS:IP, restart classification and pending
effects. It distinguishes protected events from real-mode IVT entry. For the
scoped vector-13 case, it reads and validates the IDT gate, validates the
ordinary target code descriptor, prechecks the complete eight-byte stack span,
and only then begins frame writes. Handler CS/cache, IP, FLAGS and SP publish
after every frame byte is accepted. Protected IRET validates the same-level
return CS and offset before atomically restoring the saved tuple. Invalid or
unsupported delivery/return conditions stop visibly; no protected failure is
routed through the real-mode IVT path, and nested-fault escalation is outside
this slice.

For this exact read fault, before event entry CS/DS/SS caches, AX, FLAGS and
SP remain at their pre-instruction values; the denied DS span produces no
operand transaction. After the complete frame is accepted, handler entry
publishes CS=0008, IP=0300, SP=0078 and live FLAGS=0403 together. The saved
frame contains FLAGS=0603, CS=0008, IP=0221 and error=0000. The handler's
successful DS load commits selector 0010 and its cache after its accessed
write. IRET validates the return CS and the complete three-word return state
before publishing CS:IP=0008:0221, SP=0080 and FLAGS=0603 together. It does
not restore DS; the handler's wider DS cache remains active for the retry.
For functional bus ordering, the IDT read, target-CS descriptor read and its
accessed write complete before the eight frame-byte writes; A19 records this
project-level order rather than claiming Intel specifies bus timing.

Run the cached-access decision on the full segment role, offset, access kind
and byte span before issuing the first operand request. For the included
read-limit fault, denial must suppress the data request and preserve the
faulting instruction's register/flag state. This is an instruction-level
precheck requirement; a late per-byte check after a read or write has started
does not meet it. Apply the same whole-span check to the ES destination of
INS/INSW before issuing the input-port read. **ASSUMPTION A20:** this functional
bus orders destination validation before input consumption because an I/O
read may have an external side effect; native 286 port-side-effect timing for
a segment-limit fault remains unverified. The protected DS limit test checks
denial without an operand request, and its vector-13 gate path is implemented
as described above. The source-controlled protected replay now covers INSB
beyond ES's limit, INSW straddling it, INSW at offset FFFF, and REP INSW
faults on final and nonfinal elements, in both wait modes. Full protected
fault delivery and independent validation of A20 remain open.

### Native INS fault state and handler repair

Use the corrected post-C2 restart behavior described by Intel's
[15 October 1984 REP restartability memo](https://docs.pcjs.org/manuals/intel/80286/80286_B2_B3_REP-1984-10-15.pdf)
and the INS repair rules on page 14 of its
[LOADALL technical memo](https://docs.pcjs.org/manuals/intel/80286/80286_LOADALL.pdf).
For an INS destination protection fault, DI has advanced by the element delta
(including 16-bit wrap). The handler reverses that update before retrying.
For repeated INS destination faults, the handler also adds two to CX; the
fault-time CX is the count remaining before the failed element minus two,
modulo 65536. Thus a fault on the last element leaves FFFF in the corrected
target, while B2/B3/C2's documented erratum leaves 0000. This implementation
does not select those earlier stepping errata. The saved PC points to the
instruction's first prefix, and completed transfers remain committed.

The fixture checks CX=FFFF on the last-element fault and CX=0000 when two
elements remain. Its handler widens ES, reverses the failed DI update, repairs
CX for REP, and IRETs to the exact prefix. The FFFF-offset word case explicitly
relocates DI after checking its wrapped fault state; even a 64K ES cannot
make a wrapping word valid. These register rules do not establish native
port consumption timing: A20 still suppresses the input read on a denied
destination in this functional interface. Audit the other string instructions
against the same Intel repair notes before claiming their fault semantics.

The CPU owns the functional bus while completing an instruction transaction.
