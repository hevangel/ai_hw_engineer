## Memory bank selection wiring — 2026-10-30

The type-1 U72 PROM address wiring, U63 and U64 transparent latch have a
separate synthetic-data test and structural check. Actual type-1 PROM
contents, the J18/keyboard net, timing and DRAM remain open; a documented
type-3 PROM dump is not assumed equivalent. See the
[bank selection report](../../design/intel_80286/report/2026-10-30-at-bank-select.md).

## Memory timing trigger — 2026-10-30

The IBM AT U96 read/write-to-`+RAS` trigger passes both a standalone test and
a directed integration test with refresh/HLDA and IOCHRDY stalls. Both native
BIOS integration scenarios pass; final bank-specific DRAM strobes remain open. See the
[RAS trigger report](../../design/intel_80286/report/2026-10-30-at-memory-ras-trigger.md).
The native BIOS and RAS fixtures are now consolidated; both scenarios and
their CPU replay pass against the consolidated runner with 41 inputs verified.

## WAIT trap priority counterexample and refresh page map — 2026-10-30

The connected-core BMC ended FAIL at step 20: a `WAIT` completion can claim
an interrupt before the completed instruction's sampled single-step trap is
recognized. The witness is under `work/wait_mf_nmi_formal_20261029_01/bmc/`;
the correction now passes the directed CPU regression and strict lint. Fresh
historical-software regression now passes; fresh simulation, synthesis and BMC
runs are active. The old-source PDR
is still running and cannot prove a subsequently changed core.

The source-backed refresh page-map gate model and both native BIOS scenarios
pass; the BIOS checks the programmed page on every refresh signal. DMA
transfers, remaining address lines and DRAM behavior remain open. See the
[page-map report](../../design/intel_80286/report/2026-10-29-at-refresh-page-map.md).
The checkpoint is [issue comment 6516441683](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6516441683).

## Native IBM AT BIOS refresh indication — 2026-10-29

The unchanged BIOS reached `F000:03A2` through its own port `61h` refresh
test on the native fixture in two virtual-clock/READY scenarios. Unicorn
matched 247,306 and 247,355 CPU states and data transactions with captured I/O
replay; 2,084 and 2,072 modeled refresh signals produced checked sequential
rows and read drives. Page-to-DRAM wiring, retention,
physical timing and full POST remain open. See the
[native BIOS report](../../design/intel_80286/report/2026-10-29-at-bios-native-refresh.md).
The earlier port-61 full simulation suite also passed with 209 PASS lines;
it was launched before the native BIOS fixture was added.
The checkpoint is [issue comment 6510781415](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6510781415).

## Native port 61h refresh-detect reads — 2026-10-29

The native 286 fixture now connects the source-backed port B latch and read
buffer. A directed program programs the 8254 and observes both refresh-detect
states across 16 refresh events while completing 32 checked writes. The
later authentic BIOS native fixture also uses this path; DRAM and board timing
remain open. See the [port report](../../design/intel_80286/report/2026-10-29-at-port61-native.md).
The separate CPU synthesis run passed; connected-core BMC and PDR are still active.
The checkpoint is [issue comment 6510702775](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6510702775).

## LS590 refresh row and read drive — 2026-10-29

The source-backed LS590 counter and LS125 read-drive model now connect to
the refresh path. Standalone tests cover 260 edges and wrap; the native
CPU/8254 test checks 14 sequential row/read-drive events and 32 exact CPU
writes. No DRAM consumes these signals, and page mapping and BIOS refresh
remain open. See the [row report](../../design/intel_80286/report/2026-10-29-at-refresh-row.md).
The checkpoint is [issue comment 6510618069](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6510618069).

## CPU-programmed 8254 refresh signals — 2026-10-29

The 286 native fixture now programs the real 8254 through ports `43h` and
`41h`; channel-1 OUT1 drives the partial refresh path. A directed test passes
six forced timer-write waits, 14 refresh-signal events and 32 exact memory
increments. The [timer/native report](../../design/intel_80286/report/2026-10-29-at-refresh-timer-native.md)
records the supplied clocks and remaining DRAM/BIOS limits. CPU BMC, PDR and
synthesis remain active; no whole-core proof or complete refresh is claimed.
The checkpoint is [issue comment 6510544314](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6510544314).

## Native HOLD/HLDA refresh handoff — 2026-10-29

The partial AT refresh signal path now connects to the 286 native wrapper's
HOLD and HLDA. A directed CPU program passes requests during a READY-stalled
write and a locked XCHG, verifies bus release and exactly one write at each
expected address, and reaches HLT. Timer edges, hold permission and IOCHRDY
are still test-driven; real DRAM refresh and BIOS integration remain open.
The [native report](../../design/intel_80286/report/2026-10-29-at-refresh-native.md)
records the test and timing/structural limits. A refreshed full simulation
passed with 206 PASS lines; CPU synthesis, BMC and PDR remain running.
The checkpoint is [issue comment 6510413157](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6510413157).

## Combined refresh signal path and WAIT verification — 2026-10-29

The standalone U68/U95 request, U69/U90/U98 arbiter and U118 detector now
connect and pass a signal-path test with test-driven HLDA and IOCHRDY. Yosys
reports the modeled U90 asynchronous-clear feedback as a structural loop;
native CPU, DRAM, hold inhibition and port-B integration remain open. See the
[path report](../../design/intel_80286/report/2026-10-29-at-refresh-path.md).

The WAIT priority fix passes full simulation (203 PASS lines) and the full
historical-software regression. The unchanged BIOS reaches `F000:038A`, with
247,196 and 1,295,769 CPU states matched to Unicorn using recorded I/O.
Synthesis, BMC and PDR remain active; no whole-core proof is claimed. See the
[formal report](../../design/intel_80286/report/2026-10-29-wait-event-formal.md).
The checkpoint is [issue comment 6510351122](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6510351122).

## Refresh request and WAIT priority investigation — 2026-10-29

The standalone U68/U95 refresh request and clear chain passes timer/DMA
edge, IOCHRDY stall and reset tests and a Yosys structural check. It still
needs real board grant/refresh wiring; see the
[request report](../../design/intel_80286/report/2026-10-29-at-refresh-request.md).
The corrected-bound BMC and earlier PDR both failed on a WAIT/extension-error
race with an NMI event. The CPU now defers new events when an extension fault
is reportable and preserves an already-claimed INTR; 111 bootstrap checks pass.
Full simulation and software later passed as above; synthesis, BMC and PDR
are running. No whole-core proof is
claimed. The [formal report](../../design/intel_80286/report/2026-10-29-wait-event-formal.md)
tracks the counterexample and next checks. The
[issue checkpoint](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6510250610)
records both changes.

## Formal state bound and refresh preset — 2026-10-29

The corrected WAIT/event BMC failed at step 8 because its state-range
assertion excluded the reachable `WAIT_BUSY` state. The bound now includes
all allocated states through `CALL_DESC_FINAL`. The replacement BMC later
failed on the event-priority race above. The schematic also
shows U118 preset connected to a 1 kΩ pull-up, not a board reset: its initial
value remains unspecified. The preset-high component test passes. See the
[formal report](../../design/intel_80286/report/2026-10-29-wait-event-formal.md),
[refresh report](../../design/intel_80286/report/2026-10-29-at-refresh-detect.md)
and [issue checkpoint](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6492014603).

## AT refresh-detect component — 2026-10-29

Implemented IBM 5170 schematic U118 as a standalone flip-flop driven by
`+REFRESH` and active-low preset. Its Verilator edge/preset tests and a Yosys
structural check pass. It is not connected to the BIOS fixture: source tracing,
refresh generation, native HOLD/HLDA arbitration and port 61h remain open.
See the [component report](../../design/intel_80286/report/2026-10-29-at-refresh-detect.md).
The issue checkpoint is [comment 6491915305](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6491915305).

## WAIT/event formal counterexample — 2026-10-29

The previously running current-source whole-core PDR finished **FAIL** at
step 9. The witness exposes incomplete assertions around `WAIT` retirement
and a held interrupt event across `BOUNDARY`. Updated properties and focused
NMI/INTR race tests pass the full CPU bootstrap simulation; a fresh bounded
formal run later failed on the state bound as recorded above. See the
[formal report](../../design/intel_80286/report/2026-10-29-wait-event-formal.md).
The failed PDR is not a proof, and current-source whole-core verification
remains open. The result was recorded in
[issue comment 6491814344](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6491814344).

## DMA page-register BIOS checkpoint — 2026-10-29

An explicit CPU-visible page-register fixture replaces generic port storage.
The unchanged IBM AT BIOS reaches `F000:038A` after its page-register test in
both virtual-clock/READY scenarios, with 3,573 page reads each. The full
software entry point exits 0 and Unicorn matches 247,196 and 1,295,769 CPU
instruction states using captured I/O inputs. Standalone READY-stall, slot
isolation and map-output checks pass. DMA-side page wiring, refresh and full
POST remain open; see the [page BIOS report](../../design/intel_80286/report/2026-10-29-at-page-bios.md).
The checkpoint is [issue comment 6491652810](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6491652810).

## DMA-register BIOS checkpoint — 2026-10-29

The 80286 fixture now connects two 8237 register interfaces. The unchanged
BIOS reached `F000:0302` after both DMA register tests in both READY modes;
the always-ready trace matched Unicorn for 197,920 instruction states. The
saved stalled trace now also matches 1,246,493 states. The full software entry
point exited 0 in retained container `codex-intel286-dma-software-20261029-01`,
including both timer and DMA register tests with source hashes checked. The
old PDR container is absent without a terminal proof result; the later
current-source PDR failed as recorded above. Details are in the
[DMA BIOS report](../../design/intel_80286/report/2026-10-29-at-dma-bios.md).
The checkpoint is [issue comment 6491502332](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6491502332).

## IBM AT BIOS: both channel-1 timer tests — 2026-10-29

The connected 80286/8254 fixture now reaches `F000:027B` after both the
all-bits-on and all-bits-off channel-1 BIOS tests. The two virtual-clock/READY
scenarios match Unicorn for 197,002 and 1,245,575 instruction states and
data transactions with captured I/O inputs. Full `run_software.sh` passes.
This is a bounded fixture, not full POST or independent timer verification;
see the [connected BIOS report](../../design/intel_80286/report/2026-10-29-at-timer-bios.md).
The checkpoint is [issue comment 6490338942](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6490338942).

## Previous checkpoint: IBM AT BIOS with connected 8254 — 2026-10-29

The CPU fixture now connects the existing 8254 RTL. The unchanged IBM AT BIOS
reaches `F000:0258`, past its first channel-1 timer test, under two virtual
clock/READY combinations. Unicorn matches 196,889 and 1,245,453 instruction
states and their data transactions using captured I/O inputs. The full
`run_software.sh` entry point passes and includes these cases. This is not full
POST or an independent proof of the timer; see the
[connected BIOS report](../../design/intel_80286/report/2026-10-29-at-timer-bios.md)
and [issue checkpoint](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6490277004).

## IBM AT timer fixture — 2026-10-29

Added and standalone-tested a READY-qualified adapter for the existing 8254
RTL at the BIOS timer ports. It runs timer clocks independently of bus stalls.
IBM's 1984 5170 reference supplies the variant and board wiring. CPU-connected
timer execution and full POST remain open; see the
[fixture report](../../design/intel_80286/report/2026-10-29-at-timer-fixture.md)
and [issue checkpoint](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6490068444).

## Current-source BIOS refresh — 2026-10-29 06:43 UTC

The bounded IBM AT BIOS regression was rerun after the task-gate RTL change.
It passes 196,846 independent instruction states through ROM-checksum success,
plus the BIOS helper, IRQ8 and system-register checks. All 38 runner manifest
sources match the worktree. Full POST/boot remains open; see the
[software report](../../design/intel_80286/report/2026-10-29-historical-software-current-source.md).
An exploratory run past the checksum stop reaches a timer polling loop at
`F000:0242`–`0251`: the fixture's port `41h` is static. A source-backed timer
model and machine integration are needed for the next POST stage; the probe
is not an RTL or full-POST pass. See
[issue checkpoint 6489942100](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6489942100).

## Latest checkpoint — 2026-10-29 06:40 UTC

The handler-entry regression now also makes the #DF target TSS unavailable.
Both READY modes enter quiescent shutdown with the first fault context intact,
without accessing the rejected target TSS. Focused task-gate coverage passes
32 executions; the full bootstrap reports 110 PASS lines. This follow-up changes the
testbench only. See the [handler-entry report](../../design/intel_80286/report/2026-10-29-task-gate-handler-entry.md).
The issue checkpoint is [comment 6489860781](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6489860781).
The preserved older-source PDR process remains live; it is not current-source
proof. Full formal, POST/boot, OS/2 CPGREP on RTL, native-interface and
whole-CPU acceptance remain open.

## Previous checkpoint — 2026-10-29 06:31 UTC

Added two READY-policy cases for a not-present #TS task-gate target TSS while
delivering a contributory #TS. RTL escalates this nested fault to #DF, delivers
through a valid #DF task gate, preserves the first fault's context, and lets
the #DF task repair the original TSS and task-IRET to the exact NOP/HLT
successor. The focused option passes 12 event cases, 16 incoming-task recovery
executions and 2 handler-entry recoveries; the full bootstrap passes 110 checks
with no failures or errors. The RTL changed. Details and hashes are in the
[handler-entry report](../../design/intel_80286/report/2026-10-29-task-gate-handler-entry.md).

Other handler-entry fault classes, failure while entering #DF, current-source
connected-core formal, full POST/boot, OS/2 CPGREP on RTL, native-interface
qualification and whole-CPU acceptance remain open. Issue #80 remains
OPEN/Building, Agent Codex, Path `ai_hw_engineer/design/intel_80286`, Start date
`2026-10-23`, Sprint 1. Project fields were read back, and the checkpoint
comment is [6489742960](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6489742960).

## Previous checkpoint — 2026-10-29 06:00 UTC

Expanded task-gate fault recovery to eight incoming-selector faults under both
READY policies (16 recovery executions): null/wrong-type/not-present CS,
null/not-present SS, not-present DS/ES and wrong-type LDTR. A second task gate
delivers each fault to a handler task, which repairs the saved TSS selector and
task-IRETs back. Tests check event packets and error codes, saved TSS state,
backlinks, busy bits, error pushes, repair writes, restored selectors and the
exact resumed-task successor. No RTL changed. See the
[fault-recovery report](../../design/intel_80286/report/2026-10-29-task-gate-fault-recovery.md).

Fresh Verilator 5.052 `-Wall` runner fingerprint
`e1c4f8629b7d5493ebf90039c9173eb4281e31ecea6c56b39fe6b73cfef421cb`; focused
task-gate option passes 12 event cases plus 16 recovery executions and the full
default bootstrap passes 109 `PASS:` lines with zero failure/error markers.
Faults during task-gate handler entry, current-source connected-core formal,
full POST/boot, OS/2 CPGREP on RTL, native-interface qualification and whole-CPU
acceptance remain open. Issue #80 remains OPEN/Building, Agent Codex, Path
`ai_hw_engineer/design/intel_80286`, Start date `2026-10-23`, Sprint 1.
Checkpoint posted and read back in
[comment 6489249590](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6489249590).

## Previous checkpoint — 2026-10-29 05:41 UTC

The CPL1/CPL2 DPL-0 task-gate matrix covers external INTR, software
`INT 13h`/#GP and NMI in 12 cases across both READY policies. The focused test
and existing ring-level interrupt/trap-gate matrix pass 12/12 and 8/8; the
default bootstrap passes 108 checks. See the
[event-delivery report](../../design/intel_80286/report/2026-10-29-task-gate-event-delivery.md)
and [checkpoint 6489004572](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6489004572).

## Previous checkpoint — 2026-10-29 05:09 UTC

Intel 210498-005 §8.3, printed page 8-6, says incoming-task validation faults
run in the newly loaded task context. The previous fault path updated visible
registers but retained outgoing hidden segment caches, so an incoming #GP
handler could use the outgoing SS base or read through the outgoing DS base.
The RTL now installs only validated incoming caches, invalidates the rest and
clears staged caches at each new TSS load. A directed handler test checks the
exact incoming #GP frame, no outgoing-stack writes, and a follow-on #GP for
the rejected DS in both READY modes. See the [fault-context report](../../design/intel_80286/report/2026-10-29-task-fault-context.md)
and escaped-defect note. That checkpoint's connected-core formal, full
POST/boot, OS/2 CPGREP on RTL and whole-CPU acceptance remain open.

## Previous checkpoint — 2026-10-29 04:22 UTC

Audited Intel 210498-005 section 8.3 step 7 with Playwright CLI and found the
incoming selector order must be SS, CS, DS, ES. A combined-fault case
reproduced the old CS-before-SS behavior; RTL now checks LDT, SS, CS, DS, ES,
then IP. The LDT matrix checks descriptor reads, accessed-bit writes and
partial effects. Full simulation passes with 197 `PASS:` lines and no
failure/error markers; all 13 Yosys synthesis targets pass 39 structural
checks; current-source code-load BMC, induction and cover pass with eight
witnesses. The current-source IBM AT BIOS regression passes 196,846 exact
instruction states through checksum success, with helper, IRQ8 and
system-register regressions passing too. See the
[SS-before-CS report](../../design/intel_80286/report/2026-10-29-task-switch-ss-before-cs.md).
Issue #80 remains Open/Building with Agent Codex, Path
`ai_hw_engineer/design/intel_80286`, first Start date `2026-10-23`, Sprint 1.
The checkpoint was posted and read back in
[comment 6487916045](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6487916045).

The preserved stale-source PDR remains active at frame 166, 344/411 outputs
proved, 67 timeout retries. Current-source connected-core formal, full
POST/boot, OS/2 CPGREP on RTL and whole-CPU acceptance remain open.

## Previous checkpoint — 2026-10-29 03:30 UTC

Audited Intel 210498-005 section 8.3 step 8 with Playwright CLI and found
incoming IP-limit validation ran before incoming SS/CS/DS/ES validation. Added
four cases: null SS plus invalid IP must select `#SS(0)`; valid SS plus
invalid IP must select `#GP(0)`, each with READY stalls off/on and exact task
context checks. The first case failed against the old RTL with `#GP` selected.
The RTL now checks the IP after SS, DS and ES. Full `scripts/run_sim.sh`
passes with 196 `PASS:` lines and no failure/error markers. Details and hashes
are in the [task-switch IP validation-order report](../../design/intel_80286/report/2026-10-29-task-switch-ip-validation-order.md).
The 13-target Yosys 0.69 synthesis completed with exit 0. All 13 targets
produced JSON netlists and each target log has three zero-problem structural
checks. Current-source connected-core formal and full CPU acceptance remain
open. Preserve the active stale-source PDR; its latest log is frame 166,
344/411 outputs proved and 67 timeout retries. Its source still differs from
current RTL and cannot count as current-source proof.

The project issue remains Open/Building, Agent Codex, Path
`ai_hw_engineer/design/intel_80286`, first Start date `2026-10-23`, Sprint 1.
The issue checkpoint is posted and read back in
[comment 6487134519](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6487134519).

## Previous checkpoint — 2026-10-29 02:50 UTC

The historical software entry point now provisions pinned Unicorn 2.1.4 into
its ignored work directory. The current-source `scripts/run_software.sh` run
was repeated in `ai-hw-engineer:latest` and exited 0: the unchanged IBM AT
REV1 BIOS reached its checksum-success checkpoint after 196,846 exact
instruction states; the original hex helper passed 16 cases / 464 states;
eight IRQ8 cases passed across 236 handler states; and four BIOS
system-register patterns passed across 164 states. The scope is bounded and
does not claim full POST or boot. Exact ROM, trace, build and log hashes are
in the [current-source software report](../../design/intel_80286/report/2026-10-29-historical-software-current-source.md).
Evidence is under
`design/intel_80286/work/historical_software_current_20261029_23/`.

No RTL changed. Current-source connected-core proof and the full CPU release
gate remain open; the larger OS/2 CPGREP workload has not run on RTL. The
preserved whole-core PDR remains active on its stale 21-file snapshot at frame
118 with 343/411 outputs proved and 50 timeout retries. Preserve it and defer
a competing connected-core run until it terminates.

The project issue remains Open/Building, Agent Codex, Path
`ai_hw_engineer/design/intel_80286`, first Start date `2026-10-23`, Sprint 1.
The checkpoint was posted and read back in
[issue comment 6486536094](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6486536094).

## Previous checkpoint — 2026-10-29 02:38 UTC

Extended Intel Table 8-1 rows 4–5 incoming-LDTR fault coverage through both
#DF outcomes for all five invalid-selector categories: TI set, wrong
descriptor type, wrong type with selector RPL bits, not-present LDT and GDT
limit. Ten malformed-gate cases enter sticky shutdown; ten valid #DF task-gate
cases save the faulting TSS and reach the handler successor, across both READY
modes. The not-present valid-task case uses selector `0078` because the #DF
TSS occupies `0070`. See the [incoming-LDTR report](../../design/intel_80286/report/2026-10-29-incoming-ldtr-escalation-variants.md)
and [Table 8-1 audit](../../design/intel_80286/report/2026-10-29-table-8-1-task-entry-audit.md).

Preflight, strict Verilator 5.052 `-Wall` build, focused `--iopl-controls`
and full `scripts/run_sim.sh` pass. The full log contains 195 `PASS:` lines
and no `FAIL:` or `ERROR:` markers. Protected replay is `PASS` for 79 cases
in each READY mode. Evidence is under
`design/intel_80286/work/incoming_ldtr_escalation_variants_20261029_21/`.
Only testbench code changed; synthesis remains applicable. Project fields
remain Open/Building, Agent Codex, Path `ai_hw_engineer/design/intel_80286`,
first Start date `2026-10-23`, and Sprint 1.
The checkpoint was posted and read back in
[issue comment 6486405063](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6486405063).

The preserved whole-core PDR remains active after 17 hours on its separate
stale snapshot. Its latest solver log line remains frame 118 with 343/411
outputs proved and 50 timeout retries; it cannot establish current-source
proof. Current-source connected-core formal, authentic software and whole-CPU
acceptance remain open.

## Previous checkpoint — 2026-10-29 02:28 UTC

Reviewed Intel Table 8-1 rows 1–3 and added six nested #DF target-TSS cases:
busy, short available, and not-present-plus-short descriptors in both READY
modes. Each failure enters shutdown before task-state writes. The existing
42-execution direct TSS/task-gate matrix checks exact #NP/#GP/#TS first-fault
packets and #NP priority for not-present short descriptors. Row 13 DS
TI/null-LDTR `#GP(005C)` and DS/ES GDT-limit `#GP(0188)` escalation are also
covered with GDTR.limit `0187`. See the [TSS preflight report](../../design/intel_80286/report/2026-10-29-incoming-tss-preflight-double-fault.md),
[DS/ES validity report](../../design/intel_80286/report/2026-10-29-incoming-ds-es-validity-double-fault.md)
and [Table 8-1 audit](../../design/intel_80286/report/2026-10-29-table-8-1-task-entry-audit.md).

The fixture audit corrected `setup_incoming_ldtr`, which had put `0187` in
IDTR.limit while GDTR.limit remained `007F`. Both are now set explicitly to
`0187`; this full run reran the incoming CS, SS, DS, ES and LDTR limit cases at
the exact GDT boundary. Preflight, exact-source Verilator 5.052 `-Wall` build
and focused `--iopl-controls` pass. Full `scripts/run_sim.sh` exits 0 with 195
`PASS:` lines and no `FAIL:` or `ERROR:` lines; protected replay passes 79
cases in both READY modes. Evidence is under
`design/intel_80286/work/table_8_1_tss_preflight_double_fault_20261029_20/`.
Only testbench and fixture code changed, not RTL. Project readback confirms
Open/Building, Agent Codex, Path `ai_hw_engineer/design/intel_80286`, first
Start date `2026-10-23`, and Sprint 1. The checkpoint was posted and read back
in [issue comment 6486238114](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6486238114).

The preserved whole-core PDR remains active on its separate stale source
snapshot. At 02:27:59 UTC it remained at frame 118 with 343/411 outputs proved
and 50 timeout retries; 19/21 inputs match current source. Do not count it as
current-source proof or start a competing connected-core job before it
terminates. Current-source formal, authentic software and whole-CPU
acceptance remain open.

The preserved whole-core PDR remains active. Its latest log at 01:09 UTC is
frame 96 with 343/411 outputs proved and 48 timeouts. Source comparison found
19/21 inputs match current source; `intel_80286.sv` and
`intel_80286_code_load.sv` differ, so its result cannot count as current-source
proof. Preserve it until terminal status before starting a competing core run.
See the
[PDR source-epoch audit](../../design/intel_80286/report/2026-10-29-pdr-source-epoch-audit.md)
and [latest issue checkpoint](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6485126780).
Project-item readback confirms Open/Building, Agent Codex, Path
`ai_hw_engineer/design/intel_80286`, and Start date `2026-10-23`; this
checkpoint is recorded in
[issue comment 6485126780](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6485126780).

## Previous checkpoint — 2026-10-29 00:43 UTC

Added four incoming-ES execute-only `#GP` escalation executions. Table 8-1
row 14 maps selector `0030` to `#GP(0030)` as ES while it remains valid as CS.
Both shutdown and valid #DF task-gate delivery pass in both READY modes. See
the [incoming-ES #GP report](../../design/intel_80286/report/2026-10-29-protected-incoming-es-gp-double-fault.md).

## Previous checkpoint — 2026-10-29 00:35 UTC

Added four incoming-ES non-present `#NP` escalation executions. Table 8-1 row
15 maps selector `0020` to `#NP(0020)`; invalid-#DF-gate shutdown and valid
#DF task-gate delivery pass in both READY modes. The tests check the
descriptor read, saved TSS, backlink/busy state, null error push and handler
successor. See the
[incoming-ES #NP report](../../design/intel_80286/report/2026-10-29-protected-incoming-es-np-double-fault.md).

## Previous checkpoint — 2026-10-29 00:21 UTC

Added four incoming-CS non-present `#NP` first-fault escalation executions.
Intel Table 8-1 row 7 maps non-present CS selector `0008` to `#NP(0008)`. A
malformed `#NP` gate escalates to null-error `#DF`; tests cover sticky
shutdown on an invalid vector-8 gate and successful `#DF` task-gate delivery
in both READY modes. They check exact event context and gate reads, the saved
incoming TSS image with CS=`0008`, backlink/busy state, null error push and
handler successor. Playwright CLI visually verified row 7; the screenshot
and test evidence are in
`design/intel_80286/work/incoming_cs_np_double_fault_20261029_01/`. See the
[incoming-CS #NP report](../../design/intel_80286/report/2026-10-29-protected-cs-np-double-fault-first-fault.md).

Preflight passes. Strict Verilator 5.052 `-Wall` `scripts/run_sim.sh` exits 0
with 175 `PASS:` lines and no `FAIL:` or `ERROR:` lines. Protected replay
passes 79 cases in both READY modes. RTL is unchanged, so the prior synthesis
remains applicable. Current-source connected-core proof, other task-entry
fault phases, authentic software and whole-CPU acceptance remain open.
Project-item reads are still blocked by the GitHub GraphQL rate limit; no
project fields were changed. The checkpoint was posted and read back in
[issue comment 6484304062](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6484304062).

## Previous checkpoint — 2026-10-29 00:13 UTC

Added four incoming-CS first-fault `#TS` escalation executions. A null
incoming CS raises `#TS(0000)` under Intel Table 8-1 row 6. With a malformed
`#TS` gate, the follow-on protection fault selects null-error `#DF`; tests
cover shutdown on an invalid vector-8 gate and successful vector-8 task-gate
delivery in both READY modes. They check the original event context, exact
gate reads, sticky shutdown, the incoming TSS image with CS=`0000`,
backlink/busy state, the null error push and exact handler successor. See the
[incoming-CS #DF report](../../design/intel_80286/report/2026-10-29-protected-cs-double-fault-first-fault.md).

Preflight passes. Strict Verilator 5.052 `-Wall` `scripts/run_sim.sh` exits 0
with 174 `PASS:` lines and no `FAIL:` or `ERROR:` lines. Protected replay
passes 79 cases in both READY modes. Evidence and hashes are in
`design/intel_80286/work/incoming_cs_double_fault_20261029_01/`. RTL is
unchanged, so the prior synthesis remains applicable. Current-source
connected-core proof, other task-entry fault phases, authentic software and
whole-CPU acceptance remain open. GitHub project-item reads remain blocked by
the GraphQL API rate limit; no project fields were changed. The checkpoint
comment was posted and read back in
[issue comment 6484222610](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6484222610).

## Previous checkpoint — 2026-10-29 00:01 UTC

Added an incoming-task ES system-descriptor case. Intel Table 8-1 row 13
maps an invalid DS/ES selector to `#GP`; ES selector `0050` now checks exact
`#GP(0050)` after valid CS/SS/DS checks. The incoming CS/SS/DS/ES fault
matrix covers 24 configurations and 48 executions in both READY modes. The
SS RPL-mismatch case also checks exact `#SS(0028)` from Table 8-1 row 9.

Preflight passes. Strict Verilator 5.052 `-Wall` `scripts/run_sim.sh` exits 0
with 173 `PASS:` lines and no `FAIL:` or `ERROR:` lines. Protected replay
passes 79 cases in both READY modes. Evidence and hashes are in the
[incoming ES descriptor report](../../design/intel_80286/report/2026-10-29-incoming-es-system-descriptor.md)
and `design/intel_80286/work/incoming_task_es_type_20261028_01/`. RTL is
unchanged, so the prior 13-target synthesis remains applicable. Current-source
connected-core proof, other post-transfer task-switch fault phases, authentic
software and whole-CPU acceptance remain open. GitHub project-item readback is
still rate-limited; no project fields were changed. The latest issue checkpoint
was posted and read back in
[issue comment 6483988275](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6483988275).

## Earlier checkpoint — 2026-10-28 23:55 UTC

Added an incoming task SS selector RPL-mismatch case. Intel 210498-005 Table
8-1 maps invalid incoming stack selectors to `SF` (#SS); the test checks exact
`#SS(0028)` for selector `002B` with RPL 3 at CPL 0. The incoming CS/SS/DS/ES
fault matrix now covers 23 configurations and 46 executions in both READY
modes. The earlier draft's `#TS` expectation was corrected from the table and
the observed task-gate packet; RTL is unchanged.

Preflight passes. The strict Verilator 5.052 `-Wall` full run records 173
`PASS:` lines and no `FAIL:` or `ERROR:` lines. Protected replay passes 79
cases in each READY mode. Logs, manifest and hashes are in the
[incoming SS RPL report](../../design/intel_80286/report/2026-10-28-incoming-ss-rpl-fault.md)
and `design/intel_80286/work/incoming_task_ss_rpl_20261028_02/`. The existing
13-target synthesis remains applicable because RTL did not change. Current-
source connected-core proof, remaining task-switch fault phases, authentic
software and whole-CPU release acceptance remain open. The prior GitHub
project-item readback was blocked by a GraphQL rate limit; no project fields
were changed. The latest issue checkpoint reports Open/Building, Agent Codex,
Path `ai_hw_engineer/design/intel_80286`, and first Start date 2026-10-23.
The checkpoint was posted and read back in
[issue comment 6483919626](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6483919626).

## Earlier checkpoint — 2026-10-28 23:47 UTC

Added the missing incoming ES GDT-limit fault. The CS/SS/DS/ES selector-fault
matrix now covers 22 configurations and 44 executions across both READY
modes. ES selector `0188` beyond GDT limit `0187` raises exact `#GP(0188)`
after valid CS/SS/DS checks, with no read of the rejected descriptor.

Preflight passes; strict Verilator 5.052 `-Wall` `scripts/run_sim.sh` exits 0
with 173 PASS lines and no FAIL/ERROR lines. The same run passes the 460-case
incoming-LDT DPL/RPL matrix, eight LDT-limit faults, and 79 protected replay
cases in both READY modes. Evidence and hashes are in the
[ES GDT-limit report](../../design/intel_80286/report/2026-10-28-incoming-es-gdt-limit.md)
and `design/intel_80286/work/incoming_task_selector_bounds_20261028_01/`.
No RTL behavior changed; previous 13-target Yosys synthesis remains
applicable. Current-source connected-core proof, other task-switch phases,
authentic software and full release acceptance remain open.

Issue #80 remains Open/Building, Agent Codex, Path
`ai_hw_engineer/design/intel_80286`, Start date 2026-10-23. The issue
checkpoint was posted and read back in
[comment 6483734952](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6483734952).

## Previous checkpoint — 2026-10-28 23:41 UTC

Expanded valid incoming non-null-LDT task entry to 460 privilege executions
across CPL0–2. CS/SS use DPL=RPL=CPL; DS/ES cover every DPL/RPL combination
satisfying `max(CPL,RPL) <= DPL` in both READY modes. The LDT limit is exactly
`0027`; all four descriptors, including ES at the upper bound, load and reach
the exact successor. Eight additional cases place CS/SS/DS/ES at offset
`0038`, checking Table 8-1 `#TS/#SS/#GP`, exact `003C` errors, transferred-task
state, prior read order, and no out-of-limit reads or accessed writes.

The manual's §7.4.1 and Table 8-1 were visually checked with `playwright-cli`.
Preflight passes. Strict Verilator 5.052 `-Wall` `scripts/run_sim.sh` exits 0
with 173 PASS lines and no FAIL/ERROR lines. Protected replay passes all 79
cases in both READY modes. Evidence and hashes are recorded in the
[incoming-LDT report](../../design/intel_80286/report/2026-10-28-incoming-ldt-privilege-limit-matrix.md)
and `design/intel_80286/work/incoming_ldt_rpl_20261028_02/`. No RTL behavior
changed; the previous 13-target Yosys 0.69 synthesis remains applicable.

Current-source connected-core proof, remaining task-switch phases, authentic
historical software, native timing qualification and the full release gate
remain open. The preserved PDR process is still active against a different
21-file snapshot without a terminal result.

Issue #80 remains Open/Building, Agent Codex, Path
`ai_hw_engineer/design/intel_80286`, Start date 2026-10-23. The issue
checkpoint was posted and read back in
[comment 6483636717](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6483636717).

## Previous checkpoint — 2026-10-28 23:30 UTC

The initial valid non-null-LDT matrix covered 58 CPL0–2 privilege executions
with selector RPL=CPL. Eight additional LDT-limit faults checked Table 8-1
exceptions and no descriptor access beyond `0027` in both READY modes. The
coverage is now expanded to the full allowed DS/ES DPL/RPL boundary above.

## Previous checkpoint — 2026-10-28 23:16 UTC

Added a 192-execution direct-TSS CALL/JMP privilege matrix covering CPL0–2,
selector RPL0–3, TSS DPL0–3 and both READY policies. All 104 allowed transfers
and 88 denials pass `max(CPL,RPL) <= TSS_DPL`, with exact successors, CALL
backlink/NT return and frame behavior, JMP busy-bit behavior, #GP frames and
task-state preflight checks. The focused `--iopl-controls` run passes all 23
suite groups; strict Verilator 5.052 `-Wall` full `scripts/run_sim.sh` exits 0
with 172 PASS lines and no failures or errors. Protected replay passes 79
cases in both READY modes. Details and hashes are in the
[direct-TSS report](../../design/intel_80286/report/2026-10-28-direct-tss-privilege-matrix.md).

No RTL behavior changed, so the 13-target Yosys 0.69 synthesis remains
applicable. Current-source connected-core formal, remaining task-switch fault
phases, authentic historical software, native physical timing qualification
and the full release gate remain open. The older PDR process was still alive
when checked at 23:18 UTC; its latest log entry remains 22:21:21 UTC at frame
27, 342/411 outputs proved and 31 timeout retries, without a terminal result.
Preserve it and do not count it as current-source evidence.

Issue #80 remains Open/Building, Agent Codex, Path
`ai_hw_engineer/design/intel_80286`, Start date 2026-10-23. The ownership
fields were read back before this checkpoint and remain as recorded. The
checkpoint was posted and read back in
[issue comment 6483230260](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6483230260).

## Previous checkpoint — 2026-10-28 22:52 UTC

Added and passed 384 reachable CPL1/CPL2/CPL3 ARPL cases. The matrix covers
every source/destination RPL pair, register and SS-memory forms, both initial
ZF states and both READY policies. It enters each ring through outer IRET,
checks only-ZF changes, exact instruction fetch and two unprivileged NOP
successors, and exact conditional memory RMW traffic. The focused `--arpl`
run passes; strict Verilator 5.052 `-Wall` `scripts/run_sim.sh` exits 0 with
171 PASS lines and no failures/errors. Protected replay passes 79/79 cases in
both READY modes. Evidence root:
`design/intel_80286/work/arpl_reachable_privilege_20261028/`; see the
[ARPL report](../../design/intel_80286/report/2026-10-28-arpl-reachable-privilege-matrix.md).

The 13-target Yosys 0.69 synthesis remains valid; no RTL behavior changed.
Current-source connected-core formal, alternate-stepping ARPL evidence,
authentic historical software, native physical timing qualification and the
full release gate remain open. The older whole-core PDR is active on a
different 21-file source snapshot; at 22:21 UTC it remained at frame 27 with
342/411 outputs proved and 31 timeouts, without terminal PASS. Preserve it and
do not treat it as current-source evidence.

Issue #80 remains Open/Building, Agent Codex, Path
`ai_hw_engineer/design/intel_80286`, Start date 2026-10-23. The latest
checkpoint was read back in
[issue comment 6482816712](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6482816712).

## Previous checkpoint — 2026-10-28 22:40 UTC

Expanded the direct task-gate privilege matrix to all 192 CPL0–2,
selector-RPL0–3, gate-DPL0–3, CALL/JMP and READY-mode combinations. All 104
permitted transfers and 88 denied transfers pass, checking exact successors,
#GP frames and destination-task preflight. The full strict Verilator 5.052
`-Wall` `scripts/run_sim.sh` exits 0 with 170 `PASS:` lines and no failures or
errors. Protected replay passes all 79 cases in both READY modes. Evidence is
under
`design/intel_80286/work/task_gate_privilege_exhaustive_current_20261028/`;
the [direct-transfer report](../../design/intel_80286/report/2026-10-28-protected-direct-task-transfers.md)
records hashes and scope.

Corrected-source Yosys 0.69 synthesis remains valid for the functional RTL;
all 13 targets and structural checks pass. Since synthesis, RTL changed only
by the A26 inline assumption comment. A26 remains unresolved. The earlier
whole-core PDR is still running on a different 21-file snapshot. At 22:40 UTC
its latest log remained at frame 27 with 342 outputs proved and 31 timeout
retries, with no terminal PASS. Preserve it and do not start overlapping
core formal work. Current-source connected-core formal, authentic historical
software and full release acceptance remain open.

Issue #80 remains Open/Building, Agent Codex, Path
`ai_hw_engineer/design/intel_80286`, Start date 2026-10-23. The last verified
checkpoint was read back in
[comment 6482597698](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6482597698).

## Previous checkpoint — 2026-10-28 21:47 UTC

This records the pre-audit interpretation and is superseded by the 22:24
checkpoint above: Intel 210498-005 §8.5 says the 286 ignores a nonzero
task-gate offset, and Table 8-1 assigns #GP(selector) to a busy incoming TSS.

Direct task-transfer rejection coverage found a task-gate reserved-offset bug:
the decoder accepted a nonzero offset and continued toward the target TSS. The
core now raises #GP(task-gate selector) before target-TSS lookup. The focused
`--iopl-controls` passes 44 executions across 22 selected direct-TSS/task-gate
fault configurations in both READY modes. Paired task-gate CALL/JMP cases
reject a busy target TSS and an embedded TSS selector beyond the GDT limit
with #TS(target selector). The matrix checks exact
#GP/#NP/#TS packets, exception frames, descriptor-read boundaries, and no
task-image or busy-bit writes. A further
900 reset-cut executions across direct CALL/JMP and TSS/task-gate entry, including
eight post-commit cuts, also pass and replay only the exact reset-vector HLT.
The corrected full `scripts/run_sim.sh` exits 0 with 169 `PASS:` lines and no
`FAIL`/`ERROR` lines; all 79 protected replay cases pass in both READY modes.

The corrected-source 13-target Yosys 0.69 matrix exits 0 under
`design/intel_80286/work/direct_task_faults_synth_20261028/`, writes all 13 JSON
netlists and logs, and reports zero problems in three structural checks per
target (39 total, no errors). Full-core, `NATIVE_BEATS=1`, and native-CPU
synthesis took 493.39 s, 482.24 s and 463.26 s.
Hashes and completed simulation evidence are in the
[direct-transfer report](../../design/intel_80286/report/2026-10-28-protected-direct-task-transfers.md).
No current-source whole-core formal was started because an older PDR remains
active on a different 21-file source snapshot. Its latest log (21:34:45 UTC)
reached frame 20 with 342 outputs proven and 14 timeout retries; at 21:47 UTC
the process had run 12:18:26. Additional direct-transfer faults,
current-source connected-core formal, authentic historical software and full
release acceptance remain open. Issue #80 remains Open/Building, Agent Codex,
Path `ai_hw_engineer/design/intel_80286`, Start date 2026-10-23; the last posted
checkpoint is [comment 6481394556](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6481394556).

## Previous checkpoint — 2026-10-28 21:03 UTC

The protected direct far CALL/JMP task-transfer slice passes full
`scripts/run_sim.sh` with 167 `PASS:` lines and zero `FAIL`/`ERROR` lines.
Protected replay passes all 79 cases in both READY modes. The current-source
13-target Yosys 0.69 matrix exits 0, writes all 13 JSON netlists and logs, and
every target's final `check -assert` reports zero problems. Full-core,
`NATIVE_BEATS=1`, and native-CPU synthesis take 466.67 s, 540.22 s and 530.26 s.
Source hashes, command and evidence directories are in the
[direct-transfer report](../../design/intel_80286/report/2026-10-28-protected-direct-task-transfers.md).

No current-source whole-core formal was started because an older PDR is still
active on a different source snapshot. Direct task-transfer fault priority,
current-source connected-core formal, authentic historical software and full
release acceptance remain open. Issue #80 remains Open/Building, Agent Codex,
Path `ai_hw_engineer/design/intel_80286`, Start date 2026-10-23.
The checkpoint was posted and read back in
[issue comment 6480638015](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6480638015).

## Previous checkpoint — 2026-10-28 20:43 UTC

Protected far CALL/JMP now supports tested available-TSS descriptor and task-
gate transfers. The eight-case matrix checks nested CALL, backlink and NT return
versus non-nested JMP, busy clearing, exact successors, retirement, and both
READY policies. A separate ordinary code-segment far JMP confirms the
single-read code-load path remains intact. The full `scripts/run_sim.sh`
passes with 167 `PASS:` lines, no `FAIL`/`ERROR` lines, and all 79 protected
replay cases in both READY modes. Verilator 5.052 `-Wall` is part of the runner.

The 13-target Yosys 0.69 matrix is still running in
`design/intel_80286/work/direct_task_transfers_synth_20261028/`; its result is
not yet counted. No formal job was started: the older whole-core PDR is still
active on a different source snapshot. Direct task-transfer fault priority,
current-source connected-core formal, authentic historical software, and
release acceptance remain open. The [direct-transfer report](../../design/intel_80286/report/2026-10-28-protected-direct-task-transfers.md)
will retain the final hashes and synthesis result.

Issue #80 remains Open/Building, Agent Codex, Path
`ai_hw_engineer/design/intel_80286`, Start date 2026-10-23. The latest posted
issue checkpoint is [comment 6479402130](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6479402130).

## Previous checkpoint — 2026-10-28 20:07 UTC

The 82C284 digital RES synchronizer remains integrated with the native CPU, bus
and 82288. Its two delay settings and connected reset paths pass focused
Verilator 5.052 `-Wall` tests. The current-source 13-target Yosys 0.69 matrix
passes with zero structural problems.

Expanded `--iopl-controls` with first-fault `#TS` from an invalid incoming
LDTR. A malformed #TS handler gate escalates to null-error #DF. In both READY
modes, one case enters sticky shutdown on an invalid vector-8 gate; a second
uses a valid #DF task gate, saves the faulting TSS with exact state, updates
backlink/busy state and executes the handler at its exact successor. The
existing #NP/#SS IDT-limit cases remain passing. Strict Verilator 5.052
`-Wall`, the focused matrix and full `run_sim.sh` pass; the full run has 165
PASS lines and protected replay passes 79 cases in both READY modes. Exact
hashes and limits are in the
[protected #DF first-fault report](../../design/intel_80286/report/2026-10-28-protected-double-fault-first-faults.md).

The older whole-core PDR remains on its distinct 21-file source snapshot and
is not current-source evidence. No new formal job was started. Issue #80
remains Building, Agent Codex, Path `ai_hw_engineer/design/intel_80286`, Start
date 2026-10-23. The checkpoint was posted and read back in
[issue comment 6479402130](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6479402130).

Next: cover more second-fault classes and later event/task-entry failure
phases. Preserve the existing proof artifacts and avoid starting another
connected-core formal epoch while the stale PDR process is live.

## Native CPU clock phase regression — 2026-10-28 19:02 UTC

Updated the connected native CPU test driver so `clk_i` and external 2x
`clk_2x_i` have the documented 2:1 frequency relationship. One processor
clock period spans two external clock periods, with a deterministic test
phase. No RTL changed. The focused pin test passes; full `run_sim.sh` exits 0
with 162 PASS lines and 79 protected replay cases in both READY modes. Exact
source hashes, logs and limits are in the
[native-clock report](../../design/intel_80286/report/2026-10-28-native-clock-phase.md).
The issue checkpoint is
[comment 6478016839](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6478016839).

The 82C284 analog startup and RESET edge conflict remain open. At 18:54 UTC,
the older whole-core PDR was still active on its earlier 21-file snapshot at
frame 89, with 329/411 outputs proved and 50 timeout retries. It does not
verify current source; no new formal run was started.

## Protected outer IRET fault priority — 2026-10-28 18:43 UTC

Intel 210498-005 Table 7-4 orders outer IRET checks as current-stack bounds,
return-CS descriptor, outer SS, then saved-IP limit. Two combined-fault
regressions exposed opposite early-check bugs: null CS before the complete
five-word frame check, and saved-IP limit before outer-SS validation. The RTL
now validates CS at offset zero after frame preflight and defers the saved-IP
limit check until after outer SS. The resulting #GP(0) does not partially
commit return context; the CS accessed-bit side effect is checked.

Twelve paired priority executions and the 36-execution `--protected-iret-faults`
matrix pass across both READY modes. Strict Verilator 5.052 `-Wall`, full
default bootstrap (71 PASS lines), `scripts/preflight.py`, and the current-source
Yosys 0.69 12-target matrix pass. All targets produced JSON netlists and logs,
with 36 zero-problem checks and no errors. Exact run identities and limits are
in the [fault-priority report](../../design/intel_80286/report/2026-10-28-protected-iret-fault-priority.md).
Issue #80 was updated and read back in [comment 6477632896](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6477632896).

The older whole-core PDR remains active on an earlier RTL snapshot and does
not prove current source. Current-source connected-core proof, broader
fault/task cases, independent historical-software evidence and the full release
gate remain open. Issue #80 remains Building with Agent Codex, original Start
date 2026-10-23, and Path `ai_hw_engineer/design/intel_80286`.

## Protected outer IRET frame bounds and synthesis — 2026-10-28 17:42 UTC

Added the missing current-stack checks required before protected outer IRET
descriptor lookup. An SP above the current SS limit raises #SS(0) before any
source-frame read. If SP is valid but the final byte of the five-word frame
crosses the limit, IRET reads only IP/CS/FLAGS and faults before reading outer
SP/SS or looking up the target CS descriptor. Both cases preserve the frame; a
handler loads a wider current SS, retries IRET and reaches the exact ring-3
successor. Both READY modes pass.

The full `--protected-iret-faults` matrix now totals 24 executions. Strict
Verilator 5.052 `-Wall`, the focused matrix, full default bootstrap and
`scripts/preflight.py` pass. The current-source Yosys 0.69 synthesis matrix
also exits 0: all 12 targets produced netlists, and each target log reports
zero structural problems. Logs and netlists are under
`design/intel_80286/work/iret_current_synth_20261028_14/synth/`. The older
whole-core PDR uses a different 21-file source snapshot and is not current-source
proof. See the [protected IRET recovery
report](../../design/intel_80286/report/2026-10-28-protected-iret-fault-recovery.md).
The current GitHub checkpoint is [comment 6476273413](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6476273413).

## Protected outer IRET fault recovery — 2026-10-28 16:59 UTC

Expanded `--protected-iret-faults` to 20 executions across both READY modes:
null, non-present and system-descriptor return CS; inward return; saved IP
beyond the code limit; and null, non-present, wrong-type, RPL/DPL-mismatched
and out-of-GDT-limit outer SS. The regressions check #GP/#NP/#SS vectors and
error codes, unchanged source frames, descriptor reads/accessed writes, handler
repair, retry of the same IRET and exact successor. Playwright CLI review of
Intel 210498-005 Tables 7-4 and 9-1 confirms outer-SS #SS(selector) and an
out-of-limit saved IP #GP(0). Strict Verilator 5.052 `-Wall`, the focused
matrix, full default bootstrap and `scripts/preflight.py` pass. Build
fingerprint is `1e23dcf233aaae05eacb153eeaebacc5345823ab25188b266712e18c646da879`.
The current-source 12-target synthesis rerun is still running; the last
completed matrix is for the preceding source snapshot. The older whole-core
PDR is at frame 25 with 326/411 outputs proved and 24 timeouts as of 16:57 UTC,
but its RTL copy hash differs from the current source. This is not current-
source proof.
See the [protected IRET recovery report](../../design/intel_80286/report/2026-10-28-protected-iret-fault-recovery.md).
The GitHub checkpoint is [comment 6475373524](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6475373524).

## Protected-mode WAIT interruption — 2026-10-28 15:54 UTC

Added a 16-case regression for NMI and acknowledged INTR during a BUSY-stalled
WAIT at CPL1/CPL2. It covers interrupt/trap gates and both READY modes, checks
TSS stack switching, exact outer frames and exact IRET successors. The strict
Verilator 5.052 `-Wall` runner build, `--protected-wait` slice and full default
bootstrap pass. No RTL changed. Evidence and hashes are in the
[protected WAIT report](../../design/intel_80286/report/2026-10-28-protected-wait-interruption.md).
The issue checkpoint is [comment 6473853937](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6473853937).

The CPU's saved IP during interrupted WAIT remains assumption A25; native pin
timing, current-source connected-core proof, successful ESC transfers and the
full CPU release gate remain open. The whole-core PDR is still running against
an earlier 21-file snapshot and does not establish this source.

## 80287 source cross-check — 2026-10-28 15:46 UTC

Playwright CLI visual review of Intel's 1986 *Microsystem Components
Handbook: Microprocessors, Volume I*, printed page 4-31, confirms the
reserved-port, IOPL/CPL-bypass, memory-operand and bus-priority rules already
captured from other Intel manuals. It still does not provide the byte-level
command or port sequence for each successful ESC form, so ESC transaction
implementation remains source-blocked. No RTL changed. See the
[80287 source report](../../design/intel_80286/report/2026-10-28-80287-processor-extension-slice.md).
The issue checkpoint is [comment 6473621922](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6473621922).
The older whole-core PDR remains active on a 21-file snapshot; its 15:42 UTC
log is at frame 11 with 326/411 outputs proved and five timeouts. It is not
current-source evidence; see the [formal plan](../../design/intel_80286/plans/formal_plan.md).

## WAIT interruptibility — 2026-10-28 15:32 UTC

The functional core now accepts eligible real-mode NMI and IF-enabled INTR
while opcode `9Bh` WAIT is stalled by BUSY. The strict Verilator 5.052 `-Wall`
build, focused `--processor-extension` slice and full default bootstrap pass.
Intel's 1983 iAPX 286/10 handbook says the CPU may be interrupted while
waiting, but it does not state the saved IP. Assumption A25 uses the already
advanced successor IP and remains open pending independent 286 validation.
The handbook also gives additional ESC memory-transfer port/count details but
no command bytes or port order. See the
[verification report](../../design/intel_80286/report/2026-10-28-wait-interruptibility.md).
The GitHub checkpoint is [issue comment 6473353919](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6473353919).

The separate whole-core PDR remains active on an earlier 21-file snapshot; at
15:32 UTC it was at frame 8 with 326/411 outputs proved and one timeout retry
in the current pass. It does not verify this source. Current-source connected
proof, complete protected-mode/ISA coverage and the `run_all.sh` release gate
remain open.

## CPL1/CPL2 protected event delivery — 2026-10-28 15:17 UTC

The strict Verilator `-Wall` runner build, existing CPL3 event regression,
four new CPL1/CPL2 event matrices (48 executions total) and full default
bootstrap pass. The software-INT matrix covers interrupt/trap gate types,
allowed/denied DPL boundaries and #GP(006A); the privileged-LIDT matrix checks
that exceptions ignore gate DPL 0/3 and deliver #GP(0) without reading the
operand; the external-INTR and NMI matrices confirm vector 13 and vector 2
delivery through DPL-0 gates, with no NMI acknowledge cycle and NMI service
unblocked by outer IRET.
All four use outer IRET entry, TSS SP0:SS0, exact five-/six-word frames,
IF/TF checks, interrupted-stack no-write assertions and exact return
successors in both READY modes. This is testbench-only; no RTL changed. Intel
210498-005 §9.4/Figure 9-4 was visually reviewed through Playwright CLI. See the
[event report](../../design/intel_80286/report/2026-10-28-protected-event-ring12.md).
The issue checkpoint is
[comment 6472602584](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6472602584).

Evidence and hashes are in
`design/intel_80286/work/selector_ring12_dev_20261028/`. The full bootstrap
log SHA-256 is
`8f307eba64dbe373ffa6c851de4feb45e09601692363e1afc4b49a555bab765a`.
Other CPL1/CPL2 processor exceptions and external vectors, task gates,
current-source connected-core proof, exact-source formal audit, and
`run_all.sh` remain open. The still-running whole-core PDR uses an older
21-file snapshot and does not establish this source.

## Current-source component formal refresh — 2026-10-28 14:46 UTC

All 12 standalone component formal configurations pass BMC, proof and cover:
36/36 tasks, with 59 reached cover witnesses. `preflight.py` passes, and the
exact-source audit confirms the saved task configs and copied inputs match the
current files. See the
[formal report](../../design/intel_80286/report/2026-10-28-formal-components-current.md).
This excludes the connected-core proof and PDR.

The old-snapshot whole-core PDR remained active at frame 89 with 321/411
outputs proven and 70 timeout retries at 14:46 UTC. The full CPU acceptance
gate remains open.

## Full-bootstrap verification — 2026-10-28 14:39 UTC

The full default bootstrap passes with the 768 reachable CPL1/CPL2 selector
queries included, as does the complete `--selector-exec` slice and strict
Verilator `-Wall` runner build. The 54-line default log SHA-256 is
`b8b4f5785f276e9336a009fe23e724073e7d58c3aad5b00b722b478943629d41`.
Evidence is in the
[CPL1/CPL2 report](../../design/intel_80286/report/2026-10-28-selector-query-ring12.md)
and [issue comment 6471994393](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6471994393).

At 14:39:46 UTC, the separate older-snapshot whole-core PDR reached frame 83,
with 321/411 outputs proven and 68 timeout retries. It does not prove current
source. Whole-CPU acceptance remains open.

## Reachable CPL1/CPL2 selector-query matrix — 2026-10-28 14:35 UTC

The strict Verilator `-Wall` runner build and complete `--selector-exec` slice
pass with 768 new reachable CPL1/CPL2 query cases. Each privilege level is
entered through outer IRET. The matrix covers writable data, readable
nonconforming code and readable conforming code for every DPL/RPL pair, VERR,
VERW, LAR and LSL, and both READY policies. It checks exact ZF-only behavior,
result preservation, descriptor reads/no writes and the exact successor. This
is testbench-only; no RTL changed. Intel 210498-005 §11.3 was visually reviewed
with Playwright CLI. See the
[verification report](../../design/intel_80286/report/2026-10-28-selector-query-ring12.md).

At 14:35 UTC, the separate whole-core PDR was active at frame 80 with 321/411
outputs proven and 66 timeout retries. It uses an earlier 21-file source
snapshot and does not verify current source. Full current-source formal and
whole-CPU acceptance remain open.

## 80287 ESC source audit — 2026-10-28 14:16 UTC

Intel 210760-002 Chapter 6 Figure 6-3 (printed page 6-6, PDF page 216) pins
the data-channel request window: requests may occur after ESC while BUSY is
high and stop after BUSY falls until another ESC; an even-address word uses
two bus cycles and an odd-address word uses three. A Playwright CLI review of
Intel AP-113 (printed page 9) found its coprocessor interface is for 8087 with
an 8086/88 host, so its S2:S0/QS1:QS0 sequence cannot be applied to the
80286/80287. No successful ESC command bytes or port order were inferred. The
next step is another 286/287-specific Intel interface source or an independent
pin trace; successful ESC RTL remains blocked on that evidence. See the
[80287 slice report](../../design/intel_80286/report/2026-10-28-80287-processor-extension-slice.md)
and [native-bus specification](../../design/intel_80286/spec/native_bus_interface.md).
The source result is also in [issue comment 6471416319](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6471416319).

## Reachable CPL3 selector-query and table-bound coverage — 2026-10-28 14:12 UTC

The CPL3 regression now has 160 passing query runs across both READY modes. It
covers conforming code; all seven system/gate types; a P=0 writable data
descriptor; null GDT selectors; and GDT/LDT descriptors beyond their limits.
The P=0 descriptor remains queryable. Null/over-limit selectors clear ZF
without descriptor reads; memory-source cases verify the selector operand is
still read. The strict runner build and complete `--selector-exec` slice pass.
This is testbench-only; RTL needed no correction. Broader privilege/fault cases
remain open. See the
[verification report](../../design/intel_80286/report/2026-10-28-selector-query-cpl3.md).
The [GitHub issue checkpoint](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6471331193) records
the latest result and unchanged project fields.

The separately running whole-core PDR remains on the earlier 21-file snapshot
`work/release_lock_checkpoint_20261028_0720/formal_runs/current_pdr_20261028_0926`.
At 14:18:30 UTC it had reached frame 61 with 321/411 outputs proven and 61
timeout retries. It predates current source and is not evidence for this
testbench update; no formal job was started for this test-only change. See
[issue comment 6471459873](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6471459873).

## Source and plan audit — 2026-10-28 13:31 UTC

Playwright CLI inspection of Intel's scanned LOADALL memo confirms that page
14 explicitly directs the exception handler to update SI after SCAS, with the
index delta determined by DF and operand size. For REP SCAS it says to add two
to CX. The ordinary SCAS entry in Intel's Programmer's Reference Manual names
ES:DI and DI advancement. Page 13 of the LOADALL PDF is unrelated implementation
notes; the earlier page-13 citation was wrong and is corrected in
`spec/protected_mode_integration.md`.

The local capture/archive search found no SCAS fault trace; its SCAS hits were
opcode constants and BIOS disassembly. The source disagreement is therefore
still open: page 14 is verified, but no independent 80286 evidence explains
whether SI is intentional or a source error. No RTL change was made. Keep
protected SCAS fault repair release-blocking and require an independent 286
trace or another primary, source-backed explanation before implementing its
handler repair. A cross-check against the completed IOPL slice found the
revised plan still described IOPL enforcement as open. Corrected that stale
statement: protected direct/string IOPL enforcement is implemented; the
combined 480-scenario privilege regression includes 288 dedicated IOPL/IF
cases covering the direct CPL/IOPL matrix, bounded REP INS/OUTS, flag controls
and both READY policies. Physical port-side-effect ordering remains open. See
the [source audit](../../design/intel_80286/report/2026-10-28-scas-restart-source-audit.md)
and [IOPL report](../../design/intel_80286/report/2026-10-27-iopl-controls.md).
The inspected Intel manuals do not provide the complete byte-by-byte
reserved-port command sequence for successful ESC forms. Obtain a primary
interface source or independent pin trace before generating those
transactions.

## 80287 active-high BUSY correction — 2026-10-28 13:17 UTC

Playwright CLI inspection of Intel 210760-002, 80286 Hardware Reference
Manual, Chapter 6 (printed pages 6-2–6-6; PDF pages 212–216), establishes
that the physical 80287 BUSY output is active high and wired directly to the
CPU. The core and native wrapper were corrected from active-low BUSY to
active-high busy_i; active-low ERROR# remains unchanged. WAIT and ESC stall
while BUSY is asserted, then deliver #MF only after BUSY falls. ESC's EM/TS
#NM gate precedes the BUSY wait. Corrected focused simulation passes. The
corrected full run_sim.sh passes with all 79 protected-mode replay cases.
Current-source Yosys 0.69 synthesis passed all 12 targets with 36
zero-problem checks, no `ERROR:` lines and 12 JSON netlists.

The same chapter specifies ESC reserved-port operations that bypass I/O
privilege checks and require zero wait states, plus the processor-extension
data-channel setup and arbitration contract. PEREQ is active high, PEACK# is
active low, and an operand transfer uses one I/O operation and one or two
memory operations. Normal ESC command and data transfers remain unimplemented.

The earlier 21-file whole-core PDR remains stale for this slice and native
wrapper. At 13:16:02 UTC it reached frame 23 with 316/411 outputs proved and
27 timeouts in the current pass, without a counterexample or terminal result.
The aggregate formal audit, depth-12 induction UNKNOWN and full release gate
remain open. See the
[80287 slice report](../../design/intel_80286/report/2026-10-28-80287-processor-extension-slice.md)
and [latest issue checkpoint](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6470033599).

## Earlier 80287 checkpoint — superseded BUSY polarity

The 12:36 and 12:14 checkpoints described BUSY as active low. Intel 210760-002
Chapter 6 resolves the polarity: BUSY is active high. Their implementation
status is historical; the corrected behavior and current evidence are above.

## Native reset source correction — 2026-10-28 11:52 UTC

The connected CPU test now holds native active-high RESET for 16 complete
processor clocks, checks the CPU bus and 82288 outputs stay inactive throughout
the modeled reset edges, and asserts the first instruction-fetch status
address is physical `FFFFF0h`. Focused `run_native_cpu.sh` passes under
Verilator 5.052. The full `run_sim.sh` also passes, including all 79
protected-mode replay cases; its manifest is under
`design/intel_80286/work/reset_source_full_sim_20261028/`. Intel 210760-002
Chapter 3 printed pages 3-41–3-43 document the 82C284 `RES` power-up hold and
PCLK synchronization, but conflict on single-CPU RESET edge synchronization:
page 3-41 says high-to-low must synchronize, while pages 3-42–3-43 say the
rising edge is delayed one or two clocks and the falling edge may be
asynchronous. The fixed 38-external-CLK delay is also unsupported by these
pages. The wrapper remains a conditioned-RESET model pending an independent
82C284 source. Details are in the
[reset audit](../../design/intel_80286/report/2026-10-28-reset-source-audit.md).
The analog 82C284 and board clock model remain open.

The whole-core PDR remains active at frame 60 with 286/411 assertion outputs
proved and 89 timeout retries; no counterexample or terminal result is
reported. The aggregate release gate remains open. Issue #80 remains
Open/Building with Agent Codex.

# Intel 80286 continuation status

## 82288 local controller and connected CPU — 2026-10-28 11:24 UTC

The source-backed non-MULTIBUS local profile is now implemented in
`design/intel_80286/src/intel_80286_82288.sv` and connected to
`intel_80286_native_cpu`. The wrapper accepts a processor-rate `clk_i` and a
separate external 2x `clk_2x_i`; clock division and phase generation remain a
board/system responsibility. The controller emits ALE, DEN, DT/R, active-low
memory/I/O/INTA strobes and MCE. Its directed test passes status decode,
READY waits, CENL/CEN/CMDLY, write-DEN preparation, direct back-to-back cycles,
halt suppression and the MCE-over-ALE interval. The connected native-CPU
regression also passes and observes every exercised command output. Verilator
5.052 strict `-Wall` lint passes. The full `run_sim.sh` passes with 142 PASS
lines, including the connected controller and all 79 protected-mode replay
cases; its manifest is under `design/intel_80286/work/controller_sim_20261028/`.
The complete Yosys 0.69 `run_synth.sh` exits 0 across 12 targets: every target
reports zero problems in `check -assert`, no log has an `ERROR:`, and all 12
JSON netlists were emitted. The integrated native CPU wrapper has 50,824
generic cells including three submodules; the standalone 82288 model has 71.
Logs and netlists are under
`design/intel_80286/work/controller_82288_20261028/`. See the
[82288 report](../../design/intel_80286/report/2026-10-28-82288-local-controller.md)
and [native-bus contract](../../design/intel_80286/spec/native_bus_interface.md).

The exact 21-file whole-core PDR snapshot remains active and does not include
the native wrapper. At 11:24:22 UTC its ABC engine log reached frame 24 with
280/411 assertion outputs proved and 52 timeout retries; output 147/property
line 189 was already proved in frame 14. No new output was proved in the
latest pass, and there is no counterexample or terminal result. The standalone
depth-12 induction result and stale 36/40 aggregate audit remain unresolved,
so the full `run_all.sh` release gate stays open. MB=1, clock/reset generation,
the 80287 interface, an independent CPGREP-on-RTL trace, the broader
completion ledger and physical qualification also remain open. Issue #80
remains Open/Building with Agent Codex.

## 82288 source resolution and live PDR — 2026-10-28 10:48 UTC

Playwright CLI was used to inspect Intel's original scanned HMOS M82288
datasheet. It defines CENL as active high, latched at the start of each bus
cycle and sampled high at the end of `Ts` to select the controller. Sampled
low suppresses commands and DEN. This resolves the conflicting sentence in
Intel 210760-002; the later compatible M82C288 datasheet corroborates the
polarity. The functional local-bus profile is now source-backed, including
the CEN, CMDLY and READY behavior. The system-clock/processor-clock boundary
is still open. Details are in the
[source reconciliation report](../../design/intel_80286/report/2026-10-28-82288-cenl-source-conflict.md)
and [native-bus contract](../../design/intel_80286/spec/native_bus_interface.md).

The whole-core current-source PDR run remains active with the exact 21-file
snapshot. The latest engine log is at frame 6 of its new anytime pass, with
276/411 assertion outputs proved; no counterexample or terminal result is
reported. Assertion output 147 (property line 189) was already proved in
frame 14. No environment assumptions were added. The stale aggregate audit
and `run_all.sh` release gate remain open. Issue #80 remains Open/Building.

## Current-source whole-core PDR, OS/2 replay and 82288 source audit — 2026-10-28 10:37 UTC

A separate `intel_80286_pdr.sby` run uses an exact current-source snapshot in
`design/intel_80286/work/release_lock_checkpoint_20261028_0720/formal_runs/current_pdr_20261028_0926/`.
All 21 copied RTL/property files match the worktree; the top property file
hash is `A86878199D5B1CE79CD92F2C2987723F13E430A12FA9312F1616E8E503006BA2`.
Yosys translation completed in 299.26 seconds. The latest log entry at
10:37:23 UTC shows ABC PDR at frame 33 with 273 of 411 assertion outputs proved
and 133 timeout retries in the current anytime pass. The current-source
whole-core PDR proved the assertion at `formal/intel_80286_props.sv:189` as
output 147 in frame 14; the separate depth-12 induction result at that line
remains UNKNOWN. No reachable counterexample or terminal PASS/FAIL has been
reported, and no environment assumptions were added. A Playwright CLI rerun reached retail
OS/2 1.0's command prompt and reproduced `CPGREP -yn fast ..\README`, returning
the expected line 11 with `FAST`. The captured instruction history still
contains only the shell wait loop, so this remains emulator-only software
evidence, not a CPGREP trace or RTL execution. This follow-up does not close
the stale aggregate formal audit or the full `run_all.sh` gate. Intel's
210760-002 Hardware Reference Manual contains contradictory statements about
82288 `CENL`; the Intel M82C288 datasheet calls it active high and is the
current functional polarity reference. At this checkpoint the original HMOS
datasheet had not yet been inspected; the following 10:48 update resolves the
polarity conflict. See the
[formal report](../../design/intel_80286/report/2026-10-28-formal-induction-gap.md),
[82288 source reconciliation](../../design/intel_80286/report/2026-10-28-82288-cenl-source-conflict.md),
and [formal correction 6466581278](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6466581278).

## Independent release stages — 2026-10-28 09:20 UTC

After the aggregate stopped at CPU formal prove, the remaining stages were run
separately against the current LOCK-connected RTL in
`design/intel_80286/work/release_lock_checkpoint_20261028_0720/`:

- `run_sim.sh`: 141 PASS lines, including the 79-case protected-mode replay.
  The source/tool manifest is
  `protected_mode_continuation_20261028T0847Z/build_manifest.json`.
- Independent vectors: 99,650 Unicorn cases and 1,715,162 exact instruction
  states passed. Hardware replay: 68,510 physical Harris-286 captures in both
  READY modes, 52 #GP protection captures in both modes, plus all oracle
  corruption checks.
- Mutation suites detected 4 undefined-opcode, 4 protection, 6 event and 15
  protected-string faults. The run exposed stale mutation patterns for the
  #UD event call and protected-fault event calls; both harnesses were updated
  to match the current event packet API, then all mutations passed.
- IBM AT software regressions passed using the pinned original BIOS: ROM
  checksum/entry checks, 196,846 exact instruction states, IRQ timer, and
  system-register tests.
- Yosys 0.69 passed all 11 targets. Every log ended normally, had three
  `check -assert` runs with zero problems and no `ERROR:`; all 11 JSON netlists
  were written.

The formal audit of the earlier aggregate snapshot is 36/40. Component
BMC/prove/cover tasks pass. Core BMC and prove fail current-source audit because
their copied property is stale; current core prove also returned UNKNOWN on an
induction-only state. Core cover was not reached and PDR did not start. This
audit does not change the aggregate status: `run_all.sh` has not been rerun
after the property updates and no full release pass is claimed. The standalone
current-property depth-12 run passes its base case and remains UNKNOWN at the
task-switch/PE invariant. See the
[formal report](../../design/intel_80286/report/2026-10-28-formal-induction-gap.md)
and [issue checkpoint 6465245755](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6465245755).

## Formal induction checkpoint — 2026-10-28 08:42 UTC

The isolated `run_all.sh` attempt in
`design/intel_80286/work/release_lock_checkpoint_20261028_0720/` stopped with
exit code 4 at connected-core depth-12 `prove`. Component BMC/prove/cover tasks
passed. The connected-core depth-24 BMC passed with no output asserted and no
counterexample; this is bounded evidence only. The core RTL inputs copied into
the prove task match current core sources; the native CPU wrapper is not part
of that formal target. Its engine log SHA-256 is
`19478725D2A951895A255E6751B0D4AEEC554C9A43CFB6278C328CE95CAE3248`.

The aggregate prove task used an older copied property file (SHA-256
`FEBE486C2A49558E438B1FFEA4DA32F02D04C4549B7DAD1AD1ED3694FF750FD0`) and
returned UNKNOWN on induction at line 812. After narrowing two assertion scopes,
a standalone proof using the current property file (SHA-256
`A86878199D5B1CE79CD92F2C2987723F13E430A12FA9312F1616E8E503006BA2`) passed
its depth-12 base case and returned UNKNOWN on induction at
`formal/intel_80286_props.sv:189`, which requires PE=1 while a code or segment
load waits. The induction-only trace starts in arbitrary `TASK_SEGMENT_START`
with PE=0 and reaches `SEGMENT_LOAD_WAIT`. It is not a reachable counterexample
established by the passing bounded run. The formal gap is a missing
task-switch-state/PE invariant; no RTL change has been made for this trace. The
induction trace SHA-256 is
`66084D61B7A3C66163A2DD6EB64992F0D95550C155EDE4573C4E15F2E4DDCE49`.
Logs and trace are retained under
`design/intel_80286/work/formal_runs/induction_reset_mask_20261028_0830/`.

The aggregate did not continue into bus-owner/native-bus/native-core tests,
simulation, vectors, hardware replay, mutations, software, synthesis or the
formal source audit, and it has not been rerun after the property-only edits.
The LOCK-connected `run_sim.sh` (141 PASS lines, including
79 protected replay cases) and all 11 Yosys synthesis targets passed before
this aggregate attempt, as recorded in the
[native LOCK report](../../design/intel_80286/report/2026-10-28-native-lock-integration.md).
The full release gate remains open. Issue #80 is Open/Building; see the
[checkpoint](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6464509177)
and [correction](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6464545239).

## Native CPU LOCK integration — 2026-10-28 07:13 UTC

The core now exports `bus_lock_o`, and `intel_80286_native_cpu` connects that
intent to the native bus controller. Explicit LOCK-prefixed memory MOV/MOVS/
INS/OUTS and rotate-memory forms are modeled alongside implicit memory XCHG.
The connected test verifies explicit MOV load/store, memory ROL, explicit and
implicit XCHG, and two iterations each of `REP LOCK MOVSB`, `REP LOCK INSB`
and `REP LOCK OUTSB`. It checks LOCK across memory and I/O READY waits,
operand gaps, HOLD exclusion, release afterward, and inactive LOCK during
instruction fetch. The focused
test and full `run_sim.sh` pass; the full suite records 141 PASS lines,
including all 79 protected-mode replay cases. The replay manifest is
`design/intel_80286/work/native-lock-candidate-20261028/protected_mode_lock_20261028T0708Z/build_manifest.json`.
Details and evidence are in the
[native LOCK integration report](../../design/intel_80286/report/2026-10-28-native-lock-integration.md).

Yosys 0.69 `run_synth.sh` completed all 11 targets. Each log ended normally,
reported zero problems in all three checks, and contains no `ERROR:`. The
integrated wrapper reports 50,003 generic cells; retained logs and JSON
netlists are under `design/intel_80286/work/native-lock-candidate-20261028/synth/`.
Issue #80 remains Open/Building with Agent Codex; Path, first Start date and
Sprint are unchanged. The verified checkpoint is recorded in
[issue comment 6463032004](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6463032004).

Automatic descriptor-table and processor-extension LOCK, external clock
division/reset timing, 82288 strobes, 80287 signaling, current-source
connected-core formal, CPGREP on RTL, an independent instruction trace and the
full `run_all.sh` release gate remain open.

## Integrated native CPU-pin bridge — 2026-10-28 06:21 UTC

`intel_80286_native_cpu` now connects the opt-in `NATIVE_BEATS=1` core to
`intel_80286_native_bus`. The bridge routes the physical READY handshake,
16-bit lane data, INTR/NMI and two-cycle INTA/vector exchange, and exposes
address, data, lanes, CPU status, LOCK#, HOLD/HLDA, halt/shutdown and fault
signals. Its input clock is already one processor clock.

Verilator 5.052 `run_sim.sh` passes with 141 PASS lines, including the default
CPU suite, standalone components, native-core and bus-owner tests, the
integrated pin test, and all 79 protected-mode replay cases. The focused pin
test checks even/odd word transfers, READY waits, HOLD/HLDA, INTA lock,
interrupt frame and exact IRET/HLT return. Yosys 0.69 `run_synth.sh` passes all
11 targets with `check -assert` reporting zero problems, including the
integrated wrapper (50,664 generic cells). Commands, hashes and retained logs
are in the [native CPU bridge report](../../design/intel_80286/report/2026-10-28-native-cpu-bridge.md).

The wrapper does not model the external clock divide or reset timing. Core
LOCK intent is not connected, so LOCK-prefix and automatic LOCK behavior
remain open; 82288 commands/ALE, 80287 signaling and physical qualification
are not implemented. The older connected-core cover ended with SBY
`ERROR`/rc=16 because Yices did not return a status; its 45/73 count is stale
after native-beat changes. The corrected depth-12 proof still has UNKNOWN
induction results, and no current-source connected-core proof covers this
RTL. The PCjs/OS/2 CPGREP run used `playwright-cli` and remains emulator-only,
without RTL execution or an instruction trace. The full `run_all.sh` release
gate remains open. Issue #80 remains Open/Building with Agent Codex, Path
`ai_hw_engineer/design/intel_80286`, first Start date `2026-10-23`, Sprint 1.
The [latest issue checkpoint](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6462275940)
records these results and remaining work.

## Standalone native-bus controller — 2026-10-28 05:09 UTC

Added `design/intel_80286/src/intel_80286_native_bus.sv`, a CPU-pin cycle
controller that accepts scheduled one/two-byte physical beats. Its directed
Verilator 5.052 regression passes memory/instruction/I/O status, byte lanes,
even-word beats, the two-cycle odd-word form, READY waits, HOLD/release, LOCK,
two-cycle INTA/vector capture and HALT/shutdown A1. Yosys 0.69 synthesis and
`check -assert` pass with zero problems (238 generic cells). Logs, netlist,
commands, hashes and limitations are in the [controller report](../../design/intel_80286/report/2026-10-28-native-bus-controller.md).

This controller is not connected to the CPU. The core still handshakes one
byte at a time, so the one/two-byte beat scheduler and 16-bit data path remain
the next integration task. External clock division/reset delay, automatic
core LOCK, the 80287 interface and the 82288 system component are also open.
The connected-core cover process is still active at 45/73 goals with no
terminal result; no full-chip or release-pass claim is made. The latest [issue
checkpoint](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6461200716)
records component evidence and integration gaps.

## Native bus implementation boundary — 2026-10-28 05:01 UTC

The native-bus RTL audit found a core-side prerequisite: the integrated bus
currently accepts one byte per `core_bus_ready`, `bus_size_o` is the complete
operation's byte count, and read/write data at that boundary is only eight
bits. The descriptor code-load and segment-load engines also transact one
byte at a time. A wrapper cannot emit an even-word 80286 cycle because it
cannot see the second write byte before the first handshake or return both
read lanes through the current response. Early-acknowledging and buffering
writes would move the commit point ahead of physical READY and weaken reset,
event and precise-restart behavior.

The [native bus contract](../../design/intel_80286/spec/native_bus_interface.md)
now requires a core-side one/two-byte beat interface with 16-bit lane data,
explicit completed-byte count, and physical READY as the commit boundary
before the pin adapter is built. This is a source-level architecture finding;
no native-bus RTL is claimed. The active connected-core cover remains at
45/73 goals with no terminal result. CPGREP is still emulator-only, and full
80286 acceptance remains open. The latest [issue checkpoint](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6461098792)
records the bus-boundary finding.

## Release evidence-root plumbing — 2026-10-28 04:56 UTC

`design/intel_80286/scripts/run_all.sh` now accepts `--work-dir DIR` or
`INTEL_80286_WORK_DIR`; without either, it creates a unique release directory
under `design/intel_80286/work/`. An explicitly selected directory must be
empty. The setting is used by the shell runners and Python build, vector,
hardware, software, mutation, replay and audit stages. Protected-mode mutation
snapshots override the setting to keep their private replay evidence inside
each snapshot. `audit_formal.py` and physical replay test defaults use the same
root resolver.

Checks passed: Bash syntax for every script, Python syntax for every script,
and the `test_work_paths.py` (3), `test_preflight.py` (6),
`test_audit_formal.py` (17) and `test_build_runner.py` (11) unit suites.
`run_all.sh --help` works, and an explicitly selected non-empty root is
rejected. The aggregate `run_all.sh` gate has not been run: the connected-core
cover process is still active at 45/73 goals, with Yices CPU-active and no
terminal result. No release-pass claim is made. Native-bus RTL, CPGREP-on-RTL,
and full 80286 acceptance remain open.

## Connected-core formal checkpoint — 2026-10-28 04:47 UTC

The pre-correction 21-file RTL/property snapshot passed the connected-core
depth-24 BMC (`abc bmc3`): no output asserted in 24 frames, with no
counterexample. It is bounded evidence only. The first depth-12 prove passed
its base case but failed temporal induction at `intel_80286_props.sv:526`.
The trace showed `state=SHUTDOWN`, `halt_latch=1`, and `shutdown_o=1`; the
ordinary HLT assertion had omitted the shutdown guard. I narrowed it to
non-shutdown halts, and formal preflight passes. The corrected prove's
depth-12 base case passes, but induction returns UNKNOWN on assertions at
lines 525 and 775. Its trace begins from unconstrained internal state; reset
reachability beyond the checked bound is unresolved. Source-to-log coverage
accounting finds 45/73 active goals reached: 38/52 top-level CPU-property
covers and 7/21 active component covers. The newest witness is
`intel_80286_muldiv_props.sv:38` at step 32 (`trace42`). The cover search
advanced to step 33 and reached a 1-hour wait marker without another
witness. The earlier `44/52` tally mixed component hits with the
core-only denominator and is superseded. Yices remains active without failure
or terminal result. The run is in
`design/intel_80286/work/formal_runs/core_20261027_04/`. A SHA-256 comparison
confirms all 21 copied run inputs (14 RTL and 7 property files) match current
sources. Since the property changed, rerun BMC and aggregate exact-source audit
on this corrected snapshot. PDR remains open.

The independent SDK 1.00 `CPGREP.EXE` baseline and source/platform audit are
in the [replay report](../../design/intel_80286/report/2026-10-27-os2-cpgrep-pcjs-replay.md).
The [native local-bus contract](../../design/intel_80286/spec/native_bus_interface.md)
is source-backed but not implemented. The current RTL remains a byte-transaction
core; instruction tracing, CPGREP-on-RTL, native-bus RTL/protocol verification,
the broader #DF matrix and full release acceptance are open. Issue #80 remains
Open/Building with Agent Codex and Path `ai_hw_engineer/design/intel_80286`.
The latest [coverage checkpoint](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6460910153)
records the reached covers and unresolved proof limit.

## Native bus contract and CPGREP baseline — 2026-10-27 15:02 UTC

The independent SDK 1.00 `CPGREP.EXE` baseline passes in local PCjs/OS/2 1.0;
the exact command, input/media hashes and screenshot are in the
[replay report](../../design/intel_80286/report/2026-10-27-os2-cpgrep-pcjs-replay.md).
Source review documents the default thread/semaphore and OS/2 API requirements.
An independent instruction trace and RTL run remain open.

The new [native local-bus contract](../../design/intel_80286/spec/native_bus_interface.md)
is based on Intel 210760-002. It defines the CPU-pin layer and keeps 82288-
generated ALE and command strobes in the system interface. It is specification
only: the implemented top is still a byte-transaction scheduler. Bus RTL,
pin-level verification and the broader #DF matrix remain open.

At this checkpoint, the connected-core depth-24 BMC was still live at frame 22.

## OS/2 CPGREP baseline and RTL path audit — 2026-10-27 14:57 UTC

The unchanged SDK 1.00 `CPGREP.EXE` now runs from its Samples floppy in a local
PCjs v2.26 IBM PC AT configured with an 80286 at 8 MHz and 2 MB RAM. The
Microsoft OS/2 1.0 install disk boots to its setup screen; Esc returns to the
OS/2 command prompt. From `B:\APPS\CPGREP`,
`CPGREP -yn fast ..\README` returns line 11, containing uppercase `FAST`.
The executable, input and disk hashes, machine setup, screenshot and limits
are in the
[replay report](../../design/intel_80286/report/2026-10-27-os2-cpgrep-pcjs-replay.md).

This closes the independent software-baseline step only. The run used retail
Microsoft OS/2 1.0 rather than the pre-release OS/2 kernel from SDK 1.00; no
instruction trace was captured and CPGREP has not run on the RTL. The source
audit shows default `-yn` initializes four semaphores, creates two worker
threads, and uses OS/2 file and console APIs. `-S` selects synchronous I/O and
skips those threads, but still needs the protected executable loader and OS/2
APIs; it is a debug reduction, not acceptance. The RTL top remains a
byte-transaction scheduler without the native 16-bit data bus, BHE/status,
ALE or T-state interface. Define both the platform path and native-bus scope
before attempting the same binary/input on RTL. The source audit, source hash
and dependency details are in the
[replay report](../../design/intel_80286/report/2026-10-27-os2-cpgrep-pcjs-replay.md).
Keep the earlier BIOS 1782 hard-disk failure in the media report as historical
evidence.

The current-source connected-core depth-24 BMC is still running. Its latest
log entry at 14:54 UTC reached frame 22 without a terminal result. See
`design/intel_80286/work/formal_runs/shutdown_bus_core_20261027_01/intel_80286_bmc/logfile.txt`;
whole-core prove, cover, PDR, aggregate audit,
native bus pins, the broader #DF matrix and full release acceptance remain
open. Issue #80 remains Open/Building with Agent Codex and Path
`ai_hw_engineer/design/intel_80286`. Latest checkpoint:
[GitHub comment 6445145179](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6445145179).

## HALT/shutdown bus indications and task-switch reset cuts — 2026-10-27 14:11 UTC

The byte-transaction interface now exposes separate `bus_halt_cycle_o` and
`bus_shutdown_cycle_o` signals. They are mutually exclusive, stay asserted
with READY low, and issue no byte request. Raw 80286 status, A1 and ALE pins
remain outside this abstraction. Shutdown still ignores INTR and clears only
after a valid NMI event commit or RESET.

The focused `--iopl-controls` suite passes all 480 privilege scenarios,
234 reset cuts after every accepted data transfer during nested #DF task-gate
entry (117 per READY policy), and 180 such cuts during task IRET (90 per
policy). Each cut checks RESET cleanup and executes the exact reset-vector
HLT. The full default bootstrap passes. Strict Verilator 5.052 `-Wall` lint,
release preflight and Yosys 0.69 synthesis pass on the unchanged RTL/property
snapshot. Synthesis `check -assert` reports zero problems; the design contains
49,771 cells across 11 submodules. Core properties have 309 assertions, one
assumption and 52 covers. Detailed hashes and logs are in the
[bus-cycle report](../../design/intel_80286/report/2026-10-27-shutdown-bus-cycles.md).

The earlier pre-bus core BMC was stopped at frame 17 without a terminal
result. A fresh depth-24 current-source BMC is running in
`design/intel_80286/work/formal_runs/shutdown_bus_core_20261027_01/`; its last
recorded progress is frame 12, with no terminal result. No connected-core
formal task has passed. Prove, cover, PDR and aggregate exact-source audit
remain open. Raw pin-level bus timing, the broader #DF matrix, OS/2 CPGREP,
broad ISA coverage and full release acceptance remain open. Issue #80 remains Open/Building with Agent Codex, Path
`ai_hw_engineer/design/intel_80286`, Start date `2026-10-23`, Sprint 1.
Checkpoint: [GitHub issue comment 6444263447](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6444263447).

## Escalate qualifying first-handler gate faults — 2026-10-27 13:10 UTC

An invalid IDT gate encountered while invoking restartable protected #DE,
#TS, #NP, #SS or #GP now escalates to vector 8 with a null error code and the
original saved context. A DIV-by-zero regression faults while reading the
vector-0 gate, then verifies the vector-8 gate read and shutdown on its
invalid descriptor. Both READY modes pass, as do the shutdown categories,
successful #DF task entry/IRET and the full default bootstrap.

Strict Verilator 5.052 `-Wall` lint and release preflight pass. The fresh
runner, focused suite, full bootstrap, exact hashes and remaining limits are
recorded in the [double-fault report](../../design/intel_80286/report/2026-10-27-double-fault-shutdown.md)
and `design/intel_80286/work/shutdown_20261027_05/`. No current-source
connected-core proof covers this update.

Next: derive and test the rest of the 286 first/second-fault matrix, cover
additional failures during task-gate delivery, implement NMI wake and the
external shutdown HALT cycle, then add task-switch reset cuts and current
connected-core proofs. Issue #80 remains Open/Building with Agent Codex. Read
back the [latest checkpoint comment](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6442740201).

## Protected #DF shutdown — 2026-10-27 13:04 UTC

Protected #DF delivery now enters sticky shutdown on a vector-8 IDT-limit
failure, invalid gate, invalid target-TSS admission or invalid incoming task
LDTR/segment/code state. Immediate and stalled READY tests cover invalid gate,
vector-8 IDT bounds, not-present target TSS and invalid incoming LDTR. They
check no fault packet replacement, no retirement or bus request, correct
task-switch side effects and RESET recovery. Valid #DF task entry/IRET remains
passing.

Verilator 5.052 strict `-Wall` lint, release preflight, a fresh runner,
`--iopl-controls` and full default bootstrap pass. Logs and exact hashes are in
the [shutdown report](../../design/intel_80286/report/2026-10-27-double-fault-shutdown.md)
and `design/intel_80286/work/shutdown_20261027_04/`. The property inventory is
302 assertions, one assumption and 50 covers. No current-source connected-core
proof covers this update; the `_21` cover/PDR jobs are older snapshots.

Remaining: broader 286 #DF generation and delivery-phase coverage, NMI exit
from shutdown, the external shutdown HALT bus cycle, task-switch reset cuts,
current-source connected-core proofs and full-chip acceptance. Issue #80
remains Building with Agent Codex, Path `ai_hw_engineer/design/intel_80286`,
Start date `2026-10-23` and Sprint 1. GitHub checkpoint:
[comment 6442632822](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6442632822).

## Valid non-null LDTR task entry — 2026-10-27 12:50 UTC

The validated incoming GDT LDT descriptor now fills a staged LDTR cache that
code and segment checks can use while `task_switch_active` is set. The base,
limit and valid bit publish with the incoming segment caches at task-entry
commit. A directed task resolves CS/SS/DS/ES from a four-entry LDT, verifies
all 32 descriptor-byte reads, the four accessed-byte writes, visible selector
values and exact instruction fetches, then reaches HLT. Both READY modes pass.

Verilator 5.052 strict `-Wall` lint, fresh build, focused `--iopl-controls`,
full default bootstrap and release preflight pass. Evidence and logs are in
the [non-null LDT task report](../../design/intel_80286/report/2026-10-27-non-null-ldt-task-entry.md)
and `design/intel_80286/work/task_gate_nonnull_ldt_20261027_01/`.
RTL SHA-256:
`37524595378713bb32b55ca62ac850d593ffe33f25ef23c10842a57d787e7135`;
testbench SHA-256:
`088ecc35e5572cda57b819ab8ce086d3bc15a3c7ce007a367d5dd19c142b0c4d`.

Broader nested-fault escalation, task-switch reset cuts, shutdown and
current-source connected-core proof remain open. The older `_21` cover/PDR
jobs remain on earlier snapshots. Project #80 remains Open/Building with Agent
Codex, Start date `2026-10-23`, Path `ai_hw_engineer/design/intel_80286`, and
Sprint 1. The issue checkpoint is [comment 6442330360](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6442330360).

## No-error task-gate entry and null selectors — 2026-10-27 12:45 UTC

Successful software task-gate entry now completes and fetches the incoming
task's first instructions. The fix suppresses an event-bus re-claim on a cycle
where task-entry completion is releasing event ownership while the CPU already
owns the bus. The eight-case matrix varies null LDTR, DS and ES selector RPL
values 0–3 under immediate and stalled READY, checking visible values through
`SLDT`/`MOV`, no error push or null-descriptor GDT read, backlink/busy state,
and ordered fetches from `0030:0300` through `0030:0307` before HLT at `0030:0308`.

Verilator 5.052 strict `-Wall` lint, fresh build, focused `--iopl-controls`,
full default bootstrap and release preflight pass. Evidence and hashes are in
the [no-error task-gate report](../../design/intel_80286/report/2026-10-27-task-gate-noerror.md)
and logs under `design/intel_80286/work/task_gate_noerror_20261027_01/`.
RTL SHA-256:
`61a8c78f38bb0712dc2d4586c1f0208d487e0e1f907fe08b84223d82630f46d9`;
testbench SHA-256:
`8dc63676e8191abecd382b8dd43c97c57fa530d73660615dcfab5962a026f8bc`.

Intel's 1984 information sheet documents an earlier-stepping erratum that
clears null DS/ES selectors to zero; those stepping errata are not selected by
this target profile. Non-null LDTR task lookups, nested-fault escalation,
broader double-fault classification, shutdown, task-switch reset cuts and
current-source connected-core proof remain open. The older `_21` cover/PDR
jobs remain on earlier snapshots; no current-source connected-core proof
covers this change. Issue #80 remains Open/Building with Agent Codex, Start
date `2026-10-23`, Path `ai_hw_engineer/design/intel_80286`, and Sprint 1.
The issue checkpoint is [comment 6442211666](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6442211666).

## Incoming CS/SS/DS/ES task-switch faults — 2026-10-27 12:28 UTC

Incoming task entry now checks CS, then SS, DS and ES after LDTR validation,
using the Intel 286 Table 8-1 vectors and selector error codes. It publishes
the transferred task state before routing a failing descriptor through its
exception task gate. Eighteen invalid selector/type/presence/privilege cases
plus three pairwise priority cases pass under both READY modes (42 runs).
The tests check exception packets, all 15 saved TSS words, backlink/busy bits,
and the pushed error word.

The five incoming-LDTR fault cases were rerun in both READY modes after
correcting the out-of-GDT selector from 0080 (in-bounds under limit 0187) to
0188. Strict Verilator 5.052 -Wall lint, release preflight, fresh runner build,
focused --iopl-controls and full default bootstrap pass. Logs and hashes are in
the [incoming segment report](../../design/intel_80286/report/2026-10-27-incoming-segment-faults.md)
and [issue checkpoint](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6441881555).
RTL SHA-256:
17362192f52c23fc28e03720c7531746f918d76f5645f63c5b06a5892a88b2fe;
segment-check SHA-256:
53cef7c2a800b9c6d5ece1223e0ed7d0c18a67b607d918815465eaca0c998777;
testbench SHA-256:
b4cea12a5b65fcb108a9de7e31d713cc548a995c25884d98763a41dbf8e0277e.

Valid non-null LDTR task execution still lacks an LDT cache path. No-error
task-gate completion, null-selector RPL variants, additional nested-fault
paths, task-switch reset cuts, current-source connected-core properties,
shutdown and full-chip acceptance remain open. The older _21 cover/PDR jobs
remain active on earlier source/property snapshots; no current-source proof
covers this change.

## Incoming-LDTR task-switch faults — 2026-10-27 12:06 UTC

Task entry now checks a non-null incoming LDTR against the GDT after loading
the incoming TSS image. TI, GDT-limit, wrong-type and not-present failures
raise #TS with the selector error code. The core publishes the transferred
task's registers, selectors, FLAGS and TR before delivery, allowing a second
task gate to save all 15 incoming TSS words and push the selector error. Five
fault cases pass in both READY modes, including an RPL-set selector proving
that the error code clears RPL. The focused suite, full default bootstrap,
strict Verilator 5.052 `-Wall` build and release preflight pass. Logs and runner
are in `design/intel_80286/work/task_ldtr_fault_build/`.

RTL SHA-256 is
`f897772d10e89a3c861a4dbc5fa6cd48c173e5c018065fb055945f35a1147c65`; testbench
SHA-256 is
`ac0aaaabea11b5b33750d9900effb2e44362df821c976f139ad3e0b79837f0af`; runner
SHA-256 is
`2f2ce1f26c5ed262c2ba40018d87cd7c0fbec950acea8e8c7a5d096ba60ca5ba`.
See the [incoming-LDTR report](../../design/intel_80286/report/2026-10-27-incoming-ldtr-faults.md)
and [issue checkpoint](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6441542853).

Follow-up correction: this section's GDT-limit test originally used selector
0080, which is in-bounds under the fixture's 0187 GDT limit. The fixture now
uses 0188, and both READY cases pass in the current incoming-segment report.

Valid non-null LDT task entry still needs the segment/cache lookup path;
task-switch reset cuts, connected-core properties, nested-fault completion
and full-chip acceptance remain open. An
exploratory no-error software task-gate case using LDTR `0003` reached
`0030:0300` but did not fetch the HLT. Null-selector RPL variants and that
no-error completion path need a separate directed investigation. The older
`_21` core cover/PDR jobs remain active on earlier source/property snapshots;
no current-source connected-core result covers this checkpoint.

## Invalid task-return backlink faults — 2026-10-27 11:44 UTC

IRET with NT set now delivers pre-switch backlink admission failures as
restartable protected faults in the current task. Null, LDT, out-of-GDT,
wrong-type and undersized TSS selectors raise #TS(selector); a not-present
backlink TSS raises #NP(selector); and an available rather than busy TSS
raises #GP(selector). Selector error codes have RPL bits cleared. These paths
leave the current task's TSS image and busy bit unchanged before fault
delivery.

The new `--iopl-controls` matrix enters a valid task through a task gate,
corrupts the backlink only after entry, then verifies the exact #TS/#NP/#GP
packet, same-task handler landing and no state-save/busy-clear writes. Seven
failure classes pass under immediate and stalled READY (14 cases total). The
valid backlink return/re-entry test remains passing. Strict Verilator 5.052
`-Wall` lint, `scripts/preflight.py`, the focused suite and the full default
bootstrap pass. Logs and runner are in
`design/intel_80286/work/task_return_fault_build/`.

RTL SHA-256 is
`181bc652c484d183ade6d650d588c5e1b3c2b7918e5334f092c7451d2e1339aa`; testbench
SHA-256 is
`5aecc413c2fe34ddba64b12af68e8d7e0781087a4f859d461317a166a2aae391`; the
unchanged connected-core property SHA-256 is
`d650dd7231a11b85b7737a9295afe0161a2cf87c235ae90fff6915f2688b28cb`, and the
fresh runner SHA-256 is
`c48c4edded9b78b8f9567748ffb4d59888831dab22663d1fefe1b5fd161dee94`.
Older `_21` cover/PDR processes remain active on earlier source/property
snapshots. No current-source connected-core proof covers this change, and no
overlapping proof was started.

Incoming-LDTR post-transfer #TS delivery is implemented in the newer checkpoint
above. The next gate is 286-accurate fault delivery for invalid incoming
SS/CS/DS/ES, followed by nested-fault escalation, reset cuts, task-switch
properties, shutdown and full-chip acceptance. See the
[task-return fault report](../../design/intel_80286/report/2026-10-27-task-return-faults.md),
[revised plan](2026-10-26-audit-and-revised-plan.md), and
[issue checkpoint](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6441100122).

## Nested-task IRET through the backlink — 2026-10-27 11:33 UTC

Implemented the successful protected IRET path when NT is set. The core reads
the current TSS backlink, validates the backlink as a busy present GDT 286
TSS, saves the active task's dynamic image with the post-IRET IP and NT
cleared, clears its busy bit, loads the backlink task without nesting, and
atomically publishes its registers and segment caches. The test enters the #DF
task, executes IRET back to the interrupted CPL3 task, observes that task
fault again, re-enters the now-available handler TSS, and verifies the saved
handler successor lands exactly at `0030:0302`.

Strict Verilator 5.052 `-Wall` lint, `scripts/preflight.py`, focused
`--iopl-controls`, and full default bootstrap pass. Logs and the fresh runner
are in `design/intel_80286/work/task_iret_build/`. RTL SHA-256 is
`59093efc7fc8e54fa9f34f6466bc98a1b6c1ce511eebe7175d29cecd2dacca22`;
testbench SHA-256 is
`011945bedbd909cafc61e95182b767c63746fc878f8d25404fc6bfa915d49810`; formal
property SHA-256 remains
`d650dd7231a11b85b7737a9295afe0161a2cf87c235ae90fff6915f2688b28cb`; runner
SHA-256 is
`4a177535356da0ff615667f7c893ae55c191319c84abab5f17ce1e2ea55db95a`.

Only valid #DF entry/return with null LDTR is verified. Invalid backlink or
incoming-task descriptors and segment faults still stop diagnostically;
additional #DF causes, shutdown, reset cuts and task-switch properties remain
open. Older `_21` connected-core cover/PDR jobs remain active on earlier
snapshots (cover last waiting at step 35; PDR last reported 366 outputs at
11:33:15 UTC). No current-source core formal result exists, and no overlapping
run was started. Issue #80 remains Building with Agent Codex, Path
`ai_hw_engineer/design/intel_80286`, first Start date `2026-10-23`. Full 80286
acceptance remains open. See the
[task-IRET report](../../design/intel_80286/report/2026-10-27-task-iret.md),
[task-entry report](../../design/intel_80286/report/2026-10-27-task-gate-switch.md),
[revised plan](2026-10-26-audit-and-revised-plan.md), and
[issue checkpoint](https://github.com/hevangel/ai_hw_engineer/issues/80).

## Historical #DF task-gate switch before task IRET — 2026-10-27 11:24 UTC

Implemented a bounded successful nested task switch for the protected #DF
task gate. After validating the gate and present available GDT TSS, the core
sets the target busy bit, writes the outgoing TR selector to the backlink,
saves the outgoing dynamic TSS words, loads the incoming 15-word state image,
sets NT and TS, validates a null LDTR plus SS/CS/DS/ES, pushes the #DF error
word on the incoming stack, and atomically publishes the new task state. The
focused regression checks exact outgoing TSS words, incoming registers and
hidden segment caches, busy/backlink/TS/NT, zero error push, and the handler's
exact HLT landing in both READY modes.

Strict Verilator 5.052 `-Wall` lint, `scripts/preflight.py`, the focused
`--iopl-controls` suite, and the full default bootstrap pass. Logs and fresh
binary are in
`design/intel_80286/work/task_gate_switch_build/`; the build used a fresh
ignored directory and preserved the older cached artifacts. RTL SHA-256 is
`effc3001a1ababb405e1f76653afb9076b950551a23351398c165296e143f9c3`;
testbench SHA-256 is
`2fc4b8feb5c3e2356845a4d82d3c92b09a07e45b699438fa2e9c405236677bc7`; CPU
property SHA-256 remains
`d650dd7231a11b85b7737a9295afe0161a2cf87c235ae90fff6915f2688b28cb`; runner
SHA-256 is
`7b4785d58e4b2340fcd96f5d994619807cf23210154c0e1a11bd6f1c9c640843`.

This verifies only the successful #DF task-entry slice. Invalid TSS and
incoming segment fault priority/escalation, non-null LDTR loading, task IRET
through the backlink, shutdown, broader vectors and reset cuts remain open.
The older `_21` connected-core cover/PDR jobs are still active on prior source
snapshots: cover last logged waiting at step 35 at 11:12:25 UTC; PDR last
logged 366 outputs proved at 11:22:28 UTC. No connected-core formal result
covers this RTL; wait for those jobs to terminate before starting another core
run. Issue #80 remains Building with Agent Codex, Path
`ai_hw_engineer/design/intel_80286`, first Start date `2026-10-23`. Full 80286
acceptance remains open. See the
[task-switch report](../../design/intel_80286/report/2026-10-27-task-gate-switch.md),
[revised plan](2026-10-26-audit-and-revised-plan.md), and
[issue checkpoint](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6440730446).

## Historical IDT task-gate preflight — 2026-10-27 11:10 UTC

This checkpoint verified only task-gate/TSS descriptor admission and no-write
behavior. It is superseded by the successful #DF task-entry slice above; its
source hashes and detailed record remain in the
[preflight report](../../design/intel_80286/report/2026-10-27-task-gate-preflight.md)
and [issue comment](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6440466589).

## Earlier nested protected #GP to #DF vector selection — 2026-10-27 11:00 UTC

Added one bounded double-fault selection case in `EVENT_START`: a CPL3 HLT
raises the first #GP, then the IDT limit makes lookup of that handler's vector
13 gate fault with #GP. The RTL converts this event to vector 8, sets the null
error code, and preserves the original saved CS:IP:FLAGS:SP. The fixture sets
an all-zero vector-8 descriptor; the current interrupt/trap-only gate
validator stops there. It does not implement task-gate entry, task switching,
#DF handler entry or shutdown. The test-first run failed before the RTL
change. Both immediate and stalled READY cases pass, as do the full default
bootstrap and release preflight.

Evidence: `design/intel_80286/report/2026-10-27-double-fault-escalation.md`;
logs and manifest:
`design/intel_80286/work/double_fault_classification_20261027_01/`. RTL
SHA-256 is
`2777eaea08bd5de2247a994d1468ab707f5d596d4e367915bb097c031af75d90`, testbench
SHA-256 is
`42a1726bd7dd589426934650f947788944b732c23c763f2540a222362eb8d137`, and the
runner fingerprint is
`50306e079cfaa8a48e8dd565ca9e092620e7aef3dbb5015f7d42333dc9f599d8`.

Added a connected-core assertion that this transition selects vector 8 with a
null error code and preserves saved CS:IP:FLAGS:SP:SS, plus a cover for the
transition. Preflight passes with 299 assertions, one assumption and 50
covers; property SHA-256 is
`d650dd7231a11b85b7737a9295afe0161a2cf87c235ae90fff6915f2688b28cb`. No
connected-core result covers the new property yet.

No connected-core formal result covers this RTL/property pair. The older `_21`
cover job remains waiting at step 35 (last log 10:42:24 UTC); PDR advanced to
frame 29 with 366 outputs proved and 28 timeouts (10:58:49 UTC). Both remain
active on prior-source snapshots; do not start overlapping formal work. See
the [issue checkpoint](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6440006292).

## CPL 1–3 LLDT/LTR privilege matrix — 2026-10-27 10:37 UTC

Expanded the reachable `--selector-exec` privilege regression from CPL3 to
CPL1, CPL2 and CPL3. The fixture uses matching DPL code/data/stack descriptors,
raises #GP through a same-level gate, repairs the saved IP and returns through
IRET. All 24 combinations pass: LLDT/LTR register and memory forms across
three CPLs and both READY policies. They check the exact frame and successor,
no retirement or memory operand read, no descriptor/TSS access, and unchanged
LDTR/TR. The other selector execution cases also pass.

The full default bootstrap and release preflight pass. Logs and manifest are
under `design/intel_80286/work/selector_privilege_cpl_20261027_01/`. The RTL is
unchanged at SHA-256
`12142e802f75351dc0a5eaff2e3094ee2b6d424d8f15d20b67505625f25406a4`; the
updated testbench SHA-256 is
`5448afc1e2fbaab2c7bfa8979bf079dbcd1c19587e0c2ff0cabbf9e9fe2dab0a`. The
Verilator 5.052 runner fingerprint is
`9dbaeac8b7ba50d432ddd9db9a3746151ab8720eea62e0ff754e023831b90ff1` and its
binary SHA-256 is
`8a38276cbda9199698d316ae4888e0dcd96c0feec80fce82f06ddf5adff0cee0`.

The `_21` connected-core cover and PDR jobs are still active on older
snapshots; the last progress remains cover waiting at step 35 and PDR frame 23
with 366 outputs proved and 27 timeouts. No current-source connected-core
formal result exists. Full protected-mode and chip acceptance remain open.
Issue checkpoint: [comment 6439781875](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6439781875).

## Protected system-instruction privilege — 2026-10-27 10:31 UTC

Added protected CPL-0 checks for LGDT, LIDT, LMSW and CLTS, retaining the
existing nonzero-CPL LLDT/LTR check. The check raises restartable #GP(0) before
a memory-form operand read. Intel 210498-005 §§10.2–10.3 is the architectural
source; the contract and scope limits are in
`design/intel_80286/spec/system_register_execution.md`.

The combined `--iopl-controls` regression passes 480 scenarios in immediate
and stalled READY modes. The new slice adds 120 nonzero-CPL denials (CPL 1–3,
all IOPL, five instruction forms) and 40 CPL-0 controls. It checks exact saved
state, no retirement or architectural update on denial, and no denied memory
read. The full default Verilator bootstrap and release preflight pass. Exact
hashes, build fingerprint and log paths are in
`design/intel_80286/report/2026-10-27-system-instruction-privilege.md`.

RTL SHA-256 is
`12142e802f75351dc0a5eaff2e3094ee2b6d424d8f15d20b67505625f25406a4`; runner
SHA-256 is
`adbbc12e3ab2b1216e4b7b38d1641243d54d256e15b595fc4fc2bfa30ea38993`; build
fingerprint is
`69bccb704a93683de2cb0b8b1696408d94c438b481ab5982c8b5d74c9b8bb8c0`.
Connected-core formal work has not evaluated this snapshot. The `_21` cover
job was waiting at step 35 at 10:27:23 UTC; PDR was at frame 23 with 366
outputs proved and 27 timeout retries at 10:30:25 UTC. Both jobs are on older
snapshots and remain active. Wait for termination before launching current
formal work. Full-chip acceptance remains open.

Issue checkpoint: [comment 6439651353](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6439651353).

## Protected IOPL and HLT controls — 2026-10-27 10:18 UTC

Implemented the scoped protected-mode IOPL and IF rules in
`design/intel_80286/spec/iopl_control.md`: `IN`, `OUT`, `INS`, `OUTS`, `CLI`
and `STI` fault with restartable `#GP(0)` when `CPL > IOPL`; protected
`POPF`/`IRET` load IOPL only at CPL 0 and load IF only when permitted. The
real-mode behavior remains unchanged. The source authority is Intel order
210498-005, §§3.11.1, 3.11.3, 4.1 and 10.1.

Also implemented the Intel §3.11 protected-HLT rule in
`design/intel_80286/spec/hlt_privilege.md`: protected HLT is permitted only at
CPL 0, independent of IOPL; other CPLs fault before halt or retirement.

The focused `--iopl-controls` regression passes 320 scenarios in both READY
modes: the 288 IOPL/IF checks documented below, plus 32 HLT cases covering all
CPL/IOPL pairs and READY modes. The HLT matrix verifies CPL 0 can halt at every
IOPL, and CPL 1–3 raise restartable `#GP(0)` at every IOPL. The full default
Verilator bootstrap passes; its log is
`design/intel_80286/work/iopl_controls_20261027/full_bootstrap.log`. Release
preflight passes. Verilator 5.052 runner fingerprint is
`b70b79df2eac78d675627c4e47bd6f354d9efdd8f862b853249cfdd75c63c991`.

Current RTL SHA-256 is
`2ca0d9a8f46e9b3774505593c0dcebb0a70ec6530e848c3fb0d39eccba55fec1`; the
bootstrap SHA-256 is
`a5950b687d035d4dad76ba2a5dae07d6d9c39c7ed9af0273700020eed3ce9fc9`.
Current properties remain at 298 assertions, one assumption and 49 covers;
their SHA-256 is
`85b8d6f497c927d084f21da29b10fa0be1ea8438242e2de735ee655e20056f53`.
No connected-core formal run has evaluated this RTL snapshot. The older `_21`
cover and PDR runs remain active on earlier source. At 10:17:23 UTC, cover
was waiting on the solver while checking step 35. At 10:16:28 UTC, PDR was at
frame 20 with 366 outputs proved and 27 timeout retries. Start current-source
formal only after those jobs terminate. The full connected-core, aggregate audit, task switching,
nested-fault escalation, independent historical software and release gate
remain open.

The full bootstrap also corrected a prior ring-3 recovery expectation: a
same-level CPL-3 interrupt gate clears IF, and IRET at CPL 3 with IOPL 0 must
leave that handler IF state unchanged. The saved exception-frame FLAGS remain
checked against the interrupted image.

The full bootstrap also replaced ring-3 HLT stop markers with NOPs, since HLT
is now correctly privileged at nonzero CPL. The existing ring-3 interrupt-gate
test confirms that IRET with CPL 3 and IOPL 0 leaves handler IF cleared while
the exception frame retains the interrupted FLAGS.

Latest issue checkpoint: [combined IOPL and HLT update](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6439265529).
Live project readback confirms issue #80 is Open/Building with Agent `Codex`,
Path `ai_hw_engineer/design/intel_80286`, and first Start date `2026-10-23`.
Preserve that first date and Path while work continues.

## Verification refresh — 2026-10-27

### Connected-core retry and outer RETF span fault — 2026-10-27 09:19 UTC

Run `_26` passed its depth-12 base case and returned `UNKNOWN` at induction on
the protected-return-owner assertion (line 86). The induction-only trace
starts with mutually inconsistent RET, IRET and event owners, then reaches
handler execution while the RET owner is still set. Trace inspection alone
does not establish a reset-reachable counterexample. RTL review did identify
a reachable cleanup gap: a failed protected outer-RETF stack-span precheck
entered normal exception delivery without clearing the abandoned RET owner
and outer-return preflight flags.

The generic memory-fault path now clears those RET ownership flags before
delivering the exception, including when unsupported event/IRET escalation
stops the core. A new case in `--call-gate-retf-faults` narrows ring-0 SS to
limit `00FB` after a real call gate has written its outer return frame. RETF
can read IP:CS at `00F8`–`00FB`, then raises exact restartable `#SS(0)` when its
span check reaches `00FC`–`00FF`. The regression checks the exception packet,
frame bytes, absence of access beyond the limit, handler SS repair, IRET retry
and exact ring-3 successor in both READY modes. The focused suite passes.
Release preflight passes. Verilator 5.052 runner build fingerprint is
`e2037a67cdc9c881a98063562c2c3dc996ec81e2b2288a949c1501cfc4747cca`.

Current RTL SHA-256 is
`ffa9248d1866ecea38b2357f265028821a79768349e2ba86b7f0ac036ba6642b`.
Current CPU properties contain 298 source assertion statements, one
assumption and 49 covers; SHA-256
`edbef28f43c79e09a09035ea7d40a8b76e18d95c58adf2d17a6051e35b96ee36`.
Connected-core prove `_27` copied this RTL/property snapshot at 09:19:25 UTC.
Its depth-12 base case passed, then induction returned UNKNOWN at line 86 on a
non-inductive owner/opcode assertion; details follow below. Evidence is under
`design/intel_80286/work/formal_runs/protected_event_outer_20261027_27/core/intel_80286_prove/`.

Earlier `_21`–`_26` connected-core results use different RTL or property
snapshots and do not close this 298-assertion set. The 36 `_21` component
passes remain separate evidence. Current-property BMC, complete prove, cover,
PDR and exact-source aggregate audit remain open. Nested-fault escalation is
unsupported. Next, close `_28`, then run current-property BMC, cover, PDR and
aggregate audit before proceeding to task gates, task switching and the full
documented fault matrix.

### Formal invariant refinement and retry — 2026-10-27 09:27 UTC

Run `_27` matched the RETF cleanup RTL SHA and prior property hash above. Its
depth-12 base case passed; induction still failed at line 86 because an
arbitrary induction state started with RET and IRET owners both set, then
changed `opcode` to `89` during instruction fetch. The trace is not a
reset-reachable counterexample and did not exercise the memory-check fault
path. The broad global owner/opcode assertion was replaced by a direct
one-cycle transition assertion: after any denied `MEMORY_CHECK`, the protected
RET owner and its outer-return flags must be clear. Existing state-specific
RET continuation assertions still bind owner, PE and RETF opcode at use sites.

Preflight passes. The property count remains 298 assertions, one assumption
and 49 covers; the updated property SHA-256 is
`bdc4e685c1d37906a744075ccfcbb76fc9cc6243a3418d8fcf9f2865095a42d0`. RTL SHA
remains `ffa9248d1866ecea38b2357f265028821a79768349e2ba86b7f0ac036ba6642b`.
Connected-core prove `_28` started at 09:27:30 UTC and is copying this new
property snapshot. Evidence is under
`design/intel_80286/work/formal_runs/protected_event_outer_20261027_28/core/intel_80286_prove/`.
Current-property BMC, cover, PDR and exact-source aggregate audit remain
open. This plan continues after `_28` reaches a terminal result.

### `_28` live solver progress — 2026-10-27 09:32 UTC

The copied RTL and property hashes match the current source exactly. Yosys
model preparation completed at 09:30:42 UTC. At 09:32:18 UTC the depth-12
base case was checking step 11, while induction was trying step 3. Both are
still active; there is no terminal proof result yet.
The full Verilator bootstrap also passes on this RTL/TB snapshot; its captured
log is `design/intel_80286/work/sim_codex_20261027/full_bootstrap.log`.

### RET continuation owner refinement — 2026-10-27 09:36 UTC

Run `_28` passed its depth-12 base case and returned UNKNOWN at induction
line 578. Its induction-only trace enters `RET_CODE_START` from an arbitrary
BUS return continuation with opcode `83`; the denied-memory-check cleanup
assertion passed. The RET code-load property now checks protected mode and an
active RET owner at that state, while the `FAR_RETURN_DONE` path retains the
RETF opcode check.

Preflight passes. Current properties contain 298 assertions, one assumption
and 49 covers; SHA-256 is
`95b1d902dac419a23b2ed19758f4061ddb4ad175fef19ab11deecd717f567dfc`. RTL SHA
remains `ffa9248d1866ecea38b2357f265028821a79768349e2ba86b7f0ac036ba6642b`.
Connected-core prove `_29` copied this exact snapshot at 09:36:34 UTC. Its
Yosys model is still being prepared, with no terminal proof result. Evidence
is under
`design/intel_80286/work/formal_runs/protected_event_outer_20261027_29/core/intel_80286_prove/`.

### Event continuation invariant refinement — 2026-10-27 09:46 UTC

Run `_29` used RTL SHA-256
`ffa9248d1866ecea38b2357f265028821a79768349e2ba86b7f0ac036ba6642b` and
property SHA-256
`95b1d902dac419a23b2ed19758f4061ddb4ad175fef19ab11deecd717f567dfc`. Its
depth-12 base case passed; induction returned UNKNOWN at line 329. The trace
starts from an arbitrary BUS continuation carrying `EVENT_GATE_TAIL` while
`event_delivery_active=0` and the event packet is invalid. This is an
induction-only owner/state mismatch, not evidence of a reset-reachable
counterexample.

I refined the reverse event-state assertion to require that the previous
cycle already had an active event owner. The complementary owner-to-path
assertions remain in place. Current property SHA-256 is
`b46fea44605d534db9578a494663fdd3d76b0f1ad07e263ba8d9ca041d96e9c5`; the
source assertion count remains 298, with one assumption and 49 covers. RTL
is unchanged. Preflight passes. The `_29` result and current property source
are under
`design/intel_80286/work/formal_runs/protected_event_outer_20261027_29/`;
the next connected-core proof snapshot has not started. Earlier `_21` cover
and PDR jobs remain active. Current-property BMC, prove, cover, PDR and the
aggregate exact-source audit remain open. Latest issue checkpoint:
https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6438637209.

### Previous live solver checkpoint — 2026-10-27 08:14 UTC

Matching SBY's reached-cover records against the 49 CPU assertions in
`intel_80286_props.sv` shows 38 reached and 11 remaining. The run now has 43
VCD files; the newest is a `multiply_divide` component witness at step 32, so
the CPU-cover count remains 38/49. The remaining CPU goals concern async REP/debug events,
F7 /6 and PUSHA, protected error-frame write and outer-IRET code-load commit,
protected CS and DS/ES/SS cache transitions, and vector-8 IDT-limit delivery
(lines 485, 486, 697, 699, 783-788 and 790). The solver remains at step 32;
SBY logged another 30-minute wait at 08:02:12 UTC, while Yices remains
CPU-active.
The previous whole-core ABC PDR anytime pass ended at frame 29 with 366
proven outputs and 28 timeouts (latest on output 137). ABC started a new
anytime pass, reusing clauses, and has advanced to frame 7. It retains 366
proven outputs and has three timeout retries queued from outputs 350, 357 and
367.
Both tasks are active and have no
terminal status. This does not establish a complete core proof or cover. See
[latest issue checkpoint](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6436940553).

Release preflight passes for the current reviewed property inventory. A fresh
SymbiYosys 0.70/Yosys 0.69 run completed all 36 component tasks: BMC, prove and
cover for each of the 12 component configurations. Exact source snapshots and
logs are under
`design/intel_80286/work/formal_runs/protected_event_outer_20261027_21/components/`.

The prior aggregate audit against current files reported 9/40 because saved
component copies were stale and current connected-core task directories were
absent; those were stale-evidence findings, not failures in the refreshed
tasks. The current-source connected-core depth-24 ABC BMC now passes
(`PASS 0 2055`, no counterexample through 24 frames) under
`design/intel_80286/work/formal_runs/protected_event_outer_20261027_21/core/intel_80286_bmc/`.
Core prove `_21` returned `UNKNOWN`: the base case passes through depth 12,
then induction fails at `intel_80286_props.sv:160`. Its induction VCD hash
matches `_20` exactly; it starts in `CODE_LOAD_WAIT` with PE clear and does not
establish a reset-reachable counterexample. The exact-source audit is 37/40;
core cover, PDR and the final audit remain pending. RTL SHA-256 remains
`7ad3e9a821f87640c632bfef1294a612a091617b7a9a7e88692c2eee9e97cea1` and CPU
property SHA-256 remains
`5055f212d8397f2505bf6e6c681758146547167cb4b942e785564f988ea2e874`. See
[latest issue checkpoint](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6436940553).

## Implementation checkpoint — protected privilege-changing event delivery (2026-10-26)

Protected IDT interrupt and trap gates now deliver events from a reachable
ring-3 program to a more privileged nonconforming handler. The core resolves
the target code descriptor, chooses SPn:SSn from the 286 TSS, validates the
new stack, prechecks the complete frame, writes saved SS:SP plus FLAGS/CS/IP
and any error word, then commits the new SS:SP and CS:IP. Interrupt gates
clear IF and TF; trap gates preserve IF and clear TF. Software INT/INT3/INTO
checks the IDT gate DPL, while exceptions ignore it.

The new `--protected-event-outer` regression covers interrupt and trap gates,
software INT DPL rejection to #GP(006A), exact ring-transition frame bytes,
TSS/SS descriptor access ordering, and outer IRET back to the exact successor.
All eight cases pass across both READY modes. The complete bootstrap also
passes, including the existing real-mode, selector, CALL-gate, return,
protected replay setup, reset, and stall suites. Its former invalid protected
#UD decode check now expects the architectural IDT gate read before stopping
on the fixture's invalid gate.

All six compiled mutations are detected by their matching protected-segment
or event suite, including five event-specific cases for saved PC, error word,
atomic handler-state publication, software-INT DPL and interrupt-gate IF.
Exact binaries and diagnostics are recorded under
`design/intel_80286/work/protected_event_mutations_20261026_04/`.

Exact-source Verilator 5.052 build and evidence are under
`design/intel_80286/work/protected_event_outer_20261026_07/`. The full bootstrap
log is `full_bootstrap.log`; focused results are in `protected_event_outer.log`.
Build fingerprint is `e9ca9902fb57e97a94d408a0f765424bc01932e1bedb8535f557a0a71542d6f3`;
binary SHA-256 is `46f647eaea4fbe0681e19a0fe328ca58076eb0eedac878f418973eaba92bf5a2`.
Current RTL SHA-256 is
`7ad3e9a821f87640c632bfef1294a612a091617b7a9a7e88692c2eee9e97cea1`, CPU
properties SHA-256 is
`0a05576210b770e0647ad2e7615402476ad5cd86b3608cfaf79be69eb9e32703`, and
bootstrap SHA-256 is
`247aebddec6991aabc39367332a5f279d66d5da001d99dfffbbfd156c8fd8741`.
The 79-case replay, synthesis and formal results in older checkpoints do not
match this updated RTL/property snapshot. The source-matched PDR started as
run `_30` before the event changes and is not evidence for this checkpoint.

Nested-fault escalation during gate/target/TSS/stack failure remains
unsupported; such paths stop visibly. Task gates and task switching, the full
protected vector/fault matrix, broader CPL1/CPL2 and IOPL rules, current-source
formal BMC/prove/cover/PDR, independent software, native timing and the release
gate remain open.

Next protected-event work follows Intel 210498-005 §§8.3–8.5, 9.4 and 9.6.2:
implement the IDT task-gate/TSS switch needed for #DF, then test the 286 rule
that a second fault after vectors 0/10/11/12/13 becomes #DF and a protection
violation while processing #DF causes shutdown. The source-backed task layout,
busy/backlink/NT/TS ordering, error-code placement and remaining gaps are
recorded in
[`protected_privilege_transition.md`](../../design/intel_80286/spec/protected_privilege_transition.md).

## Previous checkpoint — ring transitions and CPL3 selector faults (2026-10-26)

The existing ring-3-to-ring-0 gate, invalid gate/LDT/TSS matrices, 13-case
outer-RETF fault/recovery path, and 79-case protected replay still pass. New
reachable cases now call nonconforming DPL-1 and DPL-2 targets from ring 3
through a DPL-3 gate. They select `SP1:SS1` and `SP2:SS2` at TSS base offsets
6 and 10, validate the corresponding stack descriptor before writing, copy
two parameters, check the full inter-level frame, and return with `RETF 4` to
the exact ring-3 successor. Four level/READY combinations pass.

A second case calls DPL-1 conforming code from CPL 3. The target selector keeps
RPL 3, caller SS:SP remain active, and the gate creates a same-level return
link. The test confirms no TSS read, new-stack write, or parameter copy even
with a nonzero gate parameter count. `RETF` resumes at the exact ring-3 HLT in
both READY modes. Intel 210498-005 §7.5.1.2 and §7.5.1.4 define the conforming
intra-level rule and the TSS-selected privilege stacks.

The selector suite now reaches CPL3 through validated outer IRET and attempts
LLDT/LTR using register and memory operands. All eight operand/READY
combinations deliver #GP(0) before operand, candidate-descriptor or TSS
traffic. A same-level ring-3 handler repairs the saved IP and IRETs to the
exact successor. The tests confirm the existing LDTR remains null, TR remains
0050, and the candidate TSS stays available. Intel 210498-005 §§10.2.2–10.3
defines LLDT/LTR as privileged and prescribes #GP(0) outside CPL0.

The Verilator 5.052 exact-source runner, focused `--selector-exec` log and full
bootstrap log are under
`design/intel_80286/work/selector_privilege_20261026_02/`. The bootstrap also
passes the existing ring-level and conforming gate tests. RTL SHA-256 remains
`cbde2d3ceea2179cf75a73ac4973d6b1ef06ef4742a58f44f77566fa00b6c865`.
Formal properties have since changed during the separate induction audit.

Current testbench SHA-256:
`bcdcca03983fa4f8697d79d804b1434ff85fe96e47274cc20b21c726a85e4c05`.
Runner fingerprint:
`db9f1ade8953bdcebe86c848bbfdbc5fe556e5695dfa7883a61f45260c899681`;
binary SHA-256:
`a3f0491772456693e2dc9c57001d98b94b9c4f92c2520103ccc4258378e2b332`.

The exact-source Verilator 5.052 runner manifest, focused logs, and full
bootstrap log are in
`design/intel_80286/work/callgate_ring_levels_conforming_20261026_01/`.
GitHub progress is recorded in [issue comment 6424806945](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6424806945).
Runner fingerprint: `2616ade2c321530681c39190cb1dd89e47c7e9dc90d26697eb1a9d0b73017c9e`;
binary SHA-256: `574b782e45e6bc0697d8f5cf7ce9fa3ff514484258dfb144e00643d2b25c8ed3`;
bootstrap SHA-256:
`72aeee6d6dc427235a476ab4a979f2e4755d559bef4b5eb5d7cfbe75304ff7d1`.
The RTL (`cbde2d3ceea2179cf75a73ac4973d6b1ef06ef4742a58f44f77566fa00b6c865`)
was unchanged for that runner; the formal properties have since been revised.

### Formal property audit — 2026-10-26

The core RTL remains SHA-256
`cbde2d3ceea2179cf75a73ac4973d6b1ef06ef4742a58f44f77566fa00b6c865`.
Current CPU properties are SHA-256
`3a21719d8b6dfb974f9593e00445ee1a9c1fa8e7d50b7cb18582d1d9febd72a4`.
Current depth-12 Yices run `_29` is under
`design/intel_80286/work/formal_runs/selector_privilege_current_20261026_29/core_prove/`.
Its base case passes all 12 frames; induction ends `UNKNOWN` at property lines
261–262, which tie protected event-frame bus continuations to an active,
valid protected event packet. The induction-only trace starts from a
`CODE_LOAD_WAIT`/outer-IRET continuation with an invalid packet, then reaches
an event-frame continuation. The initial state violates the event-packet
lifecycle, but k-induction has not established that provenance. No
reset-reachable counterexample has been found, and this result is not a proof.

Trace review corrected several continuation contracts and added asserted
ownership relationships for protected CALL, outer IRET/RET and event-frame
transactions. Run `_21` showed that outer IRET enters `MEMORY_CHECK` before
commit, unlike same-level IRET; run `_22` showed that an `0F` LTR transaction
can use the normal `COMMIT_MEMORY` continuation for its TSS busy bit. Run
`_28` exposed an event-only precheck return assertion; the current property
compares against the captured `memory_return` continuation. These runs passed
their depth-12 base cases and failed induction. The depth-24 BMC `PASS 0 2009`
remains valid for the prior CPU-property SHA-256
`a9772652904194f9de03c925a163e5fe3a665f5f833539d151cc2f2505ed9ed0`, not the
current property file. No exact-current-property depth-24 BMC, reachable cover,
PDR or aggregate exact-source audit is available. The run logs and induction
traces are retained under runs `_21` through `_29`. The latest issue update
is [comment 6428101255](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6428101255).

For the protected interrupt/trap-gate RTL SHA-256
`7ad3e9a821f87640c632bfef1294a612a091617b7a9a7e88692c2eee9e97cea1`, the
connected-core depth-24 ABC BMC completed `PASS 0 2293` with no counterexample
through 24 frames. Its CPU-property SHA-256 was the pre-refinement
`0a05576210b770e0647ad2e7615402476ad5cd86b3608cfaf79be69eb9e32703`; see
`design/intel_80286/work/formal_runs/protected_event_outer_20261026_01/core_bmc/run_manifest.json`.
This BMC does not cover the current property file.

Current CPU-property SHA-256 is
`5055f212d8397f2505bf6e6c681758146547167cb4b942e785564f988ea2e874` with
290 assertions, one assumption and 49 covers. Release preflight passes. The
full design helper suite passed 78 tests on an earlier property snapshot (one
POSIX-only test skipped); it was not rerun for this property-only continuation.
Depth-12 Yices prove `_20` passed its bounded base case but returned `UNKNOWN`
at induction on `intel_80286_props.sv:160`. The induction-only witness starts
in `CODE_LOAD_WAIT` with PE clear and violates the PE ownership invariant. The
actual code-load launch paths are PE-gated or originate in protected event and
return states, so this is not a reset-reachable counterexample. The exact
staged inputs, log, witness and manifest are under
`design/intel_80286/work/formal_runs/protected_event_outer_20261026_20/core_prove/`.
Runs `_12`–`_20` all passed their depth-12 base cases and returned `UNKNOWN` at
induction. Their induction-only traces exposed stale event-packet fields,
unowned TSS stack state, impossible real-mode entries into protected
descriptor waits and invalid far-return continuations. The property set now
binds active interrupt checks, TSS stack markers, PE-gated descriptor waits and
far-return opcode ownership. No reset-reachable counterexample or
current-snapshot induction proof has been established.

Yosys 0.69 synthesis and `check -assert` still pass on the unchanged RTL with
zero problems and 40,652 cells. The current-source depth-24 core BMC passes
through 24 frames (`PASS 0 2055`) under
`design/intel_80286/work/formal_runs/protected_event_outer_20261027_21/core/intel_80286_bmc/`.
The aggregate exact-source audit is 37/40. Core prove `_21` is `UNKNOWN` at
induction (same induction-only line-160 trace as `_20`); the depth-64 cover is
running and PDR remains open. Latest issue progress is [comment 6436940553](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6436940553).

The depth-64 core cover is running under
`design/intel_80286/work/formal_runs/protected_event_outer_20261027_21/core/intel_80286_cover/`.
After it completes, run whole-core PDR on the same source snapshot and complete
the aggregate exact-source audit. Use those results to identify any remaining
reachable failure or proof boundary before adding more induction invariants.
Continue
privilege-changing #TS/#SS delivery, task-gate recovery and shutdown, CPL1/CPL2
checks, broader ISA and exception coverage, authentic software and native
timing. Full 80286 acceptance remains open.

## Previous checkpoint — CALL-gate rejection and outer RETF recovery (2026-10-26)

The reachable protected path covers same-level GDT CALL gates, gate-selector
and gate-access #GP/#NP cases, ring-3-to-ring-0 GDT gates with 0/1/31 copied
words, and outer RETF. A directed program loads an LDT, reaches ring 3 with
LDT-backed CS:SS, calls an LDT-resident gate to GDT ring-0 code through the
TSS stack, and returns to the LDT caller. LDT target faults cover invalid
LDTR, out-of-limit, present data and non-present code descriptors. The gate
matrix checks all 15 non-call system descriptor types plus a data descriptor,
and DPL/presence rejection. Tests verify exact #GP/#NP frames, byte-read
counts, and no target/TSS reads or CALL-frame writes before validation. Every
case runs in both READY modes without seeding CPL or hidden caches.

The TSS/stack suite adds nine reachable ring-3-to-ring-0 CALL-gate failures in
both READY modes: short TSS, null/out-of-GDT/wrong-type/RPL-mismatched/
DPL-mismatched SS0, absent SS0, SP0 underflow and insufficient SS0 limit.
Expected errors are #TS(TSS selector), #TS(SS0 selector), #SS(SS0 selector)
or #SS(0) per Intel 210498-005 Table 9-5, §7.5.1.4 and §9.6.6. The tests
check restart state, exact error frames on the original ring-3 stack,
descriptor reads and no new-stack CALL-frame writes.

Outer RETF has a 13-case invalid-return matrix in both READY modes. It checks
null/out-of-table/wrong-type/privilege-invalid/non-present return CS and SS,
exact #GP/#NP/#SS packets and frames, CS validation before SS reads, and SS
validation before the return-IP limit check. A reachable #GP handler repairs
the saved outer SS selector, returns with IRET and retries RETF; the ring-3
caller resumes at its exact successor with the restored SS:SP.

Current source identities:

- RTL SHA-256: `cbde2d3ceea2179cf75a73ac4973d6b1ef06ef4742a58f44f77566fa00b6c865`
- Bootstrap SHA-256: `ba2f3f0c6683632e684d9114da5f4deb0c71d3a2a85a52bbba6ad044f2a4bc07`
- CPU formal properties SHA-256: `a9772652904194f9de03c925a163e5fe3a665f5f833539d151cc2f2505ed9ed0`
- Verilator runner fingerprint: `66d9da88beb60689e8f341dea6e27beee91cdc141013e5a16531930b8e1d2d09`
- Verilator runner binary SHA-256: `15f7eeb7d554e061bebf0ee271cd26d9cf4c6825a22644dc8fa8b32ddc4ddfca`
- Protected replay manifest SHA-256: `d41f5f0736b737aefbc4b75a86bfc773d6c32db957cc742b0d020679815c9dee`

Verilator 5.052 `--build -j 2 -Wall`, the focused `--call-gate-retf-faults`
suite and full bootstrap pass under
`design/intel_80286/work/outer_retf_faults_20261026_08/`. The fresh 79-case
protected replay is under
`design/intel_80286/work/callgate_outer_retf_replay_20261026_01/`. All 15
protected INS/string mutations are detected against that manifest; results
are under `design/intel_80286/work/outer_retf_current_mutations_20261026_01/`.
Yosys 0.69 full-core synthesis, `check -assert`, `stat` and JSON export pass
with zero check problems and 37,493 cells. Logs and netlist are under
`design/intel_80286/work/outer_retf_faults_20261026_06/synth/`.

The exact-source connected-core depth-24 BMC is running in
`design/intel_80286/work/formal_runs/outer_retf_formal_20261026_01/`. Core
induction, reachable cover and PDR remain open. The complete 80286 remains
incomplete.

Remaining: expand CPL1/CPL2 privilege and event combinations beyond the
tested software `INT 13h`, including other exceptions and asynchronous events;
task-gate #TS/#SS entry and nested-fault escalation; current-source core
proof/cover/PDR; authentic historical software; the aggregate release gate;
and the native pin interface.

Next: close the current BMC run, expand reachable ring-1/ring-2 event coverage
beyond software `INT 13h`, and extend #TS/#SS recovery to task gates and
broader privilege-changing events. See the
[active revised plan](2026-10-26-audit-and-revised-plan.md).

## Previous checkpoint — selector query execution (2026-10-26)

The current core implements ring-0 protected VERR/VERW/LAR/LSL alongside
SLDT/STR/LLDT/LTR, LDT-backed data loads and same-level selector #GP/#NP
delivery. Strict Verilator lint, the focused selector suite, the full bootstrap
regression and the 79-case protected-string replay pass on this exact source.
The full 80286 objective remains open.

Current source identities:

- RTL SHA-256: `F6F13192A55E775E32C29CA046F47A14EE3DA5662B228D6AEC5DA60A34AE5939`
- Bootstrap test SHA-256: `957DF9B621BD9DFB2D7E6B122EA879550CB3EB517F6C07885CD90D12194F8585`
- Formal properties SHA-256: `A9772652904194F9DE03C925A163E5FE3A665F5F833539D151CC2F2505ED9ED0`

Exact-source evidence is in
`design/intel_80286/work/selector_query_20261026_11/`. Verilator 5.052 strict
lint passes. The CPU runner manifest fingerprints all RTL and testbench inputs;
`--selector-exec` passes two selector-state executions, ten selector #GP/#NP
handler-repair/IRET cases, two null-LDTR recovery cases and 82 VERR/VERW/LAR/LSL
executions across both READY modes. The full default bootstrap also passes its
real-mode, boundary, shift, event, system-register, cache, protected segment,
selector and ARPL suites.

Yosys 0.69 full-core synthesis and `check -assert` pass on this RTL hash. The
hierarchy contains 32,580 cells and the check reports zero problems. Logs and
the JSON netlist are in the same evidence directory.

The fresh protected-mode replay passes 79 cases on this same source. Its
manifest is `design/intel_80286/work/selector_query_replay_20261026_01/`;
its manifest SHA-256 is `4f63a5c7229c9f5cba12dcad54afb0ed8a5708bcbee8345c6f683ae2abd13fcd`.
The exact-manifest protected-string mutation run detects all 15 mutations;
results are in
`design/intel_80286/work/selector_query_mutations_20261026_01/mutations.json`.

The earlier depth-24 ABC BMC completed `PASS 0 1665` on prior core hash
`fd6004af2605621dc18e3bad6efae834b8027fe3f1e99059c676f8cfb3d319b0` and prior
property hash `d6c782e88c49a9b1a353b1f8bce5e2cb6cd54e93842222163ab4cce0e09c6f3f`.
That snapshot predates selector-query execution. The selector-query source then
completed depth-24 ABC BMC with `PASS 0 1977` in
`design/intel_80286/work/formal_runs/selector_query_current_20261026_01/`.
Both BMC results predate outer IRET and are not current-source formal evidence.
Current-source prove/cover/PDR remain open. Earlier induction and partial
cover/PDR results are historical; the current protected-string mutation result
is 15/15 detected on the replay manifest above.
`run_all.sh` has not run and still uses fixed output paths. The prior 79-case
replay and 52 Harris captures belong to an older RTL snapshot; the fresh replay
above covers the current source, while a current-source Harris replay remains
open.

Nonzero-CPL transitions, task switching, privilege-changing event delivery,
general exception escalation, broad ISA closure, OS/2 CPGREP, the aggregate
release gate and the native pin interface remain open. The known PCjs BIOS 1782
attempt is not a usable software result. See the
[active audit and revised plan](2026-10-26-audit-and-revised-plan.md).

Issue #80 remains Open/Building with Agent Codex, Start date 2026-10-23, Path
`ai_hw_engineer/design/intel_80286` and its existing Sprint 1 assignment. The
latest verified progress update is [comment 6424281244](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6424281244).

## Previous checkpoint — selector state and execution (2026-10-26)

The current core implements protected ring-0 SLDT/STR register and memory
forms, LLDT/LTR descriptor validation and commit, LTR's TSS busy-byte update,
null-LDTR invalidation, and LDT-backed data-segment loading. VERR/VERW/LAR/LSL
remain valid protected encodings that stop visibly after complete decode;
real-mode #UD and invalid `0F 00 /6–/7` remain.

Current RTL SHA-256:
`D8E67D092B66B05AF6831C8996AB713AD2F6894925C012267D970757D50F0C14`.
Formal property SHA-256:
`D6C782E88C49A9B1A353B1F8BCE5E2CB6CD54E93842222163AB4CCE0E09C6F3F`.
**ASSUMPTION A17:** reset sets visible LDTR/TR selectors to zero and their
hidden caches invalid/zero; Intel's cited reset documentation does not define
those values.

Evidence from the focused selector runner:

- Two protected programs pass in both READY modes. The checks cover SLDT/STR
  register and memory forms, LLDT/LTR register and memory forms, GDT/LDT byte
  read order, an LDT-backed DS load and data read, busy/accessed writes,
  unchanged FLAGS and exact retirement successors.
- Five descriptor rejection cases create exact #GP/#NP packets without
  modifying rejected descriptors. A separate case checks null LDTR
  invalidation and confirms no later LDT descriptor read.
- The 16-case decode matrix covers remaining VERR/VERW/LAR/LSL valid forms,
  invalid `/6`/`/7`, displacement fetches and both READY modes.
- Selector #GP(selector)/#NP(selector) delivery is incomplete: the event engine
  records the correct packet, then stops with diagnostic code 3 because only
  #GP(0) delivery is currently supported. The checks prove packet creation,
  not handler delivery.

The exact-source `run_development.sh` refresh completed with exit 0. Its log
is `design/intel_80286/work/selector_exec_20261026_01/run_development_a17.log`.
It passes the focused suite, refreshed 79-case replay, and 52 historical
Harris-286 captures replayed in stalled and unstalled modes (104 executions).
The matching replay manifest is
`design/intel_80286/work/protected_mode_dev_20261026T120325Z/build_manifest.json`.
The exact-source depth-24 BMC is running in
`design/intel_80286/work/selector_exec_20261026_01/formal/intel_80286_bmc_a17/`.
At the latest poll it had reached frame 15/24, without a terminal status. The
previous connected-core depth-12 prove was UNKNOWN at an induction-only
event-bus owner/path assertion; this did not establish a reachable
counterexample. Current proof, completed cover, PDR and exact-source formal
audit remain open.

Yosys 0.69 full-core synthesis and `check -assert` passed on the same RTL logic
before the A17 comment. The exact-source log
`design/intel_80286/work/selector_exec_20261026_01/core_synth_a17.log` ends
during memory lowering without a terminal result, so exact-source synthesis is
not yet confirmed. The 15/15 protected-string mutation suite also predates
this selector core and needs a fresh current-source run. `run_all.sh`, CPGREP,
broad privilege transitions, task switching, and the native 80286 interface
remain release blockers. Do not treat focused replay, selector execution, or
synthesis as full 80286 completion.

Next: close nonzero-error selector exception delivery and add a reachable
nonzero-CPL path; then implement VERR/VERW/LAR/LSL from Intel 210498-005.
Continue current-source formal and mutation work independently. See the
[active audit plan](2026-10-26-audit-and-revised-plan.md).

Issue #80 remains Open/Building with Agent Codex, Start date 2026-10-23, Path
`ai_hw_engineer/design/intel_80286`, and its existing Sprint 1 assignment.
Preserve those confirmed fields. Progress is recorded in
[latest issue comment 6415640683](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6415640683).

## Previous checkpoint — ARPL and refreshed protected-string baseline (2026-10-26)

The worktree adds the first protected-only instruction slice after the ring-0
fault/string work: ARPL. Opcode `63 /r` now compares selector RPL fields,
conditionally raises the destination RPL, updates only ZF, and checks memory
destinations as read-modify-write. Real-mode #UD remains. A null source
selector raises protected #GP(0) before operand access, following the Intel
80286(B-2/B-3) Information Sheet.

Focused evidence is isolated under
`design/intel_80286/work/arpl_dev_20261026/`:

- Verilator 5.052 with `--cc --exe --build -j 2 -Wall` built the runner. The
  build fingerprint is `8f573a6a4d8bb0696bbcddba92ec5d3636ffb888691b2037ee10d4c2d7a029c4`;
  the binary SHA-256 is `cd049b30350102a991d7e73389eb81dbac33450901ded11911fde47034a6f1a7`.
- `arpl.log`: register and memory adjustment/no-change, exact RMW traffic,
  both READY modes, exact successor PCs and null-source #GP packet pass.
- `real_mode_ud.log`: all 36 directed #UD cases and 71 reset cuts pass.
- `protected_segments.log`: existing protected #GP/IRET/reset tests and ARPL
  checks pass.
- The repository preflight and `git diff --check` pass.

Current RTL SHA-256:
`4bef2d465024748bbf6ff4240076051f2fd43a401f92006b54ee49882e586634`.
Current bootstrap test SHA-256:
`5dc0698e8b3bb58e080c0128f4a3f1ff25a43ff7cd5465a4703d7d5626294b67`.
Current-source refreshes after ARPL:

- The strict Verilator 5.052 protected replay passes 79 cases in both READY
  modes at `design/intel_80286/work/arpl_current_full_replay_20261026_01/`.
  Its manifest fingerprints the core at
  `4bef2d465024748bbf6ff4240076051f2fd43a401f92006b54ee49882e586634`; the
  binary SHA-256 is
  `2141eb75429e89244c0cc3af931b814e1337077749a273f1d21b4aee05f474d8`.
- All 15 protected-string mutations are detected against that baseline in
  `design/intel_80286/work/arpl_current_full_mutations_20261026_01/`.
- Yosys 0.69 full-hierarchy synthesis and `check -assert` pass in
  `design/intel_80286/work/arpl_current_checks_20261026_01/core_synth.log`,
  reporting 29,964 cells.
- The current-source connected-core depth-24 ABC BMC passes in
  `design/intel_80286/work/arpl_current_formal_20261026_01/` with SBY status
  `PASS 0 1577` (26m17s) and no counterexample. Depth-12 prove is `UNKNOWN`:
  its base case passes through 12, but induction fails at
  `intel_80286_props.sv:154`. The induction trace sets `code_load_target=2`
  while the code-load request is `1E80:FFFC` and saved IRET target is
  `0200:00F3`; the property antecedent omits the RTL branch's target-match and
  special-descriptor success guards. This is an induction/property-strengthening
  gap, not a reachable counterexample. The depth-64 cover run was interrupted
  after 28 witnesses at step 20, with no terminal status. The repository audit
  at `design/intel_80286/work/arpl_current_formal_20261026_01/audit.json` reports
  37/40 current tasks PASS: all 36 components and current BMC pass; prove is
  UNKNOWN, cover is incomplete, and the preserved PDR snapshot is stale for
  current RTL.

The earlier 103-line `run_sim.sh` log and 37/40 formal audit used pre-ARPL RTL
and remain historical. ARPL's broader segment-fault priority matrix and
independent physical stepping captures remain open. GitHub issue #80 remains
Open/Building with Agent Codex, Start date 2026-10-23, Path
`ai_hw_engineer/design/intel_80286`, and its existing Sprint 1 assignment.
Preserve these confirmed fields.

The current Git HEAD is still `e7c252051b4750e8382baedbf8b4015e3600beb7`;
these changes are uncommitted in the task worktree. Continue Gate 1 by correcting
the property antecedent without constraining the environment, rerunning
prove/cover/PDR, recording terminal task statuses and exact-source hashes, and
making aggregate output paths unique. Then continue the sourced, mode-specific
0F 00/02/03 selector/system group.

## Historical checkpoint — recovered harness and pre-ARPL protected-string replay (2026-10-26)

The active continuation sequence is the [2026-10-26 progress audit and revised plan](2026-10-26-audit-and-revised-plan.md). The 80286 objective remains open.

The focused CMPS implementation and report are committed at e7c2520. The following regression/specification sources were then recovered from local snapshot f490003fb78c652eb512e5f7fdd2f97f74e0b806. Newer core, current fixture and reports were preserved. The recovered files are not yet tracked: 105 files are untracked and .gitattributes is modified to preserve LF for Linux shell scripts. Worktree: B:\ai_hw_engineer\worktree\intel-80286, branch design/intel-80286, HEAD e7c252051b4750e8382baedbf8b4015e3600beb7. The branch is 37 behind and 5 ahead of the local main reference; it has not been fetched or reconciled.

### Evidence from the pre-ARPL source snapshot

- Preflight passed: PASS: regression dependencies and reviewed property source inventory.
- The focused preflight, formal-audit and build-runner helper suites passed: 33 tests.
- `design/intel_80286/work/recovered_sim_20261026_04.log` records a successful `run_sim.sh` run with 103 PASS lines, including bootstrap/component suites and the 79-case protected replay. This predates ARPL and is not a current-source CPU run.
- The pre-ARPL replay is `design/intel_80286/work/protected_mode_sim_20261026T073151Z/`. Its PASS manifest covers 79 cases and matches its 19 listed source inputs. Core SHA-256: `08ab26c1fc4fabb1320453036e09f3d62920795821bac60914483e0c594b7dca`; binary SHA-256: `6713a06c6b36c1f2585565748912081e222a143e0e899a297bc02163160a89fd`. It does not match the current ARPL core hash `4bef2d465024748bbf6ff4240076051f2fd43a401f92006b54ee49882e586634`.
- The integrated cases cover the same-level vector-13 frame/handler/IRET retry and reset cuts, plus INS, MOVS, STOS, OUTS and CMPS memory-fault phases with exact restart checks and READY stalls.
- `design/intel_80286/work/protected_string_mutations_release_20261026_01/mutations.json` records 15/15 detected mutations with expected diagnostics against that earlier baseline.
- Yosys 0.69 synthesis/check reports zero problems at `design/intel_80286/work/cmps_checks_20261026_01/synthesis.log`. Depth-12 BMC is `PASS 0 185` on its 21-file pre-ARPL snapshot. Cover mode timed out at 180 seconds after 11 complete witnesses; 53 cover statements remained unreached. These results do not verify current ARPL RTL and do not establish full proof or cover closure.

### Pre-ARPL formal audit — run.ySqmJ8

- All 36 component BMC/prove/cover tasks have SBY `PASS` status in `design/intel_80286/work/formal_runs/run.ySqmJ8/`.
- Connected-core depth-24 BMC passes (`PASS 0 1699`) for its recorded pre-ARPL snapshot. Connected-core depth-12 prove is `UNKNOWN`: its base case passes through the configured depth, then induction fails at `formal/intel_80286_props.sv:388`. The induction-only trace starts in event-target `CODE_LOAD_WAIT` with `event_packet.valid=0` and a stale `instruction_retired=1`, then reaches `EVENT_FRAME_CHECK`. This state is inconsistent with the event-packet lifecycle, so it points to an invariant-strengthening gap; reachability beyond the basecase depth is not established, and this is not a proof pass. The current ARPL core must be audited and reproved separately.
- Connected-core cover was interrupted at step 15 after 21 witnesses. Whole-core PDR was interrupted after `PRV=243`. Both directories preserve logs/traces but have no terminal PASS; neither counts as complete.
- The exact-source audit reports 37/40 tasks PASS, 229 elaborated CPU assertions and 49 covers; it finds no stale source/config snapshots. `test_audit_formal.py` passes 17 tests after the auditor was updated to accept the prove-only PDR config.
- `scripts/run_formal.sh` now parses the declared task names, runs component configs before bounded core tasks and full-core PDR last, and accepts config basenames for selected runs. The full formal inventory is 14 configs/40 tasks.

The 103-line simulation and 15-mutation run are focused implemented-subset evidence on the pre-ARPL snapshot; they do not verify the current core or the full release. The aggregate `scripts/run_all.sh` has not run. OS/2 SDK 1.00 CPGREP has not executed; the recorded PCjs setup still stops at BIOS 1782 without a shell. Broad ISA and protected mechanisms, IOPL execution/tests, SCAS fault semantics, A20/native I/O timing, native pin-level interface, full proof/cover and authentic software acceptance remain open. Intel's reference manual does specify `#GP(0)` for OUTS when CPL exceeds IOPL; the core cannot yet reach that privilege state. The LOADALL memo's SCAS fault-restart SI rule still conflicts with the ordinary SCAS ES:DI/DI-advance definition, so protected SCAS repair stays blocked pending independent evidence.

The aggregate is also not safely rerunnable yet: `run_all.sh` and its stage
scripts write lint, runner, vectors, hardware, software and synthesis artifacts
to fixed `work/` paths. Add one configurable release evidence root before the
next aggregate run so it cannot replace the saved baseline outputs.

Issue [ai_hw_engineer#80](https://github.com/hevangel/ai_hw_engineer/issues/80) remains the tracking item. Live `gh project item-list` confirms Open/Building, Agent Codex, Start date 2026-10-23, Path `ai_hw_engineer/design/intel_80286`, and the existing Sprint 1 assignment; preserve the first start date and path. This audit is recorded in [issue comment 6412698512](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6412698512).

Next: finish the exact-source depth-24 BMC and record its terminal status; obtain a complete current-source synthesis/check result; then add a configurable fresh evidence root to `run_all.sh` and every stage. Continue selector work by making nonzero-CPL execution reachable, closing nonzero-error delivery, and implementing VERR/VERW/LAR/LSL. Preserve/review and track the recovered files before commit or PR. Strengthen event-state induction invariants without constraining the environment. Do not claim the full 80286 is complete or repeat the known BIOS-1782/no-shell attempt as new evidence.

## Historical audit and revised plan — 2026-10-25

The [audit and replacement plan](2026-10-25-audit-and-revised-plan.md) is now the
active task sequence. Baseline HEAD is `af9026410fef74c871cbc084aea909d2e11f5e55`;
RTL/properties still match the MOVS/STOS/OUTS checkpoint below. Five existing
dirty files add unfinished CMPS tests, manifest fields and mutation definitions;
no CMPS RTL fix or passing 79-case result exists yet. Preserve those edits.

Audit checks: the hash-matched saved baseline binary passes all 55 cases again;
the unfinished CMPS binary exits 1 with a native-state mismatch. Ten historical
mutation logs match their recorded hashes/diagnostics. Both current formal
snapshots match all 21 RTL/property inputs each. Only 16/19 passing replay
inputs match the dirty checkout; the two test sources and recorder changed.
No compiler, synthesis, proof, cover or mutation compilation was rerun for this
documentation audit. Details and ignored scratch audit outputs are in the plan.

**Correction to older job statements:** Docker containers `08ff02ed061f` (PDR)
and `8f82f426aa15` (cover) are still running the recovered Task 4 retry3 snapshot,
core `c77cfbce...` / properties `4d184fc5...`. Neither has a terminal SBY status.
The inspected cover directory has 52 `.yw` files and progress at step 48; PDR
reports PRV=289 without final PASS. These results cannot verify the newer RTL.
No container was stopped or duplicated by the audit. Account for these jobs
before scheduling replacements; earlier claims that they were gone are superseded.

Next work: Gate 0 of the revised plan (durable inputs, missing harness inventory,
live-job accounting), then finish the pending CMPS change under Gate 1. Broader
ISA/#UD classification, protected mechanisms, software/platform evidence, native
interface and full formal/release closure remain open. The complete CPU is not
verified, and no RTL changes were made during this audit.

Updated 2026-10-25 during recovery into the `design/intel-80286` worktree.

## Current checkpoint — protected MOVS/STOS/OUTS fault repair

The prior goal turn made concrete progress (INS correction, tests, committed
source and issue update). This continuation extends the same externally found
defect to MOVS source/destination, STOS and OUTS memory failures. The full
80286 objective and completion ledger remain in force.

Current core SHA-256:
`3e2a84e8a5d417e153b3fe525ecd66e180428e3814b644fbc33c2c2258687f96`.
Current CPU property SHA-256:
`a6ce79a5e9853f915156fbff15ce0b967fbc9b023fad23fccd6fc2f2c0c40cbd`.
These supersede the INS-only snapshot below. See the
[string-fault report](../../design/intel_80286/report/2026-10-25-protected-strings.md).

Completed: strict Verilator build and 55-case replay at
`work/protected_strings_20261025_03/`, plus Yosys synthesis (28,734 cells) at
`work/strings_checks_20261025_01/`. Forty new cases cover four fault phases
with byte REP, word REP last/nonfinal, backward word and FFFF wrap, each in
both wait modes. The failing pre-fix model and full input source copy are at
`work/protected_strings_red_20261025_01/`.

Further completed checks:

- Ten mutations compile and are detected with the expected semantic diagnostic
  in `work/protected_strings_mutations_20261025_01/`. The manifest identifies
  both mutation scripts and each mutated core/log. Five new faults target
  MOVS source count, destination SI, STOS DI, OUTS SI and early wrap dispatch.
- Depth-12 BMC passes in 251 seconds in `work/strings_checks_20261025_01/bmc12/`.
  It is a smoke bound and does not reach the entire protected workload.
- Cover mode times out at 180 seconds with eight complete witnesses; a ninth
  VCD is only partially emitted. Solver progress reached step 10. This is
  incomplete and does not establish the native fault-path formal covers.
- `work/strings_checks_20261025_01/source_audit.json` confirms both 21-file
  formal snapshots match current source. All 19 replay inputs also match the
  passing manifest. Replay binary SHA-256:
  `cf69a2a7565ef3428c40db4dfcf8cf0bf4b83f808da47aa40b45751b3737956e`.

Sessions 38324, 84635 and 42001 are terminal; no jobs from this checkpoint
remain active. The source scan of Intel LOADALL memo page 14 was rendered
and checked: the SCAS paragraph really names SI. Further corroboration is
needed before choosing its fault-time index behavior.

Next architectural work: CMPS source/destination fault repair, then resolve
SCAS's contradictory index naming in the old Intel memo using independent
286 evidence. OUTS IOPL, INS DF=1, native port timing and broader full-chip
gates remain open. The existing synthetic fixtures do not replace OS/2 CPGREP.

## INS-only checkpoint (historical snapshot 408bab2)

Issue: [ai_hw_engineer#80](https://github.com/hevangel/ai_hw_engineer/issues/80).
Project fields: Agent Codex, Building, Start date 2026-10-23, Path
`ai_hw_engineer/design/intel_80286`.

Intel's original LOADALL page-14 repair rules and 1984-10-15 REP restartability
memo exposed a shared false assumption: a protected INS destination fault
does not preserve DI/CX. The core now implements the corrected post-C2 repair
state, including wrapped DI and CX=FFFF for a failed last REP element. The
handler reverses DI and adds two to CX before retrying. See the
[escaped-defect note](../../failure_notes/2026-10-25-intel80286-ins-fault-state.md).

Current core SHA-256:
`0947d5aa793426c868899ae9e5a48efa7cff4e07157e9d77996d251afc669b26`.
Current CPU property SHA-256:
`4bac795c0b5564c83604b12c02fcb95c667811e3dffc699e11bc9cf8e20a776d`.
The earlier formal/synthesis identities below are historical; they do not
verify this changed RTL/property pair.

Changed files include the core, CPU properties, protected replay C++, replay
runner/manifest, a new `scripts/run_protected_ins_mutations.py`, specification,
design README, continuation plan and the failure note/index. The runner now
uses fresh evidence names and refuses to overwrite prior runs.

Completed:

- `bash design/intel_80286/scripts/run_protected_mode_replay.sh protected_ins_native_20261025_01`
  passes 15 cases: the five prior #GP/IRET/reset checks and ten INS runs
  (byte overrun, word straddle, 64K wrap, REP last and nonfinal faults in both
  wait modes). Every byte request is stalled in the INS wait runs, with
  explicit I/O and destination stall witnesses. Exact PCs, frames, register
  repair, completed elements and external byte transfers are checked.
- The build uses strict Verilator 5.052 `-Wall`. Exact source/tool/binary
  identities and the log are in
  `design/intel_80286/work/protected_ins_native_20261025_01/`.
  Binary SHA-256:
  `ea0b380bb27cb7794689423d2b6db778b4d65a6d53101ee2580b43c68a3a14c1`.
- `python3 design/intel_80286/scripts/run_protected_ins_mutations.py design/intel_80286/work/protected_ins_native_20261025_01/build_manifest.json protected_ins_native_mutations_20261025_01`
  rejects all five mutations: ignoring ES denial, checking only the first
  word byte, saving the successor PC, retaining pre-fault indices, and
  decrementing REP twice after successful transfer. Each compiles and fails
  with its expected semantic diagnostic. Logs and per-mutation hashes are in
  `design/intel_80286/work/protected_ins_native_mutations_20261025_01/`.
- The externally derived test fails on the old core. Its preserved executable,
  source identities and `expected_failure.log` are in
  `design/intel_80286/work/protected_ins_native_red_20261025/`.

Additional completed checks under
`design/intel_80286/work/ins_checks_20261025_01/`:

- Generic Yosys 0.69 synthesis passes, with 28,654 cells including submodules
  and zero problems from `check -assert`; exact script and `synthesis.log`
  are retained.
- Depth-12 ABC BMC passes in 221 seconds in `bmc12_retry/`. The earlier
  `bmc12/` run timed out at 180 seconds while checking frame 10; both remain.
  This is a smoke bound, not an unbounded proof or a completed protected INS
  boot/fault/handler trace in formal.
- Depth-64 cover mode times out at 180 seconds, with 11 complete witnesses
  saved and the solver checking step 10. This is incomplete; native INS fault
  non-vacuity is demonstrated by the directed simulation cases, not by these
  shallow cover traces. Full formal/prove/cover closure remains open.
- `source_audit.json` confirms all three 21-file formal snapshots match the
  current RTL/properties. All 18 replay inputs also match the passing manifest.
  The evidence-overwrite guard rejects an existing run name and preserves its
  binary hash. Staged whitespace checks pass. Local attributes preserve LF
  source/script line endings on future Windows checkouts.

No verification jobs remain active from this checkpoint.

Remaining semantic decisions: A20 still assumes destination denial suppresses
native port consumption; this has no physical 286 trace yet. IOPL faults,
decrementing-direction integration, and other string instruction repair rules
need independent coverage. OS/2 CPGREP still has not run. Next architectural
edit: audit the MOVS/OUTS/STOS/SCAS/CMPS fault-state paths against Intel's repair
rules, keeping the broader full-80286 requirements open.

## Workspace

- Worktree: `B:\ai_hw_engineer\worktree\intel-80286`
- Branch: `design/intel-80286`, based on `main` commit
  `4612e2ce6313e386b683d13deacf249028749ff6`.
- The recovered design sources, Task 5 reference media, plan, and complete
  ignored `design/intel_80286/work/` evidence directory are in this worktree.
  The retry3 BMC exited before the directory was moved, so its outputs are
  preserved here rather than in the original checkout.

## Recovered source identity (historical baseline)

The retry3 SymbiYosys source snapshot was the last complete CPU/formal source
copy available after the checkout reset. The restored core RTL SHA-256 is
`c77cfbcedb8e0868a9826ad3df033e5b1f586338082018d3be905241fd54a702`; the
restored CPU property source SHA-256 is
`4d184fc59ad991c3ac02b81530b1e69e8965e7d11816886f6a9b4e2368fe3f57`.
There are 207 assertions, one assumption, and 49 covers in the recovered
property inventory. The protected-mode fixture header has SHA-256
`ca589bf34dc756d24f5316f0cbbf3aff043ea184f82baa3f34b96f8caad804fb`.

Restored tracked files currently include the CPU and its 13 RTL submodules,
seven formal property files, `formal/intel_80286.sby`, the protected-mode
fixture, the ring-0 integration contract, this status file, and the
continuation plan. The prior Verilator binary and build manifest are preserved
under `design/intel_80286/work/sim/`; the manifest matches all 14 RTL sources
and the binary, but 12 C++ testbench inputs are missing and the recovered
fixture differs from the fixture recorded by the manifest. Do not present the
old full runner as source-reproducible. A new focused testbench and build
script have been added from the recovered Intel-backed fixture and audited
against the current 14 RTL sources.

## Formal and simulation evidence

- Task 4 retry2 depth-24 BMC passed without a counterexample in 26m13s. Its
  prove base case passed, but k-induction found that the original fixed-address
  assertion was false: accepted bytes advance the IDT address, and reset can
  cancel the request while return-state bookkeeping is stale. The corrected
  property tracks `memory_index` for both gate-tail and gate-validation reads
  and requires reset deasserted plus an active bus request.
- Task 4 retry3 depth-24 BMC passed after 30m26s with no counterexample. Its
  complete evidence tree is now under
  `design/intel_80286/work/task4_protected_event_retry3/` in this worktree.
  The standard depth-12 prove passed its base case but induction failed at
  `intel_80286_props.sv:43` on a trace starting from a non-reset event-gate
  state while PE is clear. ABC PDR proved the corresponding assertion output
  252 in frame 7, confirming that specific induction trace is not
  reset-reachable. The latest PDR log proves 283 outputs through frame 51; the process
  is no longer present and no final SBY PASS record was written, so the full proof
  remains incomplete. The latest depth-64 cover log saved 43 witnesses and
  reached the check at step 39 before the process stopped, also incomplete.
  A hash audit confirms all 21 RTL/property source files in the BMC, prove,
  PDR and cover snapshots matched the recovered source tree at that checkpoint. Strict Verilator
  5.052 lint (`--lint-only -Wall`) passes without warnings. The logs are under
  `design/intel_80286/work/task4_protected_event_retry3/`. The formal
  RTL/property snapshot audit is complete; the old runner's missing C++ inputs and final proof/config/
  result closure remain open.
- Fresh generic Yosys synthesis of all 14 current RTL files passes with 28,595
  cells including submodules; the log is
  `design/intel_80286/work/synth_current/yosys.log`. The historical 22,359-cell
  result predates the integrated bus-owner, code-load, and segment-load
  modules, so it is not the current hierarchy count.
- Earlier Task 4 focused simulation covered the #GP frame, error-code removal,
  handler DS repair, IRET retry, exact successor and HLT in both wait modes,
  reset cuts, and four strict RTL mutations on the original checkout. The
  preserved runner was replayed after recovery and exited 0. Its output
  includes `both wait modes complete protected #GP recovery and reset cuts
  across gate, descriptor, frame and IRET commit`, along with the existing
  real-mode/component suites. The binary SHA-256 is
  `a80516521b0bcfc8c076c2dfe9531618a781c72467fb9b0197cc8943f6eeadce`; its
  manifest matches the recovered RTL. The replay log is
  `design/intel_80286/work/sim/recovered_runner_replay.log`. Because the
  testbench source inputs are missing, this is a preserved-binary replay, not
  a source-audited rebuild. The four historical mutation results have not
  been rerun from this worktree.
- The new source-controlled `tb/protected_mode_replay.cpp`, run by
  `scripts/run_protected_mode_replay.sh`, was built against all 14 current RTL
  files and passed with and without READY stalls. It checks the fixture's
  exact retired PC/successor sequence, descriptor/gate reads and accessed
  writes, protected #GP packet and frame, handler commit, denied operand
  request, IRET retry and final HLT state. Its captured log is
  `design/intel_80286/work/protected_mode_replay_results/replay.log`; its
  exact source/tool/binary manifest is beside it. It also resets after the
  handler descriptor read, the first protected frame byte, and the IRET CS
  accessed-byte write, then verifies exact recovery; the accepted frame byte
  remains in external memory across reset. The broader historical reset-cut
  matrix and four mutation checks are still not reproduced by source here.
- Task 3 retry44 BMC/prove passed; cover stopped incomplete at step 41 after
  44 witnesses. This is not a complete proof of the 80286.

## Task 5 media recovery and initial prerelease boot attempt

The SDK 1.00 media was already present in ignored `scratchpad/`; it was not
missing. All nine raw 1.2 MB images and the extracted `CPGREP` sample have been
hash-verified. `extracted/samples/APPS/README` identifies CPGREP as
“Protect” (protected mode) and describes it as a multi-threaded fast string
search program. The C and EXE hashes are recorded in
`design/intel_80286/report/2026-10-25-task5-media.md`; the earlier recovery
summary had these two filenames’ hashes reversed. The source set is an OS/2
prerelease build, not final OS/2 1.0.

A local PCjs headless run loaded the SDK program disk and a local hard-disk
image via `--diskette` and `--disk`, then printed the OS/2 Version 10.0,
Revision 3.42.1.1 banner. The AT BIOS reported `1782-Disk Controller Failure`.
After F1, the banner printed again but no command-shell prompt appeared; an
injected CPGREP command produced no program output. This was a failed initial
prerelease boot attempt, not a CPGREP run. It was superseded as the independent
software baseline by the later [Playwright CLI PCjs replay](../../design/intel_80286/report/2026-10-27-os2-cpgrep-pcjs-replay.md),
which runs the unchanged SDK CPGREP binary under retail OS/2 1.0 and verifies
the expected match. That remains emulator evidence only: no instruction trace
or RTL execution has been captured, and PCjs is not a normative 286 source.

## Remaining scope

Task 4 only implements a bounded same-level protected vector-13 path. Task 5
selects the Microsoft OS/2 SDK 1.00 `CPGREP.EXE` sample for real-software
validation. The emulator baseline passes under retail OS/2 1.0, but CPGREP has
not run on the RTL and independent 286 trace evidence is open. Independent INS
port timing, remaining string-fault semantics, full protected-fault delivery,
nested-fault escalation, broader ISA completion, real-software regression,
and full-suite closure remain open. The overall 80286 objective is incomplete.

## Current handoff — protected outer IRET faults, 2026-10-28 16:34 UTC

The full CPU objective remains active and incomplete. The current change closes
two protected return-CS descriptor-fault cases; it does not close invalid
outer-SS, earlier null/inward-CS, return-IP/frame-boundary, nested delivery or
the broader protection contract.

Changed in this slice:

- `design/intel_80286/src/intel_80286.sv`: deliver protected IRET code-load
  #NP/#GP faults at the IRET instruction; convert a system descriptor in the
  CS slot to #GP(selector); clear pending outer-return state before delivery.
- `design/intel_80286/tb/bootstrap.cpp`: add
  `--protected-iret-faults`, with non-present code and system-descriptor cases
  in both READY modes. Each verifies the error frame, rejected-descriptor
  traffic, unchanged original five-word frame, handler repair, IRET retry and
  exact ring-3 successor.
- `design/intel_80286/spec/protected_privilege_transition.md` and
  `design/intel_80286/spec/protected_execution.md`: narrow the open-fault
  statement to the cases still uncovered.
- `design/intel_80286/report/2026-10-28-protected-iret-fault-recovery.md`:
  source, implementation, test scope, hashes and remaining limits.
- `plans/286/README.md`, this status file and the revised audit plan: current
  progress and next actions.

Current source/build identity:

- Worktree `B:\ai_hw_engineer\worktree\intel-80286`, branch
  `design/intel-80286`.
- `src/intel_80286.sv` SHA-256
  `0eff3537e99e2a7ffb61189f016418209a3546917b2261e34ea5df261a7e6efc`;
  `tb/bootstrap.cpp` SHA-256
  `9e775787f04c1b82ff0c37ef37731e9673122ad3c4c3a904d4dd46efb59fa0a2`.
- Verilator 5.052, g++ 15.2.0, `-Wall`; runner fingerprint
  `b4d78d68b6f29a1caf0a77d6f0f6348c11eb21c5a8a2406bb21586a3cda9ef50`.
- Build manifest and binary:
  `design/intel_80286/work/iret_faults_20261028_02/sim/`.
- Focused and full bootstrap logs:
  `design/intel_80286/work/iret_faults_20261028_02/protected_iret_faults.log`,
  `outer_iret.log`, and `bootstrap.log`.

Passed commands: container `python3 scripts/preflight.py`, strict runner build,
`Vintel_80286 --protected-iret-faults` (4/4), `--outer-iret`, and the complete
default bootstrap. `sh scripts/run_synth.sh` exited 0: all twelve targets
produced netlists and every log reports zero structural problems. Yosys 0.69
logs and JSON files are under
`design/intel_80286/work/iret_faults_20261028_01/synth/`. No current-source
connected-core formal run has been made for this RTL change. Existing
whole-core PDR PID 4917 was observed active on an older 21-file snapshot and
cannot verify this source.

Issue #80 remains Open/Building with Agent Codex, Path
`ai_hw_engineer/design/intel_80286`, and Start date `2026-10-23`; no project
fields were changed. The verified issue checkpoint is
[comment 6474767733](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6474767733).
Next, add source-backed cases for the earlier null/inward-CS
rejection and invalid outer-SS descriptor paths, then continue task-gate,
nested-fault, current-source formal, independent software, native timing and
full release verification. Preserve the existing dirty worktree and evidence.
