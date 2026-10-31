# Planned asynchronous interrupt and trap extension

Status: functional real-mode INTR/NMI/TF core integration and directed tests
pass. The INTR/NMI epoch passed all eighteen formal tasks and its remaining
regression stages. The full TF regression also passed all eighteen formal
tasks, core reachability, directed/independent/firmware tests and synthesis.
A9/A10 edge gates remain.
The current INT/INTO/#DE/#BR paths are described
in procedure_execution.md. Sources are Intel 210498-005 sections 2.3, 5.2,
9.2, 9.5 and 9.7, plus MOV/POP/STI/IRET in Appendix B; the primary manual is
linked in the [chip README](../README.md).

## Recognition and restart

Protected-mode exception delivery through interrupt and trap gates is tracked
in [protected privilege transitions](protected_privilege_transition.md). The
directed suite covers CPL3-to-ring0 TSS stack switching, exact outer frames,
IRET, software-INT gate DPL, task-gate delivery, selected nested-fault
escalation, sticky #DF shutdown and shutdown NMI recovery. NMI recovery ignores
INTR, processes vector 2 through the protected gate/frame path, and returns to
RESET-only shutdown if delivery faults. See the [double-fault
checkpoint](../report/2026-10-27-double-fault-shutdown.md) and [NMI recovery
checkpoint](../report/2026-10-27-shutdown-nmi-recovery.md). The remaining #DF
classification and delivery matrix, every protected vector, reset cuts,
connected-core proof and native pin timing remain open. The real-mode
recognition and INTA contract below remains a separate integration gate.

Add maskable INTR, edge-triggered NMI and TF single-step delivery in real mode.
Accept asynchronous events only at complete instruction boundaries or completed
REP elements, never halfway through an operand transaction. An accepted event
must suppress the next instruction fetch on the functional transaction bus.
HLT has already retired: an eligible event wakes it without retiring HLT again,
and its return IP names the instruction following HLT.

INTR requires IF=1 and an eligible recognition boundary. Acquire its vector
through an explicit held-ready acknowledgement transaction; IF=0 prevents
acknowledgement. Native two-cycle INTA timing remains a separate adapter gate.
Do not equate this functional transaction with native pin validation.

NMI uses fixed vector 2, independently of IF, with no vector-acknowledgement
transaction. Remember at most one new NMI while the current NMI is being
serviced. Hold further NMIs until IRET; a held input level must not produce
repeated requests. A later low-to-high transition can produce a new request.
Reset clears pending/service state and must not emit an event or acknowledgement.

Real-mode entry saves FLAGS/CS/IP, clears TF/IF and loads the IVT pointer.
Preserve the existing A5 native-ordering evidence gate. Ordinary asynchronous
events save the next instruction IP. A partial REP event saves the first byte
of its original prefixed instruction and preserves completed data effects,
pointer updates and remaining CX. A completed REP event saves the successor IP.
No synthetic retirement is emitted for event entry; prior instruction/element
observations remain exact and distinct.

## Single-step and priority

Latch the applicable TF state for an instruction rather than deciding solely
from flags after retirement. Restoring TF via POPF/IRET must permit the next
program instruction to execute before its first single-step handler. INT
clears TF. Faults must not retire. The exact effect of a previously sampled
TF on INT/fault handler entry remains the source-reconciliation gate below.

Before implementing this rule, reconcile the primary text: section 9.7.1
states that INT clears TF and debuggers must emulate it, whereas Appendix C
item 12 says an INT/instruction-exception handler can still be single-stepped.
Do not turn either statement into an unchecked blanket suppression rule.
The controller accepts a qualified step request and makes no decision about
these instruction semantics. A pinned independent 286 trace must resolve
the exact INT/fault/first-handler boundary before core TF integration.

The primary processing order is instruction exception, single-step, NMI,
processor-extension segment overrun, INTR (tables 5-1 and 9-4). Selection must
preserve pending lower-priority requests and re-evaluate handler-entry state.
Processor-extension and protected-mode delivery remain required later gates.

For WAIT stalled on BUSY, a newly reportable extension error is an instruction
exception: when BUSY falls with ERROR# active, the core must not claim a new
NMI or INTR on that same clock. An NMI edge remains pending through fault
entry. An INTR already selected and awaiting vector acknowledgement follows
the A8 atomic-selection contract below: the core waits for the acknowledgement
and delivers the claimed interrupt before leaving WAIT. Its saved-IP behavior
remains the separately documented A25 assumption. The full WAIT/error/NMI and
already-claimed INTR races require the scoped tests and evidence reported in
[the WAIT formal report](../report/2026-10-29-wait-event-formal.md).

MOV SS and POP SS inhibit all interrupts, including NMI, through the following
instruction. Do not infer STI, repeated-instruction or IRET-fault boundary
details from a modern x86 emulator. The cached primary STI wording and the
independent MAME 286/8086 implementations differ in explicit inhibition state;
resolve and pin an independent 286 artifact before implementing that boundary.
The exact treatment of a following REP, TF stepping between elements, and
NMI re-enablement on a faulting IRET must also be sourced and tested. These are
open semantic requirements, not implicit choices or claims of completion.

The pinned [PCjs STI implementation](https://github.com/jeffpar/pcjs/blob/1a91d38eb12e5fdf91116b21ad9ef1935710a496/machines/pcx86/modules/v2/x86ops.js#L4324)
sets its next-instruction inhibition marker for the 286-capable core, unlike
the inspected MAME 286 handler. PCjs's flag-load helper separately defers a
newly enabled TF trap. Use these as explicit external artifacts to investigate
the boundary, not as proof of all related NMI/REP behavior. Also audit the
primary compatibility notes versus the general invalid-opcode description
for undefined POP/PUSH group fields before choosing #UD versus #GP.

## Functional event-controller contract

The separately verified controller is connected to the instruction sequencer.
Its caller supplies an eligible
recognition boundary, an all-event inhibition signal and an already qualified
single-step request. Therefore this component does not choose STI/SS/REP/TF
boundary semantics. Instruction exceptions take priority by withholding that
boundary. At an eligible boundary it chooses single-step (1), then an unblocked
pending NMI (2), then INTR if IF is set, in Intel table 9-4 order.

NMI input transitions are sampled on the functional clock; the caller must
provide a synchronized level. A rising level sets a one-entry pending latch
even during delivery of another event. Selecting NMI consumes the pending
request and blocks further NMI selection until the caller reports a completed
IRET. A new rising transition during service is remembered, and a held high
level produces no repeated requests. Selection on the same edge as IRET uses
the newly unblocked state. An edge coincident with selection is consumed by
that selection, rather than creating two requests. Reset clears pending and
service state; a level held high through reset is a new request on release.
Intel section 9.2 explicitly specifies one remembered NMI and IRET unmasking.

ASSUMPTION: A8 extends the functional-bus abstraction A1: selection claims a
single event atomically. An INTR selection holds vector-acknowledge request
until ready, samples the supplied vector once, then holds delivery valid and
vector until accepted by the sequencer. Neither later IF/INTR changes nor a
higher-priority arrival preempts that selected event. New NMIs remain pending.
Native INTA timing, CDC/metastability and the event-recognition instant are
outside this component's contract and remain explicit integration/native
evidence gates. Standalone proofs alone do not establish CPU boundary behavior;
the integrated frame/restart and original IRQ8 tests provide separate evidence.

Reset immediately suppresses request/valid outputs and synchronously cancels
any pending acknowledgement or delivery. No acknowledgement is generated for
single-step or NMI. Delivery cannot precede a ready vector acknowledgement for
INTR. Standalone formal and directed transaction tests must exercise stalls,
priority, masking, remembered/coalesced NMI, simultaneous IRET, and reset at
each transaction phase before core integration.

## Exception and verification requirements

## INTR/NMI integration implementation contract

Add synchronized `intr_i` and `nmi_i` levels and a separate
`inta_req_o`/`inta_ready_i`/`inta_vector_i` functional acknowledge channel.
The latter is one vector transaction, not native two-cycle INTA. Existing
memory/I/O transactions are never withdrawn to accept an event. Explicit
bus-idle boundary/poll states precede every new instruction and every
nonzero-count REP element; an already issued fetch finishes as part of its
instruction. Reset starts at a boundary before the first reset-vector fetch.
The extra internal cycles are permitted by A1 and are not native timing.

Normal boundaries save current CS:IP; REP boundaries save original prefixed
IP and preserve all completed elements. Final/zero-count REP saves fallthrough
IP. HLT remains architecturally halted while polling and awaiting INTR vector;
accepted delivery wakes it, saves the already advanced IP, and emits no extra
retirement. Pending lower-priority NMI survives a claimed INTR transaction.
IRET notifies the NMI controller only when its current valid real-mode return
frame has committed; faulting-IRET behavior is a separate unresolved gate.

Intel's 1983 *Microprocessor and Peripheral Handbook*, iAPX 286/10 Chapter 4,
Table 1 (printed page 4-3), says the CPU may be interrupted while BUSY holds it
in WAIT. The connected functional core now lets eligible NMI/INTR requests
select at this wait boundary in real mode and protected CPL1/CPL2 execution;
INTR still requires IF and the usual acknowledge, while NMI has no acknowledge.
The 16-case protected regression checks both event types, interrupt/trap gates,
TSS stack switching, exact outer frames, both READY modes and exact IRET
successors. ESC's separate BUSY wait is not included. **ASSUMPTION A25:** the
asynchronous frame saves the IP after WAIT, which the decoder has already
advanced. The handbook establishes interruptibility but does not specify the
saved IP for this case. The directed tests hold BUSY through the handler and
IRET to distinguish the successor from restarting WAIT; this checks the
chosen behavior, not an independent 286 oracle. Keep the return-IP rule open
for independent-source or real-code validation before sign-off. Native pin
timing is not covered. See the [protected WAIT report](../report/2026-10-28-protected-wait-interruption.md).

Source: [Intel 1983 Microprocessor and Peripheral Handbook (Bitsavers scan)]
(https://bitsavers.org/components/intel/_dataBooks/1983_Intel_Microprocessors_and_Peripherals_Handbook.pdf).

SS-load shadow is created only by a successful MOV SS/POP SS. It suppresses
NMI and INTR at the next boundary. STI creates an INTR-only shadow. At the
first byte of the following instruction these shadows are transferred to
instruction context, so prefixes cannot consume a shadow. A following REP
retains that context through its elements. Event entry clears shadow context.

ASSUMPTION: A9. Use a one-following-instruction STI INTR shadow, following
the pinned [PCjs opSTI](https://github.com/jeffpar/pcjs/blob/1a91d38eb12e5fdf91116b21ad9ef1935710a496/machines/pcx86/modules/v2/x86ops.js#L4324)
and [86Box opSTI](https://github.com/86Box/86Box/blob/1db9ae4cc910b0b7e6e9b49995910b0cc19747a0/src/cpu/x86_ops_flag.h#L64).
The primary Appendix B wording is less specific and MAME's inspected 286
handler differs. Hold SS/STI inhibition through a following whole REP per
the primary next-instruction wording; the pinned 86Box SS handlers execute
the following instruction internally, but its REP time slicing cannot prove
the exact hardware shadow release at an intermediate element. Consecutive
shadow producers, REP/shadow edges and faulting IRET need a native 286 trace
and historical interrupt-driven validation before sign-off. Keep these gates
visible rather than treating general x86 agreement as final 286 evidence.

## TF integration contract

Sample TF at the first byte of an instruction, retaining it across prefixes.
Qualify a vector-1 request at its ordinary retirement boundary or after a
completed partial REP element. A zero-count REP still retires and can trap;
its saved PC is fallthrough. An unfinished REP saves its original prefixed PC
and completed CX/pointer/memory progress. A newly loaded TF from POPF/IRET
therefore takes effect after the following program instruction, while clearing
TF with a stepped POPF does not erase the already sampled request.

HLT enters the same immediate retirement boundary with its halt latch set,
allowing a pending single-step to wake it and save its successor without a
second retirement. MOV/POP SS inhibition also inhibits vector 1 through the
following instruction; A9 governs the whole-REP shadow policy. STI inhibits
INTR but not single-step. At a shared boundary debug precedes NMI/INTR, and
lower-priority requests survive. Entry clears TF/IF; selection at the handler
boundary re-evaluates the resulting flags, rather than restoring old IF.

ASSUMPTION: A10 resolves the currently conflicting primary INT prose by
following Intel 9.7.1 and pinned 86Box: suppress the post-instruction TF request
for a synchronous software INT/INTO entry or fault. The independent
[286/386 interpreter](https://github.com/86Box/86Box/blob/1db9ae4cc910b0b7e6e9b49995910b0cc19747a0/src/cpu/386.c#L306)
samples TF before executing the opcode;
[interrupt helpers](https://github.com/86Box/86Box/blob/1db9ae4cc910b0b7e6e9b49995910b0cc19747a0/src/cpu/386_common.c#L1661)
clear pending trap state on faults and clear its TF bit on software INT.
The [286 IRET handler](https://github.com/86Box/86Box/blob/1db9ae4cc910b0b7e6e9b49995910b0cc19747a0/src/cpu/x86_ops_ret.h#L149)
restores flags without replacing that instruction-start sample. These are
external artifacts, not a reference translated from RTL. Appendix C item 12
still needs native 286/real debugger evidence; no final sign-off on that edge
is claimed. Historical debugger software, SS/REP and real-mode pending-INTR
priority edges remain full-chip verification gates.

Separate truly invalid encodings from valid but still unimplemented system,
prefix and coprocessor operations before converting development diagnostics
into architectural #UD. Source exact #GP/#SS selection, ten-byte-length faults,
stack shutdown/escalation, error-code and partial-progress rules before replacing
limit diagnostics. Protected descriptor/gate/TSS checks cannot be closed by
passing a real-mode frame test.

Test exact saved/next PCs, frame bytes, TF/IF state, retirement counts and
executed successors. Cover IF masking, HLT wakeup, priority races, held NMI,
remembered NMI during a handler, IRET restoration, SS inhibition, REP interruption
and reset during acknowledgement/entry. Use externally sourced expectations
and unmodified historical interrupt-driven software, with required platform
devices. Keep byte-bus stall stability, formal non-vacuity, original BIOS,
lint, synthesis and mutation-sensitivity gates. Full native-interface and
protected-mode software sign-off remain in the completion ledger.
