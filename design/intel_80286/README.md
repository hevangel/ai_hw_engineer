# Intel 80286

**First introduced:** 1982. Intel dates the 80286 introduction to 1982 and
documents its adoption in IBM's PC/AT. The 286 carried protected-mode memory
management and privilege levels into the PC platform while retaining
compatibility with 8086/8088 software; these capabilities made it an important
step toward protected, multitasking personal-computer operating systems.
[Intel's 286 history](https://timeline.intel.com/1982/the-286-changes-personal-computing)
and its [1984 annual report](https://www.intel.com/content/dam/www/central-libraries/us/en/documents/2025-05/history-1984-annual-report.pdf)
describe the launch and PC/AT adoption. The manufacturer's
[80286 and 80287 Programmer's Reference Manual, order 210498-005](https://bitsavers.trailing-edge.com/components/intel/80286/210498-005_80286_and_80287_Programmers_Reference_Manual_1987.pdf)
is the primary architectural reference used for this design.

## Design status

The IBM AT's source-backed U118 refresh-detect flip-flop is modeled and
passes its standalone edge/preset test. The U68/U95 timer request and clear
chain also passes a standalone READY-stall test; complete board arbitration
and the BIOS refresh test remain open. See the
[refresh-detect report](report/2026-10-29-at-refresh-detect.md),
[request/clear report](report/2026-10-29-at-refresh-request.md), and
[combined signal-path report](report/2026-10-29-at-refresh-path.md).
The standalone path now connects those circuits through an arbiter, but its
HLDA is test-driven and Yosys reports a cross-coupled asynchronous-clear
loop. A separate native fixture now connects the path to the 286's HOLD/HLDA
and passes READY-stall and LOCK handoff tests; board synthesis, actual DRAM
refresh and BIOS integration remain open. See the
[native refresh report](report/2026-10-29-at-refresh-native.md).
The CPU can now program the connected 8254 and generate refresh-signal
handoffs in a directed native test, with six timer-write wait cycles and 32
checked memory increments. Real DRAM refresh and BIOS integration remain
open; see the [timer/native report](report/2026-10-29-at-refresh-timer-native.md).
The native timer test also observes sequential LS590 refresh-row and
memory-read signals; page mapping and DRAM are not connected. See the
[refresh-row report](report/2026-10-29-at-refresh-row.md).
The same native fixture now connects the source-backed port `61h` latch and
read buffer. A directed 286 program observes both refresh-detect states. See the
[port 61h report](report/2026-10-29-at-port61-native.md).
The unchanged IBM AT BIOS now passes its refresh-indication loop on the
native fixture in two virtual-clock/READY scenarios, with CPU state and data
transactions compared against Unicorn. Actual DRAM refresh and complete POST
remain open; see the [native BIOS report](report/2026-10-29-at-bios-native-refresh.md).
The refresh path now selects the CPU-programmed page register through the
schematic's mapper gates. DRAM attachment and DMA transfer behavior remain
unimplemented; see the [page-map report](report/2026-10-29-at-refresh-page-map.md).
The memory timing chain's initial RAS trigger is modeled and tested separately;
the bank-specific DRAM strobes remain open. See the
[RAS trigger report](report/2026-10-30-at-memory-ras-trigger.md).
The type-1 bank-select PROM wiring and latch have a separate digital test;
the original PROM content is still needed. See the
[bank selection report](report/2026-10-30-at-bank-select.md).

An IBM AT fixture connects the CPU to the shared 8254 and two 8237 register
interfaces. The unchanged BIOS passes both timer bit tests and both DMA
register tests and the page-register test under two virtual-clock/READY scenarios;
CPU instruction states and data transactions match Unicorn with recorded I/O
inputs. See the [fixture contract](spec/ibm_at_timer_fixture.md) and
[DMA fixture contract](spec/ibm_at_dma_fixture.md) and
[page BIOS report](report/2026-10-29-at-page-bios.md). Full POST and
physical board timing remain open.

The latest handler-entry regression also checks a not-present #DF target TSS:
both READY modes reach quiescent shutdown while retaining the first fault
context and leaving the rejected TSS untouched. Focused task-gate coverage
passes 32 executions; the full bootstrap reports 110 PASS lines. See the
[handler-entry report](report/2026-10-29-task-gate-handler-entry.md).

The latest task-gate audit covers a handler-entry fault: a not-present #TS
task-gate target TSS faults while delivering a contributory #TS, escalates to
#DF through a valid task gate, and the #DF handler repairs the original task
before task-IRET resumes its exact successor. Both READY policies pass. The
focused option passes 30 executions (12 event, 16 incoming-task recovery, 2
handler-entry recovery); the full bootstrap passes 110 checks. See the
[handler-entry report](report/2026-10-29-task-gate-handler-entry.md) and the
[incoming-task fault-recovery report](report/2026-10-29-task-gate-fault-recovery.md).
The issue checkpoint is [comment 6489742960](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6489742960).

The preceding task-switch audit covered the post-load incoming-task fault
path. Intel 210498-005 §8.3, printed page 8-6, says validation faults run in the
incoming task context and warns that DS/ES can hold nonzero selectors with
unusable hidden caches. The RTL now installs only validated incoming segment
caches, invalidates the rest, and clears staged caches at each new TSS load.
A directed handler test verifies the exact incoming #GP stack frame, no
outgoing-stack writes, and a follow-on #GP through rejected DS in both READY
modes. Full `scripts/run_sim.sh` passes with 198 `PASS:` lines and no
failure/error markers; the protected replay passes 79 cases in both READY
modes. Exact-source Yosys synthesis passes all 39 structural checks across 13
targets. The exact-source IBM AT REV1 BIOS reaches ROM-checksum success after
196,846 instruction states; helper, IRQ8 and system-register workloads pass.
See the [fault-context report](report/2026-10-29-task-fault-context.md) and
[escaped-defect note](../../failure_notes/2026-10-29-intel80286-task-fault-context.md).
The issue checkpoint is in
[comment 6488534632](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6488534632).
The preserved whole-core PDR is stale-source evidence; current-source
connected-core formal remains open.

The preceding task-switch audit corrected incoming validation order:
LDTR, SS, CS, DS, ES, then IP. See the
[SS-before-CS report](report/2026-10-29-task-switch-ss-before-cs.md).

The preceding step 8 audit separately fixed IP-limit validation to occur
after SS, CS, DS and ES, including the earlier null-SS/IP priority case. Its
simulation and synthesis evidence is tied to that prior source snapshot; see
the [IP validation-order report](report/2026-10-29-task-switch-ip-validation-order.md).

Table 8-1 rows 1–3 now have direct first-fault evidence for incoming TSS
presence (`#NP`), idle/busy state (`#GP`) and minimum limit (`#TS`), including
priority when a TSS is both not present and short. Six added #DF-target cases
show busy, short and not-present-plus-short target TSS descriptors enter
shutdown before task-state writes, in both READY modes. Row 13's DS TI with
null LDTR `#GP(005C)` and DS/ES GDT-limit `#GP(0188)` also cover malformed-gate
shutdown and valid #DF task-gate delivery; GDTR.limit is exactly `0187`.
The fixture correction reran all incoming CS, SS, DS, ES and LDTR limit cases
at that exact boundary. This run also confirms row 6 CS `#TS`, row 9 SS `#SS`,
row 10 SS descriptor-type `#GP` and row 12 SS selector-RPL `#SS` escalation.
Rows 4–5 now send all five invalid incoming-LDTR categories through malformed
gate #DF shutdown and valid #DF task-gate delivery in both READY modes; see
the [incoming-LDTR escalation report](report/2026-10-29-incoming-ldtr-escalation-variants.md).
Preflight, the Verilator 5.052 `-Wall` runner build, focused
`--iopl-controls`, and full `scripts/run_sim.sh` pass; the full run has 195
`PASS:` lines and no failures or errors, and protected replay passes 79 cases
in each READY mode. `playwright-cli` reviewed and captured Table 8-1 page 156.
See the [TSS preflight report](report/2026-10-29-incoming-tss-preflight-double-fault.md),
[DS/ES validity report](report/2026-10-29-incoming-ds-es-validity-double-fault.md),
and [updated Table 8-1 audit](report/2026-10-29-table-8-1-task-entry-audit.md).
Only testbench and fixture code changed, so existing synthesis remains
applicable. Current-source connected-core formal, full POST/boot and whole-CPU
acceptance remain open.

The bounded historical-software gate now passes on current source. The
unchanged IBM AT REV1 BIOS reaches its ROM-checksum success checkpoint after
196,846 exact instruction states; the original hex helper, IRQ8 handler and
system-register self-test also pass against independent traces. The runner
installs pinned Unicorn 2.1.4 into its ignored evidence directory. This does
not claim full POST or boot; see the
[current-source software report](report/2026-10-29-historical-software-current-source.md).
The OS/2 SDK 1.00 CPGREP workload still has no RTL trace.

The 2026-10-28 task-gate source audit corrected two shared oracle errors from
Intel 210498-005: task-gate CALL/JMP offsets are ignored by the 286, and a busy
incoming TSS raises #GP(incoming TSS selector), not #TS. A new exhaustive
192-execution direct task-gate matrix covers CPL 0–2, selector RPL 0–3, gate
DPL 0–3, CALL/JMP and both READY modes; it checks 104 permitted transfers and
88 exact #GP denials. A further 192-execution direct-TSS matrix covers the
same CPL/RPL range against TSS DPL 0–3 and both READY modes, checking the
`max(CPL,RPL) <= TSS_DPL` rule and 104 permitted versus 88 denied transfers;
see the [direct-TSS report](report/2026-10-28-direct-tss-privilege-matrix.md).
Incoming task entry through a non-null LDT now passes 460 valid CPL0–2
DS/ES DPL/RPL combinations satisfying `max(CPL,RPL) <= DPL`, plus eight
just-beyond-limit CS/SS/DS/ES faults. The cases check Table 8-1 exceptions,
exact successors, accessed-byte updates and no out-of-limit descriptor reads; see the
[incoming-LDT report](report/2026-10-28-incoming-ldt-privilege-limit-matrix.md)
and [incoming ES GDT-limit report](report/2026-10-28-incoming-es-gdt-limit.md).
The 26-configuration incoming segment fault matrix (52 executions) includes
an SS selector RPL mismatch that raises exact `#SS(0028)`, an ES system
descriptor that raises `#GP(0050)`, and execute-only code rejected through
both DS and ES with `#GP(0030)`; see the [DS readability report](report/2026-10-29-incoming-ds-readability-double-fault.md),
[ES readability report](report/2026-10-29-incoming-es-readability.md),
[SS RPL report](report/2026-10-28-incoming-ss-rpl-fault.md) and
[ES system-descriptor report](report/2026-10-29-incoming-es-system-descriptor.md).
Incoming-task `#TS` escalation also covers an invalid incoming CS selector: a
malformed `#TS` gate escalates to `#DF`, with both sticky shutdown and valid
`#DF` task-gate delivery checked in both READY modes. The valid path checks
the faulting TSS image, null error push and exact handler successor; see the
[incoming-CS #DF report](report/2026-10-29-protected-cs-double-fault-first-fault.md).
An incoming CS selector `0010` naming a data descriptor also raises
`#TS(0010)` under Table 8-1 row 6. Its malformed `#TS` gate escalates to
null-error `#DF`; shutdown and valid #DF task-gate delivery pass in both READY
modes with exact TSS and handler-successor checks. See the
[incoming-CS type-fault report](report/2026-10-29-incoming-cs-type-double-fault.md).
Incoming-CS `#NP` escalation now covers a non-present code descriptor at
selector `0008`; its malformed `#NP` gate escalates to `#DF`, with shutdown
and successful task-gate delivery checked in both READY modes. Playwright CLI
verified Table 8-1 row 7; see the
[incoming-CS #NP report](report/2026-10-29-protected-cs-np-double-fault-first-fault.md).
Incoming CS selector `0038` also checks Table 8-1 row 8: its RPL 0 mismatches
the present code descriptor's DPL 3 and raises `#TS(0038)`. A malformed
vector-10 gate escalates to #DF shutdown or valid task-gate delivery in both
READY modes; see the
[incoming-CS DPL/RPL report](report/2026-10-29-incoming-cs-dpl-double-fault.md).
Incoming-ES `#NP` escalation now covers non-present data selector `0020`
through both sticky shutdown and valid `#DF` task-gate delivery in both READY
modes; it checks the failed descriptor read, saved TSS image, null error push
and exact handler successor. Playwright CLI reviewed Table 8-1 row 15; see the
[incoming-ES #DF report](report/2026-10-29-protected-incoming-es-np-double-fault.md).
Incoming-ES `#GP` escalation now covers execute-only code selector `0030`,
which is valid for CS but not readable as ES under Table 8-1 row 14. Both
invalid-#DF-gate shutdown and valid #DF task-gate delivery pass in both READY
modes with exact saved TSS and handler successor checks; see the
[incoming-ES #GP report](report/2026-10-29-protected-incoming-es-gp-double-fault.md).
Incoming-DS readability now has the matching Table 8-1 row 14 `#GP(0030)`
first-fault escalation and direct transferred-task packet check. Invalid-#GP-
gate shutdown and valid #DF task-gate delivery pass in both READY modes; see
the [incoming-DS readability report](report/2026-10-29-incoming-ds-readability-double-fault.md).
An incoming ES system descriptor at selector `0050` now covers Table 8-1 row
13's `#GP(0050)` path through both shutdown and valid #DF task-gate delivery in
both READY modes; see the
[incoming-ES system-descriptor report](report/2026-10-29-protected-incoming-es-system-double-fault.md).
Incoming DS system-descriptor failure now covers the corresponding Table 8-1
row 13 case: DS selector `0050` raises `#GP(0050)` after task transfer. Both
invalid-#DF-gate shutdown and valid #DF task-gate delivery pass in both READY
modes; see the [incoming-DS system-descriptor report](report/2026-10-29-protected-incoming-ds-system-double-fault.md).
Incoming DS and ES privilege failures now cover Table 8-1 row 16: DS=`0013`
and ES=`0023` violate the CPL-0 incoming task's DPL check, raising `#GP(0010)`
and `#GP(0020)` respectively. Both invalid-#DF-gate shutdown and valid #DF
task-gate delivery pass in both READY modes; see the
[incoming-DS privilege report](report/2026-10-29-protected-incoming-ds-privilege-double-fault.md)
and [incoming-ES privilege report](report/2026-10-29-protected-incoming-es-privilege-double-fault.md).
Incoming-SS `#SS` escalation now covers a non-present stack selector `0010`;
its malformed handler gate escalates to `#DF`, with sticky shutdown and valid
task-gate delivery checked in both READY modes. See the
[incoming-SS #DF report](report/2026-10-29-protected-incoming-ss-double-fault.md).
The incoming SS read-only data case now covers Table 8-1 row 10: selector
`0010` raises `#GP(0010)` after task transfer, then escalates through a
malformed vector-13 gate to #DF. Shutdown and valid #DF task-gate delivery
pass in both READY modes; see the
[incoming-SS read-only report](report/2026-10-29-incoming-ss-read-only-double-fault.md).
Incoming SS selector `0040` also checks Table 8-1 row 12: the writable DPL-3
stack descriptor mismatches incoming CPL 0 and raises `#SS(0040)`. Its
malformed vector-12 gate escalates to #DF shutdown or valid #DF task-gate
delivery in both READY modes; see the
[incoming-SS DPL report](report/2026-10-29-incoming-ss-dpl-double-fault.md).
An incoming null SS selector now checks Table 8-1 row 9: task entry raises
`#SS(0000)` without reading the GDT null descriptor. Invalid vector-12 gate
shutdown and valid #DF task-gate delivery pass in both READY modes; see the
[incoming-SS null-selector report](report/2026-10-29-incoming-ss-null-double-fault.md).
Incoming SS selector `0188` beyond GDT limit `0187` now checks row 9's
selector-bound case as `#SS(0188)`, with no out-of-limit descriptor read.
Shutdown and valid #DF task-gate delivery pass in both READY modes; see the
[incoming-SS GDT-limit report](report/2026-10-29-incoming-ss-gdt-limit-double-fault.md).
The [Table 8-1 audit](report/2026-10-29-table-8-1-task-entry-audit.md) maps
all rows to direct fault and escalation evidence and lists remaining gaps.
The eight successful direct transfers and 900 reset cuts also pass. Full
`scripts/run_sim.sh` exits 0 with 190 `PASS:` lines, no failures/errors, and
all 79 protected replay cases pass in both READY modes. A new 384-case
reachable CPL1–3 ARPL matrix covers every source/destination RPL pair, register
and SS-memory forms, both initial ZF values and both READY modes, with exact
successors and conditional writes. Corrected-source Yosys 0.69 synthesis
completed all 13 targets; every `check -assert` reports zero problems, and all
target logs and netlists are present.

**ASSUMPTION A26 remains open:** Intel marks additional task-gate fields unused
but does not specify the 286 fault response for nonzero values. The old
whole-core PDR is still running against another 21-file snapshot; at 03:07:38 UTC
it reached frame 166 with 344/411 outputs proved and 67 timeout retries,
without terminal PASS. The source audit found 19/21 copied
inputs match current files; the top-level core and code-load module differ. See
the [PDR source-epoch audit](report/2026-10-29-pdr-source-epoch-audit.md). Current-source connected-core formal,
full POST/boot and whole-CPU acceptance remain open. See the
[task-gate source audit](report/2026-10-28-task-gate-source-audit.md),
[direct task-transfer report](report/2026-10-28-protected-direct-task-transfers.md)
and [failure note](../../failure_notes/2026-10-28-intel80286-task-gate-contract.md).
ARPL evidence is recorded in the
[reachable-privilege report](report/2026-10-28-arpl-reachable-privilege-matrix.md).
Issue #80 remains Open/Building with Codex, Path
`ai_hw_engineer/design/intel_80286`, and first Start date 2026-10-23. The
incoming-DS system-descriptor checkpoint is in
[issue comment 6485001888](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6485001888);
the latest incoming-ES privilege checkpoint is in
[issue comment 6485126780](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6485126780).
The native
CPU accepts active-low 82C284 RES through the source-backed digital synchronizer.
The protected privilege matrix verifies first-fault `#NP` and `#SS`
escalation through IDT-limit faults and post-transfer `#TS` from invalid
LDTR/CS, `#NP` from non-present CS/DS/ES, `#GP` from execute-only ES, system
descriptors in DS and ES, privilege mismatches in DS and ES, and `#SS` from
non-present SS. These
task-switch cases cover shutdown on an invalid #DF gate and successful #DF
task-gate delivery with exact faulting-TSS saves and handler successors in both
READY modes. See the [incoming-ES privilege report](report/2026-10-29-protected-incoming-es-privilege-double-fault.md).
Broader event/task fault phases, current-source
connected-core formal, authentic historical software and whole-CPU acceptance
remain open. See the [reset audit](report/2026-10-28-reset-source-audit.md)
and [#DF first-fault report](report/2026-10-28-protected-double-fault-first-faults.md),
and [direct task-transfer report](report/2026-10-28-protected-direct-task-transfers.md).

Protected outer IRET now applies Intel Table 7-4 order: current-stack frame
bounds, return-CS descriptor, outer SS, then saved-IP limit. Twelve pairwise
fault-priority executions pass in both READY modes, alongside the existing
outer-IRET repair/bounds matrix. Strict Verilator `-Wall`, preflight, the full
default bootstrap and current-source 12-target Yosys matrix pass; its 36
structural checks report zero problems. Connected-core formal and whole-CPU
acceptance remain open. See the
[outer-IRET fault-priority report](report/2026-10-28-protected-iret-fault-priority.md).

The selector regression now passes 768 reachable CPL1/CPL2 VERR/VERW/LAR/LSL
queries across writable data, readable nonconforming code, readable conforming
code, every DPL/RPL pair and both READY policies. It complements the existing
ring-0 and 160-case CPL3 query coverage; see the
[CPL1/CPL2 selector-query report](report/2026-10-28-selector-query-ring12.md).
This is focused testbench evidence, not whole-CPU acceptance.
All 12 standalone component formal configurations also pass BMC, proof and
cover on their current source inputs (36/36 tasks, 59 reached cover witnesses);
the connected-core formal and whole-CPU gates remain open. See the
[current component formal report](report/2026-10-28-formal-components-current.md).

Protected event delivery now has four reachable CPL1/CPL2 regressions (48
cases). Software `INT 13h` checks gate-DPL allow/deny boundaries and
#GP(006A); privileged LIDT #GP(0) checks exception delivery with gate DPL 0/3
and confirms the operand is not read; external INTR vector 13 and NMI vector 2
check delivery through DPL-0 gates. The tests verify TSS-selected
ring-0 stacks, exact outer frames, gate flags, interrupted-stack preservation
and IRET successors in both READY modes; the NMI cases also verify no
acknowledge transaction and unblock on IRET. The existing CPL3 event test and
full default bootstrap pass. An additional twelve-case matrix checks CPL1/CPL2
external INTR, software `INT 13h`/#GP, and NMI through a DPL-0 IDT task gate in
both READY modes, including nested TSS state, the error push, INTA/NMI block
behavior and task-IRET resumption. Other CPL1/CPL2 exception and external-
vector combinations and handler repair/IRET for other task-entry faults remain
open. See the
[CPL1/CPL2 event report](report/2026-10-28-protected-event-ring12.md) and
[task-gate event report](report/2026-10-29-task-gate-event-delivery.md) and
[fault-recovery report](report/2026-10-29-task-gate-fault-recovery.md).

Protected IOPL/IF controls are implemented for direct and string `IN`/`OUT`,
`CLI`/`STI`, POPF/IRET restoration, and protected HLT's CPL-0 privilege rule.
The combined focused regression now passes 480 scenarios, including CPL-0-only
checks for protected LGDT/LIDT/LMSW/CLTS and nonzero-CPL #GP(0) denials before
memory access. The separate selector regression also checks LLDT/LTR register
and memory faults at CPL1–3 in both READY modes. A nested #GP caused by an
IDT-limit failure during initial #GP delivery selects vector 8 with a null
error code and preserves the original context. A valid #DF task gate now
switches to a present available 286 TSS with a null LDTR, validates and stages
SS/CS/DS/ES, saves and loads the dynamic TSS state, sets busy/backlink/NT/TS,
pushes the null #DF error word, and publishes the new context atomically.
Protected IRET with NT set returns through a valid busy backlink TSS, saves
the handler's post-IRET continuation with NT cleared, clears the handler TSS
busy bit, and restores the interrupted task. The regression observes the
interrupted task fault and the handler's exact re-entry successor in both READY
modes. Invalid backlink admission now raises restartable #TS for null, LDT,
out-of-GDT, wrong-type and undersized TSS selectors; #NP for a not-present
backlink TSS; and #GP when the backlink TSS is available instead of busy. The
14-case matrix checks selector error codes and confirms no outgoing TSS save
or busy-bit clear before fault delivery, in both READY modes. Strict `-Wall`
lint, release preflight, the focused privilege/task-switch suite and the full
default bootstrap pass. Incoming task entry validates LDTR, SS, CS, DS and ES
in order and delivers the 286-specific post-transfer faults through task gates.
Eighteen descriptor-fault cases plus three pairwise priority cases pass in both
READY modes, checking exception packets, all 15 saved TSS words, backlink/busy
state and error pushes. The five incoming-LDTR cases also pass in both modes;
the GDT-limit fixture uses selector 0188 against limit 0187. No-error software
task-gate entry now fetches and executes the exact target task stream. Eight
cases vary null LDTR/DS/ES selector RPL values in both READY modes and check
visible selector preservation, no error push, backlink/busy state, no null GDT
descriptor read and sequential fetches through HLT. A present non-null LDT
descriptor now stages a hidden LDTR cache used for incoming CS/SS/DS/ES
lookup, then publishes it with the task context. A two-mode regression reads
all four eight-byte descriptors through the LDT base, checks accessed-byte
writes and cache bases, and executes the target stream. See the [no-error
task-gate report](report/2026-10-27-task-gate-noerror.md) and [non-null LDT task
report](report/2026-10-27-non-null-ldt-task-entry.md). Broader LDT descriptor,
privilege and limit combinations remain open. Current RTL SHA-256 is recorded
in the latest task status and report.
HLT and protected shutdown now have distinct `bus_halt_cycle_o` and
`bus_shutdown_cycle_o` indications at the byte-transaction boundary. They
persist while READY is low and do not issue byte requests; raw status, A1 and
ALE pins remain outside this interface. The focused suite passes 234 reset
cuts after each accepted data transfer during nested #DF task-gate entry and
replays an exact reset-vector HLT after every cut. See the [bus-cycle and
reset-cut report](report/2026-10-27-shutdown-bus-cycles.md).

The opt-in `NATIVE_BEATS` core path now reports one/two-byte physical beat
completion with 16-bit lane data. Its focused CPU simulation covers even-word
beats, two-cycle odd-word transfers, and real-mode INT 30h IVT/frame/IRET word
beats with exact data. The independent bus-owner test holds high-lane values
across READY waits. The byte-compatible default remains available. The current
`run_sim.sh` run passes with 165 PASS lines across the CPU, component,
native-beat, reset synchronizer, pin-wrapper, local 82288 and 79-case
protected-mode replay suites.
Yosys 0.69 synthesis and `check -assert` pass for the default and beat-mode cores,
components, native bus controller and integrated CPU wrapper. Exact evidence
and hashes are in the [core native-beat report](report/2026-10-28-core-native-beat-interface.md)
and [native CPU bridge report](report/2026-10-28-native-cpu-bridge.md).
`intel_80286_native_cpu` now connects the beat-mode core to the native bus
controller and a separate source-backed `intel_80286_82288` local controller.
Its Verilator pin-level test drives external `READY#`, hardware INTR/INTA, the
vector and memory data; it checks READY stalls, even/odd word lanes, the IVT,
interrupt frame, IRET, exact HLT return and each exercised 82288 command output.
The wrapper accepts processor-rate `clk_i` and explicit external 2x `clk_2x_i`;
it does not derive or phase-lock them. Its test driver now supplies the
documented 2:1 frequency relationship with a deterministic digital phase.
The `intel_80286_82c284_reset` model implements the Intersil datasheet's
falling-CLK RES synchronizer with selectable one- or two-CLK delay; both
settings pass. The native CPU wrapper routes its default two-CLK output to the
core, bus and 82288 controller, while retaining the already-conditioned RESET
input. The wrapper still receives both clocks separately; analog startup and
the clock/PCLK circuit remain unmodeled. The core
decodes explicit LOCK-prefixed memory MOV/MOVS/INS/OUTS and
rotate-memory operations, and implicit memory XCHG. The connected pin test
checks explicit MOV load/store, memory ROL, XCHG, and two iterations each of
REP MOVSB/INSB/OUTSB lock coverage through memory and I/O READY waits and
operand gaps. HOLD exclusion and release after locked operations also pass.
Automatic descriptor-table and processor-extension locks,
MULTIBUS timing, full board reset/clock timing, 80287 and physical qualification
remain open. See the [82288 controller report](report/2026-10-28-82288-local-controller.md),
[native LOCK report](report/2026-10-28-native-lock-integration.md),
[native CPU bridge report](report/2026-10-28-native-cpu-bridge.md),
[native-bus controller report](report/2026-10-28-native-bus-controller.md),
[native-clock phase report](report/2026-10-28-native-clock-phase.md), and
[82C284 reset-source report](report/2026-10-28-reset-source-audit.md).

D8 register-form ESC now sends its command and instruction pointer to the
80287's reserved I/O ports; its order is backed by physical-286 captures and a
native-bus test. The memory data channel and other ESC opcodes remain open.
See the [D8 physical-command report](report/2026-10-30-d8-physical-command.md).
The unconnected [processor-extension transfer engine](report/2026-10-30-pedc-component.md)
has separate component tests; it is not yet an operational CPU data channel.

Full-core Yosys 0.69 synthesis passes `check -assert` with zero problems. The
pre-correction connected-core depth-24 BMC passed, but its property snapshot
is stale after the HLT/shutdown correction. The corrected depth-12 prove
passes its base case and returns UNKNOWN on induction at lines 525 and 775.
The old connected-core cover snapshot stopped with SBY `ERROR`/rc=16 after
Yices did not return a status; its recorded reach count was 45/73. That
snapshot predates the native-beat changes and is not current-source evidence.
See the
[incoming-segment report](report/2026-10-27-incoming-segment-faults.md),
[incoming-LDTR report](report/2026-10-27-incoming-ldtr-faults.md),
[task-return fault report](report/2026-10-27-task-return-faults.md),
[task-IRET report](report/2026-10-27-task-iret.md),
[task-gate switch report](report/2026-10-27-task-gate-switch.md),
[historical task-gate preflight report](report/2026-10-27-task-gate-preflight.md),
[double-fault report](report/2026-10-27-double-fault-escalation.md),
[double-fault shutdown checkpoint](report/2026-10-27-double-fault-shutdown.md),
[protected shutdown NMI recovery report](report/2026-10-27-shutdown-nmi-recovery.md),
[bus-cycle and reset-cut report](report/2026-10-27-shutdown-bus-cycles.md),
[native-bus controller report](report/2026-10-28-native-bus-controller.md),
[core native-beat interface report](report/2026-10-28-core-native-beat-interface.md),
[system-instruction privilege report](report/2026-10-27-system-instruction-privilege.md),
[LLDT/LTR privilege report](report/2026-10-27-lldt-ltr-privilege.md),
[HLT privilege report](report/2026-10-27-hlt-privilege.md), and
[current task status](../../plans/286/STATUS.md). The initial #GP-to-#DF
transition, first-handler gate escalation and bounded shutdown response are
implemented. Protected NMI now leaves shutdown only after its gate and frame
commit; an NMI-delivery fault returns to RESET-only shutdown. The external
interface distinguishes HLT from shutdown at the transaction abstraction.
The full double-fault classification and delivery matrix, raw bus-pin cycles,
task-IRET reset cuts, current-source connected-core proof, historical software
and full-chip acceptance remain open. The NMI suite, privilege/task suite and
full bootstrap pass; event-controller BMC, k-induction and cover pass on the
component snapshot. Reports record exact hashes and scope.

This repository contains a developing synthesizable 80286 core, component and
CPU formal properties, and directed regression infrastructure. Protected-mode
execution remains incomplete. The core reaches and executes ring 3 through a
valid outer IRET, performs same-level GDT and LDT-resident CALL gates, then
calls from ring 3 to ring 0 using the TSS stack. The GDT gate regression checks
parameter counts 0, 1 and 31; the LDT fixture checks an LDT-backed ring-3
caller, an LDT gate targeting GDT code, and outer RETF. All paths check exact
frame contents in both READY modes. Ring-0 gate-selector checks verify #GP
for null and out-of-limit selectors without a descriptor read. A present
available-TSS descriptor in the gate slot also verifies #GP before target
lookup. Gate access checks verify #GP for a DPL violation and #NP for a
non-present gate before target lookup. Target checks verify #GP for a data
descriptor, #GP for a DPL-3 nonconforming target from CPL 0, and #NP for a non-present code
descriptor before TSS lookup or CALL-frame writes. Target-selector checks also
verify #GP(0) for null, #GP(00A0) for an out-of-limit target, and descriptor
faults. LDT targets cover invalid LDTR, out-of-limit, present data and
non-present code descriptors. The gate-selector matrix rejects all 15
non-call system descriptor types and a data descriptor, plus DPL/presence
violations. Tests check exact frames, descriptor reads and no target/TSS reads
or CALL-frame writes before validation. The `--call-gate-tss-stack-faults`
suite covers nine invalid TSS stack conditions, including short TSS,
null/out-of-table/wrong-type/privilege-invalid SS0, absent SS0 and insufficient
SP0/limit. It checks #TS/#SS codes and exact caller-stack frames, confirms no
new-stack CALL writes, and passes in both READY modes.

The `--call-gate-retf-faults` suite checks 13 invalid outer-return cases in
both READY modes. It verifies exact #GP/#NP/#SS packets and frames, return-CS
validation before saved-SS reads, and saved-SS validation before the return-IP
limit check. A reachable #GP handler repairs the saved outer SS selector,
returns with IRET, retries RETF and resumes the ring-3 caller at the exact
successor.

The recorded Verilator 5.052 `--build -j 2 -Wall`, focused RETF fault and
repair tests, ring-1/ring-2 and conforming-target CALL-gate tests, full
bootstrap, 79-case protected replay, and Yosys 0.69 full-core
synthesis/`check -assert` pass for the earlier RTL snapshot
`cbde2d3ceea2179cf75a73ac4973d6b1ef06ef4742a58f44f77566fa00b6c865`.
Ring-1/2 cases verify SP1:SS1 and SP2:SS2, exact inter-level frames, copied
parameters and RETF restoration. The conforming target preserves CPL 3 and
the caller stack without TSS access or parameter copying. The synthesis has
37,493 cells and zero check problems. Runner evidence is under
`work/outer_retf_faults_20261026_08/`; synthesis log and JSON netlist are
under `work/outer_retf_faults_20261026_06/synth/`. The replay manifest is
under `work/callgate_outer_retf_replay_20261026_01/`. All 15 protected-string
mutants are detected against that manifest in
`work/outer_retf_current_mutations_20261026_01/`. The earlier connected-core
depth-24 BMC passed `PASS 0 2009` under
`work/formal_runs/outer_retf_formal_20261026_01/core_bmc/` with an older
property hash. Those replay, synthesis, mutation and BMC results do not qualify
the newer protected-event RTL. The new call-gate regression evidence is under
`work/callgate_ring_levels_conforming_20261026_01/`; the testbench-only update
does not change the formal core/property hashes. Earlier focused evidence
paths are preserved under their original names.

The selector regression now adds eight reachable CPL3 LLDT/LTR checks across
register and memory operands and both READY modes. Each raises #GP(0) before
operand/descriptor/TSS traffic, preserves LDTR/TR, and returns through a
same-level handler to the exact successor. The focused selector suite and full
bootstrap pass under `work/selector_privilege_20261026_02/`; RTL and formal
property hashes are unchanged.

The earlier protected-event milestone used RTL SHA-256
`7ad3e9a821f87640c632bfef1294a612a091617b7a9a7e88692c2eee9e97cea1` with CPU
properties SHA-256
`0a05576210b770e0647ad2e7615402476ad5cd86b3608cfaf79be69eb9e32703`. The
eight-case CPL3 interrupt/trap-gate suite, four invalid protected-decode cases,
strict build and full bootstrap passed in both READY modes. Five event-path
mutations and the cached-permission mutation are detected by the matching
focused suites. Evidence is under
`work/protected_event_outer_20261026_07/` and
`work/protected_event_mutations_20261026_04/`; the
[event-gate report](report/2026-10-26-protected-event-gates.md) records exact
hashes and limits. The first depth-24 core BMC passed through 24 frames on the
pre-refinement property snapshot. Run `_21` also passed a depth-24 ABC BMC
through 24 frames (`PASS 0 2055`) under
`work/formal_runs/protected_event_outer_20261027_21/core/intel_80286_bmc/`.
The 36 component formal tasks and 37/40 aggregate audit belong to that run
snapshot. Core prove `_21` returned `UNKNOWN` at line-160 induction, repeating
`_20`; its cover and PDR jobs remain active on earlier sources. The `_21` CPU
properties had SHA-256
`5055f212d8397f2505bf6e6c681758146547167cb4b942e785564f988ea2e874` (290
assertions, one assumption and 49 covers). Depth-12 prove `_20` passed the
base case but returned `UNKNOWN` at induction under
`work/formal_runs/protected_event_outer_20261026_20/core_prove/`. Its witness
starts in `CODE_LOAD_WAIT` with PE clear and violates the PE ownership invariant.
Runs `_12`–`_20` passed their base cases and returned `UNKNOWN` at induction;
no reset-reachable counterexample has been established. Event packet validity,
TSS stack ownership, protected descriptor waits and far-return continuations
now have explicit properties. No current-snapshot induction proof has passed;
the fresh `_21` run repeats the `_20` line-160 induction-only failure. Core
cover is running, and PDR and aggregate exact-source audit remain open. Yosys
0.69 synthesis and `check -assert`
pass on the same current RTL snapshot with zero check problems and 40,652
cells on that event-gate RTL; the hash manifest, log and JSON netlist are in
`work/protected_event_outer_20261026_01/synthesis/`.

Task-gate delivery and bounded task switching are implemented for directed
paths. Broader failed-delivery escalation, NMI wake and native shutdown bus
signaling, #TS/#SS recovery, broad exception coverage, independent historical
software, the aggregate release gate and the complete native pin protocol remain
open. The IOPL/IF slice now has focused coverage, but native I/O timing and
other protected privilege rules remain open. These tests do not represent a
finished 80286. See the active
[continuation status](../../plans/286/STATUS.md) and
[progress audit and revised plan](../../plans/286/2026-10-26-audit-and-revised-plan.md)
for hashes, evidence boundaries and next work.
## Relevant documents

- [Processor specification](spec/spec.md)
- [Native 80286 local-bus interface contract](spec/native_bus_interface.md)
- [Ring-0 protected-mode integration contract](spec/protected_mode_integration.md)
- [Protected IOPL and FLAGS contract](spec/iopl_control.md) and
  [focused regression report](report/2026-10-27-iopl-controls.md)
- [Protected outer-IRET and call-gate contract](spec/protected_privilege_transition.md)
- [CPL1/CPL2 protected-event regression](report/2026-10-28-protected-event-ring12.md)
- [Selector-register execution scope and limits](spec/selector_execution.md)
- [Implementation plan](plans/implementation_plan.md)
- [Completion requirements](plans/completion_requirements.md)
- [Worktree recovery report](report/2026-10-24-worktree-recovery.md)
- [Protected INS correction and verification](report/2026-10-25-protected-ins.md)
- [MOVS/STOS/OUTS correction and verification](report/2026-10-25-protected-strings.md)
- [CMPS fault repair and verification](report/2026-10-26-protected-cmps.md)
- [Current progress audit and revised plan](../../plans/286/2026-10-26-audit-and-revised-plan.md)
- [CPU formal harness](formal/intel_80286.sby)
- [Reset-reachable PDR harness](formal/intel_80286_pdr.sby)
- [Protected-mode directed fixture](tb/protected_mode_fixture.h)
- [Protected-mode replay test](tb/protected_mode_replay.cpp) and
  [runner](scripts/run_protected_mode_replay.sh)
- [Protected string fixture](tb/protected_string_replay.h)
- [Protected string mutation checks](scripts/run_protected_string_mutations.py)
  (includes the [INS checks](scripts/run_protected_ins_mutations.py))
- [INS fault-state escaped defect](../../failure_notes/2026-10-25-intel80286-ins-fault-state.md)
- [Full 80286 continuation plan](../../plans/286/README.md)
- [Current continuation status](../../plans/286/STATUS.md)

The Intel 80286 was introduced in 1982; no more precise month is claimed here.

## Focused protected-mode regression

From the tool container with this worktree mounted at `/work`:

```sh
bash design/intel_80286/scripts/run_protected_mode_replay.sh my-new-run
python3 design/intel_80286/scripts/run_protected_string_mutations.py \
  design/intel_80286/work/my-new-run/build_manifest.json my-new-mutation-run
```

Use a fresh name for each run; existing evidence directories are preserved.
The replay checks same-level #GP/IRET recovery and reset cuts, plus protected
INSB/INSW/REP INSW destination faults and MOVS/STOS/OUTS memory faults with
native index/count repair, exact prefix restart, byte transfers and READY
stalls. Backward word and 64K-wrap scenarios exercise the latter families.
CMPS memory-fault repair has directed coverage; SCAS fault behavior, native
per-beat ordering, A20 port timing, broader privilege behavior and the full
release gate remain open. See the IOPL report for the bounded IOPL/IF slice.
