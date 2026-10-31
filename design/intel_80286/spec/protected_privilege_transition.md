# Protected privilege transitions

Status: reachable ring-0-to-ring-3 IRET, same-level GDT call gate, LDT-resident
call gate to GDT code, and ring-3 calls to nonconforming ring-0/1/2 targets
with TSS stack selection are implemented and tested in both READY modes. A
DPL-1 conforming target is also called from CPL 3 without changing CPL or the
stack. The GDT-gate fixture covers 0, 1 and 31 copied parameter words;
outer-level RETF restores GDT-backed and LDT-backed callers. Nine invalid
TSS/SS0/stack-span cases deliver exact #TS/#SS frames. A 13-case outer-RETF
fault matrix checks CS/SS fault ordering, and a reachable #GP handler repairs
the saved SS, IRETs and retries RETF. Protected interrupt/trap gates now
switch CPL3 faults to the TSS ring-0 stack, build the exact outer frame and
return through IRET; software INT gate-DPL rejection and IF/TF behavior are
tested. Four reachable CPL1/CPL2 matrices now check allowed and denied
software-INT gate-DPL boundaries, privileged-LIDT #GP(0) delivery through
gate DPL 0/3, external INTR vector 13 and NMI vector 2 through DPL-0 gates.
They verify TSS ring-0 stack selection and exact outer frames through both gate
types and READY policies; the NMI slice also checks no acknowledge cycle and
unblocking on outer IRET. One bounded nested-#GP case now
selects vector 8 with a null error
code when an initial protected #GP handler lookup itself hits the IDT limit.
The fixture leaves the vector-8 descriptor all-zero; the current
interrupt/trap-only gate validator stops there. A valid #DF task gate now
switches to a GDT 286 TSS and pushes the null error word. Protected IRET with
NT set returns through the backlink, clears the outgoing task's busy bit, and
restores the interrupted task. The valid entry/return fixture supports a null
LDTR. Pre-switch invalid backlink cases now deliver restartable #TS, #NP or
#GP selector errors in the current task. Incoming LDTR/segment failure
priority and nested task-switch faults have focused delivery tests. Protected
#DF delivery now has sticky shutdown on selected IDT/gate/TSS/incoming-task
faults, and NMI can leave shutdown only after protected event delivery commits.
The full first/second-fault matrix, every NMI target/frame failure, external
shutdown signaling, reset cuts, full vector coverage and broader privilege
combinations remain open.

## Primary sources

Intel, *80286 and 80287 Programmer's Reference Manual*, order 210498-005:

- §7.4 and Tables 7-2/7-3: CALL/JMP transfer and call-gate checks.
- §7.5.1.2: intra-level CALL-gate transfer to conforming code with DPL <= CPL.
- §7.5.1.4 and Figure 7-12: TSS-selected stack and inter-level CALL frame.
- §7.5.2 and Table 7-4: inter-level far return checks and stack restoration.
- §9.4: IRET uses the inter-level return checks with the additional FLAGS word.
- Table 9-5 and §9.6.6: invalid-TSS selector errors and stack-fault error codes.
- Chapter 8: 80286 TSS layout and initial stack values for CPL 0–2.

The [Intel manual](https://bitsavers.org/components/intel/80286/210498-005_80286_and_80287_Programmers_Reference_Manual_1987.pdf)
is the semantic authority. Modern processors and shared-ISA emulators are not
substitutes for these 286-specific rules.

## Protected interrupt and trap gates with a privilege change

Intel §9.4 and its gate/interrupt tables distinguish 286 interrupt gates
(type 6) from trap gates (type 7). The IDT descriptor DPL is checked for
software `INT n`, `INT3` and `INTO`; it is ignored for processor exceptions
and external interrupts. On a transfer to a more privileged nonconforming
handler, the processor obtains that CPL's SPn:SSn from the current TSS,
validates the new stack, saves the old SS:SP along with FLAGS/CS/IP, and pushes
an exception error code when applicable. Interrupt-gate entry clears IF and
TF; trap-gate entry preserves IF and clears TF.

The current implementation exercises a reachable ring-3 #GP through both gate
types and software-INT gate-DPL rejection through each type. The
`--protected-event-outer` regression checks exact TSS and stack descriptor
reads, frame bytes and order, no writes to the old user stack, gate-specific
flags, handler repair, and outer IRET to the exact successor, with and without
READY stalls. The full bootstrap also passes. Exact logs and source hashes are
in `work/protected_event_outer_20261026_07/` and
`plans/286/STATUS.md`.

The focused `--protected-event-ring12` regression adds reachable CPL1/CPL2
software `INT 13h` delivery through type-6 and type-7 gates. It tests the
allowed boundary (gate DPL equals CPL) and denied boundary (gate DPL is one
level more privileged), with READY asserted and stalled. Allowed INT saves the
post-instruction IP and uses a five-word outer frame; denied INT delivers
restartable #GP(006A), saves the INT IP, and uses a six-word frame. A handler
discards the error word, skips the rejected INT and returns with outer IRET.
The test checks the TSS stack read/validation/write order, no writes to the
interrupted ring-1/ring-2 stack, IF/TF semantics and the exact successor. The
full default bootstrap passes. Evidence is in
`report/2026-10-28-protected-event-ring12.md` and
`work/selector_ring12_dev_20261028/`.

The companion `--protected-event-ring12-exception` regression executes
privileged `LIDT [0010]` at CPL1/CPL2 under interrupt/trap gates with DPL 0 and
3. All 16 cases require restartable #GP(0), no pseudo-descriptor read, the
exact outer error frame, and handler IRET to the five-byte instruction's
successor. This checks that processor-exception delivery ignores IDT gate
DPL at these privilege levels.

The `--protected-event-ring12-external` regression presents external INTR
vector 13 from CPL1/CPL2 through type-6 and type-7 gates whose DPL is zero.
Eight cases check instruction-boundary sampling after the first NOP, the
no-error five-word outer frame, TSS SP0:SS0 selection before ring-0 stack
validation and writes, no writes to the interrupted stack, IF/TF behavior and
outer IRET followed by execution of the exact successor in both READY modes.
This covers the DPL-bypass behavior for this external vector and gate setup;
it does not establish coverage for other external vectors or native pin timing.
See `report/2026-10-28-protected-event-ring12.md` for exact logs and hashes.

The `--protected-event-ring12-nmi` regression presents NMI vector 2 through
type-6 and type-7 DPL-0 gates from CPL1/CPL2. Eight cases verify no vector
acknowledge, exact no-error outer frames and IRET successors, and NMI service
blocking during the handler followed by release on a valid outer IRET. READY
is asserted and stalled. This is focused functional event evidence; it does
not establish NMI pin timing or all protected NMI/fault interactions.

This is a tested delivery slice rather than complete protected event
semantics. Invalid gate/target/TSS/new-stack faults still stop diagnostically
instead of escalating through a nested-fault matrix. Task gates and task
switching, other CPL1/CPL2 exception and external-vector transitions, all
vectors/error-code cases, native interrupt-pin timing, and current-source
formal closure remain open.

## 80286 double-fault and shutdown rules

Intel §9.6.2 defines the 286 rule directly: when two separate faults occur
during one instruction, vector 8 (double fault) is generated if the first
fault is vector 0, 10, 11, 12 or 13. The error code for double fault is null,
and its saved address identifies the instruction being executed or ready to
execute. Intel specifically says a task gate must be used for the double-fault
handler so the handler gets a proper task state; the backlink identifies the
task that caused the exception.

The same section says a protection violation while processing vector 8 enters
shutdown, in which no further instruction or exception is processed. NMI can
leave shutdown only if processing the NMI itself succeeds; a fault during that
attempt requires RESET. RESET also leaves shutdown and clears protected mode.
The manual separately excludes vectors 1,
2, 3, 4, 5, 6, 7, 9 and 16 from double-fault generation while their handlers
are being invoked. Implement these 286-specific rules from the manual's
exception tables; do not substitute the later 386 contributory/page-fault
classification.

The event core converts an IDT-limit #GP while looking up an initial
restartable #DE/#TS/#NP/#SS/#GP handler to vector 8 with a null error code,
preserving the original saved context. A protection fault while validating
the first handler gate for any of those restartable exceptions also escalates
to vector 8. A protection violation during protected #DF delivery now enters
sticky `shutdown_o`: vector-8 IDT bounds,
invalid gates, task-gate selector/TSS admission and incoming task descriptor
validation all suppress further bus activity and instruction execution until
RESET. Directed tests cover invalid gate contents, vector-8 IDT overflow,
non-present target TSS and invalid incoming LDTR in both READY modes. A
DIV-by-zero case with an invalid vector-0 gate checks first-fault #DE gate
escalation to #DF and subsequent shutdown on an invalid vector-8 gate.

The IDT-limit matrix also raises first-fault #NP by loading a non-present code
descriptor and #SS by pushing across the loaded stack limit. In both READY
modes these cases preserve the original context, select vector 8 with a null
error code, read only the expected target descriptor and vector-8 gate, and
enter sticky shutdown when that gate is invalid. They cover the IDT-limit
second-fault path. Post-transfer first-fault #TS cases use an invalid incoming
LDTR and null incoming CS; Table 8-1 row 6 maps the latter to `#TS(0000)`. A
CS selector `0010` naming a data descriptor also raises `#TS(0010)` under row
6. Its malformed vector-10 gate selects null-error #DF; shutdown and valid
task-gate delivery check the faulting TSS image and exact handler successor in
both READY modes. See the
[incoming-CS type-fault report](../report/2026-10-29-incoming-cs-type-double-fault.md).
A non-present incoming CS selector `0008` raises `#NP(0008)` per row 7.
Incoming CS selector `0038` has RPL 0 and names a present DPL-3 code
descriptor, so the row-8 mismatch raises `#TS(0038)`. A malformed vector-10
gate selects null-error #DF; shutdown and valid #DF task-gate delivery check
the exact faulting task state in both READY modes. See the
[incoming-CS DPL/RPL report](../report/2026-10-29-incoming-cs-dpl-double-fault.md).
Non-present incoming SS selector `0010` raises `#SS(0010)` per row 11, and
non-present incoming ES selector `0020` raises `#NP(0020)` per row 15. A
present, read-only incoming SS selector `0010` raises `#GP(0010)` per row 10.
Its malformed vector-13 gate selects null-error #DF; shutdown and valid #DF
task-gate delivery check exact task state in both READY modes. See the
[incoming-SS read-only report](../report/2026-10-29-incoming-ss-read-only-double-fault.md).
Incoming CPL 0 with writable DPL-3 stack selector `0040` raises `#SS(0040)`
per row 12; its malformed vector-12 gate selects null-error #DF. Shutdown
and valid #DF task-gate delivery check the exact faulting task state in both
READY modes. See the
[incoming-SS DPL report](../report/2026-10-29-incoming-ss-dpl-double-fault.md).
A null incoming SS selector raises `#SS(0000)` per row 9 without a GDT null
descriptor read. Its malformed vector-12 gate selects null-error #DF; shutdown
and valid #DF task-gate delivery check the exact faulting task state in both
READY modes. See the
[incoming-SS null-selector report](../report/2026-10-29-incoming-ss-null-double-fault.md).
Incoming SS selector `0188` beyond GDT limit `0187` also raises `#SS(0188)` per
row 9 without an out-of-limit descriptor read. Its malformed vector-12 gate
selects null-error #DF; shutdown and valid #DF task-gate delivery pass in both
READY modes. See the
[incoming-SS GDT-limit report](../report/2026-10-29-incoming-ss-gdt-limit-double-fault.md).
A non-present incoming DS selector `0010` raises `#NP(0010)` per row 15; its
malformed vector-11 gate selects null-error #DF, with shutdown and valid
task-gate delivery checked in both READY modes. See the
[incoming-DS #NP report](../report/2026-10-29-protected-incoming-ds-np-double-fault.md).
An execute-only code descriptor at ES selector `0030` raises `#GP(0030)` per
row 14 while remaining valid as the incoming CS.
The same execute-only descriptor at incoming DS selector `0030` also raises
`#GP(0030)` per row 14. The invalid `#GP` handler gate selects null-error
`#DF`; both shutdown and valid #DF task-gate delivery check the exact saved
task context in both READY modes. See the
[incoming-DS readability report](../report/2026-10-29-incoming-ds-readability-double-fault.md).
An incoming ES system descriptor at selector `0050` raises `#GP(0050)` per
row 13.
An incoming DS system descriptor at selector `0050` raises the same
`#GP(0050)` per row 13; shutdown and valid #DF task-gate delivery pass in both
READY modes. See the
[incoming-DS system-descriptor report](../report/2026-10-29-protected-incoming-ds-system-double-fault.md).
An incoming CPL-0 task with DS selector `0013` fails the data-segment
`max(CPL,RPL) <= DPL` rule and raises `#GP(0010)` per row 16. Its malformed
vector-13 handler gate selects null-error vector 8; shutdown and valid #DF
task-gate delivery both pass in both READY modes, checking the saved TSS with
DS=`0013`. See the
[incoming-DS privilege report](../report/2026-10-29-protected-incoming-ds-privilege-double-fault.md),
[incoming-DS #NP report](../report/2026-10-29-protected-incoming-ds-np-double-fault.md).
An incoming CPL-0 task with ES selector `0023` violates the same row-16
privilege rule and raises `#GP(0020)`; invalid-#DF-gate shutdown and valid
#DF task-gate delivery pass in both READY modes, with ES=`0023` in the saved
faulting TSS. See the
[incoming-ES privilege report](../report/2026-10-29-protected-incoming-es-privilege-double-fault.md).
Malformed matching #TS/#NP/#SS handler gates then select null-error vector 8.
Malformed #GP handling also selects null-error vector 8. Tests cover
invalid-#DF-gate shutdown and valid #DF task-gate delivery, with saved faulting
TSS, backlink/busy state, null error push and exact handler successor checks.
The ES #NP/#GP cases also check the failed descriptor read and both first-fault
and #DF gate lookups. These selected cases do not establish the full #DF
classification or every task-entry failure phase. See the [first-fault
coverage report](../report/2026-10-28-protected-double-fault-first-faults.md),
[incoming-CS #TS report](../report/2026-10-29-protected-cs-double-fault-first-fault.md),
[incoming-CS #NP report](../report/2026-10-29-protected-cs-np-double-fault-first-fault.md),
[incoming-SS #SS report](../report/2026-10-29-protected-incoming-ss-double-fault.md)
and [incoming-ES #NP report](../report/2026-10-29-protected-incoming-es-np-double-fault.md),
[incoming-ES #GP report](../report/2026-10-29-protected-incoming-es-gp-double-fault.md),
[incoming-ES system-descriptor report](../report/2026-10-29-protected-incoming-es-system-double-fault.md),
[incoming-DS system-descriptor report](../report/2026-10-29-protected-incoming-ds-system-double-fault.md),
[incoming-DS privilege report](../report/2026-10-29-protected-incoming-ds-privilege-double-fault.md),
[incoming-ES privilege report](../report/2026-10-29-protected-incoming-es-privilege-double-fault.md).

The shutdown-only NMI path ignores INTR, routes vector 2 through the protected gate
and frame checks, clears shutdown after a successful commit, and returns to
RESET-only shutdown if delivery faults. Directed cases cover a valid gate,
invalid gate, IDT-limit fault and invalid target descriptor in both READY
modes. Intel's local-bus contract makes the external shutdown indication observable:
`S1:S0=00`, `COD/INTA=0`, and `M/IO=1` identify a halt/shutdown
operation; address line A1 is 1 for HLT and 0 for shutdown. The controller
does not issue ALE and READY is not required to terminate this special
operation. Only NMI or RESET exits shutdown; INTR is ignored. These signal
values and timing are specified in Intel's [80286 Hardware Reference Manual,
§3, “HALT/SHUTDOWN CYCLES”](https://bitsavers.org/components/intel/80286/210760-002_80286_Hardware_Reference_Manual_1987.pdf)
and the shutdown wake rule in the [Programmer's Reference Manual,
§11.6](https://bitsavers.trailing-edge.com/components/intel/80286/210498-005_80286_and_80287_Programmers_Reference_Manual_1987.pdf).
The byte-transaction interface now exposes `bus_halt_cycle_o` for an active
HLT and `bus_shutdown_cycle_o` for sticky shutdown. They are mutually
exclusive, independent of `bus_ready_i`, and separate from `bus_req_o`. These
signals identify the HALT/shutdown cycle class and preserve the A1 distinction
at this abstraction boundary; raw `S1:S0`, `COD/INTA`, `M/IO`, A1 and ALE pins
are not modeled. Directed tests check persistence with READY low, no byte
request, and INTR being ignored during shutdown. See the [NMI recovery
checkpoint](../report/2026-10-27-shutdown-nmi-recovery.md) and [shutdown
checkpoint](../report/2026-10-27-double-fault-shutdown.md).

A valid type-5 #DF task gate now has a bounded successful entry path. The
implementation validates a present available GDT 286 TSS with limit at least
`002Bh`, marks it busy, writes the old TR selector to its backlink, saves and
loads the 15 dynamic TSS words, and stages the incoming segment caches. It
supports a null LDTR and validates SS, CS, DS and ES before publishing the new
task state. It sets NT and TS, pushes the #DF error word on the incoming stack,
then commits the incoming registers, FLAGS, TR and segment caches atomically.
The focused regression verifies the complete outgoing image, incoming
registers and hidden bases, backlink/busy/NT/TS, error push, and exact handler
landing in both READY modes; see
[`2026-10-27-task-gate-switch.md`](../report/2026-10-27-task-gate-switch.md).

Protected IRET with NT set now reads the current TSS backlink, requires a busy
present GDT 286 TSS, saves the outgoing task's state with the post-IRET IP and
NT cleared, clears the outgoing TSS busy bit, and switches to the backlink task
without nesting. A directed #DF test returns to the interrupted CPL3 task,
re-enters the now-available handler TSS, and checks that the handler resumes at
its saved post-IRET instruction. This valid backlink return is covered only
with a null LDTR.

Invalid backlink selector/TI/GDT-bound/type checks now raise restartable
#TS(selector); a not-present backlink TSS raises #NP(selector), an available
instead of busy TSS raises #GP(selector), and a too-short TSS raises
#TS(selector). Directed tests verify those packets before any outgoing TSS
save or busy-bit clear. Invalid incoming LDTR selectors now raise #TS after
publishing the transferred task registers and TR. A nested #TS task-gate test
checks the exact selector error, backlink/busy state and saved incoming TSS
image. A no-error software task-gate entry now
commits the incoming context, releases the event bus owner and fetches the
target task's exact instruction stream. Eight cases vary null LDTR, DS and ES
selector RPL values 0 through 3 under both READY modes. `SLDT` and `MOV` from
DS/ES observe the loaded selector words; the cases also check no exception
error push, backlink/busy state, no GDT null-descriptor read, and sequential
fetches through the HLT successor. The [1984 Intel B-2/B-3 information
sheet](https://docs.pcjs.org/manuals/intel/80286/80286_B2_B3_Errata-1984-11-21.pdf)
records an earlier-stepping erratum that clears null DS/ES selectors to zero;
this design does not select those stepping errata. The full double-fault
generation matrix, additional NMI delivery failure phases, external shutdown
HALT-cycle modeling, reset cuts and task-switch formal properties remain open;
unimplemented validation paths still stop diagnostically.

For valid non-null incoming LDTR state, the present GDT LDT descriptor's base,
limit and validity are staged through CS/SS/DS/ES validation, then published
with the task's segment caches at entry commit. The code-load and segment-load
paths use this staged LDTR while the task switch is active. The valid LDT
privilege matrix passes 460 executions across CPL0–2 and both READY modes.
CS/SS use DPL=RPL=CPL; DS/ES independently cover every DPL/RPL pair
satisfying `max(CPL,RPL) <= DPL`. It checks visible selectors, segment cache
bases/validity, exact task successors, all four descriptor read orders and
accessed-byte writes, and task backlink/busy state. The LDT limit is exactly
`0027`, so the ES descriptor ends at its final valid byte. The task reads back
DS/ES selectors but does not access their data segments.

A separate eight-execution limit matrix places CS, SS, DS or ES at LDT offset
`0038`, beyond limit `0027`. It checks Table 8-1 `#TS(CS)`, `#SS(SS)` and
`#GP(DS/ES)` packets, the exact transferred-task state and error push, prior
descriptor read order, and no read or accessed-byte write for the rejected
selector. Both matrices pass in immediate and stalled READY modes. See the
[incoming-LDT privilege and limit report](../report/2026-10-28-incoming-ldt-privilege-limit-matrix.md).

The incoming CS/SS/DS/ES selector-fault matrix covers 25 invalid-selector
26 configurations in both READY modes. It includes CS, SS, DS and ES GDT-limit
faults; the ES case checks exact `#GP(0188)` and no read beyond GDT limit
`0187`. The SS RPL-mismatch case checks exact `#SS(0028)` for selector
`002B` at CPL 0. The ES system-descriptor case checks exact `#GP(0050)`.
The DS and ES execute-only-code cases each check exact `#GP(0030)`. See the
[incoming DS readability report](../report/2026-10-29-incoming-ds-readability-double-fault.md),
[incoming ES readability report](../report/2026-10-29-incoming-es-readability.md),
[incoming ES system-descriptor report](../report/2026-10-29-incoming-es-system-descriptor.md),
[incoming SS RPL report](../report/2026-10-28-incoming-ss-rpl-fault.md) and
[incoming ES GDT-limit report](../report/2026-10-28-incoming-es-gdt-limit.md).

## IDT task gates and 286 task switching

Intel §§8.2–8.5 and 9.4 define the task-gate path. A task gate contains a GDT
TSS selector; it does not contain a handler offset. The 286 TSS is 22 words,
with minimum limit `002Bh`. The switch validates the incoming descriptor as an
available 286 TSS and checks presence before the switch begins. The switch
sets the incoming busy bit, saves the outgoing dynamic TSS state, loads TR
and the incoming general registers/IP/FLAGS, sets TS, then validates and loads
the incoming LDTR, SS, CS, DS and ES before execution begins. This ordered
sequence matters: later validation faults occur after earlier task-switch
side effects and must follow the 286 error table.

Incoming LDTR validation checks TI, GDT bounds, descriptor type and presence
after loading the incoming TSS. These failures raise #TS(selector) after
publishing the incoming task context and TR, so a task-gate #TS handler can
save the transferred task. The GDT-limit case uses selector `0188` against
limit `0187`; the earlier `0080` fixture was in-bounds and has been corrected.
Five invalid-selector cases pass in both READY modes.

After LDTR validation, task entry checks SS, CS, DS and ES in that order.
Invalid CS type/selector and CS DPL/RPL mismatch raise #TS(selector); absent
CS raises #NP(selector). Invalid SS selector or privilege raises #SS(selector),
a present non-writable/non-data SS raises #GP(selector), and absent SS raises
#SS(selector). Invalid DS/ES selector/type/privilege raises #GP(selector);
absence raises #NP(selector). Error codes clear selector RPL. Eighteen
descriptor-fault cases and three pairwise priority cases pass under both READY
modes. The nested task-gate tests verify the transferred TSS save, backlink,
busy bits, restartable exception packet and error push.

Intel 210498-005 §8.3, printed page 8-6 (PDF page 156), notes that the new
task's registers are loaded before the incoming LDT and segment checks. A
fault during those checks is handled in the incoming task context. Consequently
the handler's same-level exception frame must use a successfully validated
incoming SS cache and incoming SP; a rejected or not-yet-checked DS/ES selector
may remain nonzero while its cache is unusable. The handler can save and
examine those selectors before repairing them. `task_entry_fault_context`
publishes only segment caches that passed validation, invalidates the others,
and carries over the incoming LDTR cache only when its descriptor passed.
Staged caches are cleared at the start of each TSS load so a later switch
cannot inherit an earlier task's descriptor state. A both-READY-mode regression
faults on incoming DS, checks the exact #GP frame on the incoming stack, then
confirms a read through the rejected DS raises #GP before reaching the outgoing
task's data base. See the
[incoming-task fault-context report](../report/2026-10-29-task-fault-context.md).

An interrupt-initiated task switch nests the task: it writes the old TR
selector into the incoming TSS backlink, sets NT in the incoming flags, and
keeps the outgoing TSS busy. An exception error code is pushed on the new
task's stack; the interrupted return address is saved in the old TSS. IRET
with NT set returns through the backlink and clears the outgoing task's busy
state according to Intel Table 8-2. Task-gate DPL is checked for software INT;
processor exceptions and external interrupts ignore it. TSS access, task
availability, reserved bits and selector errors must use the 286 tables, not
later 386 task-switch rules.

Far CALL/JMP task transfers are also supported for the tested available 286
TSS descriptor and task-gate forms (Intel 210498-005 §§8.2–8.5). CALL nests:
the destination backlink names the old TR, NT is set in the incoming task,
and the old TSS remains busy until task IRET returns through that backlink.
JMP does not write a backlink or set NT; it saves the post-instruction
successor, clears the old TSS busy bit, and leaves the destination TSS busy.
The destination gate/TSS is validated before those busy-state changes. A
focused eight-case matrix checks CALL/JMP through both descriptor forms,
backlink/busy behavior, exact target and caller successors, retirement, and
both READY policies. A separate protected far JMP to a code descriptor checks
that ordinary control transfers retain their single validated code-load path.
See the [direct task-transfer report](../report/2026-10-28-protected-direct-task-transfers.md).

For a direct far CALL/JMP through a task gate, Intel §8.5 checks the selector's
effective privilege against the gate DPL: `max(CPL, selector.RPL) <= gate.DPL`.
The 192-execution regression exhausts CPL 0–2, selector RPL 0–3, gate DPL 0–3,
CALL/JMP and both READY policies. All 104 permitted cases check task transfer,
exact successors and CALL return frames; all 88 denied cases check
#GP(selector), exact same-task frames and no incoming TSS/task-image access or
mutation. Same-level CPL0 frames are checked without outer SS:SP words. This
establishes the enumerated access matrix, not every task-switch fault phase.

Intel 210498-005 §8.5, printed page 8-8, says the offset portion of a far
CALL/JMP destination through a task gate is ignored. Figure 8-3 labels the
field unused and notes that zero is required for 80386 compatibility; this is
not a 286 #GP rule. The task-gate CALL/JMP success matrix now supplies a
nonzero offset and verifies the exact incoming-task successor in both READY
modes. Table 8-1, printed page 8-6, maps a busy incoming TSS to #GP with the
incoming TSS selector as the error code. Paired busy-target CALL/JMP cases
check #GP(0078), exact frames, descriptor-read boundaries and no task-image or
busy-bit writes.

**ASSUMPTION A26:** the direct far task-gate path currently raises
#GP(task-gate selector) when the additional descriptor fields checked by the
RTL (`protected_call_descriptor_header[2:0]`,
`protected_call_parameter_count`, or `protected_call_descriptor_tail`) are
nonzero. Figure 8-3 labels the corresponding task-gate fields unused and says
zero is required for 80386 compatibility, but the inspected 286 text does not
specify whether nonzero values fault or are ignored. The current direct-transfer
matrix keeps these fields zero, so it does not validate this behavior. Keep the
RTL rule as provisional implementation policy, not a confirmed 286 rule, until
independent 286 evidence resolves it; any future test of the rule is regression
evidence only, not architectural acceptance.
The source gap and exact RTL check are recorded in the
[task-gate source audit](../report/2026-10-28-task-gate-source-audit.md).

A 21-configuration negative matrix (42 executions) runs in both READY modes
and checks exact #GP/#NP/#TS packets and frames for selected direct-TSS/task-
gate DPL, presence, busy/type, limit, reserved-byte, selector-boundary and
current-TR cases. It also puts the task-gate descriptor at the end of the GDT
and its embedded TSS selector just beyond the limit; both CALL/JMP cases raise
#TS(0078) before reading that descriptor. A separate 900-cut matrix resets
direct TSS/task-gate CALL/JMP after each accepted data transfer in both READY
modes, including eight post-commit cuts, and verifies only reset-vector
replay. Existing nested #DF task-gate entry and task-IRET cut matrices remain
separate. More fault combinations, partial-write fault phases, current-source
task-switch formal properties, and broader task-switch software coverage
remain open; these directed cases do not close task switching. See the
[task-gate source audit](../report/2026-10-28-task-gate-source-audit.md) for
the independent source review.

Next, close the unresolved task-gate field assumption with independent 286
evidence where available; add current-source connected-core properties for
task entry/return after the preserved older PDR terminates; and expand valid
LDT descriptor, privilege and limit coverage. Keep the successful #DF entry/return, null and non-null LDTR task
entry, no-error task entry, post-transfer LDTR/segment faults and pre-switch
backlink checks separate from unverified paths.

## Reachable CPL 3 bootstrap through IRET

The directed program starts in the supported CPL-0 state and constructs a
protected outer-level IRET frame in its valid ring-0 stack. It checks the full
frame span, validates the return CS descriptor, reads the outer SP and SS,
validates the new stack descriptor, and only then publishes CS:IP, FLAGS,
SS:SP and their caches. The directed `--outer-iret` regression checks exact
descriptor/frame read order, accessed-byte writes, atomic state publication,
DS/ES invalidation and the exact ring-3 successor in both READY modes.

The ring-3 target must be an ordinary test program reached through this frame;
the testbench must not seed CS.RPL, CPL, SS, or descriptor caches directly.
The valid ring-0-to-ring-3 return is covered. Invalid CS/SS return cases still
stop diagnostically and do not establish architectural fault delivery. This
IRET milestone alone does not establish general protected event delivery.

## Ring-3 CALL through a call gate

The current valid-transfer slice is exercised from a ring-3 program reached
through IRET, with no seeded CPL or segment-cache state. The CALL gate tests
cover same-level transfer and ring-3-to-ring-0 transfer through both GDT and
LDT gates. The inter-level cases load SP0:SS0 from a valid TSS, validate SS0, precheck both
stack spans, copy 0, 1 and 31 words in order, write the exact return link, and
publish CS:IP/SS:SP only after the frame is complete. Its RETF cases locate
the saved outer SS:SP after the copied words, apply the immediate to the
restored caller SP, and resume at the exact ring-3 successor. Both READY modes
are covered. This is valid-path evidence; failed-transfer exception delivery
is incomplete.

The test's ring-3 program executes a far CALL whose selector names a present
286 call gate in the GDT or the active LDT. The instruction's supplied offset
is ignored. Validate in Intel's documented order:

1. The gate selector is non-null and the full descriptor is within its table.
2. The descriptor is a call gate, the caller's effective privilege
   `max(CPL, selector.RPL)` is no greater than the gate DPL, and the gate is
   present.
3. The gate's target selector resolves to a code descriptor and the target is
   present. For a CALL, a nonconforming target DPL must be no greater than the
   caller CPL; a more privileged nonconforming target changes CPL to that DPL.
4. For a privilege change, select the target CPL's initial SP:SS pair from the
   current 286 TSS. The stack selector must identify a present writable data
   segment at the new CPL. Validate that the new stack has room for the saved
   link, copied parameters and return address before publishing the transfer.

For an inter-level CALL, copy the call gate's 0–31 parameter words from the
old stack to the new stack. Save the caller's SS:SP, then place the old CS and
the instruction successor IP as the return pointer. In ascending memory from
the final SP, the frame is: return IP, old CS, copied parameters in their
defined order, old SP, old SS. Zero-, one- and 31-word valid cases are covered.
Same-level gate calls do not select a new stack or copy parameters for an
outer-level transition.

The LDT-specific regression loads a valid LDT, returns to ring 3 with code and
stack descriptors in that LDT, and calls an LDT gate whose target code
descriptor is in the GDT. It verifies LDT gate lookup, GDT target lookup,
TSS-selected ring-0 stack use, the saved outer link and the LDT-backed return
through RETF in both READY modes. This establishes one valid GDT/LDT routing
case only; invalid LDT selectors and descriptor faults remain open.

## Ring-1/ring-2 stacks and conforming CALL targets

The `--call-gate-ring-levels` regression reaches ring 3 through IRET, then
calls separate DPL-1 and DPL-2 nonconforming code targets through a DPL-3
call gate. It verifies selection of the TSS `SP1:SS1` pair at base+6 and
`SP2:SS2` pair at base+10, validates the matching DPL stack descriptor before
any new-stack write, copies two parameter words, checks the complete inter-level
frame and returns to the exact ring-3 successor with `RETF 4`. All four level
and READY-mode combinations pass.

The `--call-gate-conforming` regression calls DPL-1 conforming code from CPL 3.
The final CS selector retains RPL 3 and the caller's SS:SP remain active. The
call uses the ordinary same-level return link; it performs no TSS read, new
stack write or parameter copy, even though the gate's parameter count is two.
`RETF` restores the exact ring-3 successor. Both READY modes pass. These
results establish one conforming target and DPL-1/2 nonconforming stack
selections; they do not establish every privilege combination.

Exact-source Verilator 5.052 build manifest, focused logs and full bootstrap
log are retained under
`work/callgate_ring_levels_conforming_20261026_01/`. The RTL is unchanged;
the runner fingerprint is `2616ade2c321530681c39190cb1dd89e47c7e9dc90d26697eb1a9d0b73017c9e`.

On success, commit CS/IP, CPL, SS:SP and their descriptor caches together.
Keep descriptor accessed-bit writes and accepted stack writes visible in the
bus trace. A rejected transfer must not expose partial register/cache updates.
Error codes, fault priority and any already accepted external writes must
follow the cited tables; tests must check each case rather than convert a
development stop into an architectural result.

## Rejected CALL-gate access

A separate ring-0 fixture calls through an RPL-3 selector naming a present
DPL-0 gate. The effective privilege check uses max(CPL, selector RPL), so it
delivers restartable #GP with error code 0068. A second fixture uses an
accessible DPL-0 gate with P clear and expects #NP(0068). Both cases check the
exact event frame, confirm the target code descriptor was not read, and
confirm that no partial CALL frame was written.

The same fixture checks a null gate selector (#GP(0)) and a non-null selector
beyond the GDT limit (#GP(0098)). Both fail before the gate descriptor is read.
It also presents an available-TSS descriptor in the gate slot; this raises
#GP(0068) before target lookup and leaves the descriptor unchanged. All five
gate-selector/type/access cases check their exact event frame and no partial
CALL-frame write in both READY modes.

Target validation is also checked after the gate passes its access checks. A
present data descriptor used as a code target delivers #GP(0010); a present
DPL-3 nonconforming code target called from CPL 0 delivers #GP(0038); a
non-present code descriptor delivers #NP(0098). These cases check target
descriptor byte reads, exact error frames, no TSS read before validation,
unchanged rejected descriptors and no CALL-frame writes. Added null and
out-of-GDT target selectors deliver #GP(0) and #GP(00A0) without reading a
target descriptor. The gate-access and target-fault cases pass in both READY
modes. The LDT target matrix also checks a present data descriptor (#GP(000C))
and a non-present code descriptor (#NP(000C)); invalid LDTR and out-of-limit
targets fail before LDT/TSS reads. The gate-slot matrix checks all 15 non-call
system descriptor types and a data descriptor, plus DPL/presence rejection.
Each test checks exact frames and verifies no target/TSS read or CALL-frame
write before validation.

## TSS and stack faults during an inter-level CALL

Intel Table 9-5 requires #TS with the relevant selector for a TSS shorter than
its 286 minimum or an invalid TSS-selected stack selector/descriptor. A null
SS selector uses #TS(0). A non-present new stack uses #SS(SS selector), while
insufficient space for the copied parameters and eight-byte inter-level frame
uses #SS(0) (§7.5.1.4 and §9.6.6). For an ordinary CALL, the external-event
error-code bit is clear.

The `--call-gate-tss-stack-faults` fixture reaches CPL 3 through IRET, loads a
real busy TSS, then invokes a ring-0 gate. Its nine cases expect: TSS limit 1
→ #TS(0058); null SS0 → #TS(0000); SS0 beyond the GDT → #TS(0070); code
descriptor as SS0 → #TS(0030); SS0 RPL mismatch → #TS(0028); SS0 DPL mismatch
→ #TS(0040); absent SS0 → #SS(0028); SP0 underflow → #SS(0000); and SS0 limit
too small for the frame → #SS(0000). In both READY modes, the test checks the
restartable CALL instruction state, exact error frame on the caller's stack,
TSS/SS descriptor read counts and absence of writes to the new stack. Invalid
TSS bounds are rejected before reading SP0:SS0. The successful CALL path still
publishes the new SS:SP only after all checks and frame writes.

This establishes same-level #TS/#SS handler entry while the original ring-3
stack remains usable. Privilege-changing exception entry, task-gate delivery,
handler repair/IRET for these cases and nested-fault escalation remain open.
The exact-source result and full bootstrap are recorded in
`plans/286/STATUS.md` and `work/callgate_tss_stack_faults_20261026_03/`.

## Return to the ring-3 caller

The ring-0 procedure returns through outer-level far RET. The valid tested
path uses RETF with the same byte count as the copied parameter list; that
count locates the saved outer SS:SP after the copied words, then adjusts the
restored caller SP. The return CS RPL selects the new CPL. Validate the return
code selector/descriptor and saved SS; check code type, DPL, presence, SS
writable data type, presence, selector RPL and DPL. Restore SS:SP, CS and
hidden caches. Clear DS/ES selectors and their caches when they are not valid
at the restored CPL, as required by the 286 return rules.

The `--call-gate-retf-faults` regression runs 13 invalid saved-CS/SS cases in
both READY modes. It checks #GP, #NP and #SS error selectors, exact handler
frames, no return-frame modification, CS validation before SS descriptor
reads, and SS validation before an invalid return-IP limit. One reachable
ring-0 #GP handler edits the saved outer SS selector in the current stack
frame, returns through same-level IRET, retries RETF and resumes at the exact
ring-3 caller successor with restored SS:SP. This does not cover every
privilege combination or prove the full return path.

Outer-level IRET is a separate return path for privilege-changing interrupt
and exception delivery. It uses the inter-level return checks and additionally
restores FLAGS; it is not the normal return instruction for a call gate. The
`--protected-iret-faults` regression now covers null, non-present and
system-descriptor return CS selectors, an inward return to a numerically lower
privilege level, a saved return IP beyond the selected code limit, and five
invalid outer SS cases: null, non-present, wrong-type, RPL/DPL mismatch and
selector beyond the GDT limit. It checks the documented #GP/#NP/#SS vector and
error code, exact restartable handler frame, unchanged source frame, descriptor
reads/accessed writes, and repair of the original return frame. The IP-limit
case raises #GP(0); its handler substitutes a valid return CS descriptor,
retries the faulting IRET and reaches the exact ring-3 successor. All cases
pass in both READY modes. Intel 210498-005 Tables 7-4 and 9-1 were visually
reviewed with Playwright CLI. Two current-stack cases now check the complete
five-word outer-IRET frame: an invalid starting SP faults with #SS(0) before
any source-frame read, while a frame crossing the current SS limit reads only
IP/CS/FLAGS before its full-span check faults.

Table 7-4 orders outer-return checks as current-stack bounds, return-CS
descriptor validation, outer-SS validation, then return-IP limit. The 12-
execution priority matrix pairs both current-stack bounds faults with a null
return CS (#SS first), null and non-present return-CS descriptors with a null
outer SS (#GP/#NP first), and null and non-present outer SS with an over-limit
saved IP (#SS first). The non-present SS case reports #SS(0040) after its
descriptor read. For outer IRET, the RTL checks the CS descriptor at offset zero,
deferring the saved-IP limit check until after the full frame and outer SS
validate. A valid CS descriptor may have its accessed bit set before a later
SS or IP fault. The limit fault is #GP(0); the CS/SS/SP/FLAGS return context is
not committed. Descriptor traffic, accessed-bit writes and source-frame reads
confirm each earlier fault prevents later checks. All cases pass in both READY
modes. Handler-repair boundary cases remain covered separately; broader
fault-priority combinations remain open. See the
[fault-priority report](../report/2026-10-28-protected-iret-fault-priority.md)
for exact source and run identities.

## Remaining checks

- Expand beyond the passing DPL-1/2 stack and one DPL-1 conforming target to
  additional selector, privilege and stack-boundary combinations. Invalid
  LDT target type/presence and non-call gate types, gate DPL/presence, target
  type/privilege/presence, TSS minimum, SS0 selector/type/privilege/presence
  and stack-span slices are covered above.
- Check exact descriptor reads, accessed writes, parameter reads, new-stack
  writes, final frame bytes, old/new caches and exact successor PCs in both
  READY modes, including rejected transfers and no-partial-write cases.
- Extend far RET/IRET checks to remaining selector combinations, frame bounds,
  DS/ES invalidation, and handler repair for each documented fault. The
  current RETF matrix checks exact CS/SS #GP/#NP/#SS delivery and SS-before-IP
  priority. Outer IRET now covers restartable null/inward/#NP/#GP return-CS
  cases, one over-limit return-IP #GP(0) case, and five #SS outer-return SS
  faults with handler repair/retry. Current-stack starting-SP and five-word
  frame bounds now have #SS(0) handler-repair/retry coverage; remaining
  selector/fault-priority checks are open.
- Check rejected transfers' specified exception/error code and verify that
  no denied instruction operand or stack read/write occurs before its
  documented check.
- Reachable nonzero-CPL LLDT/LTR register/memory checks now cover CPL1–3, and
  IOPL-controlled I/O/IF rules have focused executable coverage. Extend ARPL,
  VERR/VERW/LAR/LSL and remaining privilege/fault-priority matrices through
  reachable code before treating those families as complete.

This contract does not close task switching, task gates, complete protected
asynchronous recognition and vector coverage, nested-fault escalation, full
protected ISA coverage, native bus timing or the full 80286 completion ledger.
