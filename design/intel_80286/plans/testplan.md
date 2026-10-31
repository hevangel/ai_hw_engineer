# Intel 80286 verification plan

## Nested protected #GP to #DF vector selection — 2026-10-27

The `--iopl-controls` regression now checks one nested-fault path in both
READY modes: a CPL3 HLT raises #GP, then the IDT limit makes lookup of the
vector-13 gate raise another #GP while the vector-8 gate remains addressable.
The test requires a vector-8 packet with a null error code, original saved
CS:IP:FLAGS:SP, no instruction retirement, and reads only the eight bytes of
the vector-8 gate. The fixture leaves an all-zero, invalid descriptor because
the current gate validator accepts only interrupt/trap gates. This verifies
vector selection only, not task-gate entry, task switching, #DF handler entry
or shutdown. Test-first failed before the RTL change; both READY cases,
the complete bootstrap and release preflight pass afterward. See the
[checkpoint report](../report/2026-10-27-double-fault-escalation.md).
The connected-core property set asserts the selected vector, null error code
and preserved context, with a matching reachability cover. This property
snapshot has not yet run through connected-core formal.

## LLDT/LTR privilege matrix — 2026-10-27

The `--selector-exec` regression now enters CPL1, CPL2 and CPL3 and checks
LLDT/LTR register and memory forms in both READY modes (24 cases). Each case
requires restartable #GP(0) before retirement or operand/descriptor/TSS
traffic, checks exact exception frame and preserved LDTR/TR, then repairs the
frame in a same-level handler and IRETs to the exact successor. The full
default bootstrap and release preflight pass on the recorded build. See the
[focused report](../report/2026-10-27-lldt-ltr-privilege.md) and
[selector contract](../spec/selector_execution.md).

## Protected system-instruction privilege — 2026-10-27

The `--iopl-controls` regression now passes 480 scenarios across both READY
modes. Its 120 new denied cases cover CPL 1–3, IOPL 0–3, CLTS, LMSW AX,
LMSW [0010], LGDT [0010] and LIDT [0010], with immediate and stalled READY.
Each case checks restartable #GP(0), exact saved CS:IP:FLAGS:SP, no retirement,
unchanged architectural state and no denied memory operand read. Forty ring-0
controls cover those five forms across all IOPL values and both READY modes,
including exact operand widths/data and successors. The complete matrix also
retains the previous 320 IOPL/IF/HLT scenarios. See the
[system-register contract](../spec/system_register_execution.md#protected-system-instruction-privilege-checks)
and [checkpoint report](../report/2026-10-27-system-instruction-privilege.md).
The full bootstrap and release preflight pass; connected-core formal work has
not evaluated this RTL snapshot.

## Previous protected IOPL and HLT privilege checkpoint — 2026-10-27

See the [IOPL contract](../spec/iopl_control.md) and
[focused result](../report/2026-10-27-iopl-controls.md). The current directed
At this checkpoint, the suite ran all eight immediate/DX byte/word `IN`/`OUT` forms for every CPL and
IOPL pair, allowed and denied REP INS/OUTS, allowed and denied CLI/STI,
CPL-0/CPL-3 POPF/IRET flag restoration, and protected HLT at every CPL/IOPL
pair. All 320 scenarios run with immediate and stalled READY policies. It
verifies restartable `#GP(0)`, saved state, exact successors, no denied port
or operand transfer, no retirement, and the IOPL/IF result; protected HLT is
allowed only at CPL 0. See the [IOPL contract](../spec/iopl_control.md),
[HLT privilege contract](../spec/hlt_privilege.md), and
[combined result](../report/2026-10-27-hlt-privilege.md). The full default
bootstrap and release preflight pass on the recorded RTL snapshot.
Connected-core formal results do not yet cover that snapshot; see the
[live status](../../../plans/286/STATUS.md).

## Evidence cutoff (2026-10-21)

The #UD/TEST-alias vector, software, physical-arithmetic and 36-task formal
results below describe the earlier source snapshot. The saved follow-up real-mode
protection run records 20 segment-boundary vector-13 cases, two overlength cases
and two IDTR-limit vector-8 cases; its physical replay records 52 Harris vector-13
captures in 104 stalled/unstalled runs. The owner reports restored properties
and a passing recovery k-induction proof, with BMC, cover and full source audit
still pending. These logs do not demonstrate protected-mode execution.

For quick directed development feedback, `scripts/run_development.sh` builds
and runs the #UD and available protection-vector tests. Release verification
continues through the formal-first `scripts/run_all.sh`; `run_formal.sh` writes
each invocation to a fresh `work/formal_runs/run.*` directory (or the explicitly
selected `FORMAL_WORK_DIR`).

## Independent instruction comparison

scripts/generate_vectors.py uses pinned Unicorn 2.1.4, not an RTL-derived ISS.
Every instruction comparison checks its exact source PC/opcode, actual next
CS:IP, all eight registers, segment registers and defined flag bits. A second
instruction is executed after branch tests to check the actual landing.
There is no padding to absorb unknown PC targets. Results/seed/hash are written
to work/vectors/manifest.json. The suite alternates immediate and stalled buses.

Coverage: every register alias/direction for arithmetic, MOV, TEST and XCHG;
accumulator and 80/81/83 immediate forms; ADC/SBB carry and arithmetic edges;
INC/DEC carry preservation; NOT/NEG; CBW/CWD; segment-register moves; every
SAHF input and low LAHF flag image; all 256 count bytes for each documented
shift/rotate operation, both widths and immediate/CL sources; one-bit forms;
every Jcc condition for all five-input-flag combinations with forward, zero
and backward displacement; LOOP/LOOPE/LOOPNE/JCXZ boundary counts.

The memory extension adds all address modes and segment overrides for memory
ALU/MOV/TEST/XCHG/unary/shift operations, immediate stores, moffs, LEA, LES/LDS,
stack operands, near direct/indirect calls/returns/jumps, and byte/word I/O.
Every step checks exact fetched byte addresses and ordered data transactions
(address, data, read/write and I/O space), including writes of unchanged values.
The earlier #UD/TEST-alias source snapshot passed 99,650 cases and 1,715,162
states and rejected truncated cases (`work/undefined_final_vectors.log`). It
does not verify the later protection-fault changes.

Undefined flags and LAHF reserved bits are masked according to Intel, and no
later expected branch depends on an undefined output. Large-count logical-shift
CF is checked separately against Intel's 286 repeated-shift description because
modern Unicorn cannot establish that 286-specific contract.

## Directed safety and historical software

- Reset at FFFFF0 with the documented hidden CS base; near retention and far
  reload even for the same visible selector; addresses above one megabyte.
- HLT retires once. Valid but unsupported instructions retain a persistent
  development stop; source-classified invalid encodings deliver real-mode #UD
  with the exact restart PC and exception frame instead.
- The 256 legacy group/segment rejection cases still pass in the current
  directed simulation. Source-backed invalid cases now take vector 6; the
  undocumented shift `/6` cases remain development stops until independently
  classified. Old tests that rejected all memory operands were replaced by
  independent memory-address/data-side-effect coverage.
- Real-mode #UD cases cover Intel's explicit `64h` and `0F FF` examples,
  prefix-preserving restart, ARPL and selected system families invalid in real
  mode, invalid register/opcode-extension and register-for-memory encodings.
  Across both ready policies, 32 invalid-instruction cases check vector 6, the
  original prefixed CS:IP, no error code, ten exact IVT/frame transfers, no
  retirement, unchanged GPRs except SP, saved/live FLAGS behavior, and TF/IF
  priority. Two more cases repair the byte in the handler, IRET to the exact
  fault PC, execute NOP and INC BX, then hit the exact HLT successor. Two
  relocated-IDTR cases bring the directed total to 36. In addition, 71
  cycle-by-cycle #UD reset cuts passed, each replaying the actual handler, IRET
  and exact HLT successor, in the earlier source snapshot
  (`work/undefined_final_sim.log`). The saved later protection run is
  `work/protection_initial_sim.log`; counts and current formal status are listed
  in the evidence cutoff above.
- Pinned Harris F6.1/F7.1 physical records provide the external F6/F7 `/1`
  classification: 5,000 records per opcode, zero vector-6 events, and all
  9,507 normal records with operand bytes in the snapshot match TEST-defined
  flags. F7.1 additionally has 52 vector-13 records. The current adapter
  replays 1,254 F6.1 and 1,256 F7.1 register records against the changed RTL;
  3,746 F6 and 3,744 F7 memory records remain outside the adapter. See the
  [capture analysis](../work/undefined_hardware/analysis.log).
- Reset at 100 cycle cut points, including partially decoded and multi-cycle
  shift states, then replay to exact final state.
- Reset at 64 iterative-division cut points and after every accepted byte of
  PUSHA/event-frame writes. Accepted external data survives; incomplete
  architectural updates and event pulses are cancelled; exact reset replay
  cannot execute an old continuation.
- 4,096 Intel-derived shift-count/carry cases: all count bytes, both widths,
  both logical directions and four operand patterns.
- Byte and ModR/M/immediate segment-boundary diagnostics; no cross-limit fetch.
- Word/dword operand-limit diagnostics before any data access; LEA at FFFF
  without a data access; hidden reset-CS override above one megabyte.
- The 286 ten-byte instruction limit; nine segment prefixes plus NOP retire,
  while a tenth prefix is rejected before fetching an eleventh byte.
- Reset between the two accepted bytes of a word write preserves accepted
  external data but does not commit pending flags or registers.
- Intel B-86 real-mode POPF preserves NT/IOPL, checked independently of Unicorn.
- Multiply/divide signed and unsigned edges, register aliases, byte/word memory,
  immediate IMUL, every ENTER nesting byte, PUSHA/POPA and real-mode far transfers.
  Far programs sample actual next execution with the defective Unicorn read
  hook disabled; Intel contracts supply pointer/frame reads. PUSHA callbacks
  compare exact transaction multisets; directed tests enforce Intel push order.
- Intel-derived INT3/INT21/INTO and divide-error frames, prefixed instruction
  restart, unchanged divide operands on faults, handler entry and exact IRET
  landing. Same-selector IRET reload is tested from the reset CS cache.
- BOUND signed endpoints across register/address/segment combinations, #BR
  restart including prefixes and reversed ranges, four-byte limit diagnostics;
  all 256 XLAT indices, every segment override, offset wrap and reset-CS cache.
- String byte/word elements and documented REP forms, both DF directions,
  segment overrides, overlap, pointer wrap, 0/1/2/3/17/65535 counts and
  comparison first/middle/last exits. REP oracle callbacks aggregate until the
  actual successor executes; externally sourced INS dummy probes are validated
  and excluded. Directed tests check zero-count no-access, partial-limit progress,
  INS pre-access limits and reset after every MOVSW transfer byte.
- Adjustment AL/AF/CF space and AH edges, every AAD base, AAM nonzero bases,
  complete AL space for decimal AAM and 40,000 packed-BCD ADC/SBB chains,
  plus unpacked arithmetic chains. Directed cases check 286 whole-AX
  carry/borrow, DAS low borrow, AAM final-AL flags and prefixed zero-base #DE.
- Unaccepted data varies while ready is low; request/address remain stable.
- Unmodified, integrity-checked original IBM AT BIOS executes the exact flags,
  register, CMOS bit-walk and complete ROM-checksum path to F000:0225.
  All 196,846 instruction states, fetched bytes and memory/I/O effects are
  independently checked. The zero RAM/simple I/O fixture is not a PIT or full
  motherboard, so timer tests, full POST and boot remain incomplete. The trace
  generator must reach this checkpoint; an earlier unsupported opcode fails.
- Original IBM AT hex-output helper at F000:0543 for nibbles 0..15, including
  both original DAA instructions, DS/ES display writes, pointer increments and
  RET. A separate high-reset bootstrap and RAM return frame enter the unchanged
  complete low BIOS image; input and post-execution ROM integrity are checked.
  Sixteen cases/464 states are mandatory in run_software.sh, alongside the
  unchanged original-reset regression. This is a routine fixture, not POST.

## Proofs and test sensitivity

See formal_plan.md for exhaustive datapath contracts and core safety properties.
Strict lint and Yosys synthesis/check are mandatory in run_all.sh.
Optional scripts/run_mutations.py builds thirteen temporary RTL mutants: missing
ADC carry, inverted branch condition, four-bit shift count, incorrect IDIV
remainder sign, excluded BOUND lower endpoint, sign-extended XLAT index,
zero-count REP access, previous-ZF repeat termination, reversed string direction,
wrong DAA high threshold, suppressed AAS borrow, uncleared AAD AH and AAM
sign from the quotient. Each must compile
and then fail an independent oracle comparison; a build failure is not a detected
semantic mutation. This sensitivity check is not a completeness guarantee.

## Standalone event-controller extension

`scripts/run_sim.sh` also runs `scripts/run_event_control.sh`. Intel 210498-005
sections 9.2/9.5 and explicit functional abstraction A8 define these transaction
contracts; this test is not an instruction oracle. The 8,000 checks exercise
all 256 acknowledged vectors with deterministic randomized stalls, priority,
IF masking, all-event inhibition, held NMI, one-entry/coalesced pending NMI,
completed IRET, NMI arriving during INTR acknowledgement, vector stability and
reset cancellation in acknowledgement/delivery phases. No CPU integration or
historical hardware-interrupt result is inferred from this standalone test.

`python3 scripts/run_event_mutations.py` builds seven faulty controllers and
requires a transaction assertion failure after a successful build. Mutations
cover repeated held NMI, IF incorrectly masking NMI, discarded blocked NMI,
early NMI unblocking, acknowledgement without ready, drifting vector and
single-step priority. Only unused-signal warnings caused by the intentional
mutations are suppressed in mutant builds; baseline builds use strict -Wall.

## Integrated INTR/NMI and historical timer handler

The default simulation also runs `--interrupts` contracts for every INTR vector,
including maskable vector 2, exact frames/IRET successors, IF masking, held vector
acknowledgements, STI/SS inhibition, prefix preservation, NMI priority, held and
remembered NMI, both HLT wake paths and a CS-overridden REP MOVSW interrupted
during its first transfer. That REP must complete exactly one element before
entry, save the original F3/CS prefix PC, preserve CX/SI/DI and perform each
destination byte write exactly once across IRET/restart. Twelve reset cuts
cover unaccepted acknowledgement plus all ten IVT/frame transfers and entry
before the first such transfer; accepted external writes survive reset.
Expectations use Intel 210498-005 contracts and the explicitly open A9 policy.

`scripts/run_irq_mutations.py` requires eight compiled faulty CPU copies to fail:
ignored IF, missing STI or SS shadows, IRET not releasing NMI, skipped REP
prefix, HLT re-execution, synthetic hardware-event retirement and no intermediate
REP recognition. Only intentional unused-signal warnings are suppressed in
mutant builds. These checks supplement the thirteen independent instruction
mutants and seven standalone controller mutants.

`run_software.sh` additionally executes `--bios-irq` against the integrity-checked
original IBM AT ROM. A separate high-reset/RAM bootstrap initializes IVT, BDA,
registers and a valid stack, enables IF, then receives hardware INTR vector 8.
The complete unchanged low ROM executes from its original F000:FEA5 compatibility
entry through the timer ISR, original DS helper, nested INT 1C to original
F000:FF53 IRET, PIC acknowledgement and final IRET to the exact RAM successor.
Eight cases cover tick values 00000000, 0000FFFF, 0017FFFF and 001800AF with
motor countdown 1/2. Literal expected paths come from original ROM disassembly;
236 actual handler instruction addresses/successors, final context, timer and
motor bytes, midnight indication, PIC/motor port outputs and unchanged ROM
bytes are checked. No ROM patch, opcode emulation, skipped handler instruction
or padding is used. This is an original interrupt-driven software regression;
it does not provide a full per-instruction register oracle, native PIT timing,
full POST or all A9 shadow-edge evidence.

## Instruction-start TF and vector 1

The default simulation and `--debug` mode execute real POPF, debugger-stub stack
edits and IRET instructions. Expectations follow Intel 9.7.1 and the pinned
external artifacts in A10. They check that newly enabled TF waits for the next
instruction, clearing TF in a stepped POPF does not erase its sampled request,
and IRET restoration steps the next program opcode. Tests also require a
prefixed successor after MOV SS, immediate STI single-step despite its INTR
shadow, HLT successor/wake without duplicate retirement, and no second debug
entry from software INT or a nonretired divide fault.

A simultaneous NMI must wait behind #1 and then enter before the first debugger
opcode; exact nested CS:IP frames and subsequent instructions are checked.
Zero-count REP traps at fallthrough with unchanged pointers. A nonzero CS-override
REP MOVSW completes one element, traps with the first prefix IP, and resumes
the remaining two after the debugger clears saved TF. The six destination-byte
writes must occur exactly once. No opcode hooks, skipped instructions or padding
provide the expected landing. These are source-backed directed contracts,
not a claim of independent native-286/debugger-software sign-off.

`scripts/run_debug_mutations.py` compiles four faulty copies and requires the
debug contracts to reject post-instruction TF sampling, stepping a software INT
handler, missing partial-REP stepping and a lost HLT retirement boundary.
Only unused-signal warnings due to intentional mutations are suppressed.

## Protected segment-load checker component

`run_sim.sh` also invokes `run_segment_check.sh`. The 16,413 component cases
enumerate every access byte, CPL/RPL pair, DS/ES versus SS and GDT/LDT choices,
plus null/unusable-table/wait states, exact inclusive table ends, metadata byte
order and explicit conforming-code/presence-priority edges. Expected type lists
come from pinned 86Box loadseg_2386; layout comes from pinned PCjs. This checker
is not connected to the CPU and does not execute protected software.

`run_segment_mutations.py` builds six faulty components and requires successful
compilation followed by a contract failure: LDT index zero treated as null,
exclusive table limit, conforming code using data privileges, #NP instead of
#SS for absent stacks, presence before type/privilege, and reversed base bytes.
Only unused-signal warnings caused by intentional mutations are suppressed.

## Descriptor-load transactions

`run_sim.sh` also invokes `run_segment_load.sh`. The 16,414 transaction cases
cover the access/CPL/RPL/target/GDT-LDT matrix using pinned external semantic
type lists, plus null/bounds/LDT-invalid, exact top-table and modulo-24 physical
boundaries. Exact expected bus lists require eight reads followed by the sole
accessed-byte write on success, including an already-set A bit. Poisoned read
data while not ready and hostile caller inputs/starts while busy must have no
effect. Completion packets remain unchanged during new requests and stalls.
Cases run back to back, and reset cuts cover before traffic, every read,
validation, accepted write and a specifically stalled write with an older result.
Accepted external writes survive reset; no stale completion may follow.

`run_segment_load_mutations.py` requires seven compiled copies to fail:
six-byte instead of eight-byte fetch, wrong accessed-byte address, publication
before the write, skipped already-accessed write, live table base, partial
selector exposure on new start, and a write that does not set A. Only unused
signals introduced by intentional mutations have their warnings suppressed.
These are standalone functional-engine checks, not protected historical
software or native bus/LOCK sign-off.

## System-register instruction foundation

`bootstrap.cpp --system` runs 402 cases derived from Intel's instruction
entries, the 16-bit EA table and pinned 86Box 286 group 0F01. It checks all
eight register aliases and MP/EM/TS combinations, ignored upper LMSW bits,
CLTS, both six-byte table formats with varying unused input bytes, all ModR/M
EA classes and segment overrides, FFFA/FFFB operand boundaries, ten-byte and
code limits, invalid groups, sticky PE set/retention behavior and every byte-cut
reset for each table operation. Relocated IDTR tests drive both INT and actual
INTR at the inclusive final valid vector byte and one-byte-short limits.
Retirement and the next executed instruction have exact PCs; bus comparisons
check accepted reads/writes and data, including stalls and accepted-write
persistence across reset.

`run_system_mutations.py` requires nine compiled faults to fail: wrong CLTS bit,
LMSW reserved-bit leakage, ignored PE set, wrong unused store byte, rotated
store words, short table store, wrong LIDT base bytes, ignored IDTR base and an
off-by-one vector limit. The original IBM AT F000:064F table-register self-test
runs four byte-repeated patterns with all original comparison branches,
return and subsequent original HLT. It checks 164 original instruction states
and verifies the complete low ROM image remains unchanged. The routine-entry
fixture is not POST, protected software or an oracle for the unused sixth byte.

## Ordinary protected CS validation

`run_code_check.sh` runs 49,460 cases using the primary manual's enumerated
legal code types and ordered CALL/JMP checks, not a decoder read from RTL.
It enumerates all access bytes, CPL/RPL pairs, CALL/JMP, stack validity and
offsets below/at/above the code limit, plus null/LDT/table/availability edges.
It checks normalized visible CS RPL, raw cache fields and accessed-byte image
only on success, and zero metadata otherwise. System descriptors must defer
to a separate resolver; they cannot become code-cache candidates.

`run_code_check_mutations.py` detects eight compiled defects: data accepted as
code, reversed nonconforming RPL, spurious conforming RPL checks, wrong
absence/type priority, wrong stack/offset priority, missing CS RPL normalization,
system-descriptor acceptance and an exclusive code-limit comparison. Strict
build/lint, unconstrained BMC/prove/cover and synthesis are required. There is
no transaction or architectural CS update yet, so neither this suite nor its
formal reference establishes a complete protected transfer or historical run.

## Ordinary protected CS transactions

`run_code_load.sh` runs 98,330 cases against the primary code-type/check-order
reference plus exact A11/A13 traffic. It combines all rights/CPL/RPL/CALL/stack/
IP relationships with both tables, then checks null/table/physical-wrap edges,
all accepted-byte reset cuts and a deliberately stalled accessed write with
an older result packet. Every live input and start changes while busy; read
data is poisoned while not ready. Compare every accepted read/write, raw
special-descriptor payload, normalized ordinary-code candidate, fault/error
and original request context. Results must retain the old packet until done.

`run_code_load_mutations.py` detects nine compiled faults: six-byte fetch,
wrong accessed address, early publication, writes to a special descriptor,
skipping an already-set A write, live target offset, partial request metadata,
cleared A and corrupted special payload. Only unused signals introduced by
intentional mutants have their warnings suppressed; baseline lint is strict.
Require BMC/prove/cover and synthesis as well. A13 and protected CPU/historical
integration remain open; these tests do not create a CS transfer by themselves.

## Protected cached access decisions

`run_access_check.sh` checks 2,343,936 cases: all type/kind/usability/fault-class
combinations across representative spans, every 16-bit limit at its boundary
and first successor, and seeded arbitrary tuples. Independent type lists and
32-bit interval arithmetic detect end-offset truncation, inclusive expand-down
errors, interpreting conforming code as expand-down, readable-code writes,
execute-only reads, ignored usability and wrong #SS/#GP classification.
Eight compiled mutants must be detected by `run_access_check_mutations.py`.
Only intentional mutant unused signals have warnings suppressed.

BMC/prove/cover use no input constraints. The SBY configuration maps fixed
lookup ROMs to combinational logic before induction; their initialized values
must not become arbitrary memory state in an inductive starting point.
Strict lint and synthesis are required. This unit checks one contiguous
reference; instruction-level stack allocation/wrap, prechecks, fault priority,
inherited real-mode caches and actual protected CPU use require integration.

## Explicit real-mode architectural caches

Every Bench retirement now checks real-cache base/selector coherence, A14 raw
attributes, limits and usability; ticks reject hidden-state changes without
retirement or event commit, including intermediate string elements and bus
stalls. Reset verifies the complete bank and special high CS base. Existing
exact-PC/fetch checks remain, including same-selector far reload and event/IRET.

`bootstrap.cpp --caches` runs 128 cases: MOV/POP for ES/SS/DS and LDS/LES for
their legal targets, eight zero/nonaligned/high selector values, and both ready
modes. It checks source operands use the old cache, subsequent explicit-segment
loads/stores and PUSH/POP use the new base, every byte/data/direction and exact
successor. The main default suite includes it. The full independent/original
software replays also invoke the per-retirement metadata checks.

`run_cache_mutations.py` requires compiled missing ES/SS MOV updates, wrong
POP/LDS/LES words/bases, early metadata publication and wrong A14 attributes
to fail. This phase cannot distinguish a selector-derived address bypass from
an equivalent real cache when both bases coincide; protected-mode independent
bases must be exercised after architectural descriptor loads are connected.
No protected addressing or raw native-attribute sign-off follows from this
real-mode cache suite.

The same focused suite now performs 235 reset cuts: every cycle before the
segment-load retirement, both ready modes and all legal target/form pairs.
Distinct preloaded ES/SS/DS bases expose premature use of the new selector.
Before reset, visible selectors, SP and LDS/LES destination remain unchanged;
the cycle monitor independently checks hidden metadata. Reset clears the bank,
then an exact instruction replay checks source addresses, final selector/base,
SP/destination and the immediate NOP/HLT successors. No instruction padding
absorbs an incorrect landing. `work/cache_reset_sim.log` records the passing
default/component suite with these cases.

## Cache-bank reference frontend

`run_cached_reference.sh` enumerates every raw access byte, role, access kind,
usability/trust pair and twelve complete-span boundaries. It additionally walks
every bit of every cache base, tests byte carries/24-bit wrap and runs 200,000
seeded inputs with unrelated cache fields and alternating aliased bases.
All 397,568 cases compare against independent primary type lists and integer
interval arithmetic, including exact zeroed fault addresses and #SS/#GP(0).
Trusted CS permits only instruction fetch, still requiring usability and a
nonwrapping normal-limit span. CS data and other roles do not inherit that
permission exception. The default simulation invokes this frontend suite.

`run_cached_reference_mutations.py` detects ten compiled defects: wrong base,
limit or permission role; trusting other segments or CS data; ignoring trusted
CS usability/overflow; wrong SS classification; exposing an address on fault;
and losing the physical offset. No lint warning is suppressed in mutant builds.
Parent lifecycle/bus stability, complete instruction prechecks and historical
protected-mode execution still require CPU integration tests.

## Connected CPU reference context

The CPU now routes every segmented operand through a pre-bus validation state
and every fetched byte through a CS execute check. The bench checks reference
address/context coherence on every accepted/stalled transaction, including all
independent and original-software replay. It verifies fetch CS/execute/size 1,
no segmented I/O, legal transaction sizes and immutable held context.

`--references`, also included in the default suite, runs 102 exact-successor
cases with all four physical bases aliased. Expected roles come from each
instruction encoding. Cases distinguish DS, ES/CS/SS overrides, default BP/SS,
RMW reads versus ordinary reads and stores, stack push/pop, segmented six-byte
table-register operands, linear IVT reads, event/IRET frames, MOVS/CMPS/SCAS/
LODS/STOS/INS/OUTS, XLAT and 16-bit I/O port wrap. All pass with both ready
policies. Cache reset enumeration now includes the additional validation cycle
and passes 252 cuts. Six compiled mutants detect wrong role/offset, lost RMW
intent, segmented I/O, DS instruction fetch and ignored store override.

The earlier #UD/TEST-alias replay passed 99,650 cases, 1,715,162 independent
states and the unchanged original BIOS checksum/helper/timer/system-register traces. The
frontend's complete role selections were re-proved and all ten standalone
mutants rerun after the AIG-export fix. The 36-task core proof audit passed for
the #UD/TEST-alias source snapshot; exact-source results are under `work/formal`
and the audit is `work/undefined_canonical_formal_audit.json`. The later
recovery and descriptor/event proof epochs are recorded in `plans/286/STATUS.md`;
the retry44 cover did not reach PASS, and the retry1 Task 4 induction exposed a
missing protected-event continuation in a property. That invariant is fixed;
the matching retry2 depth-24 BMC passed without a counterexample. Induction,
cover and exact-source audit remain.
Real-only metadata checks do not establish
protected permission failures, whole-instruction prechecks or trusted-CS
lifecycle after a protected load; those remain required next tests.

## Protected same-level event and IRET integration

The ring-0 fixture faults on a DS word read that crosses the cached limit,
then enters vector 13 through a GDT-backed same-level IDT gate. It checks the
no-operand fault, exact eight-byte frame, error-code removal, handler DS reload,
IRET retry at the original instruction and exact next HLT. The handler has a
separate code descriptor so a premature CS/cache update is observable. Both
wait modes pass, including reset cuts during gate reads, handler descriptor
reads/accessed writes, partial frame writes, IRET stack/descriptor reads and a
cycle before return commit. The saved focused run is
`work/task4_protected_event_retry1/development.log`.

`python3 scripts/run_protected_event_mutations.py` detects all four required
mutations. Results are saved in
`work/protected_event_mutations_task4/results.json`: wrong saved PC, missing
error code, early handler CS/cache commit and ignored segment-permission
failure. The diagnostics point to the frame write, event transaction count,
partial hidden-base visibility and segmented bus address/context respectively.

Task 3 retry44's exact matching depth-24 BMC and k-induction passed, but its
cover stopped before PASS at step 41 after 44 witnesses. Task 4 retry1's
depth-24 BMC passed, while induction exposed a missing legal protected-event
return; the invariant is corrected. The matching retry2 depth-24 BMC passed
in 26m13s without a counterexample at
`work/task4_protected_event_retry2/intel_80286_bmc`. Matching induction is
running in `work/task4_protected_event_retry2/intel_80286_prove`; cover and
exact-source audit remain. Earlier retry44 and retry1 snapshots are not
current-source evidence. A PASS for the directed fixture alone
does not close the release gate or establish other gate types, privilege
changes, escalation or full protected-mode support.

## Protected outer-level IRET, CALL gate and RETF

The directed `--outer-iret` program reaches ring 3 from the supported ring-0
bootstrap through a real five-word frame. In both READY modes it checks the
whole return-frame span, CS validation before outer SP/SS reads, SS validation,
accessed-byte writes, atomic CS:IP/FLAGS/SS:SP/cache commit, DS/ES invalidation
and the exact HLT successor. No hidden CPL or segment-cache state is seeded.
The current runner build manifest is `work/sim/build_manifest.json`.

The focused `--call-gate` program tests a same-level protected CALL gate,
including ignored supplied offset, target descriptor validation, exact caller
link frame and successor. The `--call-gate-outer` program starts from the
reachable ring-3 state, calls a ring-0 gate, loads SP0:SS0 from the TSS,
validates the new stack, prechecks both stack spans, copies 0, 1 and 31 words,
checks the complete return frame and executes outer RETF with the matching
immediate. It verifies restoration of caller SS:SP and exact ring-3 resumption.
All cases run with READY asserted and stalled.

The `--call-gate-faults` cases cover null selector #GP(0), an out-of-GDT
selector #GP(0098), a present available-TSS descriptor in the gate slot
#GP(0068), an RPL-3 selector to a DPL-0 gate #GP(0068), and an accessible
non-present gate #NP(0068). The null and out-of-limit cases perform no
descriptor read; the other cases reject before target-descriptor lookup. All
verify the exact error frame, unchanged rejected gate descriptor and no
partial CALL-frame write in both READY modes.

The `--call-gate-target-faults` cases use a present DPL-0 gate with five
targets: null, beyond the GDT limit, a present data segment, a present DPL-3
nonconforming code segment from CPL 0, and a non-present code segment. They
expect #GP(0), #GP(00A0), #GP(0010), #GP(0038) and #NP(0098), respectively.
They check that the null and out-of-limit cases do not read a target
descriptor; that the other cases read exactly one; and that all preserve exact
error frames, rejected descriptor bytes, no-TSS-before-validation ordering and
no CALL-frame writes in both READY modes.

The `--call-gate-ldt-target-faults` cases target LDT selector `000C` through a
valid gate. They check #GP(000C) for invalid LDTR, an LDT limit of 7, and a
present data descriptor; a non-present code descriptor must raise #NP(000C).
The first two cases may not read LDT bytes; no case may read the TSS or write a
CALL frame before validation. Exact restartable error frames are checked in
both READY modes.

The `--call-gate-tss-stack-faults` suite adds nine reachable ring-3-to-ring-0
fault cases, each with and without READY stalls: TSS limit below the 286
minimum (#TS(TSS selector)); null, out-of-GDT, wrong-type, RPL-mismatched and
DPL-mismatched SS0 selectors (#TS with the applicable selector); absent SS0
(#SS(SS0 selector)); SP0 underflow (#SS(0)); and insufficient SS0 limit for
the inter-level frame (#SS(0)). It checks exact CALL restart state, exact
error frame on the original ring-3 stack, TSS/SS descriptor read counts and
no writes on the unvalidated ring-0 stack. The short-TSS case must not read
SP0:SS0. `work/callgate_tss_stack_faults_20261026_03/` holds the focused log,
full bootstrap log and matching Verilator manifest. This verifies same-level
fault entry only; task-gate and privilege-changing exception delivery,
repair/IRET and nested-fault escalation remain open.

The `--call-gate-ldt` case loads an LDT and TSS from GDT descriptors, returns
to ring 3 using LDT-backed CS and SS, calls through the LDT gate at selector
`001F`, and verifies the GDT ring-0 target, TSS stack switch, exact outer link,
RETF restoration and ring-3 successor. It runs with READY asserted and stalled.
The Verilator `--build -Wall` runner and full bootstrap pass on the same source.

The expanded `--call-gate-faults` matrix now presents each of the 15 non-call
system descriptor type nibbles and a data descriptor in the gate slot. Each
must produce the documented #GP(selector) before target lookup or CALL-frame
writes. Existing DPL, presence, null/out-of-limit and available-TSS slot cases
remain in the same exact-frame matrix, in both READY modes.

The `--call-gate-retf-faults` suite checks 13 invalid outer-return cases in
both READY modes. It covers null/out-of-limit/wrong-type/privilege-invalid/
non-present saved CS and SS descriptors, exact #GP/#NP/#SS packets and
frames, no modification of the rejected return frame, saved-CS validation
before SS descriptor reads, and saved-SS validation before the return-IP
limit check. A #GP handler repairs a saved SS selector on the inner stack,
returns with IRET, retries RETF and checks restored ring-3 SS:SP and exact
successor execution.

The `--call-gate-ring-levels` suite reaches nonconforming DPL-1 and DPL-2 code
from a ring-3 caller through a DPL-3 gate. It verifies SP1:SS1 and SP2:SS2
selection at their distinct 286 TSS offsets, validation of the selected stack
descriptor before any new-stack write, two copied parameters, exact inter-level
frames and RETF 4 restoration. The four combinations of CPL and READY mode
pass. Exact evidence and the build manifest are in
`work/callgate_ring_levels_conforming_20261026_01/`.

The `--call-gate-conforming` suite reaches DPL-1 conforming code from CPL 3.
It checks that CS retains RPL/CPL 3, caller SS:SP remain active, the ordinary
same-level link is pushed, and no TSS pair read or inter-level parameter copy
occurs even with a nonzero gate parameter count. RETF resumes at the exact
ring-3 HLT in both READY modes. This covers one conforming target case;
additional selector/privilege combinations and stack-boundary cases remain.

## Nonzero-CPL LLDT/LTR privilege faults

`--selector-exec` reaches CPL3 through a validated outer IRET, then exercises
LLDT and LTR with both register and memory selector operands. All four cases
run with READY asserted and stalled. Each must deliver restartable #GP(0)
before retirement, preserve the operand register, and write the exact error
frame for the faulting instruction. The same-level ring-3 handler adjusts the
saved IP by the instruction length, restores AX, discards the error word and
returns through IRET to the exact successor. Memory forms issue no read from
their DS operands; neither form reads the candidate LDT/TSS descriptor or TSS
image, updates the LTR busy byte, or changes LDTR/TR. CPL3 SLDT/STR after IRET
confirm the original LDTR selector 0 and TR selector 0050. The focused and
full bootstrap logs plus the exact Verilator manifest are under
`work/selector_privilege_20261026_02/`; that saved baseline covers CPL3 only.
The current 24-case CPL1–3 extension is recorded in
`work/selector_privilege_cpl_20261027_01/` and the
[updated report](../report/2026-10-27-lldt-ltr-privilege.md). Broader
trusted-instruction behavior remains open.
The IOPL/IF instruction slice is documented separately above.

Privilege-changing interrupt/trap gates pass their directed CPL3-to-ring0
delivery and outer-IRET slice. A further 16-case reachable CPL1/CPL2 software
`INT 13h` matrix checks allowed/denied gate-DPL boundaries through interrupt
and trap gates, the #GP(IDT selector) result, TSS ring-0 stack/frame behavior,
and exact outer-IRET successors in both READY modes. See the
[CPL1/CPL2 event report](../report/2026-10-28-protected-event-ring12.md) and
`spec/protected_privilege_transition.md`. A second 16-case CPL1/CPL2 matrix
checks privileged-LIDT #GP(0) delivery through gate DPL 0 and 3, no operand
read, exact error frame and outer IRET to the instruction successor. The
third, 8-case `--protected-event-ring12-external` matrix asserts external
INTR vector 13 at CPL1/CPL2 through DPL-0 interrupt/trap gates. It checks
boundary sampling after one NOP, the no-error outer frame, TSS stack selection
and access order, IF/TF behavior, preservation of the interrupted stack and
outer IRET to the exact successor under both READY policies. The fourth,
8-case `--protected-event-ring12-nmi` matrix presents NMI vector 2 through
DPL-0 interrupt/trap gates from CPL1/CPL2. It checks that no vector
acknowledge occurs, the exact no-error outer frame is delivered, and NMI
service is blocked in the handler then released on outer IRET, under both
READY policies. Other CPL1/CPL2 exceptions and external vectors, task-gate
delivery and task switching, #TS/#SS handler repair/IRET, nested-fault
escalation and complete
vector/error-code coverage remain open. The CALL-gate TSS/SS0 fault slice does
not establish those mechanisms.

## Physical-Harris-286 capture replay

The immutable SingleStepTests/80286 corpus at revision
`37c73caf53dcd22d3dd369ff09305d13d117a4fe` is imported from pinned
`04.MOO.gz`, `05.MOO.gz`, `14.MOO.gz`, `15.MOO.gz`, `1C.MOO.gz`, `1D.MOO.gz`,
`2C.MOO.gz`, `2D.MOO.gz`, `3C.MOO.gz`, `3D.MOO.gz`, and `40.MOO.gz` through
`4F.MOO.gz` artifacts. The passing set contains 5,000 captures for each of the
ten accumulator-immediate opcodes (byte/word `ADD`, `ADC`, `SBB`, `SUB`, `CMP`;
50,000 total) and 1,000 captures for each of the 16 register `INC`/`DEC`
opcodes, including SP (16,000 total). The earlier selected set passed 68,510
captures with both stalled and unstalled buses (137,020 executions): those
66,000 arithmetic records plus 1,254 F6.1 and 1,256 F7.1 register records.
The F6/F7 selection includes 86 F0-prefixed register cases. Zero selected
records were excluded by the pinned revocation list. The 7,490 F6/F7 memory
records are listed in the manifest but remain outside the RTL adapter.

The importer requires the exact recorded instruction-plus-HLT encoding,
checks its bytes against initial RAM, verifies post-HLT CS:IP, and merges final
register and RAM deltas into the complete recorded initial maps. Replay checks
all registers, FLAGS with mask `0x7fd7` for arithmetic/INC-DEC and `0x7fc7`
for F6/F7 TEST aliases (AF undefined), every recorded RAM byte, exact post-HLT
CS:IP and the HLT successor. MOO cycle records receive framing/count
validation only; cycle timing is not checked. All 33 parser/importer fixture
tests pass in Docker, including rejection of initial FLAGS with IF, TF, IOPL or
NT set because the current real-mode bootstrap cannot initialize those states.
All selected captures have those bits clear. Each selected artifact contains
initial CF=0 and CF=1 records; the manifest records per-file CF histograms and
the importer fails closed if either state is absent. The final `run_hardware.sh`
phase passed 28 replay baselines and detected 74 oracle-corruption checks
across arithmetic results, preserved state, flags, post-HLT PC, RAM, successors
and the F6/F7 alias; two undefined-AF mask controls are tracked separately.
Four checks flip initial CF independently for byte/word ADC and SBB and require
the physical oracle comparison to reject the corruption.

The prior 26-opcode directed CPU baseline included 252 cache-reset cuts and
102 aliased-role reference cases (`work/hardware_arithmetic_directed.log`).
After the #UD/TEST-alias change, the default `run_sim.sh` passed all components,
including the 256 legacy rejection cases, 36 directed #UD checks and 71
cycle-by-cycle #UD reset cuts described
above. `Bench::tick` rejects
an instruction-fetch transaction if write or I/O controls are asserted. The
focused compiled `fetch_asserts_write` mutant forces write during fetch and was
rejected with the specific `instruction fetch asserted write/I/O controls`
diagnostic in its dedicated protocol check. It is run with
`python3 scripts/run_reference_mutations.py --only fetch_asserts_write`; this
focused check is separate from the earlier six routing-mutant campaign. The
earlier full simulation result is recorded in `work/undefined_final_sim.log`.
That source snapshot also passed 36 formal tasks, 99,650 independent vectors /
1,715,162 states, the historical software regression and all eight synthesis
targets. The `run_undefined_mutations.py` phase is included in `run_all.sh`
after hardware replay; the final-testbench run detected all four compiled #UD
mutants for wrong vector, saved PC, fault retirement and missing alias
(`work/undefined_mutations.log`, `work/undefined_mutations/results.json`). No full `run_all.sh` rerun is
claimed.

The adapter does not cover other opcode forms, real-mode exception delivery,
protected mode, IF/TF, non-empty prefetch queues, small-SP shutdown, native pins
or cycle timing. It adds independent physical-capture evidence for the listed
forms; it does not close the full-chip completion ledger.
