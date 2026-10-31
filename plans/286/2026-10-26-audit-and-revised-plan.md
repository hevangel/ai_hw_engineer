# Intel 80286 progress audit and revised plan

## WAIT single-step priority and refresh page — 2026-10-30

Connected-core BMC reached a step-20 WAIT/interrupt/TF counterexample. The
core boundary fix passes exact-PC directed tests and lint; source-matched
formal, synthesis, full simulation and software checks are running.
The refresh page-map gate model and BIOS integration pass independently,
but real DRAM and DMA bus ownership remain open. See the
[page-map report](../../design/intel_80286/report/2026-10-29-at-refresh-page-map.md).

## Native BIOS refresh-indication checkpoint — 2026-10-29

The unchanged BIOS reaches `F000:03A2` through its original refresh-detect
loop on the native CPU/8254/partial-refresh fixture. Both virtual-clock/READY
scenarios and per-instruction Unicorn comparisons pass. Next connect refresh
page addressing and a real DRAM-facing
model, qualify bus/clock timing and extend POST through the next hardware
boundary. See the [native BIOS report](../../design/intel_80286/report/2026-10-29-at-bios-native-refresh.md).

## Native port 61h checkpoint — 2026-10-29

Port `61h` now reads the source-backed latch and refresh-detect signal in
the native directed fixture. A CPU program observed both bit states while
performing 32 exact memory increments. The BIOS runner is now integrated with
the native bus and DMA/page register devices; the original refresh-indication
loop passes in two virtual-clock scenarios. Page addressing, DRAM
retention, physical timing and full POST remain separate open requirements.
See the [port report](../../design/intel_80286/report/2026-10-29-at-port61-native.md).

## Refresh component and formal status — 2026-10-29

The source-backed U118 refresh-detect flip-flop and U68/U95 request/clear
chain now have standalone simulation and structural checks and connect to the
directed native fixture. A combined signal path through U69/U90/U98 now
passes a standalone test, with a Yosys warning on the cross-coupled asynchronous
clears. Native HOLD/HLDA is now connected and passes a directed READY/LOCK
handoff test. A directed native test now programs the shared 8254 and connects
OUT1 to the refresh path. LS590 row and LS125 memory-read drive are now
connected and tested; port B is connected in that fixture. Next integrate the
native path with the BIOS fixture, page addressing and DRAM refresh behavior
before extending BIOS POST. See the
[component report](../../design/intel_80286/report/2026-10-29-at-refresh-detect.md).

The earlier current-source PDR terminated with a WAIT/event assertion failure.
The counterexample was analyzed, the properties corrected and matching CPU
race regressions passed. The next BMC found an outdated state bound on WAIT;
the bound is corrected. The next BMC and earlier PDR both failed on the
WAIT/extension-error and NMI race. The RTL correction passes full simulation
and the historical-software regression; synthesis, BMC and PDR are running. Induction, cover and
the full formal audit remain open. See the
[formal report](../../design/intel_80286/report/2026-10-29-wait-event-formal.md).

## DMA page-register BIOS checkpoint — 2026-10-29

The 80286/8254/8237 fixture now includes explicit CPU-visible page registers.
The unchanged BIOS reaches `F000:038A` after testing `81h`–`8Fh`, with 3,573
page reads in each READY scenario. The complete software entry point passes,
and Unicorn matches 247,196 and 1,295,769 CPU states with captured I/O inputs.
The standalone fixture checks slot isolation and READY stalls. The next BIOS
test reads port `61h` bit 4 for the refresh indication; the fixture still
returns a static host-port value and has no refresh or bus arbitration. Source
and connect the refresh indication, DMA-side page mapping and bus arbitration
before claiming that test. The following stage exercises the 8042 keyboard
controller. See the [page BIOS report](../../design/intel_80286/report/2026-10-29-at-page-bios.md)
and [DMA fixture contract](../../design/intel_80286/spec/ibm_at_dma_fixture.md).
The checkpoint is [issue comment 6491652810](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6491652810).

## DMA-register BIOS checkpoint — 2026-10-29

The 80286 fixture now connects two 8237 register interfaces. Both READY modes
reached `F000:0302` after the BIOS DMA register tests; the always-ready trace
matched Unicorn for 197,920 instruction states. The recovered stalled trace
also matches 1,246,493 states. The full software entry point passed in
`codex-intel286-dma-software-20261029-01`. The previous PDR container is absent;
a later current-source PDR failed as recorded above. See
the [DMA BIOS report](../../design/intel_80286/report/2026-10-29-at-dma-bios.md).
The checkpoint is [issue comment 6491502332](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6491502332).
Next: implement the source-backed AT DMA page registers: the next BIOS test
uses `81h`–`8Fh`, while the generic host-port array currently only stores bytes.
IBM's channel-to-page mapping and remaining decode questions are in the
[DMA fixture contract](../../design/intel_80286/spec/ibm_at_dma_fixture.md).
Then connect refresh and DMA arbitration; the current fixture covers register
I/O only.

## Both channel-1 timer tests — 2026-10-29

The connected CPU/8254 BIOS regression now reaches `F000:027B` after both
channel-1 bit tests. Two virtual-clock/READY scenarios match Unicorn for
197,002 and 1,245,575 CPU instruction states and their data transactions using
recorded I/O inputs. Full `run_software.sh` passes with source hashes checked.
Next, implement the board components needed for the subsequent DMA tests;
full POST and real timing remain open. See the
[connected BIOS report](../../design/intel_80286/report/2026-10-29-at-timer-bios.md).
The checkpoint is [issue comment 6490338942](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6490338942).

## Connected 8254 BIOS regression — 2026-10-29

Connected the 80286 fixture to the existing 8254 RTL. The unchanged IBM AT
BIOS reaches `F000:0258` after its first channel-1 timer test. Two virtual
clock/READY scenarios match Unicorn for 196,889 and 1,245,453 CPU instruction
states and data transactions using captured I/O inputs. The full software
entry point passes and includes these runs. See the
[connected BIOS report](../../design/intel_80286/report/2026-10-29-at-timer-bios.md)
and [issue checkpoint](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6490277004).
Next: continue the remaining timer tests and add the board devices needed for
later POST; establish native clock and bus evidence independently.

## IBM AT timer fixture — 2026-10-29

The 1984 IBM 5170 reference identifies the 8254-2, timer clocks and gate/output
wiring. A standalone adapter around the existing timer RTL now passes a
READY-stall and independent counter-clock check for canonical ports `40h`–`43h`.
Next connect it to accepted 80286 fixture I/O, define an explicit virtual clock
schedule, and compare CPU execution with an independent oracle using captured
I/O events. The adapter is not yet connected to the CPU or a full AT board.
See the [fixture report](../../design/intel_80286/report/2026-10-29-at-timer-fixture.md)
and [issue checkpoint](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6490068444).

## Current-source BIOS refresh and POST boundary — 2026-10-29 06:43 UTC

The bounded IBM AT BIOS suite passes again after the task-gate RTL change:
196,846 independently checked instruction states through checksum success,
plus helper, IRQ8 and system-register checks. All 38 manifest sources match.
An exploratory oracle-only run past that point reaches its 500,000-instruction
bound in the ROM's timer polling loop because the fixture supplies a static
port `41h` value. Next, specify and integrate a source-backed timer model and
continue POST with the required machine devices. See the
[software report](../../design/intel_80286/report/2026-10-29-historical-software-current-source.md)
and [issue checkpoint](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6489942100).
Reuse candidate: `design/intel_8253_8254/src/intel_8253_8254.sv` already
implements the timer programming interface, and `system/ibm_pc/src/ibm_pc.sv`
shows an existing integration. Before using it for the AT, source the exact
5170 timer variant, port decoding, clock and gate wiring, and define how the
CPU fixture advances peripheral time. Its sampled-clock digital abstraction
does not by itself establish authentic board timing.

## #DF target shutdown — 2026-10-29 06:40 UTC

Extended the preceding handler-entry scenario with a not-present #DF target
TSS. Both READY modes reach quiescent shutdown with the first fault context,
task links and rejected TSS intact. The focused task-gate option passes 32
executions and full bootstrap reports 110 PASS lines; the follow-up changes the
testbench only. See the [handler-entry report](../../design/intel_80286/report/2026-10-29-task-gate-handler-entry.md).
The issue checkpoint is [comment 6489860781](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6489860781).

## Task-gate handler-entry fault recovery — 2026-10-29 06:31 UTC

Added two executions, one for each READY policy, where external INTR enters a
task with null CS and the subsequent #TS task-gate target TSS is not present.
That contributory-exception delivery fault now escalates to #DF through a
valid #DF task gate. The #DF handler repairs the original TSS CS, task-IRETs to
the first task, and checks its exact NOP/HLT successor. The focused task-gate
option passes 12 event cases, 16 incoming-task recovery executions and these 2
handler-entry recoveries; full bootstrap passes 110 checks. RTL changed. Source
review used Playwright CLI on Intel 210498-005 Table 9-3 / §9.6.2 pages 171–172.
See the [handler-entry report](../../design/intel_80286/report/2026-10-29-task-gate-handler-entry.md).
The issue checkpoint was posted and read back in [comment 6489742960](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6489742960).

**Next:** expand task-gate handler-entry coverage to other fault types and
faults while entering the #DF handler, while pursuing current-source
connected-core formal and end-to-end software/native-interface gates. Keep the
whole-CPU completion claim open until all requirements are met.

## Previous checkpoint — 2026-10-29 06:00 UTC

## Task-gate fault recovery — 2026-10-29 06:00 UTC

Expanded repair-and-IRET coverage to eight incoming-task selector faults under
both READY policies (16 recovery executions): null, wrong-type and not-present
CS; null and not-present SS; not-present DS/ES; and wrong-type LDTR. A second
task gate enters a valid handler task, which repairs the selector in the
faulting task's saved TSS and task-IRETs back. Checks cover event packets and
error codes, TSS context, backlinks, busy bits, error pushes, repair writes,
restored selectors and the exact resumed successor. The focused event/recovery
option passes 28 executions and the full bootstrap passes 109. No RTL changed.
The manual review used Playwright CLI on 210498-005 pages 156–157. See the
[fault-recovery report](../../design/intel_80286/report/2026-10-29-task-gate-fault-recovery.md)
and [issue comment 6489249590](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6489249590).

**Next:** cover faults during task-gate handler entry. Current-source
connected-core formal, full POST/boot, OS/2 CPGREP on RTL, native-interface
qualification and whole-CPU acceptance remain open.

## IDT task-gate event delivery — 2026-10-29 05:41 UTC

**Previous checkpoint:**

Extended `--protected-event-task-gate` to 12 CPL1/CPL2 cases over both READY
policies: external INTR, software `INT 13h`/#GP, and NMI. The DPL-0 task gate
accepts external INTR and NMI without error words; INTR acknowledges once,
while NMI has no INTA, is blocked on task entry, and is released by task IRET.
Software INT raises #GP with error `006A`, then exception delivery enters that
task gate and places the error word on the incoming stack. Checks cover saved
TSS context, backlink, busy/NT/TS, packet fields, stack preservation and exact
task/handler successors. Intel 210498-005 §9.4 and Table 9-1 were reviewed via
Playwright CLI. No RTL changed.

Fresh Verilator 5.052 `-Wall` runner fingerprint `e5d7f7f02ff5`: the focused
matrix passes 12/12, the existing CPL1/CPL2 external interrupt/trap-gate
matrix passes 8/8, and the full bootstrap has 108 PASS lines with no
FAIL/ERROR markers. Reproduction, hashes and scope are in the
[task-gate event report](../../design/intel_80286/report/2026-10-29-task-gate-event-delivery.md).
The expanded issue checkpoint is [comment 6489004572](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6489004572).

**Follow-up completed by the 05:54 checkpoint:** added task-gate `#TS`/`#SS`
delivery with handler repair, task IRET and exact successor checks. See the
[task-gate fault-recovery report](../../design/intel_80286/report/2026-10-29-task-gate-fault-recovery.md).

## Incoming-task validation-fault context — 2026-10-29 05:09 UTC

Intel 210498-005 §8.3, printed page 8-6, says the incoming task's registers
are loaded before its LDT and segment checks finish, so faults during those
checks run in the incoming task context. It also warns that DS/ES selectors
can be nonzero while their hidden caches are unusable. The previous
`task_entry_fault_context` path updated visible state but retained outgoing
segment caches. A #GP handler could therefore use the outgoing SS base for its
incoming SP and read outgoing data through rejected DS. The pre-fix unstalled
case reproduced the wrong stack path.

The RTL now installs only successfully validated incoming segment/LDTR caches,
invalidates the others, sets `cs_trusted` only after CS validation and clears
staged caches on each new TSS load. The directed handler regression checks the
exact incoming #GP frame and a subsequent #GP through rejected DS, with no
outgoing-stack write or outgoing-DS read, in both READY modes. The generic
testbench cache invariant now permits this Intel-defined partial context
transition before the event pulse.

Exact-source simulation passed 198 checks; protected replay passed 79 cases
in both READY modes. Exact-source synthesis passed all 13 Yosys targets and
39 structural checks. The unchanged IBM AT REV1 BIOS passed 196,846 exact
instruction states to ROM-checksum success; helper, IRQ8 and system-register
workloads passed. Detailed hashes and limits are in the
[fault-context report](../../design/intel_80286/report/2026-10-29-task-fault-context.md).
The issue checkpoint was posted and read back in
[comment 6488534632](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6488534632).
The escaped defect and prevention rule are recorded in
[`failure_notes/2026-10-29-intel80286-task-fault-context.md`](../../failure_notes/2026-10-29-intel80286-task-fault-context.md)
and `AGENTS.md`.

**Next:** continue the section 8 task-switch partial-state/order audit. Preserve
the whole-core PDR on its stale snapshot; its last recorded state was frame
166 with 344/411 outputs proved and 67 timeout retries. Do not count it as
current-source connected-core proof. Full POST/boot, OS/2 CPGREP on RTL,
current-source connected-core formal and whole-CPU acceptance remain open.

## Previous activity — Incoming task descriptor validation order — 2026-10-29 04:22 UTC

Playwright CLI review of Intel 210498-005 section 8.3 step 7 showed that
incoming selectors must be checked SS, CS, DS and ES. A combined-fault test
reproduced the old CS-before-SS behavior: invalid CS selected `#TS(0010)` over
the architecturally earlier `#SS(0188)`. The task-entry state machine now
validates LDT, SS, CS, DS, ES, then IP. The expanded LDT matrix checks
descriptor read/accessed-bit order and partial effects; additional cases prove
invalid LDT precedence and incoming IP ordering in both READY modes.

Exact-source `scripts/run_sim.sh` passes with 197 `PASS:` lines and no
`FAIL:`/`ERROR:` markers (Verilator 5.052; log SHA-256
`d10cf39693bd94902bfe55f5272eef24cc3af5f16656776e4f2ee227d9705548`). All
13 exact-source Yosys synthesis targets complete, emit JSON netlists and pass
three structural checks each (39 checks, no errors; log SHA-256
`4c589f259e1325633250035895ac8d5889d29bc6c42433bc2029e027bc0e1f17`). The
current-source code-load component passes BMC, k-induction and cover with eight
cover witnesses. A fresh BIOS replay also passes 196,846 exact instruction
states through checksum success, plus the hex-helper, IRQ8 and system-register
workloads. Evidence and limitations are in the
[SS-before-CS report](../../design/intel_80286/report/2026-10-29-task-switch-ss-before-cs.md).
The current project fields were verified and the checkpoint was posted to
[issue #80](https://github.com/hevangel/ai_hw_engineer/issues/80) in
[comment 6487916045](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6487916045).

**Next:** continue review of task-switch partial state/order against the
manual, then reconcile and rerun connected-core formal after the preserved
whole-core PDR finishes. That PDR is still active at frame 166 (344/411 outputs
proved, 67 timeout retries) on stale source; do not count it as current-source
proof. Full POST/boot, OS/2 CPGREP on RTL and whole-CPU acceptance remain open.

## Incoming task IP validation order — 2026-10-29 03:30 UTC

Playwright CLI review of Intel 210498-005 section 8.3 step 8 showed that the
incoming IP limit check belongs after incoming SS, CS, DS and ES validation. Four
cases reproduced the previous priority error and now pass: null SS plus
out-of-limit IP selects `#SS(0)`; valid SS plus out-of-limit IP selects
`#GP(0)`, with both READY policies. The full simulation has 196 passing checks
and no failure/error markers. All 13 Yosys 0.69 synthesis targets pass with
three zero-problem checks each. See the
[validation-order report](../../design/intel_80286/report/2026-10-29-task-switch-ip-validation-order.md).
The checkpoint was posted and read back in
[issue comment 6487134519](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6487134519).

**Next:** preserve the active PDR on its stale snapshot. Its latest log is
frame 166 with 344/411 outputs proved and 67 timeout retries; its two differing
RTL files still prevent it from proving this source. Once that process
terminates, refresh connected-core formal from current source. Meanwhile
continue the section 8 task-switch audit for remaining ordering and partial
state cases; keep full POST/boot, OS/2 CPGREP on RTL and whole-CPU acceptance
as separate release gaps.

## Current-source IBM AT software regression — 2026-10-29 02:50 UTC

Fixed `scripts/run_software.sh` to provision its pinned Unicorn 2.1.4
dependency into the ignored work directory. The exact-source run completed
twice in the repository Docker image; the verified run exited 0. The unchanged
IBM AT REV1 BIOS passed 196,846 exact instruction states through its ROM
checksum success checkpoint. The original BIOS hex helper passed 16 cases /
464 states, eight IRQ8 timer cases passed across 236 exact handler states, and
the system-register self-test passed four patterns / 164 states. This closes
the bounded current-source IBM AT CPU regression, not full POST or boot. See
the [software report](../../design/intel_80286/report/2026-10-29-historical-software-current-source.md)
and evidence in
`design/intel_80286/work/historical_software_current_20261029_23/`.
The checkpoint was posted and read back in
[issue comment 6486536094](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6486536094).

**Next:** keep the active stale-source PDR undisturbed and inspect its status
until it terminates; it remains at frame 118 with 343/411 outputs proved and
50 timeout retries. Then refresh connected-core formal from current source.
While it runs, audit direct task-transfer fault/restart phases and prioritize
missing source-backed partial-switch cases. Keep full POST/boot and OS/2 SDK
1.00 CPGREP as separate software acceptance gaps.

## Incoming-SS GDT-limit #SS double-fault escalation — 2026-10-29 01:58 UTC

Added four post-transfer incoming-SS GDT-limit executions for Intel 210498-005
Table 8-1 row 9. With GDT limit `0187`, selector `0188` raises `#SS(0188)`
without an out-of-limit descriptor read. A malformed vector-12 gate selects
null-error `#DF`; invalid-vector-8 shutdown and valid #DF task-gate delivery
pass in both READY modes. Tests check both gate lookups, exact saved TSS state,
backlink/busy state, null error push, shutdown quiescence and handler successor.
Playwright CLI verified the source table on printed page 8-6 (PDF page 156).
See the [incoming-SS GDT-limit report](../../design/intel_80286/report/2026-10-29-incoming-ss-gdt-limit-double-fault.md).

Preflight, the exact-source Verilator 5.052 `-Wall` build and focused
`--iopl-controls` pass. Full simulation exits 0 with 190 `PASS:` lines and no
failures/errors; protected replay passes 79 cases in both READY modes. Evidence
is under `design/intel_80286/work/incoming_ss_gdt_limit_double_fault_20261029_15/`.
RTL is unchanged, so prior synthesis remains applicable. The preserved whole-
core PDR remains active on a separate 21-file snapshot and is not current-source
proof. The Table 8-1 audit maps rows 1–5 to existing preflight and incoming-LDTR
tests; see the [audit report](../../design/intel_80286/report/2026-10-29-table-8-1-task-entry-audit.md).
Remaining selector variants and whole-CPU acceptance remain open. Issue
readback confirms Building with Agent Codex, Path
`ai_hw_engineer/design/intel_80286`, and first Start date `2026-10-23`; see
[checkpoint comment 6485805280](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6485805280).

**Next:** close the remaining source-backed escalation variants: CS GDT-limit
`#TS`, SS code-type `#GP`, SS selector-RPL `#SS`, DS TI with null-LDTR `#GP`,
and DS/ES GDT-limit `#GP`. Then review the pre-transfer rows for defined
double-fault behavior and continue the other task-entry fault phases.

## Incoming-CS DPL/RPL #TS double-fault escalation — 2026-10-29 01:51 UTC

Added four post-transfer incoming-CS privilege-fault executions for Intel
210498-005 Table 8-1 row 8. Incoming selector `0038` has RPL 0 and names a
present DPL-3 code descriptor, so task entry raises `#TS(0038)`. A malformed
vector-10 gate selects null-error `#DF`; invalid-vector-8 shutdown and valid
#DF task-gate delivery pass in both READY modes. Tests check the rejected code
descriptor read, both gate lookups, the saved faulting TSS, backlink/busy
state, null error push, shutdown quiescence and exact handler successor.
Playwright CLI verified the source row on printed page 8-6 (PDF page 156). See
the [incoming-CS DPL/RPL report](../../design/intel_80286/report/2026-10-29-incoming-cs-dpl-double-fault.md).

Preflight, the exact-source Verilator 5.052 `-Wall` build and focused
`--iopl-controls` pass. Full simulation exits 0 with 189 `PASS:` lines and no
failures/errors; protected replay passes 79 cases in both READY modes. Evidence
is under `design/intel_80286/work/incoming_cs_dpl_double_fault_20261029_14/`.
RTL is unchanged, so prior synthesis remains applicable. The older whole-core
PDR remains active on its separate 21-file snapshot and is not current-source
proof. Current-source connected-core formal, authentic historical software,
remaining Table 8-1 gaps, other task-entry fault phases and whole-CPU acceptance
remain open. Issue readback confirms Building with Agent Codex, Path
`ai_hw_engineer/design/intel_80286`, and first Start date `2026-10-23`; see
[checkpoint comment 6485730211](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6485730211).

**Next:** finish the source-by-source audit of Table 8-1 rows 1–5 and the
remaining CS/SS/DS/ES selector fault variants. Compare each direct fault case
with its current escalation coverage and add only meaningful missing paths.
Preserve the active PDR and defer connected-core formal until it terminates.

## Incoming-SS null-selector #SS double-fault escalation — 2026-10-29 01:43 UTC

Added four post-transfer incoming-SS null-selector executions for Intel
210498-005 Table 8-1 row 9. A null SS selector raises `#SS(0000)` and causes no
GDT null-descriptor read. A malformed vector-12 gate selects null-error `#DF`;
invalid-vector-8 shutdown and valid #DF task-gate delivery pass in both READY
modes. Tests check the faulting task state, both gate reads, backlink/busy state
on task delivery, null error push, shutdown quiescence and exact handler
successor. Playwright CLI reviewed the table on printed page 8-6 (PDF page
156). See the
[incoming-SS null-selector report](../../design/intel_80286/report/2026-10-29-incoming-ss-null-double-fault.md).

Preflight, the exact-source Verilator 5.052 `-Wall` build and focused
`--iopl-controls` pass. Full simulation exits 0 with 188 `PASS:` lines and no
failures/errors; protected replay passes 79 cases in both READY modes. Evidence
is under `design/intel_80286/work/incoming_ss_null_double_fault_20261029_13/`.
RTL is unchanged, so prior synthesis remains applicable. The older whole-core
PDR remains active on its separate 21-file snapshot and is not current-source
proof. Current-source connected-core formal, authentic historical software,
remaining Table 8-1 gaps, task-entry fault phases and whole-CPU acceptance
remain open. The issue remains Building with Agent Codex, Path
`ai_hw_engineer/design/intel_80286`, and first Start date `2026-10-23`; see
[checkpoint comment 6485605914](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6485605914).

**Next:** compare every applicable Intel Table 8-1 row against both the direct
incoming-selector matrix and task-entry #DF escalation tests, using the
Playwright CLI source capture as reference. Add only source-backed missing
cases; then resume the remaining task-entry fault phases. Preserve the active
PDR and defer connected-core formal until it terminates.

## Incoming-SS DPL mismatch #SS double-fault escalation — 2026-10-29 01:39 UTC

Added four post-transfer incoming-SS privilege-fault executions for Intel
210498-005 Table 8-1 row 12. Incoming CPL 0 with SS selector `0040` names a
writable DPL-3 stack descriptor with RPL 0, so the first fault is
`#SS(0040)`. A malformed vector-12 gate selects null-error `#DF`; invalid-
vector-8 shutdown and valid #DF task-gate delivery pass in both READY modes.
Tests check the rejected descriptor read, both gate lookups, the faulting TSS
image with SS=`0040`, backlink/busy state, null error push, shutdown
quiescence and the exact handler successor. Playwright CLI verified the row
on printed page 8-6 (PDF page 156). See the
[incoming-SS DPL report](../../design/intel_80286/report/2026-10-29-incoming-ss-dpl-double-fault.md).

Preflight, the exact-source Verilator 5.052 `-Wall` build and focused
`--iopl-controls` pass. Full simulation exits 0 with 187 `PASS:` lines and no
failures/errors; protected replay passes 79 cases in both READY modes. RTL is
unchanged, so the existing 13-target Yosys synthesis remains applicable. The
older whole-core PDR remains active on its separate 21-file snapshot; its
latest log at 01:09 UTC is frame 96 with 343/411 outputs proved and 48 timeout
retries. Current-source connected-core formal, authentic historical software
and whole-CPU acceptance remain open.

## Incoming-SS read-only #GP double-fault escalation — 2026-10-29 01:37 UTC

Added four post-transfer incoming-SS read-only-data executions for Intel
210498-005 Table 8-1 row 10. SS selector `0010` names a present read-only data
descriptor and raises first-fault `#GP(0010)`. A malformed vector-13 gate
selects null-error `#DF`; invalid-vector-8 shutdown and valid #DF task-gate
delivery pass in both READY modes. Tests check the rejected descriptor, both
gate lookups, the faulting task TSS with SS=`0010`, backlink/busy state, null
error push, shutdown quiescence and the exact handler successor. Playwright
CLI verified the source row on printed page 8-6 (PDF page 156). See the
[incoming-SS read-only report](../../design/intel_80286/report/2026-10-29-incoming-ss-read-only-double-fault.md).

Preflight, the exact-source Verilator 5.052 `-Wall` build and focused
`--iopl-controls` pass. Full simulation exits 0 with 186 `PASS:` lines and no
failures/errors; protected replay passes 79 cases in both READY modes. RTL is
unchanged, so the existing 13-target Yosys synthesis remains applicable. The
older whole-core PDR remains active on its separate 21-file snapshot; its
latest log at 01:09 UTC is frame 96 with 343/411 outputs proved and 48 timeout
retries. Current-source connected-core formal, authentic historical software
and whole-CPU acceptance remain open.
The checkpoint was posted and read back in
[issue comment 6485485955](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6485485955).

**Next:** audit remaining incoming-SS selector-validity checks from Table 8-1
row 9. Use the source table to resolve any difference between the direct
matrix and expected stack-fault behavior before adding more escalation cases.
Preserve the active PDR.

## Incoming-CS wrong-type #TS double-fault escalation — 2026-10-29 01:32 UTC

Added four post-transfer incoming-CS type-fault executions for Intel
210498-005 Table 8-1 row 6. CS selector `0010` names a data descriptor, so the
first fault is `#TS(0010)`. A malformed vector-10 gate selects null-error
`#DF`; invalid-vector-8 shutdown and valid #DF task-gate delivery pass in both
READY modes. The checks cover the rejected descriptor read, both gate
lookups, the faulting TSS image with CS=`0010`, backlink/busy state, null error
push, shutdown quiescence and the exact handler successor. Playwright CLI
verified row 6 in the manual capture. See the
[incoming-CS type-fault report](../../design/intel_80286/report/2026-10-29-incoming-cs-type-double-fault.md).

Preflight, the exact-source Verilator 5.052 `-Wall` build and focused
`--iopl-controls` pass. Full simulation exits 0 with 185 `PASS:` lines and no
failures/errors; protected replay passes 79 cases in both READY modes. RTL is
unchanged, so the existing 13-target Yosys synthesis remains applicable. The
older whole-core PDR remains active on its separate 21-file snapshot; its
latest log at 01:09 UTC is frame 96 with 343/411 outputs proved and 48 timeout
retries. Current-source connected-core formal, authentic historical software
and whole-CPU acceptance remain open.

**Next:** audit incoming-SS type and privilege faults from Table 8-1 rows 9–12
for missing first-fault escalation outcomes. Preserve the active PDR and defer
current-source connected-core formal until it reaches terminal status.

## Incoming-DS readability #GP double-fault escalation — 2026-10-29 01:27 UTC

Added four post-transfer incoming-DS readability executions for Intel
210498-005 Table 8-1 row 14. Incoming DS uses execute-only selector `0030`,
which remains valid as CS but raises `#GP(0030)` as DS. An invalid vector-13
gate selects null-error #DF shutdown; a valid #DF task gate instead saves the
faulting TSS and executes the exact handler successor. Both outcomes pass in
both READY modes. The direct incoming-selector matrix now also checks the
exact DS `#GP(0030)` task-entry packet, expanding from 25 configurations/50
executions to 26/52. Playwright CLI evidence for row 14 is retained with the
run. See the
[incoming-DS readability report](../../design/intel_80286/report/2026-10-29-incoming-ds-readability-double-fault.md).

Preflight, the exact-source Verilator 5.052 `-Wall` runner build, and focused
`--iopl-controls` pass. The full simulation exits 0 with 184 `PASS:` lines and
no failures/errors; protected replay passes 79 cases in both READY modes.
RTL is unchanged, so the prior 13-target Yosys synthesis remains applicable.
The older whole-core PDR remains active on its separate 21-file source
snapshot; its latest log at 01:09 UTC is frame 96 with 343/411 outputs proved
and 48 timeout retries. Current-source connected-core formal, authentic
historical software and whole-CPU acceptance remain open.
The checkpoint was posted and read back in
[issue comment 6485429155](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6485429155).

**Next:** audit the remaining post-transfer Table 8-1 selector/type/presence
cases for missing #DF escalation outcomes. Preserve the active PDR and defer
current-source connected-core formal until it reaches terminal status.

## Incoming-ES privilege #GP double-fault escalation — 2026-10-29 01:13 UTC

Added four post-transfer incoming-ES privilege executions for Intel 210498-005
Table 8-1 row 16. Incoming CPL 0 loads ES=`0023`, an RPL-3 selector naming a
DPL-0 data descriptor, so validation raises `#GP(0020)`. The malformed #GP
handler selects null-error #DF. Invalid-vector-8 shutdown and valid #DF
task-gate delivery pass in both READY modes; tests check the rejected
descriptor read, both gate reads, saved TSS with ES=`0023`, backlink/busy
state, null error push and exact handler successor. See the
[incoming-ES privilege report](../../design/intel_80286/report/2026-10-29-protected-incoming-es-privilege-double-fault.md).

Preflight and the exact-source Verilator 5.052 `-Wall` runner build pass. The
full `scripts/run_sim.sh` exits 0 with 183 `PASS:` lines and no failures or
errors; protected replay passes 79 cases in both READY modes. RTL is unchanged,
so prior 13-target Yosys synthesis remains applicable. The preserved whole-core
PDR remains active on its separate 21-file snapshot. Its 01:09 UTC log had
advanced to frame 96 with 343/411 outputs proved and 48 timeout retries; 19
inputs match current source and two RTL files differ. Do not start a competing
connected-core run until it terminates.
The checkpoint was posted and read back in
[issue comment 6485126780](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6485126780).

**Next:** audit the remaining post-transfer Table 8-1 selector/type/presence
cases for missing #DF escalation outcomes, then add a source-backed case that
does not require a connected-core formal run. Preserve the active PDR and
defer current-source connected-core formal until terminal status.

## Incoming-DS system descriptor #GP double-fault escalation — 2026-10-29 01:06 UTC

Added four post-transfer incoming-DS system-descriptor executions. Intel
210498-005 Table 8-1 row 13 requires DS/ES to name code or data descriptors;
DS selector `0050` names a system TSS descriptor and raises `#GP(0050)`. A
malformed vector-13 handler gate selects null-error `#DF`; invalid-vector-8
shutdown and valid #DF task-gate delivery pass in both READY modes. Tests
check the descriptor read, gate lookups, saved faulting TSS with DS=`0050`,
backlink/busy state, null error push and exact handler successor. Evidence is
under `design/intel_80286/work/incoming_ds_system_double_fault_20261029_07/`;
see the [incoming-DS system-descriptor report](../../design/intel_80286/report/2026-10-29-protected-incoming-ds-system-double-fault.md).

Preflight and strict Verilator 5.052 `-Wall` `scripts/run_sim.sh` pass; the
full run exits 0 with 182 `PASS:` lines and no failures or errors. Protected
replay passes 79 cases in both READY modes. RTL is unchanged, so the prior
13-target Yosys synthesis remains applicable. The preserved whole-core PDR
continues against its separate 21-file snapshot; 19 inputs match current
source and the top-level core/code-load files differ. It remains active at
frame 79 without terminal status. See the
[source-epoch audit](../../design/intel_80286/report/2026-10-29-pdr-source-epoch-audit.md)
and [issue comment 6485001888](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6485001888).

**Next:** continue the remaining Table 8-1 task-entry fault rows that can be
verified without another connected-core formal run. Preserve the active PDR;
start current-source connected-core BMC, induction, cover and PDR only after
it terminates, as required by the formal plan.

## Formal source-epoch blocker — 2026-10-29 01:02 UTC

The preserved whole-core PDR remains active at frame 79 with 342/411 outputs
proved and 40 timeouts, with no terminal result. Exact comparison found two
of 21 copied RTL/property inputs differ from current source:
`intel_80286.sv` and `intel_80286_code_load.sv`. The result cannot establish
current-source proof. See the
[source-epoch audit](../../design/intel_80286/report/2026-10-29-pdr-source-epoch-audit.md)
and the updated [formal plan](../../design/intel_80286/plans/formal_plan.md).

Preserve this run and its evidence until it reaches terminal status. Then
classify the result against its saved source epoch and run connected-core
BMC, induction, cover, PDR and the aggregate exact-source audit on current
inputs. The project formal plan prohibits a competing connected-core run while
this PDR is active.

## Incoming-DS non-present #NP double-fault escalation — 2026-10-29 00:58 UTC

Added four post-transfer incoming-DS non-present executions. Intel 210498-005
Table 8-1 row 15 requires the incoming DS descriptor to be present; selector
`0010` therefore raises `#NP(0010)`. A malformed vector-11 gate selects
null-error `#DF`; invalid-vector-8 shutdown and valid #DF task-gate delivery
pass in both READY modes. The tests check the failed descriptor read, gate
lookups, saved faulting TSS with DS=`0010`, backlink/busy state, null error
push and exact handler successor. Playwright CLI reviewed the manual table.
Evidence is under `design/intel_80286/work/incoming_ds_np_double_fault_20261029_06/`;
see the [incoming-DS #NP report](../../design/intel_80286/report/2026-10-29-protected-incoming-ds-np-double-fault.md).

Preflight and strict Verilator 5.052 `-Wall` `scripts/run_sim.sh` pass; the
full run exits 0 with 181 `PASS:` lines and no failures or errors. Protected
replay passes 79 cases in both READY modes. RTL is unchanged, so the prior
13-target Yosys synthesis remains applicable. The older whole-core PDR remains
active on its separate 21-file snapshot at frame 79 with 342/411 outputs
proved and 40 timeouts; it is not current-source proof. Current-source
connected-core proof, remaining task-entry fault phases, authentic historical
software and full CPU acceptance remain open. The issue checkpoint was
posted and read back in
[comment 6484884414](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6484884414).

**Next:** reconcile the preserved PDR source epoch and finish its status
audit; then either accept a terminal result for that exact snapshot or retire
it before starting current-source connected-core proof and reachable covers.

## Incoming-DS privilege #GP double-fault escalation — 2026-10-29 00:50 UTC

Added four post-transfer incoming-DS privilege executions. Intel 210498-005
Table 8-1 row 16 rejects DS selector `0013` with `#GP(0010)` when the incoming
task runs at CPL 0: its RPL 3 exceeds the descriptor's DPL 0. A malformed
vector-13 handler gate then selects null-error `#DF`; invalid-vector-8
shutdown and valid #DF task-gate delivery pass in both READY modes. The cases
check the failed descriptor read, gate lookups, saved faulting TSS, backlink/
busy state, null error push and exact handler successor. Evidence is under
`design/intel_80286/work/incoming_ds_privilege_double_fault_20261029_05/`. See
the [incoming-DS privilege report](../../design/intel_80286/report/2026-10-29-protected-incoming-ds-privilege-double-fault.md).

Preflight and strict Verilator 5.052 `-Wall` `scripts/run_sim.sh` pass; the
full run exits 0 with 180 `PASS:` lines and no failures or errors. Protected
replay passes 79 cases in both READY modes. RTL is unchanged, so the prior
13-target Yosys synthesis remains applicable. The older whole-core PDR remains
active on its separate 21-file snapshot at frame 79 with 342/411 outputs
proved and 40 timeouts; it is not current-source proof. Current-source
connected-core proof, remaining task-entry fault phases, authentic historical
software and full CPU acceptance remain open. The issue checkpoint was
posted and read back in
[comment 6484789531](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6484789531).

**Next:** cover the incoming-DS non-present Table 8-1 row, then reconcile the
preserved PDR source epoch before starting a current-source connected-core
proof.

## Incoming-ES system-descriptor #GP double-fault escalation — 2026-10-29 00:47 UTC

Added four post-transfer incoming-ES system-descriptor executions. Intel
210498-005 Table 8-1 row 13 maps system selector `0050` to `#GP(0050)`.
Malformed vector-13 handling then selects null-error `#DF`; invalid-vector-8
shutdown and valid #DF task-gate delivery pass in both READY modes. Tests
check the descriptor read, both gate lookups, saved faulting TSS with
ES=`0050`, backlink/busy state, null error push and exact handler successor.
Playwright CLI reviewed the primary table; evidence is under
`design/intel_80286/work/incoming_es_type_double_fault_20261029_04/`. See the
[incoming-ES system-descriptor report](../../design/intel_80286/report/2026-10-29-protected-incoming-es-system-double-fault.md).

Preflight and strict Verilator 5.052 `-Wall` `scripts/run_sim.sh` pass; the
full run exits 0 with 179 `PASS:` lines and no failures or errors. Protected
replay passes 79 cases in both READY modes. RTL did not change, so prior
synthesis remains applicable. Current-source connected-core formal, other
task-entry fault phases, authentic historical software, native timing and the
full release gate remain open. The issue checkpoint was posted and read back
in [comment 6484718375](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6484718375).

**Next:** add an incoming DS/ES `#GP` from a privilege or selector rule, then
reconcile the preserved PDR source epoch before starting current-source
connected-core proof. The older PDR's latest log at 00:43 UTC reached frame 79
with 342/411 outputs proved and 40 timeouts, without terminal PASS.

## Incoming-ES #GP double-fault escalation — 2026-10-29 00:43 UTC

Added four post-transfer execute-only incoming-ES executions. Intel 210498-005
Table 8-1 row 14 requires DS/ES code descriptors to be readable. Selector
`0030` remains valid as CS but raises `#GP(0030)` as ES; a malformed `#GP`
gate then selects null-error `#DF`. Invalid-vector-8 shutdown and valid #DF
task-gate delivery pass in both READY modes, checking the descriptor read,
gate lookups, saved faulting TSS with ES=CS=`0030`, backlink/busy state, null
error push and exact handler successor. Playwright CLI reviewed the manual
table; evidence is under
`design/intel_80286/work/incoming_es_gp_double_fault_20261029_03/`. See the
[incoming-ES #GP report](../../design/intel_80286/report/2026-10-29-protected-incoming-es-gp-double-fault.md).

Preflight and strict Verilator 5.052 `-Wall` `scripts/run_sim.sh` pass; the
full run exits 0 with 178 `PASS:` lines and no failures or errors. Protected
replay passes 79 cases in both READY modes. RTL did not change, so prior
synthesis remains applicable. Current-source connected-core formal, other
task-entry fault phases, authentic historical software, native timing and the
full release gate remain open. The issue checkpoint was posted and read back
in [comment 6484652251](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6484652251).

**Next:** cover another DS/ES post-transfer `#GP` source, especially invalid
descriptor type or privilege, then reconcile the preserved PDR source epoch
before starting current-source connected-core proof.

## Incoming-ES #NP double-fault escalation — 2026-10-29 00:35 UTC

Added four post-transfer incoming-ES non-present executions. Intel 210498-005
Table 8-1 row 15 maps selector `0020` to `#NP(0020)`. A malformed `#NP` gate
then escalates to null-error `#DF`; invalid-vector-8 shutdown and valid #DF
task-gate delivery pass in both READY modes. Tests check the ES descriptor
read, gate lookups, saved faulting TSS with ES=`0020`, backlink/busy state,
null error push and exact handler successor. Playwright CLI reviewed the
primary manual table; evidence is under
`design/intel_80286/work/incoming_es_np_double_fault_20261029_02/`. See the
[incoming-ES #DF report](../../design/intel_80286/report/2026-10-29-protected-incoming-es-np-double-fault.md).

Preflight and strict Verilator 5.052 `-Wall` `scripts/run_sim.sh` pass; the
full run exits 0 with 177 `PASS:` lines and no failures or errors. Protected
replay passes 79 cases in both READY modes. RTL did not change, so prior
synthesis remains applicable. Current-source connected-core formal, other
task-entry fault phases, authentic historical software, native timing and the
full release gate remain open. The project item remains Open/Building with
Agent Codex, Path `ai_hw_engineer/design/intel_80286` and Start date
`2026-10-23`; see the read-back checkpoint
[comment 6484561385](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6484561385).

**Next:** cover representative post-transfer DS/ES `#GP` and `#NP` escalation
rows that are still represented only by direct delivery, then reconcile the
preserved PDR source epoch before starting a current-source connected-core
proof. The older PDR reached frame 71 with 342/411 outputs proved and 40
timeouts by 00:34 UTC, still without a terminal result.

## Incoming-SS #SS double-fault escalation — 2026-10-29 00:27 UTC

Added four post-transfer non-present-SS first-fault executions. Intel 210498-005
Table 8-1 row 11 maps selector `0010` to `#SS(0010)`. A malformed `#SS` gate
then escalates to null-error `#DF`; invalid-vector-8 shutdown and valid #DF
task-gate delivery pass in both READY modes. The tests check exact event
context, both gate reads, saved faulting TSS with SS=`0010`, backlink/busy
state, null error push and exact handler successor. Playwright CLI reviewed
the manual table; evidence is under
`design/intel_80286/work/incoming_ss_np_double_fault_20261029_01/`. See the
[incoming-SS #DF report](../../design/intel_80286/report/2026-10-29-protected-incoming-ss-double-fault.md).

Preflight and strict Verilator 5.052 `-Wall` `scripts/run_sim.sh` pass; the
full run exits 0 with 176 `PASS:` lines and no failures or errors. Protected
replay passes 79 cases in both READY modes. RTL did not change, so prior
synthesis remains applicable. Current-source connected-core formal, other
task-entry fault phases, authentic historical software, native timing and the
full release gate remain open. The GitHub checkpoint was posted and read back
in [issue comment 6484408436](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6484408436).

## Incoming-CS #NP double-fault escalation — 2026-10-29 00:21 UTC

Added four post-transfer non-present-CS first-fault executions. Intel 210498-005
Table 8-1 row 7 maps selector `0008` to `#NP(0008)`. A malformed `#NP` gate
then escalates to null-error `#DF`; invalid-vector-8 shutdown and valid #DF
task-gate delivery pass in both READY modes. The tests check exact event
context, gate reads, the saved incoming TSS image with CS=`0008`, backlink/busy
state, null error push and handler successor. Playwright CLI visually checked
the source row; its screenshot and run evidence are under
`design/intel_80286/work/incoming_cs_np_double_fault_20261029_01/`. See the
[incoming-CS #NP report](../../design/intel_80286/report/2026-10-29-protected-cs-np-double-fault-first-fault.md).

Preflight and strict Verilator 5.052 `-Wall` `scripts/run_sim.sh` pass; the
full run exits 0 with 175 `PASS:` lines and no failures or errors. Protected
replay passes 79 cases in both READY modes. RTL did not change; prior
synthesis remains applicable. Current-source connected-core formal, other
task-entry fault phases, authentic historical software, native timing and the
full release gate remain open. The GitHub checkpoint was posted and read back
in [issue comment 6484304062](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6484304062).

## Incoming-CS #TS double-fault escalation — 2026-10-29 00:13 UTC

Added four post-transfer invalid-CS first-fault executions. Intel 210498-005
Table 8-1 row 6 makes a null incoming CS selector fault with `#TS(0000)`.
With a malformed `#TS` handler gate, the second protection fault selects
null-error `#DF`. Both invalid-vector-8 shutdown and valid `#DF` task-gate
delivery pass in both READY modes, with exact event context, incoming TSS save,
backlink/busy state, null error push and handler successor checks. See the
[incoming-CS #DF report](../../design/intel_80286/report/2026-10-29-protected-cs-double-fault-first-fault.md).

Preflight and strict Verilator 5.052 `-Wall` `scripts/run_sim.sh` pass; the
full run exits 0 with 174 `PASS:` lines and no failures or errors. Protected
replay passes 79 cases in both READY modes. Evidence is under
`design/intel_80286/work/incoming_cs_double_fault_20261029_01/`. This change is
testbench-only; the previous RTL synthesis remains applicable. The PDR still
runs on its older 21-file snapshot and is not evidence for this source.
Current-source connected-core formal, other task-entry fault phases,
authentic historical software, native timing and the full release gate remain
open.

The GitHub checkpoint was posted and read back in
[issue comment 6484222610](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6484222610).

## Incoming ES readability fault — 2026-10-29 00:05 UTC

Added a task-entry ES case for the Table 8-1 row 14 readability check. An
execute-only DPL-0 code descriptor at selector `0030` is valid as CS but not
readable as ES; exact `#GP(0030)` delivery passes in both READY modes. The
incoming selector matrix now covers 25 configurations and 50 executions.

Preflight and strict Verilator 5.052 `-Wall` `scripts/run_sim.sh` pass; the
full run exits 0 with 173 PASS lines and no FAIL/ERROR lines. Protected replay
passes 79 cases in both READY modes. See the
[ES readability report](../../design/intel_80286/report/2026-10-29-incoming-es-readability.md)
and `design/intel_80286/work/incoming_task_es_readability_20261029_01/`.
RTL is unchanged. Remaining post-transfer task-switch phases, current-source
connected-core proof, authentic software, native timing and aggregate release
acceptance remain open. The issue checkpoint was posted and read back in
[comment 6484047009](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6484047009).

**Next:** continue source-backed Table 8-1 post-transfer fault phases, then
reconcile the preserved PDR source epoch before starting a current-source
connected-core proof.

## Previous checkpoint — incoming ES system descriptor — 2026-10-29 00:01 UTC

Added ES system-descriptor coverage after the Table 8-1 audit showed that this
invalid-selector type was exercised through DS but not ES. Table 8-1 row 13
maps invalid DS/ES selectors to `#GP`; ES selector `0050` now checks exact
`#GP(0050)` after valid CS/SS/DS checks. The matrix covers 24 configurations
and 48 executions across both READY modes.

Preflight passes; strict Verilator 5.052 `-Wall` `scripts/run_sim.sh` exits 0
with 173 PASS lines and no failures/errors. Protected replay passes 79 cases
in both READY modes. See the
[ES system-descriptor report](../../design/intel_80286/report/2026-10-29-incoming-es-system-descriptor.md)
and `design/intel_80286/work/incoming_task_es_type_20261028_01/`. No RTL
behavior changed; the 13-target Yosys synthesis remains applicable.

**Next at that checkpoint:** continue source-backed Table 8-1 post-transfer
fault phases, then reconcile the preserved PDR source epoch before starting a
current-source connected-core proof. Authentic historical software, SCAS
restart resolution, native timing qualification and the aggregate release
gate remain open.
The issue checkpoint was posted and read back in
[comment 6483988275](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6483988275).

## Incoming SS RPL mismatch — 2026-10-28 23:55 UTC

Added the incoming task SS RPL-mismatch case. Intel Table 8-1 row 9 (“Stack
segment is valid”) maps an invalid stack selector to `SF` (#SS), with the
stack selector as error code. Selector `002B` at CPL 0 checks `#SS(0028)`.
The earlier draft expected `#TS`; manual inspection and the task-gate packet
showed the correct #SS result. The report is
[here](../../design/intel_80286/report/2026-10-28-incoming-ss-rpl-fault.md).
The full run recorded 173 PASS lines, no FAIL/ERROR lines, and 79 protected
replay cases in both READY modes. RTL is unchanged.

## Incoming ES GDT-limit fault — 2026-10-28 23:47 UTC

Added the missing ES out-of-GDT case to incoming task validation. The
CS/SS/DS/ES selector-fault matrix now covers 22 configurations and 44
executions in both READY modes. The ES descriptor selector `0188` is beyond
the configured GDT limit `0187`; the test checks exact `#GP(0188)` after
valid CS/SS/DS processing and no read of the rejected descriptor. Intel
210498-005 §8.4/Table 8-1 was visually checked through `playwright-cli`.

Preflight and the strict Verilator 5.052 `-Wall` full `scripts/run_sim.sh`
pass; the full log has 173 PASS lines and no failures/errors. The same run
passes the 460-case incoming-LDT DPL/RPL matrix, eight LDT-limit faults, and
the 79-case protected replay in both READY modes. Exact-source evidence is
under `design/intel_80286/work/incoming_task_selector_bounds_20261028_01/`;
the [ES GDT-limit report](../../design/intel_80286/report/2026-10-28-incoming-es-gdt-limit.md)
records hashes and scope. No RTL behavior changed, so the prior 13-target
Yosys synthesis remains applicable. Current-source formal, remaining task
switch phases, authentic software, native timing and the full release gate
remain open.

The checkpoint was read back in
[issue comment 6483734952](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6483734952).

**Next at that checkpoint:** continue source-backed Table 8-1 task-switch fault boundaries and
post-transfer fault priorities. Reconcile the preserved PDR source epoch
before starting a current-source connected-core proof. Authentic historical
software, SCAS restart resolution, native timing qualification and aggregate
release acceptance remain open.

## Incoming LDT DPL/RPL matrix — 2026-10-28 23:41 UTC

Expanded successful task entry through a non-null incoming LDT to 460
executions across CPL0–2 and both READY modes. CS/SS use DPL=RPL=CPL; DS/ES
independently cover all DPL/RPL pairs satisfying `max(CPL,RPL) <= DPL`.
Intel 210498-005 §7.4.1 and §8.4/Table 8-1 were visually checked with
`playwright-cli`. The existing eight just-beyond-LDT-limit faults remain
passing, and the prior 42-case incoming-segment suite includes DS/ES privilege
denials.

Preflight passes; strict Verilator 5.052 `-Wall` `scripts/run_sim.sh` exits 0
with 173 PASS lines and no failures/errors. Protected replay passes 79 cases
in both READY modes. Exact-source evidence is under
`design/intel_80286/work/incoming_ldt_rpl_20261028_02/`; the report records
hashes and scope limits. No RTL behavior changed, so prior 13-target Yosys
synthesis remains applicable. Current-source connected-core formal,
remaining task-switch fault phases, authentic historical software, native
timing qualification and the full release gate remain open. The older PDR
still runs on a different 21-file source snapshot and cannot prove current
sources.

The checkpoint was read back in
[issue comment 6483636717](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6483636717).

**Next:** continue source-backed Table 8-1 task-switch fault boundaries and
remaining post-transfer fault phases. Reconcile the preserved PDR source epoch
before starting a current-source connected-core proof. Authentic historical
software, SCAS restart resolution, native timing qualification and the
aggregate release gate remain open.

## Incoming LDT privilege and limit matrix — 2026-10-28 23:30 UTC

Extended valid incoming-LDT task coverage to 58 executions across CPL0–2,
with CS/SS DPL=CPL and every allowed DS/ES DPL pair from CPL through 3. All
four descriptors are loaded from LDT limit `0027`; the last valid ES entry
ends at the boundary. Eight fault cases place CS/SS/DS/ES selectors at LDT
offset `0038` and check Table 8-1 `#TS/#SS/#GP`, exact `003C` error codes,
transferred-TSS state, descriptor access order and no read/accessed write
beyond the limit. Both READY modes pass. The Intel manual's Table 8-1 on PDF
page 156 was visually checked through `playwright-cli`. Results and hashes are
in the [incoming-LDT report](../../design/intel_80286/report/2026-10-28-incoming-ldt-privilege-limit-matrix.md).

The strict Verilator 5.052 `-Wall` full `scripts/run_sim.sh` exits 0 with 173
PASS lines and no failures/errors; protected replay passes 79 cases in both
READY modes and preflight passes. No RTL behavior changed, so the prior
13-target Yosys synthesis remains applicable. The active PDR is still on a
different 21-file snapshot and cannot prove this testbench change.
The issue checkpoint was read back in
[comment 6483475879](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6483475879).

**Next:** continue the remaining Table 8-1 task-switch selector and
descriptor-fault boundaries, then reconcile and run current-source
connected-core formal after the preserved PDR exits. Authentic historical
software, SCAS restart behavior, native timing qualification and the aggregate
release gate remain open.

## Direct TSS privilege matrix — 2026-10-28 23:16 UTC

Added 192 direct TSS CALL/JMP executions across CPL0–2, selector RPL0–3, TSS
DPL0–3 and both READY policies. All 104 allowed cases and 88 denials pass the
Intel rule `max(CPL,RPL) <= TSS_DPL`, checking exact successors, CALL return
state, JMP busy state, exact #GP frames and preflight side effects. The
focused `--iopl-controls` run passes all 23 suite groups. Full strict Verilator
5.052 `-Wall` `scripts/run_sim.sh` exits 0 with 172 PASS lines and no failures
or errors; the 79-case protected replay passes in both READY modes. The
source-backed rule is Intel 210498-005 §8.3, printed page 8-5 (PDF page 155),
visually checked with `playwright-cli`. See the
[direct-TSS report](../../design/intel_80286/report/2026-10-28-direct-tss-privilege-matrix.md)
for the selector-collision fixture correction and hashes.

No RTL behavior changed, so the 13-target Yosys 0.69 synthesis remains
applicable. Keep the old whole-core PDR intact on its separate 21-file
snapshot; it has no terminal result and cannot establish current-source proof.
Current-source connected-core formal, remaining task-switch fault phases,
authentic historical software and full release acceptance remain open.
The issue checkpoint was read back in
[comment 6483230260](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6483230260).

**Next:** continue source-backed direct task-switch fault-phase and selector
boundary coverage without starting an overlapping core proof. Once the
preserved PDR reaches a terminal result, reconcile its source epoch before
starting a coordinated current-source connected-core formal run. The aggregate
`run_all.sh` gate, CPGREP-on-RTL, SCAS restart resolution and native timing
qualification remain completion blockers.

## Reachable ARPL privilege matrix — 2026-10-28 22:52 UTC

Added and passed 384 reachable nonzero-CPL ARPL executions: CPL1/2/3 × every
source/destination RPL pair × register/SS-memory form × prior ZF set/clear ×
both READY policies. Each ring is reached through outer IRET; exact instruction
fetch, one retirement, only-ZF updates, conditional RMW traffic and the next
two unprivileged NOPs are checked. The focused `--arpl` run passes. Strict
Verilator 5.052 `-Wall` full `scripts/run_sim.sh` exits 0 with 171 PASS lines,
no FAIL/ERROR lines, and the 79-case protected replay passing in both READY
modes. No RTL behavior changed; corrected-source 13-target Yosys synthesis
remains applicable. Evidence, hashes and exact commands are in the
[ARPL privilege report](../../design/intel_80286/report/2026-10-28-arpl-reachable-privilege-matrix.md)
and [issue comment 6482816712](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6482816712).

Playwright CLI follow-up inspected the Intel 80286 document index at
[Bitsavers](https://bitsavers.org/components/intel/80286/). It lists manuals
but no separate SCAS erratum or fault trace that resolves the LOADALL memo's
SI-versus-DI restart discrepancy. Keep protected SCAS fault repair
release-blocking and make no behavior change without an 80286 trace or another
primary source.

**Next:** continue source-backed task-switch fault-phase work that does not
need a new connected-core proof. Preserve the active PDR on its older 21-file
snapshot; its 22:21 UTC log remains at frame 27 with 342 outputs and 31
timeouts, without a terminal result. The current-source whole-core formal
epoch must wait for that process to finish. The configurable fresh evidence
root is present in `run_all.sh`, but the full aggregate has not passed.
Authentic CPGREP execution on RTL, SCAS resolution, physical native timing and
whole-CPU acceptance remain open.

## Exhaustive direct task-gate privilege matrix — 2026-10-28 22:40 UTC

Expanded the far task-gate access matrix from selected CPL1/CPL2 boundaries to
all 192 combinations of CPL 0–2, selector RPL 0–3, gate DPL 0–3, CALL/JMP and
both READY policies. The 104 allowed cases validate task transfer and exact
successors; 88 denials validate #GP(selector), same-task frames and no access
or mutation of the incoming TSS. Frame checks account for same-level CPL0
events. The strict Verilator 5.052 `-Wall` full `scripts/run_sim.sh` exits 0
with 170 `PASS:` lines and no failures/errors. Protected replay passes 79
cases in both READY modes. Current source hashes and evidence are in the
[direct-transfer report](../../design/intel_80286/report/2026-10-28-protected-direct-task-transfers.md).

The 13-target Yosys synthesis remains applicable to functional RTL; there has
been no RTL behavior change since it completed. A26 remains open. The older
whole-core PDR is still the only active core formal job, running against a
different 21-file snapshot with no progress beyond frame 27, 342 outputs
proved and 31 timeouts at 22:40 UTC. Do not start another core proof until it
terminates and the source epoch is reconciled.

**Next:** seek independent 286 evidence for A26; continue source-backed task
switch fault-phase and selector-boundary work that does not require overlapping
core formal; then launch a coordinated current-source connected-core epoch
after the old PDR reaches a terminal result. Authentic historical software,
native timing qualification and full release acceptance remain open. Issue #80
remains Open/Building, Agent Codex, Path `ai_hw_engineer/design/intel_80286`,
Start date 2026-10-23; checkpoint:
[comment 6482597698](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6482597698).

## Task-gate correction, synthesis and formal-job audit — 2026-10-28 22:24 UTC

Playwright CLI review of Intel 210498-005 §8.5/Table 8-1 corrected the direct
task-gate oracle: CALL/JMP offsets are ignored and a busy incoming TSS raises
#GP(incoming TSS selector). The corrected RTL passes the full simulation and
79-case protected replay in both READY modes; the focused matrix covers 21
rejection configurations in both READY modes, eight task-transfer successes,
and 900 reset cuts. Corrected-source Yosys 0.69 synthesis completed all 13
targets, with terminal logs, JSON netlists and zero-problem `check -assert`
results for every target. An inline A26 annotation now marks the still-open
nonzero unused-task-gate-field response. The strict post-annotation Verilator
runner and focused `--iopl-controls` pass with 21 `PASS:` lines.

A fresh process audit corrected the previous PDR status: the old whole-core PDR
is still running on its different 21-file snapshot. At 22:21:21 UTC it reached
frame 27 with 342 outputs proved and 31 timeout retries, but it has no terminal
PASS and cannot verify the current source. Keep it as the only active core
formal job; do not launch another core proof until it terminates and the source
epoch is reconciled. Independent current-source connected-core proof remains
open. The latest evidence and issue checkpoint are in the
[task-gate audit](../../design/intel_80286/report/2026-10-28-task-gate-source-audit.md),
[formal plan](../../design/intel_80286/plans/formal_plan.md) and
[issue comment 6482216205](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6482216205).

**Next:** preserve the active PDR; resolve A26 only with independent 286
evidence; continue source-backed task-switch fault-phase coverage that does
not require a competing core formal run; then start the coordinated
current-source connected-core epoch after the old run reaches a terminal
state. Authentic historical software, native timing qualification and full
release acceptance remain open.

## 82C284 reset integration and #DF first-fault coverage — 2026-10-28 19:56 UTC

The source-backed digital 82C284 RES synchronizer is connected to the native
CPU, bus and 82288 controller. The full Verilator suite exits 0 with 163
`PASS:` lines, including 79 protected replay cases in both READY modes. The
13-target Yosys 0.69 matrix passes with zero structural problems. A new
four-execution protected matrix covers first-fault `#NP` and `#SS` followed by
an IDT-limit #GP: the event core selects null-error vector 8, preserves the
original context and enters sticky shutdown when the DF gate is invalid. The
focused privilege matrix and full simulation pass. Evidence and hashes are in
the [reset report](../../design/intel_80286/report/2026-10-28-reset-source-audit.md)
and [#DF first-fault report](../../design/intel_80286/report/2026-10-28-protected-double-fault-first-faults.md).

The model covers digital RES sampling only; analog startup, board clock and
PCLK phase, and device-specific electrical limits remain open. The new #DF
tests cover IDT-limit escalation for #NP/#SS through invalid-gate shutdown;
first-fault #TS and later task/event failure phases remain open. The old
whole-core PDR remains active on a distinct 21-file snapshot and is not
current-source proof. Do not start overlapping formal work. Continue remaining
source-backed fault/task cases, then return to independent software and full
release closure. Issue #80 remains Building with Agent Codex, Path
`ai_hw_engineer/design/intel_80286` and Start date 2026-10-23; see the latest
[checkpoint comment 6479220404](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6479220404).

## Native CPU clock phase regression — 2026-10-28 19:02 UTC

The connected CPU test now drives the processor-rate clock and external 2x
clock as a phase-related pair at the source-defined 2:1 ratio. One full
processor-clock period spans two external CLK periods. The focused connected
pin test passes, and the full `run_sim.sh` suite exits 0 with 162 PASS lines;
the protected replay manifest reports 79 cases in both READY modes. This is a
testbench-only change, with exact identities and evidence in the
[native-clock report](../../design/intel_80286/report/2026-10-28-native-clock-phase.md).
Issue #80 was updated and read back in
[comment 6478016839](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6478016839).

The selected digital phase does not model the 82C284, settle the conflicting
RESET edge descriptions, or qualify physical clock timing. The live whole-core
PDR remains on its stale 21-file snapshot (frame 89, 329/411 outputs, 50
timeouts at 18:54 UTC). Preserve it and wait for a terminal result before
starting a connected-core formal epoch. Continue with sourced native/reset
gaps, remaining protected fault phases, independent historical-software
evidence and the full release gate.

## Protected outer IRET fault priority — 2026-10-28 18:43 UTC

Intel 210498-005 Table 7-4 was visually reviewed in Chrome with
`playwright-cli`. The first combined-fault regression showed null return-CS
validation preceding the complete five-word source-frame bounds check. A
second pair showed the saved-IP limit check preceding outer-SS validation. The
RTL now performs frame preflight, validates the return-CS descriptor at offset
zero, validates outer SS, then checks saved-IP limit. It preserves early
#GP/#NP for invalid CS descriptors and raises restartable #GP(0) for an
over-limit saved IP only after SS validation. The return context is not
partially committed; an accessed-bit update on valid CS descriptor loading is
checked explicitly.

The focused IRET matrix passes 36 executions in both READY modes. Its 12
priority executions pair both current-stack #SS bounds cases with null CS,
null/non-present CS with null outer SS, and null/non-present outer SS with an
over-limit saved IP. Exact first exceptions, event frames, descriptor traffic, accessed
writes and source-frame preservation are checked. Strict Verilator 5.052
`-Wall`, preflight, the 71-line full bootstrap and current-source 12-target
Yosys 0.69 synthesis pass; the matrix reports 36 zero-problem checks and no
errors. Exact identities are in the
[priority report](../../design/intel_80286/report/2026-10-28-protected-iret-fault-priority.md).

Keep issue #80 Building with Agent Codex, its original 2026-10-23 Start date,
and Path `ai_hw_engineer/design/intel_80286`; the verified checkpoint is
[comment 6477632896](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6477632896).
Do not treat the active whole-core PDR on an older RTL snapshot as
current-source evidence. After that job reaches a terminal result, run the
coordinated connected-core formal epoch and exact-source audit. Continue with
the remaining task-gate/fault-phase cases, independent historical-software
evidence and release gates.

## Protected outer IRET frame bounds and synthesis — 2026-10-28 17:42 UTC

Closed two current-stack boundary cases for protected outer IRET in four
executions across both READY modes. An invalid starting SP produces
restartable #SS(0) before frame reads. A five-word frame whose last byte crosses
the current SS limit reads only the first three words, then produces #SS(0)
before reading outer SP/SS or the target CS descriptor. In both cases the
handler loads a wider current stack, retries the unchanged IRET frame, and
reaches the exact ring-3 successor. The full focused matrix now totals 24
executions; strict Verilator, full bootstrap and preflight pass. The full
current-source Yosys 0.69 matrix exits 0: all 12 targets produced netlists and
each target log reports zero structural problems. Evidence is under
`design/intel_80286/work/iret_current_synth_20261028_14/synth/`. See the
[protected IRET recovery report](../../design/intel_80286/report/2026-10-28-protected-iret-fault-recovery.md).

The next work is broader exception/fault-priority coverage and a current-source
connected-core formal run. The issue checkpoint is [comment 6476273413](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6476273413).
Keep issue #80 Building with Agent Codex, Path
`ai_hw_engineer/design/intel_80286` and its original 2026-10-23 Start date.

## Protected outer IRET repair matrix — 2026-10-28 16:59 UTC

Expanded protected IRET recovery to 20 executions across both READY modes:
null, non-present and system return-CS selectors; inward return; an
out-of-limit saved return IP; and five invalid outer-SS selector/type/presence/
privilege/table-limit cases. The fault handlers preserve and repair the
original return frame, retry the same IRET, and reach the exact successor.
Intel 210498-005 Tables 7-4 and 9-1 were visually reviewed using Playwright
CLI; they confirm outer-SS #SS classification and #GP(0) for an IP outside the
code limit. Preflight, strict Verilator 5.052 `-Wall`, the focused matrix and
full bootstrap pass. A fresh 12-target Yosys matrix for this RTL source is
running; the prior snapshot's matrix passed. The older whole-core PDR is still
a different 21-file source snapshot and does not prove this change. See the
[recovery report](../../design/intel_80286/report/2026-10-28-protected-iret-fault-recovery.md).
The issue checkpoint is [comment 6475373524](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6475373524).

Next, cover current-stack frame-boundary checks from the 286 source, then
continue the broader exception/task-gate and release gates. Keep the project
issue Building with Agent Codex, Path
`ai_hw_engineer/design/intel_80286` and the original 2026-10-23 Start date.

## Protected outer IRET descriptor faults — 2026-10-28 16:34 UTC

The return-CS loader now delivers restartable faults during protected IRET.
Four cases cover non-present code (#NP(0048)) and a system descriptor in the
CS slot (#GP(0050)), both READY modes, the exact error frame, unchanged original
five-word return frame, no accessed-bit write to the rejected descriptor,
handler repair, IRET retry and the exact ring-3 successor. Final-source
preflight, strict Verilator 5.052 `-Wall`, the focused
`--protected-iret-faults` slice, the valid `--outer-iret` slice and full
bootstrap pass. Source evidence: Intel 210498-005 §9.6 Table 9-3 and §9.6.7,
reviewed through Playwright CLI. See the
[recovery report](../../design/intel_80286/report/2026-10-28-protected-iret-fault-recovery.md).

The complete Yosys 0.69 synthesis matrix passed: all twelve targets produced
netlists, all twelve logs report zero structural problems, and the script
exited 0. The issue checkpoint is [comment 6474767733](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6474767733).
Current-source connected-core formal proof remains open. Keep the project
issue Building with Agent Codex, Path
`ai_hw_engineer/design/intel_80286` and the original 2026-10-23 Start date.
Next close the earlier null/inward-CS and outer-SS IRET fault cases, then
continue the broader exception/task-gate and release gates.

## Protected-mode WAIT regression — 2026-10-28 15:54 UTC

The existing asynchronous boundary accepts NMI and IF-enabled INTR while
WAIT is stalled on BUSY in protected mode as well as real mode. Added 16
directed cases across CPL1/CPL2, both event types, interrupt/trap gates and
both READY modes. They enter through outer IRET, verify TSS SP0:SS0 selection,
exact frames, no interrupted-stack writes, acknowledge/NMI behavior and IRET
to the exact successor while BUSY stays high. The strict Verilator 5.052
`-Wall` build, focused slice and full default bootstrap pass; this is
testbench-only. ASSUMPTION A25 remains open because Intel's interruptibility
statement does not specify WAIT's saved IP. Native pin timing and current-source
connected-core proof remain open. See the
[protected WAIT report](../../design/intel_80286/report/2026-10-28-protected-wait-interruption.md)
and [issue checkpoint 6473853937](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6473853937).

The whole-core PDR continues on its earlier 21-file snapshot and does not
verify this testbench update. The full 80286 acceptance gates remain open.

## 80287 Intel-handbook cross-check — 2026-10-28 15:46 UTC

Playwright CLI visual review of Intel's 1986 *Microsystem Components
Handbook: Microprocessors, Volume I*, printed page 4-31, independently
confirms the reserved I/O ports, bypass of IOPL/CPL checks for ESC port I/O,
PEREQ memory-operand transfers, `00FAh` word I/O plus one or two memory
cycles, and bus-arbitration priorities. It supplies no byte-level command or
port sequence for successful ESC forms. No RTL changed; do not infer the
missing protocol. See the
[80287 source report](../../design/intel_80286/report/2026-10-28-80287-processor-extension-slice.md).
The issue checkpoint is [comment 6473621922](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6473621922).

## Interruptible WAIT slice — 2026-10-28 15:32 UTC

The functional core now accepts real-mode NMI and IF-enabled INTR while
opcode `9Bh` WAIT is stalled on BUSY. The strict Verilator 5.052 `-Wall`
runner build, focused `--processor-extension` slice and full default bootstrap
pass. The 58-line default log SHA-256 is
`6e8e3eab5bfe50f8a821377cc88a703a01a83f8d659592d2d0672458c469e873`. Intel's
1983 handbook establishes interruptibility but not the saved IP; successor-IP
behavior remains assumption A25 pending independent 286 evidence. The same
manual identifies `00FAh` word transfers for ESC memory operands and their
memory-cycle count, but the successful ESC command bytes and port order remain
source-blocked. See the
[WAIT report](../../design/intel_80286/report/2026-10-28-wait-interruptibility.md)
and [issue checkpoint 6473353919](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6473353919).

The separate whole-core PDR is still active on its earlier 21-file snapshot;
at 15:32 UTC it was at frame 8 with 326/411 outputs proved and one timeout
retry in that pass. It does not prove this source. Current-source connected
proof and the full release gate remain open.

## CPL1/CPL2 protected event slice — 2026-10-28 15:17 UTC

The strict Verilator `-Wall` build, existing CPL3 protected-event regression,
the four focused CPL1/CPL2 matrices and the full default bootstrap pass.
`--protected-event-ring12`, `--protected-event-ring12-exception`,
`--protected-event-ring12-external` and `--protected-event-ring12-nmi` add 48
executions. They cover software `INT 13h` through interrupt/trap gates at
allowed and denied DPL boundaries, privileged LIDT #GP(0) through gate DPL
0/3, external INTR vector 13 and NMI vector 2 through DPL-0 gates. They run
with and without READY stalls and check TSS SP0:SS0, exact outer frames,
IF/TF handling, no writes to the interrupted stack and exact IRET successors.
The scanned Intel
210498-005 §9.4/Figure 9-4 was reviewed with Playwright CLI. No RTL changed.
See the [event report](../../design/intel_80286/report/2026-10-28-protected-event-ring12.md).
The issue checkpoint is
[comment 6472602584](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6472602584).

At this checkpoint the tests did not cover other CPL1/CPL2 exceptions or
external vectors, task-gate event delivery, nested faults during stack
switching, connected-core formal closure or the `run_all.sh` release gate. A
2026-10-29 follow-up now covers external INTR and software-INT/#GP through a
DPL-0 IDT task gate; see the
[task-gate event report](../../design/intel_80286/report/2026-10-29-task-gate-event-delivery.md).
Other vectors, nested task-switch faults, current-source connected-core formal
and the full release gate remain open. The preserved whole-core PDR is still
an older 21-file snapshot and is not current-source evidence.

## Current-source component formal refresh — 2026-10-28 14:46 UTC

The 12 standalone formal configurations now pass BMC, proof and cover (36/36
tasks); 59 cover witnesses were reached. `preflight.py` passes, and the
component-only exact-source audit verifies every saved task configuration and
copied source against current inputs. See the
[formal component report](../../design/intel_80286/report/2026-10-28-formal-components-current.md).

The connected-core suite remains open. The active whole-core PDR is an older
21-file snapshot; at 14:46 UTC it was at frame 89 with 321/411 outputs proven
and 70 timeout retries. Do not use it as current-source evidence. A coordinated
connected-core epoch and full exact-source release audit remain next, after
this long-running job terminates.

## Full bootstrap verifies selector matrix wiring — 2026-10-28 14:39 UTC

The full default bootstrap passes with the new 768-case CPL1/CPL2 selector
matrix wired in, alongside the full `--selector-exec` slice and strict
Verilator `-Wall` runner build. The default run completed without failures;
its log SHA-256 is
`b8b4f5785f276e9336a009fe23e724073e7d58c3aad5b00b722b478943629d41`.
See the [verification report](../../design/intel_80286/report/2026-10-28-selector-query-ring12.md)
and [issue checkpoint 6471994393](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6471994393).

The separate whole-core PDR remains on its older snapshot; at 14:39:46 it was
at frame 83 with 321/411 outputs proven and 68 timeout retries. It does not
verify current source; the full acceptance gates remain open.

## Reachable CPL1/CPL2 selector-query matrix — 2026-10-28 14:35 UTC

The selector testbench now passes 768 reachable query executions after real
outer-IRET entry to CPL1 and CPL2. The matrix spans writable data, readable
nonconforming code and readable conforming code; every DPL/RPL pair; VERR,
VERW, LAR and LSL; and both READY modes. Strict `-Wall` runner build and the
complete selector slice pass. Intel 210498-005 §11.3 (printed pages 11-3–11-4)
was visually reviewed with Playwright CLI. No RTL changed. Evidence and exact
identities are in the
[CPL1/CPL2 report](../../design/intel_80286/report/2026-10-28-selector-query-ring12.md).

The separate whole-core PDR remains on its older 21-file snapshot; at 14:35 it
was at frame 80 with 321/411 outputs proven and 66 timeout retries. It does
not verify current source. Whole-CPU acceptance remains open.

## 80287 ESC source boundary — 2026-10-28 14:16 UTC

Intel 210760-002 Chapter 6 Figure 6-3 (printed page 6-6, PDF page 216) states
that data-channel transfers occur after ESC only while BUSY remains high and
that the channel is closed when BUSY falls until another ESC; word transfers
take two bus cycles at even addresses and three at odd addresses. Intel AP-113
(1981) is a primary Intel source but documents 8087/8086/88 queue/status pins,
not the 80286/80287 interface, so it cannot supply the missing ESC command
bytes. No RTL sequence was inferred. Next search another 80287-specific Intel
interface manual; if none documents the bytes, obtain an independent
80286/80287 pin trace before implementation. See the
[80287 report](../../design/intel_80286/report/2026-10-28-80287-processor-extension-slice.md)
and [native-bus specification](../../design/intel_80286/spec/native_bus_interface.md).
The source boundary is recorded in [issue comment 6471416319](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6471416319).

## CPL3 selector-query and table-bound coverage — 2026-10-28 14:12 UTC

The reachable-CPL3 selector regression now has 160 passing query runs across
both READY modes. It covers conforming code; all seven system/gate descriptor
types; a visible P=0 writable data descriptor; null GDT selectors; and complete
descriptors outside both GDT and LDT limits. The P=0 descriptor remains
queryable; null/out-of-limit cases clear ZF without descriptor reads, including
memory-source queries that still read their selector operand. The strict
Verilator runner build and complete `--selector-exec` slice pass; RTL did not
require a change. Intel 210498-005 §11.3 (printed pages 11-3–11-4, visually
inspected in Chrome through Playwright CLI) documents the visibility, type and
bounds rules. Broader privilege/fault coverage and all whole-CPU completion
gates remain open. Evidence and exact hashes are in the
[CPL3 selector-query report](../../design/intel_80286/report/2026-10-28-selector-query-cpl3.md).

At 14:18:30 UTC, the separate whole-core PDR remained active on the earlier
21-file snapshot at frame 61, with 321/411 outputs proven and 61 timeout
retries. It does not cover current source or this testbench-only update. The
formal progress and current task fields are recorded in [issue comment 6471459873](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6471459873).

## 80287 interface source pass and active-high BUSY correction — 2026-10-28 13:17 UTC

Intel 210760-002 Chapter 6 (printed pages 6-2–6-6) establishes that the 80287
BUSY output is active high and directly connected to the CPU. This corrects
the prior active-low interpretation in the design and test harness. The core
and native wrapper now expose active-high busy_i; ERROR# is active low.
ESC checks EM/TS first, waits while BUSY is high, then delivers vector 16 if
ERROR# is asserted. WAIT follows the same BUSY/ERROR ordering, with its TS
gate. Focused simulation passes with delayed ERROR# assertions on both WAIT
and ESC. The corrected full run_sim.sh passes, including all 79
protected-mode replay cases. Current-source Yosys 0.69 synthesis passed all 12
targets, with 36 zero-problem checks, no `ERROR:` lines and 12 JSON netlists.

The source also establishes that ESC emits one or more reserved-port I/O
operations regardless of IOPL/CPL and without wait states. If an operand is
needed, the CPU initializes a bounded processor-extension data channel;
PEREQ requests a transfer, PEACK# acknowledges it during the first bus
operation, and each operand transfer uses one I/O operation plus one or two
memory operations. Transfers are indivisible and have documented priority
relative to LOCK, HOLD, execution data and prefetch. The 80287 datasheet PDF
pages 2–4 and 19 provide matching pin and waveform detail. These sources now
pin the protocol contract, but normal ESC command routing and operand
transfers remain unimplemented. The inspected Hardware Reference Manual and
Programmer's Reference Manual do not provide the complete byte-by-byte
reserved-port command sequence for each ESC form. Obtain another primary Intel
interface document or an independent pin trace before generating successful
ESC transactions; do not infer command payloads from the address map alone.

Next, implement a pin-level 80287 model and connect the protocol in stages:
reserved-port ESC command transfer with no waits and privilege bypass; channel
initialization and PEREQ/PEACK request withdrawal; byte-lane and memory beat
sequencing including odd words; arbitration against LOCK/HOLD/data/prefetch;
then error, interrupt and fault boundaries. Add directed tests for each
externally visible transaction and the required protection checks before
retiring successful ESC. The whole-core PDR remains an earlier 21-file
snapshot; at 13:16:02 UTC it was at frame 23 with 316/411 outputs proved and
27 timeout retries, so it does not verify this slice. The aggregate formal
audit and full release gate remain open. See the [latest issue checkpoint](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6470033599).

## 82288 original-source resolution — 2026-10-28 10:48 UTC

Used Playwright CLI to inspect Intel's original scanned HMOS M82288 datasheet.
It states CENL is active high, latched at the start of each bus cycle, and
sampled high at the end of `Ts` to enable the controller; low suppresses
commands and DEN. This resolves the contradictory sentence in Intel
210760-002 and is corroborated by the later compatible M82C288 datasheet.
The non-MULTIBUS local-bus functional model is now source-backed. Define the
external system-clock/processor-clock boundary before connecting it to the
native CPU wrapper; do not claim physical timing qualification from the model.
See the [source reconciliation report](../../design/intel_80286/report/2026-10-28-82288-cenl-source-conflict.md)
and [native-bus contract](../../design/intel_80286/spec/native_bus_interface.md).

The live current-source whole-core PDR remains active on an exact 21-file
snapshot. It has 276/411 assertion outputs proved at frame 6 of the current
anytime pass, with no counterexample or terminal result. The assertion at
property line 189 was proved earlier as output 147 in frame 14. The aggregate
release gate is still open.

## Current-source PDR follow-up — 2026-10-28 10:27 UTC

A separate whole-core ABC PDR run now uses the current source set in
`design/intel_80286/work/release_lock_checkpoint_20261028_0720/formal_runs/current_pdr_20261028_0926/`.
The 21 copied RTL/property files match the worktree; the current top property
file hash is `A86878199D5B1CE79CD92F2C2987723F13E430A12FA9312F1616E8E503006BA2`.
Yosys translation completed in 299.26 seconds. The latest log entry at
10:27:39 UTC shows PDR at frame 19 with 261/411 assertion outputs proved and
63 timeout retries in the current anytime pass. The current-source whole-core
PDR proved the assertion at `formal/intel_80286_props.sv:189` as output 147 in
frame 14; the earlier standalone depth-12 induction result remains UNKNOWN.
No reachable counterexample or terminal PASS/FAIL has been reported; external
inputs remain unconstrained. A separate Playwright CLI PCjs debugger
rerun reached retail OS/2 1.0's command prompt and reproduced
`CPGREP -yn fast ..\README`, returning the expected line 11 with `FAST`. The
instruction-history capture still contains only the OS/2 shell wait loop; no
CPGREP trace or RTL execution evidence has been produced. This is ongoing proof
and emulator baseline work, not closure. The aggregate `run_all.sh` has not
been rerun. See
[formal report](../../design/intel_80286/report/2026-10-28-formal-induction-gap.md)
and [formal correction 6466581278](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6466581278).

## Independent release stages — 2026-10-28 09:20 UTC

The aggregate `run_all.sh` stopped at CPU prove, but its later stages are now
independently checked against the current LOCK-connected RTL in
`design/intel_80286/work/release_lock_checkpoint_20261028_0720/`. Current
simulation passes 141 lines including 79 protected replay cases. The
independent vector suite passes 99,650 Unicorn cases / 1,715,162 instruction
states. Hardware replay passes 68,510 physical 286 captures plus 52 protection
captures in both READY modes and all oracle-corruption checks. Four undefined,
four protection, six event and 15 protected-string mutations are detected.
IBM AT BIOS/software checks pass with 196,846 exact instruction states through
the ROM checkpoint. All 11 Yosys 0.69 synthesis targets pass `check -assert`
with zero problems; logs and netlists are retained in the same evidence root.

The formal evidence audit is 36/40 for the stopped aggregate: all component
tasks pass, but the core BMC/prove property copy is stale, core cover did not
run, and PDR was not reached. The complete aggregate has not been rerun after
the property fixes. The full release gate remains open. See the
[formal induction-gap report](../../design/intel_80286/report/2026-10-28-formal-induction-gap.md)
and [issue checkpoint 6465245755](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6465245755).

## Formal induction checkpoint — 2026-10-28 08:42 UTC

The isolated `run_all.sh` stopped with exit code 4 at the connected-core
depth-12 `prove` stage. All component BMC/prove/cover tasks and the connected-
core depth-24 BMC passed, but the latter is bounded evidence. The aggregate
used a copied formal-property file predating two later property-only fixes; its
core RTL inputs match current sources, but the native CPU wrapper is not in the
formal target. A separate proof using the current property file passed its
depth-12 base case; induction is UNKNOWN at
`formal/intel_80286_props.sv:189`. The trace starts from an induction-only
arbitrary `TASK_SEGMENT_START` state with PE=0 and then reaches
`SEGMENT_LOAD_WAIT`. This does not establish a reachable RTL counterexample;
the property needs a stronger invariant connecting task-switch states to
protected mode. The aggregate has not been rerun after the property edits.
Proof and trace evidence are in
`design/intel_80286/work/formal_runs/induction_reset_mask_20261028_0830/`;
the exact hashes and interpretation are recorded in the
[formal induction-gap report](../../design/intel_80286/report/2026-10-28-formal-induction-gap.md).

The aggregate did not run its later simulation, vectors, hardware, mutation,
software, synthesis or source-audit stages. LOCK-connected simulation and all
11 synthesis targets had independently passed before the aggregate attempt.
The full release gate remains open; see the
[issue checkpoint](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6464509177)
and [correction](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6464545239).

## Native LOCK integration checkpoint — 2026-10-28 07:13 UTC

The native CPU wrapper now connects the core's `bus_lock_o` intent to the
controller's active-low `LOCK#`. The core tracks F0 independently from the
general prefix state and holds its lock window across explicit LOCK-prefixed
memory MOV/MOVS/INS/OUTS and rotate-memory paths, and implicit memory XCHG.
The pin-level test passes explicit memory MOV load/store, LOCK ROL on memory,
locked and implicit XCHG, and two iterations each of REP LOCK MOVSB, INSB and
OUTSB. It checks READY waits on memory and I/O, lock coverage through operand
gaps, HOLD exclusion, release after the operation and no LOCK during fetch.
The full `run_sim.sh` result remains 141 PASS lines, including 79 protected
replay cases. See the
[LOCK integration report](../../design/intel_80286/report/2026-10-28-native-lock-integration.md).

Yosys 0.69 `run_synth.sh` completed all 11 targets; all ended normally, each
reported zero problems in three checks and no log contains `ERROR:`. The
integrated `intel_80286_native_cpu` target reports 50,003 generic cells. See
the retained logs and netlists under
`design/intel_80286/work/native-lock-candidate-20261028/synth/` and the
[native LOCK integration report](../../design/intel_80286/report/2026-10-28-native-lock-integration.md).
External clock division/reset timing, descriptor-table and processor-extension
automatic locks, 82288 commands/ALE, 80287 signaling, current-source
connected-core formal, CPGREP on RTL, an independent instruction trace and the
complete `run_all.sh` gate remain open. Issue #80 stays Open/Building with
Agent Codex; Path, first Start date and Sprint remain intact. See
[issue comment 6463032004](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6463032004).

## Previous native CPU and formal checkpoint — 2026-10-28 06:21 UTC

The source-backed [native local-bus contract](../../design/intel_80286/spec/native_bus_interface.md)
now has a partial RTL bridge. The core's opt-in `NATIVE_BEATS=1` boundary
reports one/two-byte 16-bit lane beats, and `intel_80286_native_cpu` connects
it to `intel_80286_native_bus` for physical READY, address/data/status, lanes,
INTR/NMI, two-cycle INTA, and HOLD/HLDA at one processor-clock boundary.
The captured current-source `run_sim.sh` has 141 PASS lines, including all 79
protected-mode replay cases. Yosys 0.69 synthesis and `check -assert` pass all
11 targets, including the integrated wrapper. See the
[native CPU bridge report](../../design/intel_80286/report/2026-10-28-native-cpu-bridge.md)
for commands, hashes, logs and limits.

External clock division and RESET timing remain absent. Core LOCK intent is
tied low, and 82288 command/ALE and 80287 signaling are unimplemented. The
OS/2 SDK CPGREP baseline was reproduced with `playwright-cli` in PCjs/OS/2,
but has no RTL execution or instruction trace. The old connected-core cover
ended with SBY `ERROR`/rc=16 because Yices returned no status after 45/73
goals; that input snapshot predates native-beat RTL. The corrected depth-12
proof passes its base case but remains UNKNOWN on induction. No current-source
connected-core proof covers this RTL, and the exact-source `run_all.sh` release
gate remains open. Keep issue #80 Open/Building with Agent Codex, Path
`ai_hw_engineer/design/intel_80286`, first Start date `2026-10-23`, Sprint 1.
The [latest issue checkpoint](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6462275940)
records the verified bridge evidence.

## Earlier formal and native-interface checkpoint — 2026-10-28 04:47 UTC

Added the source-backed
[native local-bus contract](../../design/intel_80286/spec/native_bus_interface.md)
from Intel 210760-002. It distinguishes CPU status/address/data pins from
82288-generated ALE and command strobes, and records lane selection, odd-word
cycles, `Ti/Ts/Tc/Th`, READY waits, HOLD/HLDA, LOCK, INTA, reset/shutdown and
processor-extension requirements. This specification does not implement the
pin layer; the core remains a byte-transaction model. The 80287 timing source
and supported speed-grade profiles remain to be selected.

The OS/2 CPGREP emulator baseline is recorded, but its instruction trace and
RTL execution remain open. Its default workload requires OS/2 threads,
semaphores and file/console APIs. The pre-correction connected-core depth-24
BMC passed after 58m55s with no counterexample. Its 21-file snapshot matched
the files at that time; it is a bounded result only. The first depth-12 prove
passed its base case but failed induction at the ordinary HLT assertion
because the reachable protected-shutdown state has `halt_latch=1` and
`state=SHUTDOWN`. The assertion now applies only when `!shutdown_o`, and
formal preflight passes. The corrected depth-12 prove passed its base case but
returned UNKNOWN on induction assertions at lines 525 and 775. The trace
starts with unconstrained internal state; the reset-reachable result beyond
the checked bound remains unresolved. Source-to-log audit now counts 45/73
active cover goals reached: 38/52 top-level CPU goals and 7/21 active
component goals. The newest is the multiply/divide property at
`intel_80286_muldiv_props.sv:38`, reached at step 32 and saved as `trace42`;
the search advanced to step 33 and reached a 1-hour wait marker without a
new witness or terminal result.
The earlier `44/52` shorthand
mixed component hits into the CPU-only denominator and is superseded. Yices
remains active with no failure or terminal result.
Artifacts are under
`design/intel_80286/work/formal_runs/core_20261027_04/`. SHA-256 comparison
confirms all 21 copied run inputs (14 RTL and 7 property files) match current
sources. The former BMC no longer matches the current property file, so rerun
BMC and the aggregate audit on the corrected snapshot. PDR remains open. Issue #80:
[latest coverage checkpoint](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6460910153).

## Verification refresh — 2026-10-27

### OS/2 CPGREP baseline and RTL path audit — 14:57 UTC

The unchanged SDK 1.00 `CPGREP.EXE` now runs in a local PCjs v2.26 IBM PC AT
configured with an 80286 at 8 MHz and 2 MB RAM. The Microsoft OS/2 1.0 install
disk reaches its setup screen; Esc returns to the OS/2 command prompt. From
the SDK Samples disk, `CPGREP -yn fast ..\README` prints line 11 containing
`FAST`. Exact hashes, setup and screenshot are recorded in the
[OS/2 replay report](../../design/intel_80286/report/2026-10-27-os2-cpgrep-pcjs-replay.md).

This is an independent emulator baseline, not an RTL run or an instruction
trace. It uses retail OS/2 1.0 rather than the SDK's pre-release kernel. The
SDK source shows that default `-yn` initializes four semaphores, creates two
worker threads, and uses OS/2 file and console APIs. `-S` forces synchronous
I/O and avoids those threads, but still requires the protected executable
loader and OS/2 APIs; use it only as a diagnostic reduction. The current RTL
top has a byte-oriented transaction scheduler and no native 16-bit bus,
BHE/status, ALE or T-state interface. The remaining software gate is to
capture an independent 286 trace, define both the native-bus and platform
scope, then run the same binary/input on RTL. Source details and its hash are
in the [OS/2 replay report](../../design/intel_80286/report/2026-10-27-os2-cpgrep-pcjs-replay.md).
The current-source depth-24 connected-core BMC reached frame 22 at 14:54 UTC,
without a terminal result. Issue #80 checkpoint:
[comment 6445145179](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6445145179).

### HALT/shutdown cycle outputs and task-switch reset cuts — 14:11 UTC

The byte-transaction interface now exposes separate `bus_halt_cycle_o` and
`bus_shutdown_cycle_o` outputs. They distinguish HLT from shutdown, remain
asserted while READY is low, and do not issue byte requests. Raw status, A1
and ALE pins remain outside this interface. The expanded `--iopl-controls`
suite passes 480 privilege scenarios, 234 reset cuts after every accepted
data transfer during nested #DF task-gate entry and 180 during task IRET,
followed by exact reset-vector HLT replay in both READY policies. The full bootstrap, strict Verilator
5.052 `-Wall`, preflight and full-core Yosys synthesis pass. `check -assert`
reports zero problems; the synthesized design has 49,771 cells across 11
submodules. See the
[bus-cycle and reset-cut report](../../design/intel_80286/report/2026-10-27-shutdown-bus-cycles.md)
for hashes and logs.

The pre-bus connected-core BMC was stopped at frame 17 without a terminal
result. A fresh current-source depth-24 BMC is active in
`design/intel_80286/work/formal_runs/shutdown_bus_core_20261027_01/`; its last
logged progress is frame 12. It has no terminal result, and no connected-core
formal task has passed. Prove, cover, PDR and aggregate audit
remain open, as do raw bus-pin timing, the full #DF matrix, OS/2 CPGREP and
full release acceptance. The component event-controller
BMC, k-induction and cover results remain valid for their recorded snapshot.
GitHub checkpoint: [comment 6444263447](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6444263447).

### Add protected shutdown NMI exit — 13:23 UTC

NMI during protected shutdown now takes vector 2 through the protected gate,
target and frame path, while INTR is ignored. Shutdown clears only after a
successful commit. An IDT-limit failure, invalid gate or invalid target
descriptor returns to RESET-only shutdown, and a second NMI cannot escape
after that failed attempt. Directed cases pass both READY modes. So do the
480-case privilege/task suite, full default bootstrap, strict Verilator 5.052
`-Wall` lint and release preflight.

The standalone event controller passes 8,016 checks and current-source BMC,
k-induction and cover, with its shutdown-NMI witness reached. This is
component evidence only; no connected-core proof covers the new CPU snapshot.
Older `_21` cover/PDR jobs remain active against previous snapshots. Exact
hashes and logs are in the [NMI recovery report](../../design/intel_80286/report/2026-10-27-shutdown-nmi-recovery.md)
and `design/intel_80286/work/shutdown_nmi_20261027_03/`.

Next, extend the 286 #DF cause and delivery-failure matrix, including NMI
failures beyond IDT/gate/target admission; model the external shutdown HALT
bus cycle; add task-switch reset cuts; then run a fresh connected-core
BMC/prove/cover/PDR epoch and aggregate source audit once the older jobs
terminate. Synthesis, OS/2 CPGREP and full release acceptance remain open.
GitHub checkpoint will follow the issue #80 readback.

### Escalate invalid first-handler gates to #DF — 13:10 UTC

Gate validation now converts a fault while invoking restartable protected
#DE/#TS/#NP/#SS/#GP into null-error #DF and retains the original CS:IP:FLAGS:SP.
A test executes DIV-by-zero, reads an invalid vector-0 gate, and then confirms
the vector-8 gate lookup; its invalid gate enters sticky shutdown. Both READY
modes pass, together with the IDT-limit, invalid #DF gate, task-TSS admission
and incoming-LDTR shutdown cases. Valid #DF task entry and task IRET also pass.

Strict Verilator 5.052 `-Wall` lint, release preflight, a fresh exact-source
runner, `--iopl-controls` and the full default bootstrap pass. See the
[double-fault report](../../design/intel_80286/report/2026-10-27-double-fault-shutdown.md)
and `design/intel_80286/work/shutdown_20261027_05/` for source hashes, build
manifest and logs. No current-source connected-core proof covers this update.

Next, derive the remaining first/second-fault combinations from the 286
manual, extend nested delivery coverage beyond IDT gate validation, then add
NMI wake, external shutdown bus signaling, task-switch reset cuts and current
connected-core proofs. Full-chip acceptance remains open.
GitHub checkpoint: [comment 6442740201](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6442740201).

### Implement protected #DF shutdown on nested delivery faults — 13:04 UTC

Protected exception 8 now enters sticky shutdown when its vector-8 IDT bound,
gate, target-TSS admission or incoming task descriptor checks raise a
protection fault. The `shutdown_o` output also asserts `halted_o`; no further
bus request or retirement is allowed, and RESET clears shutdown. Immediate
and stalled READY tests cover invalid gate contents, vector-8 IDT overflow,
not-present target TSS and invalid incoming LDTR. The latter verifies that the
task busy/backlink side effects precede the shutdown. Existing successful #DF
task entry/IRET, null and non-null LDTR, and incoming segment-fault/priority
cases remain passing.

Strict Verilator 5.052 `-Wall` lint, release preflight, a fresh exact-source
runner, focused `--iopl-controls` and the full default bootstrap pass. Source
hashes, counts, build manifest and logs are recorded in
`design/intel_80286/report/2026-10-27-double-fault-shutdown.md` and
`design/intel_80286/work/shutdown_20261027_04/`. The inventory has 302
assertions, one assumption and 50 covers. No current-source connected-core
proof covers this change; the older `_21` jobs use earlier RTL/property
snapshots.

The next task is a source-derived matrix for the remaining 286 double-fault
generation and delivery cases, then task-switch reset cuts and current-source
connected-core BMC/prove/cover/PDR. Also add the documented NMI exit from
shutdown and model the external HALT bus cycle; these remain separate hardware
and exception-contract gaps. Full-chip acceptance remains open. See the
[shutdown report](../../design/intel_80286/report/2026-10-27-double-fault-shutdown.md).

GitHub checkpoint: [comment 6442632822](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6442632822).

### Execute task segment loads through a valid non-null LDT — 12:50 UTC

Incoming tasks with a valid GDT LDT descriptor now stage the LDTR base, limit
and valid bit for code and segment validation, then publish the cache together
with the incoming task's validated segments. The regression loads CS, SS, DS
and ES from four LDT entries, checks their eight-byte descriptor reads and
accessed-byte writes, confirms the visible selectors and cache bases, and
executes the exact task program. Immediate and stalled READY both pass. The
focused suite also retains the null-selector task-entry and incoming fault
matrices.

Strict Verilator 5.052 `-Wall` lint, fresh build, focused `--iopl-controls`,
full default bootstrap and release preflight pass. Commands, hashes, reports
and logs are in
`design/intel_80286/report/2026-10-27-non-null-ldt-task-entry.md`. Broader
nested-fault escalation, task-switch reset cuts, current-source connected-core
proof, shutdown and full-chip acceptance remain open. See [issue checkpoint
6442330360](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6442330360).

### Complete no-error software task-gate entry — 12:45 UTC

Successful task-gate entry now releases event-bus ownership without the event
engine re-claiming it on the same edge when the CPU already owns the bus. The
focused test executes the incoming task's exact byte stream after `0030:0300`
with null LDTR/DS/ES selectors varying RPL 0–3. It verifies visible selectors,
no exception error push or null GDT descriptor read, backlink/busy updates and
the sequential fetches through `HLT` at `0030:0307`, under both READY modes
(eight cases). Intel's earlier-stepping B-2/B-3 null DS/ES selector-clearing
erratum remains outside the selected target profile.

Verilator 5.052 strict `-Wall` lint, a fresh build, focused `--iopl-controls`,
full default bootstrap and release preflight pass. Exact hashes, commands and
logs are recorded in
`design/intel_80286/report/2026-10-27-task-gate-noerror.md`. Non-null LDTR
segment/code lookup was the next task-switch completion gate at this checkpoint;
nested escalation, task-switch reset cuts, current-source connected-core proof,
shutdown and full-chip acceptance remain open. See [issue checkpoint
6442211666](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6442211666).

### Deliver incoming task segment faults — 12:28 UTC

Incoming task validation now checks LDTR, then SS, CS, DS and ES in 286
priority order. The core routes invalid CS to #TS/#NP, invalid SS to #SS/#GP,
and invalid DS/ES to #GP/#NP with selector error codes; it publishes the
transferred task state before task-gate delivery. Eighteen selector/type/
presence/privilege cases plus three pairwise priority cases pass in both READY
modes (42 runs). Each checks the event packet, all 15 saved TSS words,
backlink/busy state and the pushed error word.

The five incoming-LDTR cases also pass in both READY modes. Follow-up review
found the earlier out-of-GDT fixture used selector 0080 under GDT limit 0187;
it was in-bounds. The fixture now uses 0188 and verifies #TS(0188) without a
descriptor read. Strict Verilator 5.052 `-Wall`, release preflight, fresh
runner build, focused `--iopl-controls` and the full default bootstrap pass.
Hashes, commands and logs are recorded in
`design/intel_80286/report/2026-10-27-incoming-segment-faults.md` and
`plans/286/STATUS.md`. No current-source connected-core formal result exists;
the older `_21` cover/PDR jobs remain active on earlier snapshots. Valid
non-null LDTR task execution, no-error task-gate completion, null-selector RPL
variants, additional nested-fault paths, task-switch reset cuts/properties,
shutdown and full-chip acceptance remain open. Issue checkpoint:
[comment 6441881555](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6441881555).

### Deliver pre-switch task-return backlink faults — 11:44 UTC

IRET with NT set now reports invalid backlink admission through same-task
protected event delivery before saving the outgoing TSS or clearing its busy
bit. Null, LDT, out-of-GDT, wrong-type and undersized backlink TSS cases raise
#TS(selector); a not-present TSS raises #NP(selector); an available rather than
busy TSS raises #GP(selector). The 14-case matrix checks exact selector error
codes, restartable CS:IP:FLAGS:SP and no TSS-save/busy-clear writes in both
READY modes. The valid backlink return/re-entry path remains passing.

Strict Verilator 5.052 `-Wall` lint, release preflight, focused
`--iopl-controls` and full default bootstrap pass. Exact hashes and logs are in
`design/intel_80286/report/2026-10-27-task-return-faults.md` and
`plans/286/STATUS.md`. Formal properties were not changed; the older `_21`
cover/PDR jobs remain active against prior source snapshots, so no current
connected-core result covers this change. Incoming LDTR fault delivery is now
implemented in the newer checkpoint above. Next, implement the loaded-LDT
cache path for incoming tasks, investigate no-error task-gate completion,
then add task-switch reset cuts/properties and complete nested #DF/shutdown
behavior. Full-chip
acceptance remains open. Issue checkpoint:
[comment 6441100122](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6441100122).

### Implement nested-task IRET through the backlink — 11:33 UTC

Protected IRET with NT set now validates the current TSS backlink as a busy,
present GDT 286 TSS, saves the active handler task with post-IRET IP and NT
cleared, clears the active TSS busy bit, and restores the backlink task without
nesting. The regression enters a #DF task, IRETs to the interrupted CPL3 task,
observes its faulting HLT execute again, then verifies that the now-available
handler TSS is invoked and resumes at the saved `0030:0301` successor. It checks
busy-byte clear/re-set order and the saved handler task image. Immediate and
stalled READY modes pass.

Strict Verilator 5.052 `-Wall` lint, release preflight, focused
`--iopl-controls` and the full bootstrap pass. Exact source hashes and logs are
in `design/intel_80286/report/2026-10-27-task-iret.md` and
`plans/286/STATUS.md`. The tested behavior follows Intel 210498-005 §§8.3–8.4
and Table 8-2. Invalid backlink/TSS/segment priority, non-null LDTR, additional
#DF causes, shutdown, reset cuts and connected-core properties remain open.
The older `_21` cover/PDR jobs are still active on prior snapshots; no current
formal result covers this RTL and no overlapping core run was started. The
pre-switch backlink priority is now implemented in the newer checkpoint above;
post-transfer incoming-state failures remain the next task-switch gap.

### Implement a successful #DF task-gate entry slice — 11:24 UTC

Continued from the descriptor preflight into a bounded working nested task
switch. A valid type-5 #DF gate to a present, available GDT TSS now sets the
target busy bit, writes the old TR selector to the backlink, saves all 15
dynamic words in the outgoing TSS, and loads the incoming task image. The
incoming null LDTR and SS/CS/DS/ES are checked before cache publication. The
core sets NT and TS, pushes the null #DF error word on the incoming SS:SP, and
commits registers, FLAGS, TR and all segment caches atomically.

The strengthened `--iopl-controls` case passes in both READY modes and checks
the complete outgoing TSS image, incoming general registers and hidden segment
bases, backlink, target busy byte, TS/NT, error-code push, and exact
`0030:0300` to `0030:0301` HLT landing. Strict Verilator 5.052 `-Wall` lint,
release preflight and the full default bootstrap pass. Logs, fresh binary and
exact hashes are recorded in
`design/intel_80286/report/2026-10-27-task-gate-switch.md` and
`plans/286/STATUS.md`.

The entry-only checkpoint did not cover task IRET/backlink return, non-null
LDTR, architectural exception priority for invalid incoming TSS/segment
state, nested task-switch failure escalation, broad #DF generation, reset cuts or
shutdown. Task IRET has since been added in the checkpoint above. The older
`_21` core cover/PDR jobs remain active on prior snapshots
(cover last waiting at step 35 at 11:12:25 UTC; PDR last reported 366 outputs
proved at 11:22:28 UTC). No current-source connected-core proof exists, and no
overlapping run was launched. Task IRET and pre-switch backlink-fault priority
have since been implemented in the newer checkpoints above. Incoming
task-state fault delivery and current-source formal properties remain open.
The full 80286 objective remains open.

### Add a bounded nested #GP to #DF vector-selection transition — 10:53 UTC

Added protected `EVENT_START` handling for an IDT-limit #GP raised while
looking up an initial restartable #DE/#TS/#NP/#SS/#GP handler. It changes the
event packet to vector 8, uses a null error code and preserves the original
saved context. The regression starts with a CPL3 HLT, makes only the vector-13
gate lookup exceed the IDT limit, and confirms the vector-8 lookup reads its
eight gate bytes. It runs in both READY modes, and the test-first case failed
before the RTL change. The fixture leaves the vector-8 descriptor all-zero,
so the interrupt/trap-only gate validator stops. This proves selection only,
not task-gate entry or shutdown.

The focused `--iopl-controls` suite, full bootstrap and release preflight pass.
Evidence: `design/intel_80286/report/2026-10-27-double-fault-escalation.md`;
logs: `design/intel_80286/work/double_fault_classification_20261027_01/`.
RTL SHA-256 is
`2777eaea08bd5de2247a994d1468ab707f5d596d4e367915bb097c031af75d90`; testbench
SHA-256 is
`42a1726bd7dd589426934650f947788944b732c23c763f2540a222362eb8d137`. Formal
properties remain 298 assertions, one assumption and 49 covers. No current
source connected-core formal result exists. The older `_21` cover job was
waiting at step 35 at 10:42:24 UTC and PDR was at frame 25 at 10:39:46 UTC;
the complete #DF matrix, task gate and 286 task switch, shutdown behavior,
formal closure, historical software and full release acceptance remain open.
See [current status](STATUS.md) and the [issue checkpoint](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6440006292).

### Add a #DF selection invariant and reachability cover — 10:59 UTC

Added one connected-core assertion for the protected IDT-limit escalation:
the current #DE/#TS/#NP/#SS/#GP packet must become restartable vector 8 with a
null error code, preserve saved CS:IP:FLAGS:SP:SS, suppress retirement, and
leave normal event delivery inactive. A cover marks the transition reachable.
The reviewed property inventory and preflight now pass at 299 assertions,
one assumption and 50 covers. Property SHA-256 is
`d650dd7231a11b85b7737a9295afe0161a2cf87c235ae90fff6915f2688b28cb`. No
connected-core proof or cover has evaluated it: the live `_21` jobs use an
older snapshot. Do not overlap them; run a current-source BMC/prove/cover/PDR
epoch after they finish.

### Formal wait update — 11:00 UTC

Re-polled the live Docker container and solver processes. The older `_21`
cover remains at step 35, with its latest console entry still waiting on the
solver at 10:42:24 UTC. PDR advanced to frame 29 at 10:58:49 UTC: 366 outputs
proved, 28 timeout retries. These jobs remain active on prior snapshots; no
current-source result is available, so do not launch an overlapping core run.

### Extend LLDT/LTR privilege checks to CPL 1–3 — 2026-10-27 10:37 UTC

The `--selector-exec` fixture previously exercised LLDT/LTR privilege denial
at CPL3 only. I parameterized its reachable outer-IRET setup across CPL1, CPL2
and CPL3, with matching DPL code, data and stack descriptors. A same-level
exception gate delivers #GP(0); the handler repairs the saved IP and IRETs to
the exact successor. The 24-case matrix covers both register and memory forms
in both READY policies, including no denied operand read, no descriptor/TSS
traffic, preserved LDTR/TR and exact frame writes.

The focused selector suite, full default bootstrap and release preflight pass.
Evidence is in `design/intel_80286/report/2026-10-27-lldt-ltr-privilege.md`.
RTL SHA-256 remains
`12142e802f75351dc0a5eaff2e3094ee2b6d424d8f15d20b67505625f25406a4`; the
testbench hash is
`5448afc1e2fbaab2c7bfa8979bf079dbcd1c19587e0c2ff0cabbf9e9fe2dab0a`. The
older `_21` connected-core cover/PDR jobs remain active on prior source.
After those terminate, run current-source formal; continue the remaining
protected selector/fault-priority gaps and real-software/release gates. Issue
checkpoint: [comment 6439781875](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6439781875).

### Protected system-instruction privilege — 2026-10-27 10:31 UTC

The next scoped gap was protected-mode privilege enforcement for LGDT, LIDT,
LMSW and CLTS. Intel 210498-005 §§10.2–10.3 identifies these as privileged;
nonzero CPL now receives restartable #GP(0) in PREPARE, before any memory
operand read. Existing LLDT/LTR checks remain. The focused suite adds 120
denied cases across CPL 1–3, all IOPL values, five instruction forms and both
READY modes, plus 40 ring-0 controls. All 480 combined IOPL/IF/HLT/system
privilege scenarios pass. The full bootstrap and release preflight also pass.
The test-first regression failed on CPL 1 CLTS before the RTL change and
passed afterward. Exact evidence is in
`design/intel_80286/report/2026-10-27-system-instruction-privilege.md`.

The RTL SHA-256 is
`12142e802f75351dc0a5eaff2e3094ee2b6d424d8f15d20b67505625f25406a4`; current
formal properties remain at 298 assertions, one assumption and 49 covers.
The older `_21` cover/PDR jobs remain active on earlier source and property
snapshots (cover waiting at step 35; PDR at frame 23, 366 outputs proved, 27
timeouts). No current-source connected-core result exists. Continue with
source-matched core formal after those jobs terminate, then broaden the
privileged system-instruction and exception-priority matrix; task switching,
nested-fault escalation, independent historical software and full release
acceptance remain open. Issue checkpoint:
[comment 6439651353](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6439651353).

### Protected IOPL and HLT privilege controls — 2026-10-27 10:14 UTC

The next documented privilege gap was IOPL-controlled port I/O and the related
IF/IOPL restoration rules. Intel 210498-005 §§3.11.1, 3.11.3, 4.1 and 10.1
specify the protected-mode checks. The scoped contract is written in
`design/intel_80286/spec/iopl_control.md`; implementation adds restartable
`#GP(0)` before direct or string I/O when `CPL > IOPL`, applies the same gate
to CLI/STI, and gates IF/IOPL writes from POPF/IRET. Real-mode POPF/IRET
behavior is retained.

The focused `--iopl-controls` test passes 320 scenarios across both READY
modes: 288 IOPL/IF checks and 32 protected-HLT CPL/IOPL checks. Protected HLT
is allowed at CPL 0 for every IOPL and raises restartable `#GP(0)` at CPL 1–3,
independent of IOPL. The contract is in
`design/intel_80286/spec/hlt_privilege.md`; the detailed checkpoint is
`design/intel_80286/report/2026-10-27-hlt-privilege.md`. The full default
bootstrap and release preflight pass. It also verifies that ring-3 interrupt
gate IRET at IOPL 0 leaves the handler's cleared IF while preserving the
interrupted FLAGS in the exception frame. Ring-3 fixtures now use NOP
successors instead of HLT stop markers. Full log:
`design/intel_80286/work/iopl_controls_20261027/full_bootstrap.log`.

Current RTL SHA-256 is
`2ca0d9a8f46e9b3774505593c0dcebb0a70ec6530e848c3fb0d39eccba55fec1`;
bootstrap SHA-256 is
`a5950b687d035d4dad76ba2a5dae07d6d9c39c7ed9af0273700020eed3ce9fc9`; formal
property SHA-256 is
`85b8d6f497c927d084f21da29b10fa0be1ea8438242e2de735ee655e20056f53` (298
assertions, one assumption, 49 covers). The runner fingerprint is
`b70b79df2eac78d675627c4e47bd6f354d9efdd8f862b853249cfdd75c63c991`. The
`_21` cover and PDR jobs remain active on older sources; at 10:17:23 UTC the
cover was waiting on the solver at step 35, and at 10:16:28 UTC PDR was at
frame 20 with 366 outputs proved and 27 timeout retries. Do not
treat those results as evidence for this RTL. Once they terminate, resume with
exact-source connected-core BMC, prove, cover, PDR and aggregate audit; then
continue task gates, documented privilege/fault gaps, task switching and
real-software regressions. Full acceptance is not claimed.

### Outer RETF stack-span fault and prove retry — 2026-10-27 09:19 UTC

Run `_26` passed its depth-12 base case, then returned `UNKNOWN` at induction
on `protected_ret_active -> PE && (opcode==CA || opcode==CB)` (property line
86). The induction-only VCD begins with simultaneous RET, IRET and event
owners. That arbitrary state does not prove a reset-reachable failure. Code
review found a separate reachable gap: the generic `MEMORY_CHECK` exception
path did not clear the RET owner when `RET_OUTER_NEXT` rejected the current
stack span. The CPU could start handler execution with the abandoned RET owner
still set. The fault path now clears `protected_ret_active`, `ret_outer_active`
and both outer-return preflight flags before normal exception delivery; the
unsupported stop branch clears them too.

Added a focused case to `--call-gate-retf-faults`: after a real ring-3-to-ring-0
CALL gate writes the return frame, code narrows the current ring-0 SS limit to
`00FB` while preserving the same base. RETF reads saved IP:CS at `00F8`–`00FB`,
then must fault `#SS(0)` because its full span reaches `00FF`. The regression
checks exact saved `CS:IP`, flags, SP, exception-frame bytes, unchanged outer
call frame and no access above the limit. The handler discards the error word,
restores the wide SS, IRETs to retry the exact RETF, and verifies the exact
ring-3 return and successor HLT. Both READY modes pass. Release preflight
passes. Verilator 5.052 runner build fingerprint:
`e2037a67cdc9c881a98063562c2c3dc996ec81e2b2288a949c1501cfc4747cca`.

Current RTL SHA-256:
`ffa9248d1866ecea38b2357f265028821a79768349e2ba86b7f0ac036ba6642b`.
Properties remain 298 source assertion statements, one assumption and 49
covers; SHA-256:
`edbef28f43c79e09a09035ea7d40a8b76e18d95c58adf2d17a6051e35b96ee36`.
Connected-core prove `_27` copied this snapshot at 09:19:25 UTC and is still
preparing the Yosys model. Current-property BMC, complete prove, cover, PDR
and aggregate exact-source audit remain open. See [latest issue checkpoint]
(https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6438148531).

### Denied-memory-check RET owner assertion and prove `_28` — 2026-10-27 09:27 UTC

Run `_27` used the updated RETF fault cleanup RTL and the prior properties.
Its depth-12 base case passed, then induction returned UNKNOWN at line 86. The
trace starts with arbitrary simultaneous RET and IRET owners and later changes
the opcode to `89` during fetch. It does not exercise the fixed memory-check
fault path and does not establish a reset-reachable defect.

I replaced the broad owner-to-opcode invariant with a direct one-cycle
transition assertion: if the previous cycle was a denied `MEMORY_CHECK`, the
protected RET owner, outer-return flag, and both outer-return preflight flags
must now be clear. State-specific RET continuations continue to require their
protected owner and RETF opcode. Preflight passes; the property count remains
298 assertions, one assumption and 49 covers. New property SHA-256:
`bdc4e685c1d37906a744075ccfcbb76fc9cc6243a3418d8fcf9f2865095a42d0`. RTL SHA
is `ffa9248d1866ecea38b2357f265028821a79768349e2ba86b7f0ac036ba6642b`.

Connected-core prove `_28` started at 09:27:30 UTC against this property
snapshot. Its result is pending under
`design/intel_80286/work/formal_runs/protected_event_outer_20261027_28/core/intel_80286_prove/`.
The focused outer-RETF fault/retry suite passes in both READY modes. Current
BMC, cover, PDR and exact-source aggregate audit remain open.

### RET continuation owner refinement and prove `_29` — 2026-10-27 09:36 UTC

Run `_28` passed the depth-12 base case and returned UNKNOWN at induction
line 578. Its trace started at an arbitrary BUS return continuation and
reached `RET_CODE_START` with opcode `83`; the denied-memory-check cleanup
assertion passed. The state-specific RET code-load assertion now checks PE
and the active return owner there. The `FAR_RETURN_DONE` launch property still
checks the RETF opcode.

Preflight passes with 298 assertions, one assumption and 49 covers; the new
property SHA-256 is
`95b1d902dac419a23b2ed19758f4061ddb4ad175fef19ab11deecd717f567dfc`. The RTL
SHA-256 remains
`ffa9248d1866ecea38b2357f265028821a79768349e2ba86b7f0ac036ba6642b`. The
focused outer-RETF `#SS(0)` repair/retry suite and full Verilator bootstrap
pass; see `design/intel_80286/work/sim_codex_20261027/full_bootstrap.log`.

Connected-core prove `_29` copied these exact source hashes at 09:36:34 UTC;
Yosys preparation is ongoing. BMC, cover, PDR and exact-source aggregate
audit remain open.

### Event-state ownership refinement — 2026-10-27 09:46 UTC

Run `_29` copied the `09:36` RTL and property hashes. Its depth-12 base case
passed, then induction returned UNKNOWN at line 329. The induction trace
started from a BUS continuation with `memory_return=EVENT_GATE_TAIL`, but no
active event owner and no valid packet. This identifies a non-inductive
reverse state-to-owner assertion; it does not establish a reset-reachable
counterexample.

The reverse assertion now applies when the prior cycle already had
`event_delivery_active`. The complementary assertion still checks that an
active delivery has a valid protected packet and a legal continuation path.
Preflight passes with 298 assertions, one assumption and 49 covers. Current
property SHA-256 is
`b46fea44605d534db9578a494663fdd3d76b0f1ad07e263ba8d9ca041d96e9c5`; RTL
SHA-256 remains
`ffa9248d1866ecea38b2357f265028821a79768349e2ba86b7f0ac036ba6642b`.
The next proof snapshot is not started while the earlier `_21` cover and PDR
jobs remain active. Current-property BMC, prove, cover, PDR and the aggregate
source audit remain open. See the live [status](STATUS.md) and
[issue checkpoint](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6438637209).

### Earlier connected-core proof retry — 2026-10-27 09:03 UTC

The induction-only ownership failure at `intel_80286_props.sv:160` was
addressed with four state-specific assertions: two tie outer-IRET code-load
continuations to their saved return owner, and two tie protected CALL TSS
stack selection to an active CALL transaction. Run `_22` passed its depth-12
base case but still failed induction at line 160; `_23` passed that property
and exposed a separate induction-only failure at line 180. Trace review showed
that successful event code-load can reach a more privileged handler while its
TSS stack pair is invalid. This implementation explicitly stops on that
unsupported nested-fault path, so the old unconditional `EVENT_FRAME_CHECK`
assertion was too broad. It now checks the three precise outcomes: stop on an
invalid TSS pair, start the TSS-pair read when valid, or proceed directly to
frame checking at the same privilege level.

Run `_24` passed its depth-12 base case but failed induction at line 160. Its
induction-only witness enters `CALL_DESC_CHECK` → `CALL_CODE_START` →
`CODE_LOAD_WAIT` while PE is clear and no protected owner is active. That
sequence is reachable only from the PE-gated protected CALL branch. The
state-exclusion invariant added for `_25` removed this failure. `_25` passed
its depth-12 base case, then failed induction at line 572: its witness has
`protected_ret_active=1`, PE set, opcode `2Ch`, and reaches `RET_CODE_START`
from an outer-return continuation. RTL sets that owner only for protected
RETF/RETF-imm (`CB`/`CA`), so this is another unreachable induction state. A
new invariant binds the active return owner to PE and those two opcodes.

Current CPU properties have 298 source assertion statements, one assumption
and 49 covers; SHA-256
`edbef28f43c79e09a09035ea7d40a8b76e18d95c58adf2d17a6051e35b96ee36`. RTL is
unchanged at
`7ad3e9a821f87640c632bfef1294a612a091617b7a9a7e88692c2eee9e97cea1`.
Preflight passes. Connected-core prove `_26` copied the current property hash
and started model preparation at 09:02:01 UTC. It later returned UNKNOWN at
induction line 86; see the newer checkpoint above. Evidence is under
`design/intel_80286/work/formal_runs/protected_event_outer_20261027_26/core/intel_80286_prove/`.

The earlier `_21` connected-core tasks use 290 source assertions, `_24` uses
296, and `_25` uses 297. Their results do not close the current 298-statement
property set. The 36 component tasks in `_21` remain separate evidence.
Nested-fault escalation remains unimplemented. Next: finish `_26`, then run
current-property BMC, cover, PDR and aggregate audit. Continue with task gates,
task switching and documented fault escalation after the connected-core gate
is closed.

### Previous live solver checkpoint — 2026-10-27 08:14 UTC

Matching the cover log against the 49 CPU assertions in
`intel_80286_props.sv` shows 38/49 reached, with 11 remaining. The run now
has 43 VCD files; its latest witness is a component-level `multiply_divide`
cover at step 32, so the CPU-cover count is unchanged. The outstanding CPU goals exercise async REP/debug events,
F7 /6 and PUSHA, protected event-error-frame write and outer-IRET code-load
commit, PE-enabled far-CS and DS/ES/SS cache transitions, and vector-8
IDT-limit fault delivery (property lines 485, 486, 697, 699, 783-788 and 790).
The solver remains at step 32; SBY logged another 30-minute wait at
08:02:12 UTC, while Yices remains active. The previous whole-core ABC PDR
anytime pass ended at frame 29 with 366 proven outputs and 28 timeouts (last
on output 137). ABC started a new pass, reusing clauses, and has advanced to
frame 7 with 366 proven outputs and three timeout retries queued from outputs
350, 357 and 367. Both runs remain nonterminal.
The current source and run snapshots are unchanged. This is progress evidence,
not a full proof or cover pass. See [latest issue checkpoint](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6436940553).

Release preflight passes, and all 36 refreshed component tasks pass against
current source snapshots. The 12 component configurations each pass BMC,
induction and cover; evidence is under
`design/intel_80286/work/formal_runs/protected_event_outer_20261027_21/components/`.
The previous aggregate audit was 9/40 because its saved source copies were
stale for multiple components and its current-core task directories were
missing. The connected-core depth-24 ABC BMC now passes (`PASS 0 2055`, no
counterexample through 24 frames) against unchanged RTL SHA-256
`7ad3e9a821f87640c632bfef1294a612a091617b7a9a7e88692c2eee9e97cea1` and
CPU-property SHA-256
`5055f212d8397f2505bf6e6c681758146547167cb4b942e785564f988ea2e874`; the
current exact-source audit is 37/40. Core prove `_21` returned `UNKNOWN`
after the depth-12 base case passed; induction fails at line 160 with the same
induction-only trace as `_20` and no reset-reachable counterexample. Run
evidence is under
`design/intel_80286/work/formal_runs/protected_event_outer_20261027_21/core/`.
Cover, PDR and final exact-source audit remain open; see the
[latest issue checkpoint](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6436940553).

## Current audit — protected privilege-changing event delivery (2026-10-26)

The core now delivers protected IDT interrupt and trap gates from a reachable
CPL-3 program to a more privileged nonconforming handler. It resolves the
handler code descriptor, selects SPn:SSn from the 286 TSS, validates the new
stack and complete frame span, writes old SS:SP with FLAGS/CS/IP and any error
word, then commits the new stack and control state. Interrupt gates clear IF
and TF; trap gates preserve IF and clear TF. Software INT checks the gate DPL
and raises #GP(selector) when denied; exceptions bypass the gate-DPL check.

The eight-case `--protected-event-outer` regression covers interrupt and trap
gates plus software-INT DPL failure through each gate type, with and without
READY stalls. It checks TSS/descriptor ordering, exact frame contents, no
user-stack writes, flag behavior, handler repair and IRET to the exact next
instruction. The exact-source Verilator 5.052 `-Wall` build, focused suite,
invalid protected-decode suite and full bootstrap pass. Evidence and hashes
are recorded in [STATUS.md](STATUS.md), under
`design/intel_80286/work/protected_event_outer_20261026_07/`.
Five event-specific compiled mutations plus a cached-permission mutation are
detected by the combined protected-segment and event suites; logs and mutant
hashes are under
`design/intel_80286/work/protected_event_mutations_20261026_04/`.
The exact same RTL passes Yosys 0.69 full-core synthesis and `check -assert`
with zero problems and 40,652 cells. The input hashes, command, log and JSON
netlist hashes are retained under
`design/intel_80286/work/protected_event_outer_20261026_01/synthesis/`.
The release preflight passes with its reviewed property inventory refreshed;
the full design helper suite passes 78 tests (one POSIX-only test is skipped).
The unchanged RTL SHA-256 is
`7ad3e9a821f87640c632bfef1294a612a091617b7a9a7e88692c2eee9e97cea1`.
Current CPU properties are SHA-256
`5055f212d8397f2505bf6e6c681758146547167cb4b942e785564f988ea2e874`, with
290 assertions, one assumption and 49 covers. Depth-12 Yices prove `_20` passed
its bounded base case but returned `UNKNOWN` during induction at
`intel_80286_props.sv:160`. Its induction-only witness starts in
`CODE_LOAD_WAIT` with PE clear and fails the PE ownership invariant; code-load
launches are PE-gated or originate in protected event/return states. Runs
`_12`–`_20` all passed their depth-12 base cases but returned `UNKNOWN` during
induction. Earlier witnesses exposed stale event-packet fields, unowned TSS
stack state, impossible real-mode entries into protected descriptor waits and
invalid far-return continuations. No reset-reachable counterexample has been
established. The exact latest run manifest, staged sources and witness are at
`design/intel_80286/work/formal_runs/protected_event_outer_20261026_20/core_prove/`.
The earlier depth-24 BMC uses pre-refinement properties. A matching
current-property depth-24 BMC is now running; reachable cover, PDR and the
aggregate exact-source audit remain open. See [current status](STATUS.md) for
the checkpoint and next steps.

The source-directed next steps are: finish current-source core formal tasks;
implement task-gate entry and the 286 TSS task-switch contract
needed for vector 8; add reachable fault delivery for failed protected
transfers and the §9.6.2 double-fault/shutdown matrix; expand protected
IDT/error-code and CPL/IOPL behavior; then continue the remaining documented
ISA and independent software oracle.
Keep exact-source lint, mutation evidence, synthesis, native-interface checks
and the aggregate release audit tied to one frozen source snapshot. A passing
event slice or bounded proof does not close the full 80286 objective.

## Current audit — CPL3 selector privilege faults (2026-10-26)

The protected path reaches ring 3 through validated outer IRET, exercises
same-level GDT and LDT-resident CALL gates, and enters ring 0 from ring 3
through the TSS stack. GDT gates copy 0, 1 and 31 parameter words with exact
frame placement and stack-span checks; matching outer RETF restores GDT-backed
or LDT-backed callers. No hidden CPL or segment-cache state is seeded. Tests
run in both READY modes.

The LDT target matrix now covers invalid LDTR, an out-of-limit selector, a
present data descriptor and a non-present code descriptor. The gate-slot
matrix checks all 15 non-call system descriptor types and a data descriptor,
plus DPL/presence faults. Tests verify exact #GP/#NP frames, descriptor reads,
and no target/TSS reads or CALL-frame writes before validation. Nine
ring-3-to-ring-0 TSS/SS0/stack-span failures deliver exact #TS/#SS packets on
the caller stack without new-stack CALL writes.

Outer RETF has a 13-case invalid-return matrix in both READY modes. It checks
null/out-of-limit/wrong-type/privilege-invalid/non-present saved CS and SS,
exact #GP/#NP/#SS packets and frames, saved-CS validation before SS reads, and
SS validation before the return-IP limit check. A reachable ring-0 #GP handler
repairs the saved outer SS selector, returns with IRET, retries RETF and
resumes at the exact ring-3 successor.

New reachable tests also cover ring-3 calls through a DPL-3 gate to
nonconforming DPL-1 and DPL-2 targets. They select SP1:SS1 and SP2:SS2 from
the corresponding 286 TSS offsets, validate the selected stack before writes,
copy two parameter words and return through `RETF 4` with exact ring-3
resumption. A DPL-1 conforming target called from CPL 3 keeps RPL/CPL 3 and
the caller stack, performs no TSS lookup or parameter copy, and returns at the
exact successor. Both tests pass in both READY modes.

Reachable CPL3 LLDT/LTR attempts now cover register and memory operands in
both READY modes. They deliver #GP(0) before selector-memory or candidate
descriptor/TSS access, preserve LDTR/TR, and use a same-level ring-3 handler
to IRET to the exact successor. The selector tests verify the exact protected
error frames and the candidate TSS remains available. This closes the planned
CPL3 privileged-selector check only; CPL1/CPL2 and broader trusted-instruction
rules remain open.

### Current source identity

- Core RTL SHA-256: `cbde2d3ceea2179cf75a73ac4973d6b1ef06ef4742a58f44f77566fa00b6c865`
- Bootstrap SHA-256: `bcdcca03983fa4f8697d79d804b1434ff85fe96e47274cc20b21c726a85e4c05`
- CPU properties SHA-256: `3a21719d8b6dfb974f9593e00445ee1a9c1fa8e7d50b7cb18582d1d9febd72a4`
- Verilator runner fingerprint: `db9f1ade8953bdcebe86c848bbfdbc5fe556e5695dfa7883a61f45260c899681`
- Verilator runner binary SHA-256: `a3f0491772456693e2dc9c57001d98b94b9c4f92c2520103ccc4258378e2b332`
- Protected replay manifest SHA-256: `d41f5f0736b737aefbc4b75a86bfc773d6c32db957cc742b0d020679815c9dee`
- GitHub progress update: [issue comment 6424806945](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6424806945)

The Verilator 5.052 runner manifest, focused `--call-gate-retf-faults` log
and full bootstrap log are under
`design/intel_80286/work/outer_retf_faults_20261026_08/`. The current-source
79-case replay is under
`design/intel_80286/work/callgate_outer_retf_replay_20261026_01/`; all 15
protected INS/string mutants are detected against that manifest under
`design/intel_80286/work/outer_retf_current_mutations_20261026_01/`. Yosys
0.69 full-core synthesis, `check -assert`, `stat` and JSON export pass with
zero check problems and 37,493 cells under
`design/intel_80286/work/outer_retf_faults_20261026_06/synth/`.

An earlier connected-core depth-24 ABC BMC completed `PASS 0 2009` after
checking 24 frames. Its terminal status and log are under
`design/intel_80286/work/formal_runs/outer_retf_formal_20261026_01/core_bmc/`;
the result used the earlier property SHA-256
`a9772652904194f9de03c925a163e5fe3a665f5f833539d151cc2f2505ed9ed0`. It is
not an exact run of the current properties. The current proof result is
reported in the formal audit below. Code checker and CS loader component suites
retain their earlier exact-source results; they are not whole-core closure.

The exact-source ring-1/ring-2 and conforming-target tests, matching runner
manifest and expanded full bootstrap are under
`design/intel_80286/work/callgate_ring_levels_conforming_20261026_01/`.
The CPL3 LLDT/LTR privilege tests, exact-source runner manifest, focused
`--selector-exec` log and full bootstrap log are under
`design/intel_80286/work/selector_privilege_20261026_02/`.

### Current formal audit — 2026-10-26

The current CPU-property file is SHA-256
`3a21719d8b6dfb974f9593e00445ee1a9c1fa8e7d50b7cb18582d1d9febd72a4`; the core
RTL remains `cbde2d3ceea2179cf75a73ac4973d6b1ef06ef4742a58f44f77566fa00b6c865`.
Depth-12 run `_29`, saved at
`design/intel_80286/work/formal_runs/selector_privilege_current_20261026_29/core_prove/`,
passes the base case through frame 12 and returns `UNKNOWN` at induction on
property lines 261–262. The failed invariant ties protected event-frame bus
continuations to an active, valid protected packet. Its induction-only witness
starts in `CODE_LOAD_WAIT` with an outer-IRET continuation and an invalid event
packet, then reaches a protected event-frame continuation. This history does
not establish a reset-reachable counterexample; it shows the event-packet
provenance is not yet inductive.

Trace review corrected several continuation contracts and added asserted
ownership relationships for protected CALL, outer IRET/RET and event frames.
Run `_21` showed that outer IRET enters `MEMORY_CHECK` before commit, unlike
same-level IRET. Run `_22` showed that an `0F` LTR transaction can use the
normal `COMMIT_MEMORY` continuation for its TSS busy bit. Run `_28` showed that
the successful memory-precheck return must be the captured `memory_return`,
not always `EVENT_FRAME_READY`. These runs passed the depth-12 base case but
failed induction. RTL was not changed.

The depth-24 BMC `PASS 0 2009` is exact for the previous CPU-property SHA-256
`a9772652904194f9de03c925a163e5fe3a665f5f833539d151cc2f2505ed9ed0`; it does
not match the current properties. No current-property depth-24 BMC, reachable
cover, PDR or aggregate exact-source audit is complete. The induction run
directories `_21` through `_29` preserve their logs and witnesses under
`design/intel_80286/work/formal_runs/`.
The latest issue update is [comment 6428101255](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6428101255).

### What works

- Ring-0-to-ring-3 IRET uses a real five-word frame and checks CS/SS loading,
  accessed writes, atomic state/cache commit, FLAGS, DS/ES invalidation and
  the exact successor.
- Same-level CALL gate resolves and validates the target, ignores the
  supplied offset, pushes the link and reaches the gate offset.
- A ring-0 CALL through an RPL-3 selector to a DPL-0 gate delivers #GP(0068)
  before target-descriptor lookup or CALL-frame writes; exact error-frame
  contents and READY wait/stall behavior pass.
- A DPL-accessible but non-present call gate delivers #NP(0068), also before
  target lookup or CALL-frame writes. Both #GP and #NP cases check exact frames
  in both READY modes.
- A null gate selector delivers #GP(0), and an out-of-GDT selector delivers
  #GP(0098), with no descriptor read. The DPL and presence cases read the gate
  descriptor but reject before target lookup. All selector/access cases check
  exact frames and no CALL-frame writes in both READY modes.
- A present available-TSS descriptor in the gate slot delivers #GP(0068)
  before target lookup or CALL-frame writes; its descriptor remains unchanged.
- Ring-3-to-ring-0 CALL gate loads SP0:SS0 from the TSS, validates SS0,
  prechecks stack spans, copies 0/1/31 words in order, writes the exact frame,
  and commits only after the frame is complete.
- Nine invalid TSS/SS0/stack-span CALL-gate cases deliver the expected #TS/#SS
  packets and exact frames on the original ring-3 stack, without any
  new-stack CALL-frame write, in both READY modes.
- A reachable ring-3 caller with LDT-backed CS and SS calls a gate from the
  active LDT to GDT ring-0 code; the TSS stack switch and outer RETF restore
  the exact LDT-backed caller state in both READY modes.
- A data-descriptor gate target raises #GP(0010), a DPL-3 nonconforming code
  target from CPL 0 raises #GP(0038), and a non-present code target raises
  #NP(0098). The tests check descriptor reads, exact exception frames,
  unchanged target descriptors, no TSS lookup and no CALL-frame writes.
- Null and out-of-GDT target selectors raise #GP(0) and #GP(00A0). They cause
  no target descriptor reads, TSS lookup or CALL-frame writes, and their exact
  error frames pass in both READY modes.
- LDT target selector 000C raises #GP(000C) when LDTR is invalid and when the
  active LDT limit is 7. Neither case reads an LDT descriptor or the TSS, or
  writes a CALL frame before the exact restartable #GP frame.
- Invalid LDT targets also cover a present data descriptor and a non-present
  code descriptor. The gate-slot matrix rejects all 15 non-call 286 system
  descriptor types and a data descriptor before target/TSS lookup or frame
  writes.
- Outer RETF has 13 invalid saved-CS/SS cases, including exact exception
  packets and SS-before-IP priority. A real #GP handler repairs the saved SS,
  IRETs to RETF and resumes at the exact ring-3 successor.
- Outer RETF reads saved SS:SP after the copied words, applies the immediate
  to the restored caller SP, clears inaccessible DS/ES, and resumes at the
  exact ring-3 instruction.
- Ring-3 calls to DPL-1 and DPL-2 nonconforming targets select SP1:SS1 and
  SP2:SS2, check descriptors before stack writes, copy parameters and restore
  the exact ring-3 state through `RETF 4` in both READY modes.
- A ring-3 call to a DPL-1 conforming target retains CPL/RPL 3 and caller
  SS:SP, pushes the same-level link, skips TSS lookup and parameter copies,
  and returns to the exact successor in both READY modes.
- CPL3 LLDT/LTR register and memory operands raise #GP(0) before selector
  operand/descriptor/TSS traffic. Exact frames and handler-adjusted IRET
  successors pass in both READY modes; SLDT/STR confirm LDTR/TR are unchanged.
- Full bootstrap, focused protected-transition cases, strict Verilator
  `-Wall`, code-check and code-load simulation suites pass.

### What needs to change next

1. Close the current induction gap by proving the protected event-packet and
   transfer-continuation provenance with sound inductive invariants or PDR.
   Do not turn an induction-only trace into an RTL bug or weaken the
   environment to make the proof pass.
2. Refresh depth-24 BMC, prove, reachable cover and PDR on one current
   RTL/property snapshot, then run the exact-source audit. Keep `UNKNOWN`,
   interrupted and stale results distinct from PASS.
3. Keep the exercised ring-3-to-ring-0 event transition and outer IRET; add
   reachable #TS/#SS handler repair/IRET. The first nested-#GP-to-vector-8
   selection case is covered, and type-5 IDT gates now preflight a present,
   available GDT 286 TSS before stopping. That preflight is not task entry.
   Implement the outgoing TSS save, incoming TSS load, busy/backlink/NT/TS
   updates, descriptor validation and #DF error-code push; then implement
   task IRET and verify the remaining §9.6.2 cause pairs plus #DF-entry
   failure and shutdown/reset behavior.
4. Broaden the remaining privilege matrix: selector and trusted-instruction
   fault priority, ring-1/2 event transitions, and other defined operations.
   LLDT/LTR now pass reachable CPL1–3 register/memory #GP(0) cases; the
   IOPL-controlled direct/string I/O and IF/IOPL restoration slice passes its
   focused regression and full bootstrap.
5. Continue broader release work: authentic independent software, complete ISA
   and exception coverage, isolated `run_all.sh` evidence roots, native pin
   timing and external hardware comparison.

Full 80286 acceptance is not established. The valid call-gate slice is not
proof of complete protected-mode behavior.

## Previous audit — selector query execution (2026-10-26)

This audit supersedes the selector-execution assessment below. At that
checkpoint the worktree implemented the bounded ring-0 VERR/VERW/LAR/LSL
slice, and exact-source lint, selector tests, the full bootstrap runner, the
79-case protected-string replay, Yosys synthesis/check and its depth-24 BMC
passed. Later source and property changes are covered by the current audit at
the top of this file. The complete 80286 objective remains open.

Current source identities:

- Core RTL: `f6f13192a55e775e32c29ca046f47a14ee3da5662b228d6aec5da60a34ae5939`
- Bootstrap testbench: `957df9b621bd9dfb2d7e6b122ea879550cb3eb517f6c07885cd90d12194f8585`
- CPU formal properties: `a9772652904194f9de03c925a163e5fe3a665f5f833539d151cc2f2505ed9ed0`

### What works

- The ring-0 selector path executes SLDT/STR, LLDT/LTR, updates the TSS busy
  byte for LTR, invalidates a null LDTR, and loads ordinary data segments
  through the active LDT.
- VERR, VERW, LAR and LSL now execute through the operand and descriptor-read
  path. The directed suite runs 41 query cases in both READY modes (82
  executions), including GDT/LDT bounds, selector failures, DPL/RPL checks,
  readable/writable segment rules, every defined 286 system/gate type for LAR,
  TSS/LDT types for LSL, memory sources, ZF-only changes and destination
  preservation.
- Protected selector faults now pass through a bounded same-level event path.
  Ten cases cover five #GP/#NP causes in both READY modes; two additional
  null-LDTR cases check that no LDT read occurs. Tests check the error word,
  frame write order, handler repair, IRET, and the exact resumed instruction.
- Strict Verilator 5.052 `--lint-only -Wall`, the exact-source CPU runner build,
  `--selector-exec`, and the full bootstrap regression pass on the source hashes
  above. The selector log records 2 selector-state executions, 10 selector
  #GP/#NP recoveries, 2 null-LDTR recoveries and 82 query executions. The full
  bootstrap log additionally passes the existing real-mode, boundary,
  system-register, cache, ARPL and protected event suites.
- A fresh source-matched protected-string replay passes 79 cases on this same
  RTL. Its manifest is
  `design/intel_80286/work/selector_query_replay_20261026_01/build_manifest.json`.
  The prior 52 Harris captures have not yet been replayed against this source.
- All 15 protected-string semantic mutations are detected against that exact
  79-case manifest. The result is
  `design/intel_80286/work/selector_query_mutations_20261026_01/mutations.json`;
  its manifest records the baseline manifest hash and exact source hashes.
- Yosys 0.69 full-core synthesis and `check -assert` pass on the same RTL hash;
  the hierarchy contains 32,580 cells and the check reports zero problems.

### What remains unproven or incomplete

- Protected event delivery remains a narrow slice: ring-3 faults and selected
  ring-1/ring-2 software `INT 13h`, privileged-LIDT #GP(0), external INTR
  vector-13 and NMI vector-2 paths switch through the TSS to a ring-0 handler.
  Other ring-1/
  ring-2 exceptions and external vectors, all vector/error-code cases, task
  gates, nested-fault escalation and handler recovery for invalid stack/gate
  faults remain incomplete.
- Selector-query execution now reaches CPL1, CPL2 and CPL3 after outer IRET.
  CPL1/CPL2 coverage spans writable data, readable nonconforming code and
  readable conforming code across every DPL/RPL pair for VERR/VERW/LAR/LSL;
  more system descriptor, fault and broader-ISA combinations remain open.
- The earlier depth-24 BMC completed **PASS 0 1665** on core hash
  `fd6004af2605621dc18e3bad6efae834b8027fe3f1e99059c676f8cfb3d319b0` and
  property hash
  `d6c782e88c49a9b1a353b1f8bce5e2cb6cd54e93842222163ab4cce0e09c6f3f`.
  It predates the selector-query implementation. No terminal formal result is
  tied to the current core hash. The exact-source connected-core depth-24 BMC
  completed with `PASS 0 1977` in
  `design/intel_80286/work/formal_runs/selector_query_current_20261026_01/`;
  this source predates outer IRET. Earlier induction UNKNOWN and partial
  cover/PDR results remain historical and do not establish current-source
  closure. Current-source protected-string mutation is 15/15 detected, but
  does not substitute for formal proof or whole-chip closure.
- `run_all.sh` has not run. Several stages still write fixed `work/` paths;
  the runner needs a unique evidence root before a safe aggregate release run.
- The OS/2 SDK 1.00 CPGREP sample has not executed. The recorded PCjs attempt
  stops at BIOS error 1782 before a shell. A usable independent 286 software
  or trace oracle remains outstanding.
- At audit start the feature worktree had 116 modified/untracked paths,
  including recovered test, specification, formal and runner sources. HEAD is
  `e7c2520`; local `main` is 37 commits ahead and 5 behind relative to this
  branch. The remote was not refreshed during this audit. Preserve the worktree
  and classify the recovered files before staging or reconciling branches.

### Evidence paths

- Exact-source strict lint, build and selector regression: `design/intel_80286/work/selector_query_20261026_11/`
- Exact-source CPU runner manifest: `design/intel_80286/work/selector_query_20261026_11/build/build_manifest.json`
- Full bootstrap regression: `design/intel_80286/work/selector_query_20261026_11/full_bootstrap.log`
- Exact-source Yosys synthesis/check: `design/intel_80286/work/selector_query_20261026_11/synth_core.log`
- Older depth-24 BMC PASS: `design/intel_80286/work/formal_runs/fd6004af_current_20261026_01/core_bmc/`
- Earlier 79-case replay and Harris captures use a prior RTL snapshot and are not claimed against the current query source.
- Issue #80 current-source progress update: https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6419018901
- D8 formal terminal status update: https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6416058541

The earlier `run_development_a17.log`, its D8 hash, and the incomplete A17
synthesis log are historical for this source. Focused passing simulations
establish only their tested cases; they do not qualify the full processor.

## Earlier execution plan — outer RETF checkpoint, superseded by this audit

### Gate 0 — Close evidence for the current source snapshot

1. Preserve the current branch and all ignored work evidence. Classify the
   recovered source files before staging; do not overwrite existing run dirs.
2. Current-source Verilator `-Wall`, the full bootstrap, same-level CALL gate,
   gate-access #GP/#NP cases, ring-3-to-ring-0/1/2 CALL gates, conforming
   target, outer IRET/RETF, 79-case protected replay, and
   Yosys full-core synthesis/check pass. The code-check and code-load suites
   pass 98,612 cases and 98,330 transactions respectively, including their
   BMC/prove/cover jobs. Exact evidence and source identities are recorded in
   the current audit above.
3. At this checkpoint the connected-core depth-24 ABC BMC was running at
   frame 20/24. It later completed `PASS 0 2009` for the then-current property
   hash; the latest property audit above records that hash and explains why the
   result does not match today's formal source. Keep every result pinned to
   source/property hashes; resolve induction failures with sound reachable-
   state invariants, never assumptions that exclude legal inputs.
4. The current-source protected-string mutation suite detects all 15
   semantic mutants against the 79-case replay manifest. Its exact result is
   recorded in
   `design/intel_80286/work/outer_retf_current_mutations_20261026_01/`.
   Repeat focused mutations and replay after each behavior change.
5. Give `run_all.sh` and its stages a fresh, caller-selected evidence root
   before running the aggregate. Do not let it replace existing evidence.
   **Plumbing implemented 2026-10-28:** `--work-dir DIR` and
   `INTEL_80286_WORK_DIR` route release outputs through all shell/Python
   stages; the default is a unique release directory and explicit non-empty
   roots are rejected. Focused syntax and helper/build/audit/preflight tests
   pass. The full aggregate has not run against this exact source snapshot.
   The former connected-core cover ended SBY `ERROR`/rc=16 because Yices
   returned no status; its 45/73 count is stale after native-beat changes.
6. **Core beat boundary and processor-clock pin bridge implemented
   2026-10-28.** `intel_80286` now has opt-in `NATIVE_BEATS=1`, 16-bit lane data,
   explicit `bus_beat_bytes_o`, remaining-byte `bus_size_o`, and core progress
   on the completed beat count. Even words combine; odd words split, and
   descriptor transfers remain lane-aligned byte beats. The default
   `NATIVE_BEATS=0` path preserves the byte scheduler. `intel_80286_native_cpu`
   now instantiates the beat-mode core and native pin controller. Its Verilator
   test passes even/odd word transfers with READY waits, HOLD/HLDA, two-cycle
   hardware INTA, IVT reads, the exact interrupt frame, IRET and return to HLT.
   Current `run_sim.sh` passes with 141 PASS lines, including the connected
   pin test and 79-case protected replay. Yosys 0.69 `check -assert` passes all
   11 targets with zero problems, including the wrapper. See the
   [core native-beat report](../../design/intel_80286/report/2026-10-28-core-native-beat-interface.md)
   and [native CPU bridge report](../../design/intel_80286/report/2026-10-28-native-cpu-bridge.md).
   The wrapper input clock is one processor clock, core LOCK request is tied
   low, and external CLK division/reset timing, LOCK-prefix/automatic LOCK,
   82288 and 80287 behavior remain open. No current-source connected-core
   proof covers this beat-mode RTL.

**Exit:** current-source simulation, synthesis, formal status and mutation
results are separately identifiable by hash and have terminal outcomes; any
incomplete proof is stated as incomplete.

### Gate 1 — Implement VERR/VERW/LAR/LSL (bounded ring-0 slice complete)

1. The source-backed contract is in
   `design/intel_80286/spec/selector_execution.md`. It covers descriptor types,
   table bounds, TI/LDT selection, visibility, presence-bit behavior and exact
   ZF/result handling.
2. Register and memory selector operands now use the GDT or valid cached LDT.
   Null, out-of-range, invalid-type and invisible selectors clear ZF without
   selector faults; failed LAR/LSL preserves the destination.
3. Current focused evidence covers the 41-case matrix in both READY modes,
   including every defined 286 LAR system/gate type and all LSL TSS/LDT types.
   Strict lint and the complete bootstrap regression pass for the exact source.
4. Gate 0 now has refreshed current-source replay, mutation and synthesis
   evidence. Connected-core proof, reachable cover and PDR remain open.

**Exit:** met for the tested CPL-0 GDT/LDT slice. This does not establish
nonzero-CPL behavior or close whole-core verification.

### Gate 2 — Make nonzero CPL reachable and verify privilege boundaries

The valid transition slice is implemented: a real outer-level IRET reaches
CPL 3, a same-level CALL gate is exercised, and a ring-3 CALL gate enters
CPL 0 through the TSS-selected SP0:SS0 stack. Tests cover parameter counts
0, 1 and 31, exact frame layout, stack-span prechecks, outer RETF with
immediate adjustment, and the exact ring-3 successor in both READY modes.
No hidden CPL or cache state is seeded. The source-backed contract is in
`design/intel_80286/spec/protected_privilege_transition.md`.

The invalid gate-slot and LDT-target matrices, nine ring-3-to-ring-0 TSS/SS0
faults, 13 outer RETF fault/recovery cases, DPL-1/2 TSS stack selection and
one DPL-1 conforming target are covered. The 24-case LLDT/LTR matrix now
reaches CPL1–3; the focused IOPL/IF matrix covers its defined CPL/IOPL cases.
The 48-case CPL1/CPL2 event slice covers software-INT gate-DPL allow/deny
boundaries, privileged-LIDT #GP(0) delivery through gate DPL 0/3, external
INTR vector 13 and NMI vector 2 through DPL-0 gates, with exact TSS frames and
outer-IRET successors. Next expand those privilege levels
to additional exceptions and asynchronous events, add task-gate #TS/#SS
delivery and handler repair/IRET, and test nested-fault escalation. External
INTR and software-INT/#GP task-gate entry now have their own focused matrix;
use Intel-derived selector, frame, cache, PC and memory expectations for the
remaining paths.

**Exit:** an executable outer-level IRET reaches CPL 3; a ring-3 CALL gate
enters CPL 0 through the TSS stack and returns through far RET to CPL 3. Exact
stack, selector, cache, frame, PC and side-effect checks pass against
independent Intel-derived expectations. This valid-path exit is met for the
tested configurations; the negative cases and privilege matrix above remain
open and the broader protected-mode gate is incomplete.

Source basis: Intel 210498-005 §7.5.1.4 and Figure 7-12 define the TSS-selected
inner stack, copied parameters and inter-level CALL frame; §7.5.2 defines the
outer-level far return. Section 9.4 states that outer-level IRET applies the
same return checks with the additional FLAGS word. The test must use the
architectural IRET frame to enter CPL 3 and must not manufacture CPL by editing
hidden state.

### Gate 3 — Complete protected control, events and task state

Complete far calls/returns, code and stack privilege checks, LDS/LES and
segment-stack operations, interrupt and trap gates, asynchronous events,
TSS stack selection, task gates/switching, backlink/NT/busy behavior, nested
fault escalation, #DF/shutdown, and interrupt/NMI/TF/SS-shadow interactions.
Keep each feature behind source-backed tests for exact fault priority, atomic
state commit, READY behavior, reset cuts and denied side effects.

**Exit:** the protected architecture inventory has no silent stop or fallback
for a documented instruction or event path.

### Gate 4 — Close the ISA and independent-software evidence

Audit every real- and protected-mode opcode, prefix, flag, exception, bus
effect and retirement boundary against Intel 210498-005. Resolve the SCAS
restart discrepancy against independent 286 evidence before choosing its
fault-time index. The independent CPGREP baseline now passes on the PCjs/OS/2
configuration recorded in the
[replay report](../../design/intel_80286/report/2026-10-27-os2-cpgrep-pcjs-replay.md).
Capture an independent instruction/exception trace and provide a concrete RTL
execution path for the same binary and input bytes.

**Exit:** ISA inventory rows have independent expected results and tests; the
historical program has reproducible output on the independent emulator, and
the same bytes run on the RTL with compared output, exit behavior and
instruction/exception traces. The emulator-only result does not close software
acceptance.

### Gate 5 — Complete the native interface and release

The source-backed pin contract, one/two-byte core beat boundary, CPU-pin
controller, non-MULTIBUS local 82288 model, and connected CPU wrapper now exist.
The wrapper takes processor-rate `clk_i` and a separately supplied external
2x `clk_2x_i`. Directed controller and connected-CPU simulation, strict
Verilator `-Wall` lint, and the standalone 82288 Yosys synthesis/check pass;
the full 13-target Yosys rerun against the current RTL also passes. See the
[native CPU bridge report](../../design/intel_80286/report/2026-10-28-native-cpu-bridge.md)
and [82288 report](../../design/intel_80286/report/2026-10-28-82288-local-controller.md).

Remaining native-interface work includes board clock division/phase and RESET
timing, MULTIBUS mode, complete ownership/output-enable checks, descriptor and
processor-extension locks, sourced 80287 signaling, independent trace or
representative platform evidence, and physical timing qualification. Then run
the full aggregate on one source/tool/input snapshot with unique outputs,
current formal proof/reachable covers, mutations, authentic historical RTL
software and every completion-ledger row. Reconcile against refreshed
`origin/main` and submit a feature-branch PR for human review.

**Exit:** all completion requirements have reproducible evidence on the same
identified snapshot. Until then, report the design as incomplete.

---

Historical checkpoints below preserve earlier source identities and are not
current verification claims.

Historical assessment recorded 2026-10-26 after the selector-execution slice.
The current assessment and active plan are above. The 80286 objective remains
open.

## Superseded assessment — selector execution checkpoint

The worktree now implements protected ring-0 SLDT/STR/LLDT/LTR, LDT-backed data
segment loading, and exact #GP/#NP packet generation for tested selector
errors. The latest core SHA-256 is
`D8E67D092B66B05AF6831C8996AB713AD2F6894925C012267D970757D50F0C14`; the
formal-property SHA-256 remains
`D6C782E88C49A9B1A353B1F8BCE5E2CB6CD54E93842222163AB4CCE0E09C6F3F`.
Focused selector execution and decode checks pass on this core. The exact-
source `run_development.sh` refresh completed successfully and its transcript
is retained at
`design/intel_80286/work/selector_exec_20261026_01/run_development_a17.log`.
The refreshed protected replay manifest reports PASS for 79 cases and pins
this core SHA. It also replayed 52 historical Harris-286 captures in stalled
and unstalled modes (104 executions). The exact-source depth-24 connected-
core BMC is still running; it has reached frame 15/24 without a terminal
result. The A17 synthesis log is incomplete and ends during memory lowering,
before a `check -assert` result. Do not carry the older depth-12 prove or
depth-24 BMC forward as exact-current-source results.

This is still not a complete 80286. Nonzero-error exception delivery, reachable
nonzero-CPL execution, VERR/VERW/LAR/LSL, task switching, whole-core proof and
cover closure, the aggregate `run_all.sh`, CPGREP execution on the RTL, broad
protected privilege paths and the native 80286 pin interface remain open.
Focused simulation, replay and synthesis are not release qualification.

## Audit findings — selector-execution checkpoint

| Area | What works now | What is incomplete and must change |
|---|---|---|
| Verified execution subset | Exact-source development run passes, including the 79-case protected replay, selector execution, real-mode #UD cases and historical Harris-286 capture replay in both READY modes. | The evidence is bounded to covered tests and does not establish complete ISA or protected-mode behavior. |
| Selector/protected-mode slice | Ring-0 SLDT/STR/LLDT/LTR, LDT-backed data-segment loading, descriptor rejection packets and LTR busy-byte update have directed checks. | Add reachable nonzero-CPL execution; deliver selector #GP(selector)/#NP(selector) through handler and IRET; implement VERR/VERW/LAR/LSL; cover reset/bus-fault boundaries. |
| Formal and synthesis | Yosys synthesis and `check -assert` pass on the unchanged RTL; depth-12 base cases pass through `_20`, with no reset-reachable counterexample established. | Current prove is still `UNKNOWN` at induction. Run exact-current-source depth-24 BMC, reachable cover and whole-core PDR, then the aggregate source audit; keep induction invariants tied to reset-reachable behavior. |
| Regression quality | `run_development.sh` passed on the current core and its source-matched replay manifest is retained. | `run_all.sh` has not run; it still writes to fixed output paths. Add a unique evidence root, rerun current-source mutations, then run and audit the aggregate. |
| Independent evidence and hardware | Saved Harris-286 traces are replayed; source-backed Intel selector semantics and the reset assumption are documented. | OS/2 CPGREP has not run because the current PCjs boot stops before a shell. Establish an independent software/trace oracle and specify/test native 80286 pin behavior. |
| Worktree readiness | The dedicated feature worktree is preserved and `git diff --check` passes. | Recovered files remain uncommitted/unclassified, and local `main` was not refreshed from origin. Classify the recovery and reconcile with fetched `main` before commit/PR. |

## Previous checkpoint — selector state and execution (2026-10-26)

- SLDT and STR register/memory forms, LLDT/LTR descriptor transactions, the
  LTR busy-byte update, null-LDTR invalidation, and segment loads through the
  loaded LDT are implemented. FLAGS preservation and exact retirement are
  checked in both READY modes.
- The focused selector run passes two end-to-end protected programs, five
  descriptor-fault cases (wrong type, absent and busy TSS, and TI-set index 0),
  and the null-LDTR invalidation case. It checks GDT/LDT read order, no rejected
  descriptor writes, LTR busy writes, accessed-bit writes, memory/register
  results, FLAGS and exact successors. The remaining 16-case decode matrix
  covers valid-unimplemented VERR/VERW/LAR/LSL and invalid `/6`/`/7` forms in
  stalled and unstalled modes.
- Selector faults create the expected vector and error-code packet. The current
  protected event engine only delivers #GP(0), so selector #GP(selector) and
  #NP(selector) stop visibly with diagnostic code 3 after packet creation. The
  tests do not claim handler delivery or IRET recovery for these exceptions.
- **ASSUMPTION A17:** deterministic invalid LDTR/TR selector and cache reset
  values are model policy; Intel's cited 286 reset material does not specify
  them. The assumption is recorded in RTL and
  [selector_execution.md](../../design/intel_80286/spec/selector_execution.md).

### Exact-source verification status

- `scripts/run_development.sh` completed with exit 0 against the current core
  and bootstrap hashes. The transcript is
  `work/selector_exec_20261026_01/run_development_a17.log`. It records the
  preflight and component checks, 36 real-mode #UD cases / 71 reset cuts,
  402 system-register cases, the current selector execution and 16 decode
  cases, protected #GP/IRET and ARPL, a refreshed 79-case protected replay,
  and 52 historical Harris-286 captures replayed in both READY modes (104
  executions). The replay manifest is
  `work/protected_mode_dev_20261026T120325Z/build_manifest.json`; it reports
  PASS, 79 cases, and core SHA
  `d8e67d092b66b05af6831c8996ab713ad2f6894925c012267d970757d50f0c14`.
  This is broad development evidence, not the full release suite.
- The isolated selector run passes two end-to-end protected programs, five
  descriptor-rejection cases and null-LDTR invalidation. The decode matrix
  exercises 16 valid-but-unimplemented and invalid encodings. These directed
  tests establish only the covered ring-0 cases; they do not establish
  nonzero-CPL behavior or successful delivery of selector errors.
- Yosys 0.69 full-core synthesis and `check -assert` passed on the same RTL
  logic before the A17 comment. The exact-source log
  `work/selector_exec_20261026_01/core_synth_a17.log` ends during memory
  lowering and contains no terminal synthesis or `check -assert` result; do
  not report it as an exact-source pass.
- A new exact-source depth-24 connected-core BMC is running under
  `design/intel_80286/work/selector_exec_20261026_01/formal/intel_80286_bmc_a17/`.
  At the latest poll it had reached frame 15/24 and had no terminal status.
  The interrupted first attempt is preserved at `intel_80286_bmc/` and is not
  evidence of a pass or failure.
- No current-source proof, completed cover, whole-core PDR or exact-source
  aggregate audit is available. The prior prove result was UNKNOWN at an
  induction-only event-bus owner/path assertion; no reachable counterexample
  was established. The 15/15 protected-string mutation result also predates
  this selector source and must be rerun before use as current evidence.
- `scripts/run_all.sh` has not run on this source. It still writes several
  development outputs to fixed `work/` paths, so first make its evidence root
  configurable or run it with a safe isolated output root. The current full
  development run does not close that release gate.

## Previous checkpoint — selector opcode decode (2026-10-26)

- `0F 00 /0–/5` and `0F 02/03` are recognized as protected-mode-valid and
  consume their full ModR/M/displacement encoding, then stop with diagnostic
  code 3 before operand access or retirement. Real-mode #UD is retained;
  `0F 00 /6–/7` remains invalid.
- The directed matrix passes 18 cases across both READY modes. It checks all
  six `0F 00` groups, LAR, LSL, a disp16 form, exact fetched bytes, no operand
  transaction, no retirement and #UD-vs-valid-stop classification.
- `design/intel_80286/scripts/run_development.sh` exits 0 on this source. Its
  output includes the 36 real-mode #UD cases / 71 reset cuts, 402 system
  register cases, 18 selector-decode cases, protected #GP/IRET and ARPL, the
  79-case protected replay, and 52 hardware captures in stalled and unstalled
  modes (104 executions). The runner build is
  `design/intel_80286/work/sim/build_manifest.json`; the protected replay
  manifest is `design/intel_80286/work/protected_mode_dev_20261026T110607Z/`.
- Yosys synthesis and `check -assert` pass in
  `design/intel_80286/work/selector_core_synth_20261026.log`; three hierarchy
  checks report zero problems.
- The 15/15 protected-string mutation result is not exact-current-source
  evidence: `arpl_current_full_mutations_20261026_01/mutations.json` pins the
  core to the earlier ARPL SHA `4bef2d...`, before selector decode. Rerun that
  suite on the current source before counting it as current verification.
- The current-source prove is
  `design/intel_80286/work/selector_formal_20261026_01/intel_80286_prove/`.
  Base case passes at depth 12; induction returns UNKNOWN at
  `intel_80286_props.sv:72`, the event-bus owner/path invariant. The trace is
  an induction witness; this run establishes no reachable counterexample.
  The previous depth-24 BMC, prove and cover evidence used the ARPL core hash
  `4bef2d...` and must not be reported as current for this selector RTL.
- `git diff --check` passes. No current-source depth-24 BMC, completed cover,
  whole-core PDR or exact-source aggregate audit has been run yet.

## Prior audit baseline — selector decode before execution

This subsection records the earlier selector-decode checkpoint for lineage.
Its source hashes and run statuses are superseded by the current selector-
execution checkpoint above; use them only to understand the history.

- Worktree: `B:/ai_hw_engineer/worktree/intel-80286`, branch
  `design/intel-80286`, HEAD `e7c252051b4750e8382baedbf8b4015e3600beb7`.
  Relative to local `main` at `38b0a04`, it is 37 commits behind and 5 ahead.
  No fetch/rebase was performed, so remote freshness is unknown.
- The worktree has 105 untracked files, chiefly recovered design sources,
  tests and scripts, and 10 modified tracked files. None are staged or
  committed. Preserve the whole checkout; do not reset, clean or replace it
  from the recovery snapshot.
- At that checkpoint, the RTL SHA-256 was
  `4c7cc00a08a86bd8a5198f5d4f3a32feef343a02e7a960fab900a4ef8a763c70`; the
  formal-property SHA-256 was
  `d6c782e88c49a9b1a353b1f8bce5e2cb6cd54e93842222163ab4cce0e09c6f3f`. The
  selector runner manifest and formal-run source copies matched that
  checkpoint. The 79-case replay manifest also fingerprinted that core.
- The earlier checkpoint reports `run_development.sh` PASS, including 36
  real-mode #UD cases / 71 reset cuts, 402 system-register cases, 18 selector
  decode cases, protected #GP/IRET and ARPL, 79 protected replay cases, and
  52 selected hardware captures in both READY modes (104 executions). The
  selector log and replay/build manifests are retained; that checkpoint has
  been superseded by the exact-source execution run above.
- Yosys 0.69 full-hierarchy synthesis and `check -assert` pass in the saved
  selector synthesis log; all three hierarchy checks report zero problems.
  The then-current connected-core depth-12 base case passed, but induction was
  `UNKNOWN` at property line 72. No current-source depth-24 BMC, completed
  cover, PDR or exact-source aggregate audit was available at that earlier
  point; see the status above for the current BMC.
- At the start of this audit, the current-facing design README and completion
  ledger incorrectly described the 79-case replay as pre-ARPL and needing a
  rerun. The retained
  `work/protected_mode_dev_20261026T110607Z/build_manifest.json` records PASS
  for 79 cases and pins the core to the current selector-decode SHA above. This
  revision corrects those summaries; the older 103-line `run_sim.sh` run and
  its replay remain historical. SCAS, native ordering, IOPL and full release
  requirements remain open.
- The same source-lineage correction applies to the ISA inventory's mutation
  claim: its 79-case replay is current, while the 15-mutation result is from
  the earlier ARPL core. This revision records those separately.
- `run_all.sh` creates a unique formal work directory but still writes lint,
  simulation, vectors, hardware, software and synthesis output to fixed
  `work/` paths. It has not run on this checkout and could replace evidence.
- Live `gh` CLI reads confirm issue
  [hevangel/ai_hw_engineer#80](https://github.com/hevangel/ai_hw_engineer/issues/80)
  is Open with Status Building, Agent Codex, Start date 2026-10-23, Path
  `ai_hw_engineer/design/intel_80286`, and the existing Sprint 1. Preserve
  those fields and the first start date. See [the latest progress comment](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6414975327).
- This turn inspected saved evidence and did not rerun simulation, synthesis
  or formal tasks. Treat results above as the recorded checkpoint, not a new
  execution.

## Superseded execution plan — selector execution checkpoint

### Gate 0 — Preserve and make the recovered work reviewable before commit/PR

1. Keep this task worktree intact. Before commit or PR, classify the 105 untracked files against
   recovery snapshot `f490003...`; protect newer core, test, report and plan
   edits. Confirm ignored `work/` outputs and copyrighted inputs remain out of
   source control.
2. Before commit or PR, fetch current `origin/main`, compare the new refs, and
   reconcile the branch without discarding local work. The current 37/5 count
   is relative only to the local `main` pointer.
3. Keep the completion ledger and design README pinned to the exact
   current-source 79-case manifest; keep the plan, ISA inventory and issue #80
   aligned with the evidence boundary.
4. Keep the issue Open/Building with Agent Codex and preserve Start date
   2026-10-23, Path `ai_hw_engineer/design/intel_80286` and Sprint 1 while
   work continues. Keep the evidence and blockers current in progress comments.

**Exit before commit/PR:** recovered sources are classified and reviewable,
the branch is reconciled with fetched `main`, and progress documents agree on
the current source and verification boundary. This release-preparation gate
does not block the next selector implementation slice; preserve the worktree
and its source identities first.

### Gate 1 — Finish selector and descriptor behavior (active CPU slice)

1. Build a reachable nonzero-CPL path, then verify SLDT/STR privilege behavior
   and LLDT/LTR #GP(0) priority before memory operand reads. Cover both register
   and memory forms without changing unrelated code/data descriptor rules.
2. Extend protected exception delivery to carry selector #GP(selector) and
   #NP(selector) error words through a complete frame, handler, IRET and reset
   cuts. Keep the current exact-packet tests as a boundary regression.
3. Add GDT limit endpoints, LDT limit endpoints, READY stalls and reset cuts
   during LLDT descriptor reads, LTR validation and the busy-byte write. Check
   cache/visible-selector atomicity and descriptor side effects.
4. Implement VERR/VERW/LAR/LSL for GDT and LDT. Use Intel 210498-005 as the
   authority for privilege/type filtering, ZF behavior, result preservation,
   absent descriptors and invalid-LDTR behavior. Keep each valid form stopped
   until its own tests pass.
5. Add independent 286 expected results and mutants for the new selector
   transaction rules. Re-run protected-string mutations on the current source.

**Exit:** every selector form has source-backed operand, flags, privilege,
fault, side-effect and commit behavior, with exact exception delivery and
current-source evidence. This gate still does not imply full task switching.

### Gate 2 — Close current-source formal and verification infrastructure

1. Repair the event-bus owner/path induction invariant at property line 72
   without assumptions that constrain reachable inputs. Keep induction
   witnesses distinct from reachable counterexamples.
2. Finish the active exact-source depth-24 BMC, then run connected-core prove,
   completed covers, PDR and exact-source audit. Record terminal status and
   source/tool hashes; stale ARPL depth-24 and 37/40 results remain historical.
3. Rerun the protected-string mutation suite against the current source and
   retain its exact-source manifest; rerun mutation suites again after any
   core change that could affect their baseline.
4. Give development and release runs a unique evidence root. Pass it through
   every `run_all.sh` stage and save one command/output summary plus manifests
   so later runs cannot overwrite fixed `work/` evidence.
5. Once the output root is safe, run the full regression on one source
   snapshot. Preserve the failing stage, exact command and missing-input
   blocker; do not label an incomplete aggregate as passed.

**Exit:** current-source proof/cover results have terminal status and the
aggregate runs reproducibly without replacing previous evidence.

### Gate 3 — Establish the independent historical-software baseline

1. Do not repeat the known PCjs BIOS-1782/no-shell attempt as new evidence.
   Select a usable independent 286 emulator, hardware setup or recovered
   trace and record version, configuration and provenance.
2. Run unchanged OS/2 SDK 1.00 `CPGREP.EXE` on fixed input media. Preserve
   input hashes, output, exit behavior and instruction/exception trace.
3. Design the RTL boot/platform path needed to run those same bytes. A
   successful emulator run supplies an oracle trace, not RTL acceptance.

**Exit:** unchanged CPGREP runs reproducibly in an independent environment and
on the RTL using the same input bytes; compare output, exit behavior, and
instruction/exception traces. An emulator-only run or a planned RTL path is
not software acceptance.

### Gate 4 — Complete protected architecture and ISA coverage

After selector state, complete remaining descriptor/data/stack checks,
protected far control flow, privilege-changing gates, TSS stack selection,
task gates and task switching, backlink/NT/busy behavior, nested exceptions
and #DF/shutdown. Add reachable nonzero-CPL behavior before IOPL and port
permission checks. Finish interrupt/NMI/TF/SS-shadow and 80287 ESC/WAIT/MSW
boundaries. Resolve SCAS fault restart from independent 286 evidence before
implementing the disputed repair rule. Keep every row in
`design/intel_80286/plans/isa_inventory.md` linked to sources and tests.

**Exit:** each documented 80286 instruction and protected mechanism has an
explicit mode, privilege, side-effect and fault result with independent
executable evidence.

### Gate 5 — Specify and verify the native 80286 interface

Define 16-bit data lanes, BHE/status, T-states, READY, arbitration, LOCK,
interrupt acknowledge, reset and coprocessor signals from primary sources.
Add pin-level monitors, scoreboards, captures and platform tests. Keep the
functional byte scheduler separate from native timing claims. Resolve A20
and externally visible I/O ordering with evidence.

**Exit:** the documented native protocol passes source-backed pin-level
simulation and representative physical comparisons; state remaining
qualification limits.

**Progress (2026-10-28):** the source-backed non-MULTIBUS (`MB=0`) M82288
controller is implemented and connected to the native CPU wrapper. Directed
component and connected-CPU tests pass; the full simulation suite records 142
PASS lines, and Yosys 0.69 synthesis completes all 12 targets with zero
`check -assert` problems. The wrapper takes processor-rate and external 2x
system clocks separately. `MB=1`, clock/reset generation and phase, full 80287
signaling, complete native protocol coverage, and physical timing qualification
remain open. This is partial Gate 5 evidence, not gate closure; see the
[controller report](../../design/intel_80286/report/2026-10-28-82288-local-controller.md)
and [live status](STATUS.md).

**Reset-source correction (2026-10-28):** Intel 210760-002 Chapter 3 printed
pages 3-41–3-43 anchor the CPU RESET/82C284 boundary but conflict on single-CPU
RESET edge synchronization. The connected test
holds CPU RESET for 16 processor clocks, checks the bus and controller remain
inactive, and asserts a first fetch at `FFFFF0h`. The focused native-CPU test
and full `run_sim.sh` both pass, including the 79-case protected replay. The
former fixed 38-external-CLK delay was not substantiated by those inspected
pages and is no longer a contract threshold. The analog `RES` power-up
sequence and edge behavior remain unmodeled pending an independent 82C284
source; see the
[reset source audit](../../design/intel_80286/report/2026-10-28-reset-source-audit.md).

### Gate 6 — Final integration and release

Freeze source, tool and input hashes. Run strict lint, complete CPU and
component suites, independent vectors/traces, proof and reachable cover,
mutations, authentic software and synthesis on that same snapshot. Close
every row in `design/intel_80286/plans/completion_requirements.md`, publish
limitations and submit the feature branch through the repository PR workflow.

**Exit:** all agreed completion requirements have evidence tied to the same
final snapshot and pass human review.

The formal and source-hygiene gates are release requirements, but they do not
block focused selector implementation after the current worktree and its
source identities are preserved. Reconcile the branch and classify recovered
files before commit/PR, not as a prerequisite to that implementation.

## Prior audit basis — ARPL snapshot

- Worktree: B:\ai_hw_engineer\worktree\intel-80286; branch design/intel-80286; HEAD e7c252051b4750e8382baedbf8b4015e3600beb7. The branch is 37 commits behind and 5 ahead of the local main reference. No fetch/rebase was done for this audit.
- Commit e7c2520 contains the CMPS fault-repair implementation and its focused report. The current worktree has 105 untracked recovered files and 9 modified tracked files, including the ARPL RTL and plan/status updates; `.gitattributes` keeps Linux shell entrypoints at LF. These changes are not yet part of a source commit.
- The recovered files came from local snapshot commit f490003fb78c652eb512e5f7fdd2f97f74e0b806. Existing newer core, current fixture and reports were preserved rather than replaced.
- The ARPL checkpoint recorded a passing `preflight.py` and 33 focused helper tests (`test_preflight`, `test_audit_formal`, `test_build_runner`); this documentation audit did not rerun them.
- A pre-ARPL formal snapshot is preserved at `design/intel_80286/work/formal_runs/run.ySqmJ8/`. Its exact-source audit reports 37/40 tasks PASS: all 36 component tasks and connected-core depth-24 BMC (`PASS 0 1699`). The connected-core depth-12 prove is UNKNOWN: basecase passes through its configured depth, then induction fails at `formal/intel_80286_props.sv:388` from an induction-only state inconsistent with the event-packet lifecycle (event-target `CODE_LOAD_WAIT`, invalid event packet, stale retired bit). Core cover was interrupted at step 15 with 21 witnesses; whole-core PDR was interrupted after 243 proved outputs. These are incomplete, not proof/cover passes. The elaborated core models contain 229 assertions and 49 covers; the snapshot hashes match that pre-ARPL run, not current RTL.
- The formal runner previously placed PDR before later component suites and core BMC. It now discovers each `[tasks]` block, runs components then bounded core and PDR last, and accepts config basenames for selected runs. The evidence auditor was also fixed to recognize the prove-only PDR config; its 17 unit tests pass. Keep the current partial PDR/cover logs; add a sound induction invariant and targeted covers to close the remaining formal gate.
- `work/recovered_sim_20261026_04.log` records successful `run_sim.sh` completion and 103 PASS lines across bootstrap/component checks and the protected replay. The 79-case replay manifest at `work/protected_mode_sim_20261026T073151Z/build_manifest.json` reports PASS and matches its 19 listed inputs, but it was built with core SHA-256 `08ab26c1fc4fabb1320453036e09f3d62920795821bac60914483e0c594b7dca`. That is not the current ARPL core; neither the 79 cases nor the 103-line log count as current-source CPU evidence.
- The current ARPL manifest is `work/arpl_dev_20261026/build_manifest.json`: it fingerprints the current core SHA-256 `4bef2d465024748bbf6ff4240076051f2fd43a401f92006b54ee49882e586634`, the current bootstrap SHA-256 `5dc0698e8b3bb58e080c0128f4a3f1ff25a43ff7cd5465a4703d7d5626294b67`, 14 RTL files, and the bootstrap harness. Binary SHA-256 is `cd049b30350102a991d7e73389eb81dbac33450901ded11911fde47034a6f1a7`. `arpl.log`, `real_mode_ud.log`, and `protected_segments.log` pass; this run does not execute the full 79-case string replay or its mutation suite.
- work/protected_string_mutations_release_20261026_01/mutations.json records 15/15 mutations detected with their expected diagnostics.
- These logs and manifests are ignored local evidence under `design/intel_80286/work/`; keep the source identities alongside them. This audit inspected saved logs and manifests; it did not rerun tests, synthesis, or formal tasks. An escalated read-only `docker ps` showed no active container with a name identifying a 286/formal run; it did show unrelated running services. `gh project item-list` confirmed issue #80 is Open/Building with Agent Codex, Start date 2026-10-23, Path `ai_hw_engineer/design/intel_80286`, and its existing Sprint 1 assignment. Preserve those fields and the first start date. The audit summary is now recorded in [issue comment 6412698512](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6412698512).
- Current-source refresh after ARPL: `work/arpl_current_full_replay_20261026_01/build_manifest.json` reports PASS for 79 cases and fingerprints the core at `4bef2d465024748bbf6ff4240076051f2fd43a401f92006b54ee49882e586634`; replay binary SHA-256 is `2141eb75429e89244c0cc3af931b814e1337077749a273f1d21b4aee05f474d8`. This refresh includes the protected event path and INS/MOVS/STOS/OUTS/CMPS fault-repair cases in both READY modes.
- `work/arpl_current_full_mutations_20261026_01/` records 15/15 protected-string mutations detected against that current-source replay manifest.
- `work/arpl_current_checks_20261026_01/core_synth.log` records Yosys 0.69 full-hierarchy `hierarchy -check`, `synth`, and `check -assert` success, with 29,964 cells; output JSON is `core_synth.json` (the exact output filename is `intel_80286.json`).
- Current-source connected-core formal run: `work/arpl_current_formal_20261026_01/`. Depth-24 ABC BMC passes (`PASS 0 1577`, 26m17s). Depth-12 prove is `UNKNOWN`: the base case passes through 12, but induction fails at `intel_80286_props.sv:154`. The failing induction state has `code_load_target=2` but request selector/offset `1E80:FFFC` while the saved IRET target is `0200:00F3`; the assertion antecedent omits the RTL branch's target-match and special-descriptor success guards. This is an induction/property-strengthening gap, not a reachable counterexample. The depth-64 cover run was interrupted after 28 witnesses at step 20 and has no terminal status. The exact-source auditor output is `work/arpl_current_formal_20261026_01/audit.json`: 37/40 tasks PASS, comprising all 36 components and current-source BMC; current prove is UNKNOWN, cover has no completion status, and the preserved PDR snapshot is stale for current RTL.

## Earlier ARPL-snapshot evidence (retained for provenance)

The table below records the source-backed state at the ARPL checkpoint. The
latest continuation checkpoint above supersedes its source hash and verification
status where they differ.

| Slice | Current evidence | What it establishes |
| --- | --- | --- |
| Same-level protected event path | Current-source 79-case replay passes at `work/arpl_current_full_replay_20261026_01/`, including the protected #GP/IRET and reset-cut cases | The bounded ring-0 GDT/IDT vector-13 and string-repair paths pass this fixture on current ARPL RTL |
| Protected ARPL | Focused Verilator regression covers register and memory RPL adjustment/no-change, ZF, conditional write traffic, both READY modes, exact successor PCs and the Intel-documented null-source #GP | The documented protected-mode operation has a bounded functional slice; wider privilege/segment-fault ordering and independent hardware evidence remain open |
| Protected INS repair | Current-source 79-case replay | Byte/word bounds, REP final/nonfinal state, wrap and READY behavior pass the directed profiles; independent physical port timing remains open |
| MOVS, STOS and OUTS repair | Current-source 79-case replay | Directed source/destination faults cover signed index/count repair, DF, wrap, retry PC and READY stalls; privilege-sensitive I/O behavior remains open |
| CMPS repair and comparison | Current-source 79-case replay | Source/destination phases, REPE/REPNE, flags, repair and READY stalls pass the directed profiles; physical per-beat ordering remains an assumption |
| Regression sensitivity | `arpl_current_full_mutations_20261026_01/` | All 15 protected-string mutants, including five CMPS-specific faults, are detected against the current-source replay baseline |
| Recovered simulation baseline | `run_sim.sh` log contains 103 PASS lines and exits successfully on the pre-ARPL snapshot | Recovered bootstrap/component checks and protected replay were wired together then; the CPU portion is not a current-source pass |
| Harness integrity | preflight.py passes; 33 preflight/formal-audit/build-runner helper tests pass | Required local inputs and reviewed property inventory satisfy the current preflight contract |
| Synthesis and bounded formal checks | Current-source Yosys 0.69 synthesis/check succeeds with 29,964 cells. Connected-core depth-24 ABC BMC passes (`PASS 0 1577`); depth-12 prove is `UNKNOWN` after an induction-only mismatch at property line 154. Cover was interrupted after 28 witnesses at step 20. | Structural synthesis and the configured depth-24 bound pass. Strengthen the property antecedent to mirror the RTL's full valid-return guard, then rerun prove, full cover and PDR on current source. |

The earlier formal cover run at `work/cmps_checks_20261026_01/cover64_01/` timed out at its 180-second limit with 11 complete witnesses and 53 cover statements unreached. The `run.ySqmJ8` cover is also incomplete: it was interrupted at step 15 after 21 witnesses. Neither is a cover pass, and neither verifies current ARPL RTL.

The CMPS compare order follows Intel 210498-005: source at DS:SI minus destination at ES:DI. The repair expectations cite the original Intel LOADALL memo, page 14. Functional operand order is exercised; native per-beat ordering is not established by an independent pin trace. A20 port-side-effect timing is still an explicit assumption.

## Superseded remaining gaps from earlier revision

| Priority | Finding | Required response |
| --- | --- | --- |
| P0 | The core is not a complete 80286. ARPL has a focused protected-mode slice, but 0F 00 selector instructions, LAR/LSL/VERR/VERW, privilege transitions, LDT/TR state, task switching and nested-fault escalation remain incomplete. | Keep each implemented row source-linked and mode-specific. First make mode-specific decode and tests prevent real-mode-validity mistakes or protected valid-but-unimplemented opcodes from retiring as NOPs; then implement selector state and descriptor lookups in dependency order. |
| P0 | The latest protected replay and synthesis pass on selector-decode RTL. Current depth-12 base case passes, but prove is UNKNOWN at the event-bus owner/path invariant; current-source depth-24 BMC, completed cover, PDR and exact-source audit are not available. | Strengthen reachable event/owner invariants without assumptions, rerun prove, BMC, cover and PDR on one source snapshot, then audit exact source hashes. Keep prior ARPL 37/40 and depth-24 PASS results labeled historical. |
| P0 | Microsoft OS/2 SDK 1.00 CPGREP has not executed. The recorded PCjs attempt reaches the prerelease banner, then BIOS error 1782; F1 does not expose a shell and the injected command produces no output. | Do not repeat that same boot attempt as new evidence. Find an executable local 286 environment, hardware capture or recovered trace, then run unchanged CPGREP against fixed inputs. |
| P0 | The regression source set has been recovered, but 105 files are still untracked and the release aggregate has not run. | Preserve the worktree; review and track the recovered sources; inspect Docker for live jobs immediately before starting formal tasks. Keep issue #80's confirmed fields unchanged and post evidence/blockers as implementation continues. |
| P1 | Whole-core proof and non-vacuous cover are incomplete. Depth-12 BMC is shallow; the latest cover timed out; prior induction/PDR runs lack a final PASS for the current source. | Partition proof obligations, retain architectural requirements, and close proof plus reachable targeted covers against one final source snapshot. |
| P1 | `run_all.sh` writes lint, runner, vectors, hardware, software, and synthesis outputs to fixed `work/` paths. A direct rerun can replace saved evidence or binaries, so the aggregate is not yet safely repeatable against a fresh output root. | Add a configurable release evidence root and pass it through each stage, or first preserve/hash every fixed-path artifact. Run the aggregate only after outputs are isolated. |
| P1 | The ordinary SCAS description uses ES:DI and advances DI, while Intel's LOADALL restart memo page 14 explicitly directs the fault handler to update SI. Visual inspection confirms the scanned page says SI; page 13 is unrelated implementation notes. The local capture archive contains no SCAS fault trace, so it remains unknown whether the memo records intentional 286 behavior or a source error. Protected direct/string IOPL enforcement is already implemented; the combined 480-case privilege regression includes 288 dedicated IOPL/IF cases. Physical port-side-effect ordering, INS DF=1 integration and A20 timing remain open. | Keep SCAS fault repair release-blocking until an independent 286 trace or primary source resolves the restart discrepancy. Close physical port-side-effect ordering with a hardware trace, then resolve INS DF=1 and A20 timing separately. |
| P2 | The current interface is a functional byte scheduler, not a native 80286 pin-level interface. BHE/status, T-state behavior, arbitration, LOCK, interrupt acknowledge and 80287 connections are not closed. | Specify the native interface from independent sources, then add pin-level protocol monitors, scoreboards and platform tests. |

Do not describe run_sim.sh, the 79-case replay, mutation checks, synthesis, or shallow BMC as full release verification. The aggregate runner design/intel_80286/scripts/run_all.sh, CPGREP, broad ISA completion, full proof/cover and native interface remain open.

## Superseded execution plan from earlier revision

### Gate 0 — Close the CMPS repair checkpoint (complete)

1. The CMPS RTL/property/test update and focused evidence are committed as e7c2520.
2. Its report is design/intel_80286/report/2026-10-26-protected-cmps.md.
3. The pre-ARPL 79-case replay and 15-mutation result remain historical. Their refreshed current-ARPL equivalents pass under `arpl_current_full_replay_20261026_01/` and `arpl_current_full_mutations_20261026_01/`; current formal closure and the aggregate release gate remain open.

**Exit:** met for the focused CMPS slice only. It does not close SCAS, protected architecture or the full 80286.

### Gate 1 — Make the recovered regression baseline durable (active; current-source audit open)

1. Preserve the current worktree exactly. Review the 105 untracked files against snapshot `f490003...`; preserve newer files, especially the current core, replay fixture, reports and ARPL edits. Do not clean, reset or replace current files with older snapshot copies.
2. Classify the recovered files, then track the formal configs/properties, component testbenches, specs, scripts and fixtures under `design/intel_80286/`. Keep generated output and copyrighted inputs in ignored `work/` locations. Retain `.gitattributes` LF handling for Linux scripts. Record the source snapshot before staging so review can distinguish recovered files from newer work.
3. Inspect every stage in `scripts/run_all.sh` and relevant tool documentation. Before starting solvers, check Docker for prior jobs; the read-only listing during this audit showed no clearly 286-related active container. Make fixed outputs (`work/lint`, `work/sim`, `work/vectors`, `work/hardware`, `work/software`, `work/synth`) configurable under one fresh release root; refuse to overwrite existing evidence.
4. The latest `run_development.sh` passes on selector-decode RTL, including the 79-case protected replay and current-source build manifest. Yosys 0.69 synthesis and `check -assert` pass. The current depth-12 prove base case passes, but induction is UNKNOWN at `intel_80286_props.sv:72`; the depth-24 PASS (`PASS 0 1577`), line-154 prove failure, 28-witness interrupted cover and 37/40 audit belong to the prior ARPL snapshot. Rerun current-source BMC, prove, cover, PDR and exact-source audit after strengthening event/owner invariants without assumptions. The older 103-line `run_sim.sh` result remains historical.
5. Run all remaining `run_all.sh` stages against that same fresh root: vectors, hardware-capture checks, software and synthesis as configured. If an input, emulator, Docker service or external trace is unavailable, preserve the exact command/error and mark that stage blocked; never suppress it or label the aggregate passed.
6. Run `git diff --check`, reconcile the README/completion ledger/status with fresh results, and update issue #80 after GitHub access returns. Preserve its first Start date and Path; do not assign a Sprint by default.

**Exit:** recovered source is tracked, current-source focused tests and exact-source manifests are reproducible, and every required aggregate stage has a fresh result or an explicit blocker. The aggregate release gate is still reserved for Gate 6.

### Gate 2 — Establish an independent software and trace baseline

1. Select a local 286 emulator, hardware capture or recovered trace source that can execute protected-mode software. Record exact version, configuration, provenance and limitations.
2. Run unchanged SDK 1.00 CPGREP against a fixed input. Record output, exit behavior, input/media hashes and an instruction/exception trace.
3. Define a practical RTL execution path for the same workload, including boot, NE loading, required APIs/tasking and platform devices. A smaller authentic protected workload may help debug but does not satisfy the CPGREP requirement.
4. Compare observed behavior with Intel references. Treat emulator output as independent evidence, not as the architectural specification.

**Exit:** CPGREP runs reproducibly in an independent environment and the same bytes have a concrete RTL execution path. Only a successful RTL run closes the software acceptance item.

### Gate 3 — Build the mode-specific ISA and behavior ledger (active)

1. Enumerate documented opcodes, prefixes, operand forms, flags, privilege checks, exceptions, and commit/side-effect boundaries for real and protected mode. ARPL now has a bounded execution and test row; the full selector/permission fault matrix remains open.
2. Link each row to an Intel source, RTL implementation, positive/negative test and independent expected result.
3. The first selector-group decode slice is complete: 0F 00 /0–/5 and 0F 02/03 are valid in protected mode and stop visibly after complete instruction decode; real-mode #UD and invalid 0F 00 /6–/7 remain. The 18-case matrix passes in both READY modes. Continue linking every remaining encoding to Intel 210498-005 and add external positive/negative results before enabling execution. See the [Intel 80286 Programmer's Reference Manual](https://bitsavers.trailing-edge.com/components/intel/80286/210498-005_80286_and_80287_Programmers_Reference_Manual_1987.pdf), Appendix B and protected-mode chapters.

**Exit:** no documented encoding or mode is silently substituted with #UD, stop, or real-mode behavior.

### Gate 4 — Implement protected architecture in dependency groups

1. Complete selector and descriptor state in dependency order: LDTR/TR visible and hidden state; SLDT/STR/LLDT/LTR privilege and descriptor rules; GDT/LDT selection; null, expand-down and conforming descriptors; validation, accessed/busy-bit updates and atomic cache commit. Only then enable LAR/LSL/VERR/VERW for both tables. Keep TI=1 behavior explicit while LDTR is invalid; do not claim complete selector queries from a GDT-only shortcut.
2. Complete protected control flow and stack transactions: far calls/returns, segment POP, LDS/LES, privilege checks, I/O permission and precise faults.
3. Complete privilege-changing gates, TSS stack selection, task gates/switching, backlink/NT/busy behavior, nested exceptions and #DF/shutdown.
4. Close interrupt/NMI/TF/SS-shadow interactions, unresolved string/IOPL behavior, SCAS semantics, and the documented 80287 ESC/WAIT/MSW boundary.
5. For each group, write external expected transactions first. Check fault PC/successor, denied side effects, waits, reset cuts, handler repair and targeted mutations.

**Exit:** every documented mechanism has independent expected behavior and executable evidence; unsupported behavior is explicitly classified rather than passed by halting or falling back.

### Gate 5 — Specify and verify the native interface

Define 16-bit data and byte lanes, BHE/status, T-state and READY timing, bus ownership/arbitration, LOCK, interrupt acknowledge and coprocessor signals. Keep native timing distinct from the functional byte scheduler. Add protocol monitors, scoreboards, coverage and representative platform tests.

**Exit:** native interface behavior is source-backed and covered in pin-level simulation. Simulation and synthesis are not physical qualification.

### Gate 6 — Prove, integrate and release

Freeze one final source/tool/input snapshot. Run strict lint, every required component and CPU regression, independent vectors/traces, formal proof and reachable covers, mutation suites, authentic software and synthesis. Bind every result to commands, hashes, tool versions and logs. Close every row in design/intel_80286/plans/completion_requirements.md, publish limitations, and submit a feature-branch PR for human review.

**Exit:** all agreed completion requirements have evidence on the same final source snapshot and pass the repository PR workflow.

## ARPL implementation follow-up — 2026-10-26

The core now decodes opcode `63 /r` as protected-mode ARPL while retaining
real-mode #UD. The implementation handles register and memory destinations,
updates only ZF, performs memory RMW permission checking and writes only when
RPL increases. It raises restartable #GP(0) before operand access when the
source selector is null, following Intel's 1984 80286(B-2/B-3) Information
Sheet. The primary ARPL semantics are in Intel 210498-005 Appendix B, B-10.

Focused verification used the isolated output directory
`design/intel_80286/work/arpl_dev_20261026/`:

- Verilator 5.052 `--cc --exe --build -j 2 -Wall` completed; the build manifest
  fingerprints all 14 RTL files and `tb/bootstrap.cpp`.
- `Vintel_80286 --arpl` passed register adjustment/no-change, memory
  adjustment/no-write, exact protected RMW bus context, both READY modes,
  exact post-instruction PCs and the null-source #GP packet.
- `Vintel_80286 --ud` passed 36 real-mode #UD cases and 71 reset cuts.
- `Vintel_80286 --protected-segments` passed the existing protected #GP/IRET
  recovery and the new ARPL checks.
- `scripts/preflight.py` and `git diff --check` passed.

The current RTL SHA-256 is
`4bef2d465024748bbf6ff4240076051f2fd43a401f92006b54ee49882e586634`; the
testbench SHA-256 is
`5dc0698e8b3bb58e080c0128f4a3f1ff25a43ff7cd5465a4703d7d5626294b67`.
The earlier 37/40 formal audit used pre-ARPL RTL and therefore does not verify
this core. Component proof results remain source-matched to their unchanged
inputs; the core proof, cover and exact-source audit must be refreshed. No
independent hardware ARPL capture or broad selector fault-priority matrix is
available yet.

## Historical handoff — selector-execution checkpoint

Preserve and classify the 105 recovered files and 10 tracked edits before
source commits; then reconcile the branch with fetched main. The next CPU
implementation is selector state and execution, starting with SLDT/STR, then
LLDT/LTR, followed by VERR/VERW and LAR/LSL. Keep formal induction cleanup on
a separate release track and do not add environmental assumptions. Make
run_all.sh use a unique evidence root before an aggregate run. Establish a
usable independent CPGREP baseline without repeating the known BIOS-1782
attempt. Issue #80 remains Open/Building with Agent Codex, Start date
2026-10-23, Path ai_hw_engineer/design/intel_80286 and Sprint 1; preserve those
fields while work is active. The 80286 objective remains open.
