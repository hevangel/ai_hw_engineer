# Full 80286 completion requirements

The project objective is a complete, independently verified Intel 80286
implementation. A passing subset regression, synthesis run, or bounded
protected-mode slice does not complete that objective. The architectural
reference is Intel order 210498-005; later x86 behavior must not be assumed
when the 286 documentation is silent.

## Current verification checkpoint — 2026-10-30

A standalone processor-extension data-transfer engine now has directed
even/odd, both-direction, READY, request and reset tests and a successful
component synthesis. It is not connected to the CPU or native bus; its
ownership, fault and real-80287 gates remain open. The preceding D8 CPU full
simulation and software jobs have exited successfully, but the PEDC source was
added during those runs, so they are not a frozen-tree qualification of this
new component. See the [PEDC report](../report/2026-10-30-pedc-component.md).

The subsequent D8 register-form change adds independently captured command
and instruction-pointer transfers and passes the scoped functional and native
bus tests; see the [physical D8 report](../report/2026-10-30-d8-physical-command.md).
The current `intel_80286.sv` SHA-256 is
`cb5df30bde2b91bacd8fbf5d802a2fbab5b6c3b004f9ee6f77f3bb1772c08ffc`.
A full simulation and historical-software run for the D8 CPU exited zero; they
began before the new standalone channel files were added. The D8 depth-24 BMC
is still running on its saved CPU snapshot. The synthesis script reads the
source directory for multiple targets and was running while the new component
was added, so its eventual result cannot establish a single frozen-tree run.
The WAIT/TF synthesis completed successfully on the preceding CPU source, and
its depth-24 BMC is still running on that preceding snapshot; neither is proof
of the D8 RTL.
Processor-extension memory transfers and attached-80287 validation remain open.

The corrected WAIT/TF priority boundary passes directed CPU regression,
strict lint, a 210-PASS full simulation and historical-software regression.
The unchanged IBM AT BIOS also passes its refresh-indication loop through
`F000:03A2` on a partial native fixture. The two CPU replay scenarios use
captured I/O and do not independently verify peripheral behavior. The RAS
trigger and bank PROM wiring have separate scoped checks, but real DRAM,
physical timing and the original type-1 U72 PROM contents remain open.
At that checkpoint synthesis and BMC were still running; the earlier PDR uses
an older source snapshot and does not qualify the current core. See the
[WAIT report](../report/2026-10-30-wait-tf-priority.md) and
[bank report](../report/2026-10-30-at-bank-select.md).

## Previous checkpoint: DMA page-register BIOS — 2026-10-29

The unchanged IBM AT BIOS passes its page-register test through `F000:038A`
using the explicit CPU-visible page fixture. The two virtual-clock/READY
scenarios match Unicorn for 247,196 and 1,295,769 CPU states and data
transactions using captured I/O inputs. The full software entry point and
standalone page fixture check pass. Page-driven DMA addressing, bus
arbitration, refresh, physical timing and full POST remain open. See the
[page BIOS report](../report/2026-10-29-at-page-bios.md).

## Previous checkpoint — 2026-10-29

The IBM AT BIOS passes both channel-1 timer tests and both DMA-controller
register tests through `F000:0302` using the 80286/8254/8237 fixture. Two
virtual-clock/READY scenarios match Unicorn for 197,920 and 1,246,493 CPU
instruction states with captured I/O inputs; the full software entry point
exits 0. See the [DMA BIOS report](../report/2026-10-29-at-dma-bios.md).
DMA bus mastering, cascade and refresh, later POST/boot, native timing,
independent peripheral verification and whole-core acceptance remain open.
The prior PDR container is absent without a terminal result; a new
current-source PDR later failed; the subsequent BMC also found a stale state
bound. The corrected-bound BMC and an older-snapshot PDR are live as recorded
in the [formal plan](formal_plan.md). Neither is a current-source proof.

## Previous checkpoint — 2026-10-29 06:40 UTC

Both READY modes now check shutdown when the #DF task-gate target TSS is
not present after the preceding #TS handler-entry fault. Focused task-gate
coverage passes 32 executions and full bootstrap passes 110 checks. The
follow-up changes the testbench only; see the
[handler-entry report](../report/2026-10-29-task-gate-handler-entry.md).
Other #DF entry fault classes and the full-chip gates remain open.

## Previous checkpoint — 2026-10-29 06:31 UTC

Two READY-policy task-gate handler-entry cases now cover a not-present #TS
target TSS while delivering a contributory #TS. RTL escalates to #DF, enters
the valid #DF task gate, preserves the first fault context, and supports repair
plus task-IRET to the exact resumed successor. The focused option passes 30
cases/executions (12 event, 16 incoming-task recovery, 2 handler-entry); full
bootstrap passes 110 checks. See the
[handler-entry report](../report/2026-10-29-task-gate-handler-entry.md) and
[issue checkpoint 6489742960](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6489742960).

Other handler-entry and #DF-entry fault combinations, connected-core formal,
full POST/boot, OS/2 CPGREP on RTL, native-interface qualification and
whole-CPU acceptance remain open.

## Previous checkpoint — 2026-10-29 06:00 UTC

The task-gate suite now includes 16 task-entry fault-recovery executions:
eight incoming-selector faults under both READY policies (null, wrong-type and
not-present CS; null and not-present SS; not-present DS/ES; wrong-type LDTR).
A second task gate delivers each fault to a handler that repairs the saved
selector and task-IRETs to the exact resumed successor. Together with 12
external-INTR/software-INT/#GP/NMI cases, the focused option passes 28
executions. The full default bootstrap passes 109 checks with no failures or
errors. See the
[fault-recovery report](../report/2026-10-29-task-gate-fault-recovery.md).

Faults during task-gate handler entry, current-source connected-core formal,
full POST/boot, OS/2 CPGREP on RTL, remaining protected event/fault
combinations, native-interface qualification and whole-CPU acceptance remain
open. The issue update is recorded in
[comment 6489249590](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6489249590).

## Previous checkpoint — 2026-10-29 04:22 UTC

Intel 210498-005 section 8.3 step 7 requires incoming selector checks in the
order SS, CS, DS, ES; step 8 then checks IP. A combined-fault case reproduced
the previous CS-before-SS mismatch (`#TS(0010)` instead of `#SS(0188)`). The
RTL now validates LDT, SS, CS, DS, ES and then IP. The LDT matrix checks read
order, accessed-byte writes and partial effects. Full simulation passes 197
checks with no failure/error markers; all 13 exact-source Yosys targets pass
39 structural checks. Current-source code-load BMC, k-induction and cover pass
with eight witnesses. The IBM AT BIOS replay reaches checksum success after
196,846 exact instruction states; helper, IRQ8 and system-register workloads
pass. See the
[SS-before-CS report](../report/2026-10-29-task-switch-ss-before-cs.md).

The preserved PDR remains active at frame 166 with 344/411 outputs proved and
67 timeout retries on a stale source snapshot. Current-source connected-core
formal, full POST/boot, OS/2 CPGREP on RTL and whole-CPU acceptance remain
open. The prior IP-order checkpoint is below.

## Previous checkpoint — 2026-10-29 03:30 UTC

Intel 210498-005 section 8.3 step 8 requires checking incoming IP after the
incoming SS/CS/DS/ES selectors. A directed case exposed the previous RTL
reporting `#GP(0)` before the architecturally earlier `#SS(0)` for null SS plus
out-of-limit IP. The RTL now defers the IP check until after those selectors;
four READY-mode/fault-priority cases pass. Full `scripts/run_sim.sh` passes 196
checks. See the [validation-order report](../report/2026-10-29-task-switch-ip-validation-order.md).
All 13 targets of the Yosys 0.69 rerun against this changed RTL completed
with exit 0, JSON netlists and three zero-problem checks per target.

Current-source connected-core formal and whole-CPU acceptance remain open.
The preserved PDR is still active on a separate stale 21-file snapshot at
frame 166 with 344/411 outputs proved and 67 timeout retries. Preserve it and
defer a competing connected-core run until it terminates; this snapshot still
differs from current RTL. See the
[task-switch validation-order report](../report/2026-10-29-task-switch-ip-validation-order.md).
The checkpoint was posted and read back in
[issue comment 6487134519](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6487134519).

## Previous checkpoint — 2026-10-29 02:50 UTC

The current-source bounded IBM AT software regression now passes through the
original ROM-checksum success checkpoint: 196,846 exact BIOS instruction
states, plus the original-BIOS helper, IRQ8 handler and system-register
self-tests against Unicorn 2.1.4 traces. This does not claim full POST or boot;
OS/2 SDK 1.00 CPGREP still has no RTL trace. See the
[current-source software report](../report/2026-10-29-historical-software-current-source.md).

Current-source connected-core formal and whole-CPU acceptance remain open.
The preserved PDR is still active on the separate stale 21-file snapshot at
frame 118 with 343/411 outputs proved and 50 timeout retries. See the
[PDR source-epoch report](../report/2026-10-29-pdr-source-epoch-audit.md).
Project fields remain Open/Building, Agent Codex, Path
`ai_hw_engineer/design/intel_80286`, first Start date `2026-10-23`, Sprint 1;
the issue checkpoint was posted and read back in
[comment 6486536094](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6486536094).

## Previous checkpoint — 2026-10-29 02:38 UTC

The exact-source run extended Table 8-1 rows 4–5 through both #DF outcomes
for all five invalid incoming-LDTR categories. Malformed first-fault and #DF
gates reach sticky shutdown in ten executions; valid #DF task-gate delivery
saves the faulting TSS and reaches the exact handler successor in ten more,
across both READY modes. The not-present valid-task case uses selector `0078`
because the #DF target TSS occupies selector `0070`. See the
[incoming-LDTR escalation report](../report/2026-10-29-incoming-ldtr-escalation-variants.md)
and [Table 8-1 audit](../report/2026-10-29-table-8-1-task-entry-audit.md).

Preflight, strict Verilator 5.052 `-Wall` build, focused `--iopl-controls`,
and full `scripts/run_sim.sh` pass. The full log has 195 `PASS:` lines and no
failure/error markers; protected replay passes 79 cases in both READY modes.
Only testbench code changed, so existing Yosys synthesis remains applicable.
The checkpoint still has current-source formal, remaining task-entry phases
and whole-CPU acceptance open. The preserved PDR remains
active at its last logged frame 118 (343/411 outputs, 50 timeouts) on a stale
source snapshot. See the
[PDR source-epoch report](../report/2026-10-29-pdr-source-epoch-audit.md).
Project readback remains Open/Building, Agent Codex, Path
`ai_hw_engineer/design/intel_80286`, first Start date `2026-10-23`, Sprint 1;
see [issue comment 6486405063](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6486405063).

## Previous checkpoint — 2026-10-29 02:28 UTC

The exact-source run reviewed Intel Table 8-1 rows 1–3: direct target-TSS
faults check not-present `#NP`, busy `#GP`, short available `#TS`, and
not-present-plus-short `#NP` priority. Six nested #DF cases show busy, short,
and not-present-plus-short #DF target descriptors enter shutdown before task
state writes in both READY modes. Row 13 DS TI/null-LDTR `#GP(005C)` and
DS/ES GDT-limit `#GP(0188)` escalation also pass at GDTR.limit `0187`; the
corrected fixture reran all incoming CS, SS, DS, ES and LDTR limit cases at
that exact boundary. See the [TSS preflight report](../report/2026-10-29-incoming-tss-preflight-double-fault.md),
[DS/ES validity report](../report/2026-10-29-incoming-ds-es-validity-double-fault.md)
and [Table 8-1 audit](../report/2026-10-29-table-8-1-task-entry-audit.md).

Preflight, strict Verilator 5.052 `-Wall` build and focused
`--iopl-controls` pass. Full `scripts/run_sim.sh` exits 0 with 195 `PASS:`
lines and no failures or errors; protected replay passes 79 cases in both
READY modes. Only testbench and fixture code changed, so existing 13-target
Yosys synthesis remains applicable. Project readback confirms Open/Building,
Agent Codex, Path `ai_hw_engineer/design/intel_80286`, first Start date
`2026-10-23`, and Sprint 1. The checkpoint was posted and read back in
[issue comment 6486238114](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6486238114).

The preserved whole-core PDR has no terminal result. At 02:27:59 UTC it was
active at frame 118 with 343/411 outputs proved and 50 timeout retries. The
source-epoch audit found 19/21 copied inputs match current source, while
`intel_80286.sv` and `intel_80286_code_load.sv` differ, so it cannot establish
current-source proof. Preserve it and avoid a competing core run until it
terminates. See the [PDR source-epoch report](../report/2026-10-29-pdr-source-epoch-audit.md).
Current-source connected-core formal, other task-entry fault phases, authentic
software and full CPU acceptance remain open.
## Previous checkpoint — 2026-10-29 00:21 UTC

Added four post-transfer incoming-CS non-present `#NP` first-fault executions.
Intel 210498-005 Table 8-1 row 7 maps selector `0008` to `#NP(0008)`. A
malformed `#NP` gate escalates to null-error `#DF`; invalid-vector-8 shutdown
and valid `#DF` task-gate delivery pass in both READY modes. The cases check
exact event context, gate reads, the incoming TSS save with CS=`0008`,
backlink/busy state, null error push and exact handler successor. Playwright
CLI visually verified the row; see the
[incoming-CS #NP report](../report/2026-10-29-protected-cs-np-double-fault-first-fault.md).

Preflight passes; strict Verilator 5.052 `-Wall` `scripts/run_sim.sh` exits 0
with 175 `PASS:` lines and no failures/errors; protected replay passes 79
cases in both READY modes. Current-source formal, other task-entry fault
phases, authentic software and full CPU acceptance remain open. The
checkpoint was posted and read back in
[issue comment 6484304062](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6484304062).

## Previous checkpoint — 2026-10-29 00:13 UTC

Added four post-transfer incoming-CS first-fault executions. Intel 210498-005
Table 8-1 row 6 maps a null incoming CS to `#TS(0000)`. A malformed `#TS`
gate then escalates to null-error `#DF`; both invalid-vector-8 shutdown and
valid `#DF` task-gate delivery pass in both READY modes. The cases check exact
event context, gate reads, shutdown quiescence, faulting TSS save,
backlink/busy state, error push and handler successor. See the
[incoming-CS #DF report](../report/2026-10-29-protected-cs-double-fault-first-fault.md).

Preflight passes; strict Verilator 5.052 `-Wall` `scripts/run_sim.sh` exits 0
with 174 `PASS:` lines and no failures/errors; protected replay passes 79
cases in both READY modes. Current-source formal, other task-entry fault
phases, authentic software and full CPU acceptance remain open. The checkpoint
was posted and read back in
[issue comment 6484222610](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6484222610).

## Previous checkpoint — 2026-10-29 00:01 UTC

Added an incoming-task ES system-descriptor case. Intel Table 8-1 row 13
maps an invalid DS/ES selector to `#GP`; ES selector `0050` checks exact
`#GP(0050)`. The CS/SS/DS/ES fault matrix now covers 24 configurations and
48 executions in both READY modes. The SS RPL-mismatch case checks exact
`#SS(0028)` from Table 8-1 row 9. See the
[ES system-descriptor report](../report/2026-10-29-incoming-es-system-descriptor.md).

Preflight passes; strict Verilator 5.052 `-Wall` `scripts/run_sim.sh` exits 0
with 173 `PASS:` lines and no failures/errors; protected replay passes 79
cases in both READY modes. Current-source formal, remaining task-switch fault
phases, authentic software and full CPU acceptance remain open.
The checkpoint was posted and read back in
[issue comment 6484047009](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6484047009).

## Earlier checkpoint — 2026-10-28 23:55 UTC

Added an incoming task SS selector RPL-mismatch case. Intel Table 8-1 maps an
invalid incoming stack selector to `SF` (#SS); selector `002B` at CPL 0
delivers exact `#SS(0028)`. The CS/SS/DS/ES fault matrix now covers 23
configurations and 46 executions in both READY modes. The earlier `#TS`
expectation was corrected after checking the source row and observed packet;
RTL is unchanged. See the
[incoming SS RPL report](../report/2026-10-28-incoming-ss-rpl-fault.md).

Preflight passes. The strict Verilator 5.052 `-Wall` full run records 173
`PASS:` lines and no failures/errors; protected replay passes 79 cases in
both READY modes. Current-source formal, remaining task-switch fault phases,
authentic software and full CPU acceptance remain open.

## Earlier checkpoint — 2026-10-28 23:47 UTC

Added the missing incoming ES GDT-limit fault. The CS/SS/DS/ES selector-fault
matrix now covers 22 configurations and 44 executions in both READY modes.
Selector `0188` beyond GDT limit `0187` raises exact `#GP(0188)` after valid
CS/SS/DS checks, with no read of the rejected descriptor. See the
[ES GDT-limit report](../report/2026-10-28-incoming-es-gdt-limit.md).

Preflight passes; strict Verilator 5.052 `-Wall` `scripts/run_sim.sh` exits 0
with 173 PASS lines and no failures/errors. The same run passes the 460-case
incoming-LDT DPL/RPL matrix, eight LDT-limit faults, and the protected replay
with 79 cases in both READY modes. No RTL behavior changed; the existing
13-target Yosys 0.69 synthesis remains applicable. Current-source formal,
remaining task-switch phases, authentic historical software, native timing
and full release acceptance remain open. The checkpoint was read back in
[issue comment 6483734952](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6483734952).

## Previous checkpoint — 2026-10-28 23:41 UTC

Incoming non-null-LDT task entry now passes 460 valid privilege executions
across CPL0–2: CS/SS use DPL=RPL=CPL, while DS/ES cover every DPL/RPL pair
satisfying `max(CPL,RPL) <= DPL`, in both READY modes. The LDT limit is
`0027`; the ES descriptor ends exactly at its upper boundary. Eight additional
cases place CS/SS/DS/ES at offset `0038`, checking Table 8-1 `#TS/#SS/#GP`,
exact selector error `003C`, transferred-task state and no descriptor access
beyond the LDT limit. See the
[incoming-LDT report](../report/2026-10-28-incoming-ldt-privilege-limit-matrix.md).

The Intel manual's §7.4.1 and Table 8-1 were visually checked with
`playwright-cli`. Preflight passes; strict Verilator 5.052 `-Wall`
`scripts/run_sim.sh` exits 0 with 173 PASS lines and no failures/errors.
Protected replay passes 79 cases in both READY modes. No RTL behavior changed,
so existing 13-target Yosys 0.69 synthesis remains applicable. Current-source
connected-core formal, remaining task-switch fault phases, authentic
historical software, native timing and full release acceptance remain open.
The older PDR is active on a different 21-file snapshot without terminal
PASS. The checkpoint was posted and read back in
[issue comment 6483636717](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6483636717).

## Previous checkpoint — 2026-10-28 23:30 UTC

The initial valid incoming-LDT matrix covered 58 CPL0–2 executions with
selector RPL=CPL. The eight Table 8-1 LDT-limit cases passed in both READY
modes. Coverage is now expanded to the full allowed DS/ES DPL/RPL boundary.

## Previous checkpoint — 2026-10-28 23:16 UTC

Added 192 direct-TSS far CALL/JMP privilege executions across CPL0–2,
selector RPL0–3, TSS DPL0–3 and both READY policies. All 104 permitted
transfers and 88 denials pass the Intel §8.3 boundary
`max(CPL,RPL) <= TSS_DPL`, checking exact task successors, nested CALL/IRET
state, JMP busy state, #GP frames and preflight side effects. The focused
`--iopl-controls` run passes 23 suite groups; strict Verilator 5.052 `-Wall`
full `scripts/run_sim.sh` exits 0 with 172 PASS lines and no failures/errors.
Protected replay passes 79 cases in both READY modes. See the
[direct-TSS privilege report](../report/2026-10-28-direct-tss-privilege-matrix.md)
for source, hashes and retained evidence.

No RTL behavior changed, so the previous 13-target Yosys 0.69 synthesis
remains applicable. Current-source connected-core formal, remaining
task-switch fault phases, authentic historical software, native timing
qualification and full release acceptance remain open. The preserved PDR is
still active on another 21-file source snapshot without terminal status; it
does not prove current source. Issue #80 remains Open/Building, Agent Codex,
Path `ai_hw_engineer/design/intel_80286`, first Start date 2026-10-23.
The checkpoint was posted and read back in
[issue comment 6483230260](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6483230260).

## Previous checkpoint — 2026-10-28 22:40 UTC

Expanded direct far task-gate privilege coverage to 192 combinations of CPL
0–2, selector RPL 0–3, gate DPL 0–3, CALL/JMP and both READY policies. All 104
permitted transfers and 88 denials pass with exact successor, frame and task
preflight checks. The fresh strict Verilator 5.052 `-Wall`
`scripts/run_sim.sh` exits 0 with 170 `PASS:` lines, no failures/errors, and
79 protected replay cases in both READY modes. Source hashes, runner identity
and retained evidence are recorded in the
[direct-transfer report](../report/2026-10-28-protected-direct-task-transfers.md).

Corrected-source Yosys 0.69 synthesis completed all 13 targets with zero
structural problems; no RTL behavior changed afterward. **ASSUMPTION A26** is
still open because the inspected 286 source does not specify the fault
response for nonzero task-gate fields marked unused. Current-source connected-
core proof, remaining task-switch fault phases, authentic historical software,
independent-oracle agreement, native timing qualification and full release
acceptance remain open. The older whole-core PDR is still active on a different
21-file snapshot; at 22:40 UTC the process remained alive, but its latest log
stayed at frame 27 with 342 outputs proved and 31 timeouts, without terminal
PASS. Preserve it and avoid overlapping core formal work. See the
[task-gate source audit](../report/2026-10-28-task-gate-source-audit.md) and
[post-mortem](../../../failure_notes/2026-10-28-intel80286-task-gate-contract.md).
Issue #80 remains Open/Building with Agent Codex, Path
`ai_hw_engineer/design/intel_80286`, and first Start date 2026-10-23. The last
verified checkpoint is
[comment 6482597698](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6482597698).

## Checkpoint — 2026-10-28 22:52 UTC

Added a reachable CPL1/CPL2/CPL3 ARPL matrix. All 384 combinations pass:
source and destination RPL 0–3, register and SS-based memory operands, both
incoming ZF values and both READY policies. Each case reaches its nonzero CPL
through outer IRET, checks only ZF changes, verifies exact instruction fetch
and unprivileged successor execution, and checks conditional memory writes.
The focused `--arpl` run passes and the full `scripts/run_sim.sh` exits 0 with
171 PASS lines, no FAIL/ERROR lines, and the 79-case protected replay passing
in both READY modes. Evidence is under
`design/intel_80286/work/arpl_reachable_privilege_20261028/`; source identity
and results are in the [ARPL privilege report](../report/2026-10-28-arpl-reachable-privilege-matrix.md).

ARPL's reachable nonzero-CPL RPL coverage is now closed as directed simulation;
alternate-stepping evidence and current-source whole-core proof remain open.
The older whole-core PDR remains active on its different 21-file snapshot. At
22:21 UTC its log was still frame 27 with 342/411 outputs proved and 31
timeouts, with no terminal result. Do not treat it as current-source proof.
The 13-target Yosys 0.69 synthesis remains valid because no RTL behavior has
changed. Issue #80 is Open/Building with Agent Codex, Path
`ai_hw_engineer/design/intel_80286`, and first Start date 2026-10-23; the
checkpoint was posted and read back in [comment 6482816712](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6482816712).

## Previous checkpoint — 2026-10-28 20:07 UTC

The 82C284 digital RES synchronizer is integrated with the native CPU, bus and
82288. Both delay settings and the connected reset paths pass Verilator 5.052
`-Wall`; full 13-target Yosys 0.69 synthesis reports zero structural problems.
The protected event regression now covers first-fault `#NP` and `#SS` IDT-limit
escalation plus first-fault `#TS` from an invalid incoming LDTR, with both
shutdown and valid #DF task-gate delivery. The exact-source full
`run_sim.sh` passes 165 cases with 79 protected replay cases in each READY
mode. Analog startup, board clock/phase, complete #DF coverage, current-source
connected-core proof, authentic historical software and release acceptance
remain open. See the [reset-source report](../report/2026-10-28-reset-source-audit.md),
[native-clock report](../report/2026-10-28-native-clock-phase.md), and
[first-fault report](../report/2026-10-28-protected-double-fault-first-faults.md).

The older whole-core PDR remains active on a different 21-file source snapshot
and cannot prove current source. Issue #80 remains Open/Building with last
verified Agent Codex, Path `ai_hw_engineer/design/intel_80286`, and first Start
date 2026-10-23. The latest comment was read back at
[issue comment 6478368542](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6478368542);
the integration checkpoint will follow after synthesis readback.

The older whole-core PDR remains active against a different 21-file source
snapshot. At 18:54 UTC it was at frame 89 with 329/411 outputs proved and 50
timeout retries. It does not prove the current source.

## Previous checkpoint — 2026-10-28 15:54 UTC

Added 16 protected-mode WAIT interruption cases: CPL1/CPL2 × NMI/INTR ×
interrupt/trap gate × both READY modes. They check that BUSY-stalled WAIT can
take a protected event, perform the TSS stack switch, write the exact outer
frame, and IRET to the tested successor without retiring WAIT. Strict
Verilator 5.052 `-Wall`, focused `--protected-wait`, and full default bootstrap
pass. This is testbench-only; assumption A25 (saved IP after WAIT), native pin
timing, connected-core proof and the full release gate remain open. Details
and hashes are in the
[protected WAIT report](../report/2026-10-28-protected-wait-interruption.md)
and [issue comment 6473853937](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6473853937).

The whole-core PDR remains active on its older 21-file snapshot; its last
recorded checkpoint is at 15:42 UTC, frame 11, with 326/411 assertion outputs
proved and five timeouts. It does not establish current-source behavior.

## Previous checkpoint — 2026-10-28 15:46 UTC

Playwright CLI visually reviewed Intel's 1986 *Microsystem Components
Handbook: Microprocessors, Volume I*, printed page 4-31. It confirms the
reserved I/O ports, ESC IOPL/CPL bypass, PEREQ memory-operand transfers,
`00FAh` word I/O plus one or two memory cycles, and local-bus priorities, but
still does not provide the per-ESC command byte/port sequence. See the
[80287 source report](../report/2026-10-28-80287-processor-extension-slice.md)
and [issue comment 6473621922](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6473621922).
No RTL or verification results changed.

The preserved whole-core PDR remains active on an older 21-file snapshot. Its
15:42 UTC log is at frame 11 with 326/411 assertion outputs proven and five
timeouts in that pass; it does not verify current source. Current-source
connected-core proof and the full release gate remain open.

## Previous checkpoint — 2026-10-28 15:32 UTC

The functional core now accepts eligible real-mode NMI and IF-enabled INTR
while opcode `9Bh` WAIT is stalled by active-high BUSY. The new test holds
BUSY high through the handler and IRET, checks the event frames and INTR
acknowledgement, and confirms no WAIT retirement. The Intel 1983 iAPX 286/10
handbook explicitly says interrupts may occur while waiting, but it does not
state the saved IP. ASSUMPTION A25 uses the already-advanced successor IP and
remains open for independent 286 validation. The handbook's BUSY polarity
wording conflicts with the later 210760-002/manual data-sheet evidence; the
existing active-high implementation is retained. The same handbook confirms
`00FAh` word transfers for ESC memory operands, but still does not provide the
per-ESC command bytes or port order. See the
[WAIT interruptibility report](../report/2026-10-28-wait-interruptibility.md).
The GitHub checkpoint is [issue comment 6473353919](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6473353919).

The strict Verilator 5.052 `-Wall` runner build, focused `--processor-extension`
slice and full default bootstrap pass. The 58-line bootstrap log SHA-256 is
`6e8e3eab5bfe50f8a821377cc88a703a01a83f8d659592d2d0672458c469e873`; the
source/tool fingerprint is
`db8e315bfb83a4ae344d21b8a2deedca0fe4dcc1f6eea368f1e358103b2575d0`. Exact
source and evidence hashes are in the linked report. The earlier 48-case
CPL1/CPL2 event matrices remain covered by the full default run.

At 15:32 UTC the separate whole-core PDR was still active on its earlier
21-file snapshot, at frame 8 with 326/411 assertion outputs proven and one
timeout retry in that pass. It does not cover the current WAIT change and has
no terminal result. Current-source connected-core proof, the aggregate
exact-source audit, full protected-mode/software coverage and release
acceptance remain open.

## Previous checkpoint — 2026-10-28 14:46 UTC

The strict runner build and complete `--selector-exec` slice now pass 768 new
reachable CPL1/CPL2 query cases across writable data, readable nonconforming
code and readable conforming code, every DPL/RPL pair, all four query
instructions and both READY policies. Existing evidence also includes 160
reachable CPL3 query cases. The new matrix checks exact ZF-only behavior,
destination preservation, full descriptor read ordering, no descriptor writes
and exact successor execution. The full default bootstrap also passes with
this matrix wired in; its log SHA-256 is
`b8b4f5785f276e9336a009fe23e724073e7d58c3aad5b00b722b478943629d41`. This is
testbench-only; no RTL changed. Source, runner identities and limits are recorded in
[`2026-10-28-selector-query-ring12.md`](../report/2026-10-28-selector-query-ring12.md).

The 12 standalone component configurations have passed all 36 BMC/prove/cover
tasks, with 59 reached cover witnesses and 36/36 current-source audit passes.
See the
[component formal report](../report/2026-10-28-formal-components-current.md)
and [issue checkpoint](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6472164584).
At 14:46 UTC, the separate whole-core PDR remained active at frame 89 with
321/411 outputs proven and 70 timeout retries. It runs against an earlier
21-file snapshot and does not verify current source. The successful 80287 ESC
port sequence remains source-blocked. Full current-source proof, whole
protected-mode closure, independent software validation and CPU release
acceptance remain open.

The next source blocker is successful 80287 ESC transfer. Intel 210760-002
Chapter 6 Figure 6-3 (printed page 6-6) specifies the BUSY-bounded data-channel
window and even/odd word cycle count. Intel AP-113 is an 8087/8086 interface
source and cannot supply 80287/286 command bytes. The exact ESC port sequence
still needs a 286/287-specific Intel source or an independent pin trace; no
sequence was inferred.

At 14:18:30 UTC, the separate whole-core PDR remained active on its earlier
21-file snapshot at frame 61 with 321/411 outputs proven and 61 timeout
retries. It does not cover this testbench update or current source. The full
release gate remains open. The current issue checkpoint is
[recorded in issue #80](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6471459873).

### Previous checkpoint — 2026-10-28 13:31 UTC

The SCAS restart-source audit corrected the LOADALL reference to page 14.
Visual inspection confirms that the scanned Intel memo directs the SCAS fault
handler to update SI; its page 13 is unrelated implementation notes. The
ordinary SCAS entry still describes ES:DI and DI advancement, and the local
capture archive has no protected SCAS fault trace. Keep this behavior
release-blocking until an independent 286 trace or primary explanation resolves
the discrepancy. The revised plan also now reflects that protected direct and
string IOPL enforcement is implemented; the combined 480-scenario privilege
regression includes 288 dedicated IOPL/IF cases. Physical port-side-effect
ordering remains open. See the
[SCAS audit](../report/2026-10-28-scas-restart-source-audit.md) and
[IOPL report](../report/2026-10-27-iopl-controls.md).
The inspected Intel manuals establish the 80287 data-channel handshake but do
not provide the complete reserved-port command byte sequence for successful
ESC forms; source that sequence before implementing it.

### Previous checkpoint — 2026-10-28 13:17 UTC

Intel 210760-002 Chapter 6 confirms the physical 80287 BUSY signal is active
high. The core and native wrapper were corrected to active-high busy_i;
ERROR# remains active low. WAIT and ESC now wait while BUSY is high, and
report #MF only after it falls; ESC checks EM/TS #NM first. The corrected
focused processor-extension test passes for WAIT and ESC with delayed ERROR#.
The corrected full run_sim.sh exits 0 and its source-matched protected-mode
replay manifest reports all 79 cases passing. Current-source Yosys 0.69
synthesis passed all 12 targets, with 36 zero-problem checks, no `ERROR:`
lines and 12 JSON netlists. Do not treat previous-polarity synthesis as
evidence for this correction. See the
[report/2026-10-28-80287-processor-extension-slice.md](../report/2026-10-28-80287-processor-extension-slice.md).
The [latest issue checkpoint](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6470033599)
records the same scoped results and unchanged project fields.

The source-backed protocol contract says ESC reserved-port I/O bypasses I/O
privilege checks and requires zero wait states. PEREQ is active high and
PEACK# active low; operand transfers use one I/O operation and one or two
memory operations, with indivisible channel arbitration. Normal ESC command
and operand transactions remain unimplemented.

The exact 21-file whole-core PDR snapshot remains active. At 13:16:02 UTC it
reached frame 23 with 316/411 outputs proved and 27 timeout retries in that
anytime pass; there is no counterexample or terminal result. It predates this
80287 slice and excludes the native wrapper. The aggregate formal audit
remains 36/40, the depth-12 induction result remains UNKNOWN, and the full
release gate is open. The reset edge conflict, analog 82C284 model, MULTIBUS,
board clock generation, complete 80287 transactions, physical qualification
and independent CPGREP-on-RTL evidence remain open.

### Previous checkpoint — 2026-10-28 11:52 UTC

The reset-source audit now includes Intel 210760-002 Chapter 3 printed pages
3-41–3-43, inspected with Playwright CLI. Page 3-41 says CPU RESET's
high-to-low transition must synchronize to CLK; pages 3-42–3-43 describe a
one/two-CLK delay before RESET is driven high and allow a falling edge to be
asynchronous during power-up. The single-CPU edge behavior is unresolved, so
the RTL wrapper remains a conditioned-RESET model pending another primary
82C284 source. The unsupported fixed 38-CLK delay was removed. The connected
native-CPU test passes with a 16-processor-clock conditioned RESET pulse, quiet
bus/controller checks and first fetch at FFFFF0h. The subsequent full
`run_sim.sh` passes, including all 79 protected-mode replay cases; its manifest
is in `work/reset_source_full_sim_20261028/`.

The exact 21-file whole-core PDR snapshot remains active. At 11:52 UTC it is
at frame 60 with 286/411 assertion outputs proved and 89 timeout retries; it
has no counterexample or terminal result. Output 147/property line 189 remains
proved from frame 14. The aggregate formal audit is still 36/40, the standalone
depth-12 induction result remains UNKNOWN, and the full release gate is open.
MULTIBUS, board clock/reset generation, 80287 signaling, physical
qualification, independent CPGREP-on-RTL evidence and aggregate release
closure remain open. See the
[reset source audit](../report/2026-10-28-reset-source-audit.md),
[continuation status](../../../plans/286/STATUS.md), and
[current plan](../../../plans/286/README.md).

### Previous checkpoint — 2026-10-28 11:24 UTC

The non-MULTIBUS local 82288 controller is implemented in
`src/intel_80286_82288.sv` and connected to `intel_80286_native_cpu`. The
wrapper accepts processor-rate `clk_i` and a separately supplied external 2x
`clk_2x_i`; it does not divide or phase-lock the clocks. Directed controller
simulation covers status decode, active-low strobes, READY/CMDLY waits, CENL
and asynchronous CEN gating, early write DEN, back-to-back cycles, halt and
MCE timing. The connected native CPU test checks every exercised command
output. Verilator 5.052 `-Wall` lint passes. The full `run_sim.sh` passes with
142 PASS lines, including all 79 protected-mode replay cases. The complete
Yosys 0.69 `run_synth.sh` exits 0 across 12 targets; each target reports zero
problems in `check -assert`, no target log contains `ERROR:`, and all 12 JSON
netlists were emitted. This work does not close MULTIBUS timing, board clock/reset
generation, 80287 signaling, physical qualification or the overall completion
gate. See
[the 82288 report](../report/2026-10-28-82288-local-controller.md),
[the interface contract](../spec/native_bus_interface.md),
[the continuation status](../../../plans/286/STATUS.md) and the current
[continuation plan](../../../plans/286/README.md).

The separate whole-core PDR run remains active on its exact 21-file snapshot.
At 11:24:22 UTC it reached frame 24 with 280/411 assertion outputs proved and
52 timeout retries; output 147/property line 189 is proved from frame 14. No
counterexample or terminal result is reported. The aggregate formal audit is
still 36/40, the standalone depth-12 induction result remains UNKNOWN, and the
full release gate is open.

### Previous checkpoint — 2026-10-28 10:48 UTC

The independent stages after the stopped aggregate formal proof now pass on the
current LOCK-connected RTL: 141 simulation PASS lines including the 79-case
protected replay; 99,650 independent Unicorn cases / 1,715,162 instruction
states; 68,510 physical captures plus 52 protection captures in both READY
modes; 29 detected mutations; IBM AT BIOS/software regressions; and all 11
Yosys 0.69 synthesis targets with three zero-problem `check -assert` runs per
target. Evidence is under
`work/release_lock_checkpoint_20261028_0720/`.

Formal audit of the aggregate snapshot is 36/40: components pass, core BMC and
prove contain stale property snapshots, core cover did not run, and PDR was not
reached. A separate proof with current properties passes its depth-12 base case
but returns UNKNOWN on induction at line 189 from an induction-only
task-switch/PE state. The separate current-source whole-core PDR later proved
that assertion as output 147 in frame 14. The formal target does not include the native CPU wrapper.
The aggregate has not been rerun after the property edits, so full release
acceptance remains open. See the
[formal induction-gap report](../report/2026-10-28-formal-induction-gap.md),
[live status](../../../plans/286/STATUS.md), and
[issue checkpoint 6465985361](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6465985361).

A separate current-source whole-core ABC PDR run completed Yosys translation
in 299.26 seconds. Its prior pass ended at frame 38 with 273/411 assertions
proved and 135 timeout retries; the current anytime pass has reached frame 6
with 276/411 proved. The run proved the line 189 PE assertion as output 147 in frame
14; the standalone depth-12 result remains UNKNOWN. No counterexample or
terminal result has been reported. All 21 copied RTL and property
files match the worktree. A Playwright CLI rerun reached retail OS/2 1.0's
command prompt and reproduced `CPGREP -yn fast ..\README`, returning the
expected line 11 containing `FAST`. The attempted instruction-history capture
still contains only the OS/2 shell wait loop; no CPGREP trace or RTL execution
evidence has been captured. Playwright CLI inspection of Intel's original
HMOS M82288 datasheet resolved the `CENL` conflict in order 210760-002: the
original part defines it active high and latched at the end of `Ts`, with
sampled-low disabling commands and DEN. The M82C288 datasheet corroborates
this. A non-MULTIBUS local-bus functional profile is now specified; external
system-clock integration remains open. See the
[source reconciliation report](../report/2026-10-28-82288-cenl-source-conflict.md).
The run is under
`work/release_lock_checkpoint_20261028_0720/formal_runs/current_pdr_20261028_0926/`.

See the [formal evidence correction](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6466581278).

### Previous checkpoint — 2026-10-28 07:13 UTC

The connected core now exports and uses LOCK intent for explicit
LOCK-prefixed memory MOV/MOVS/INS/OUTS and rotate-memory operations, and for
implicit memory XCHG. The pin test checks explicit MOV load/store, memory ROL,
XCHG and two iterations each of `REP LOCK MOVSB`, `REP LOCK INSB` and
`REP LOCK OUTSB`, including memory/I/O waits, operand gaps, HOLD exclusion and
release. The focused test and full
`run_sim.sh` pass; the latter includes 141 PASS lines and all 79 protected-mode
replay cases. See the [native LOCK integration report](../report/2026-10-28-native-lock-integration.md).

Yosys 0.69 `run_synth.sh` completed all 11 targets; every log ended normally,
reported zero problems in all three checks and contains no `ERROR:`. The
integrated `intel_80286_native_cpu` target reports 50,003 generic cells. Logs,
JSON netlists and the integrated-log hash are in the LOCK report. Automatic
descriptor-table and processor-extension locks, reset/clock timing, 82288
strobes, 80287 signaling, current-source connected-core formal, CPGREP on RTL,
an independent instruction trace and the complete `run_all.sh` release gate
remain open. The older SBY cover failure and UNKNOWN induction results remain
unresolved. GitHub issue #80 checkpoint:
[comment 6463032004](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6463032004).

## Previous checkpoint — 2026-10-28 06:21 UTC

The `NATIVE_BEATS=1` core now connects to `intel_80286_native_bus` through
`intel_80286_native_cpu`. The connected Verilator test checks even/odd word
reads and writes, READY waits, stable pin values, HOLD/HLDA, two-cycle INTA,
interrupt-frame state and exact IRET/HLT return. The captured `run_sim.sh`
passes with 141 PASS lines, including all 79 protected-mode replay cases.
Yosys 0.69 synthesis and `check -assert` pass all 11 targets, including the
integrated CPU wrapper. Exact evidence is in the [native CPU bridge report](../report/2026-10-28-native-cpu-bridge.md).

The wrapper takes a processor-rate clock and does not model external clock
division or RESET timing; at that checkpoint, core LOCK intent was tied low.
The later LOCK integration is recorded above. Automatic descriptor-table
locks, 82288 command/ALE, 80287 pins, current-source connected-core formal,
CPGREP-on-RTL, an independent instruction trace and the full `run_all.sh`
release gate remain open. The recorded PCjs/OS/2 CPGREP run used
`playwright-cli` and is emulator evidence only. The old cover run ended with
SBY `ERROR`/rc=16 because Yices returned no status; its 45/73 result is stale
after native-beat changes. Corrected depth-12 induction remains UNKNOWN.
See the [latest issue checkpoint](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6462275940).

## Previous checkpoint — 2026-10-28 04:47 UTC

The SDK 1.00 `CPGREP.EXE` ran unchanged in local PCjs v2.26 on an 8 MHz IBM
PC/AT configured with an 80286 and 2 MB RAM, booted to the Microsoft OS/2 1.0
command environment. `CPGREP -yn fast ..\README` returned the expected line
11. This is an independent emulator baseline using retail OS/2 1.0; no
instruction trace was captured and the binary has not run on the RTL. The
source shows that the default command creates two worker threads and uses
OS/2 semaphores and file/console APIs. See the [replay report](../report/2026-10-27-os2-cpgrep-pcjs-replay.md).

A source-backed native CPU-pin contract now exists in
[native_bus_interface.md](../spec/native_bus_interface.md). It distinguishes
80286 pins from 82288-generated ALE/command strobes and specifies address/data
lanes, bus statuses, `Ti/Ts/Tc/Th`, READY waits, bus grant, LOCK, INTA, reset,
shutdown and processor-extension requirements. It is a contract, not an RTL
implementation. The current core still exposes a byte-transaction interface.

The focused `--iopl-controls` suite passes 480 protected privilege scenarios,
234 task-gate entry reset cuts and 180 task-IRET reset cuts, each followed by
exact reset-vector replay in both READY policies. The full default bootstrap,
strict Verilator 5.052 `-Wall` lint, preflight and Yosys full-core synthesis
pass on their recorded source snapshot. Yosys `check -assert` reports zero
problems. CPU properties contain 309 assertions, one assumption and 52 covers;
see the [bus-cycle and reset-cut report](../report/2026-10-27-shutdown-bus-cycles.md)
for hashes and retained logs.

The pre-correction connected-core depth-24 BMC passed with `abc bmc3`: no
output asserted in 24 frames and no counterexample. Its 21-file snapshot
matched the source files then in use; it was a bounded check. The first
depth-12 prove passed its base case but failed temporal induction at the HLT
state assertion because protected shutdown legitimately has `halt_latch=1`
and `state=SHUTDOWN`. The assertion now applies only when `!shutdown_o`, and
formal preflight passes. The corrected prove's depth-12 base case passes, but
induction returns UNKNOWN on assertions at lines 525 and 775. The trace starts
from unconstrained internal state; reset reachability beyond the checked
bound remains unresolved. Source-to-log audit finds 45/73 active cover goals
reached: 38/52 top-level CPU-property covers and 7/21 active component covers.
The newest witness is `intel_80286_muldiv_props.sv:38`, reached at step 32 and
saved as `trace42`; the search advanced to step 33 and reached a 1-hour
wait marker without a new witness or terminal result. The earlier `44/52`
shorthand mixed component hits with the CPU-only denominator. Yices is active
with no failure or terminal result in
`work/formal_runs/core_20261027_04/`. All 21 copied run inputs (14 RTL and 7
property files) match current sources by SHA-256. Because the property changed,
rerun BMC and aggregate exact-source audit; PDR also remains open. The broader #DF
matrix, native-bus implementation and protocol verification, instruction
trace, CPGREP-on-RTL run, and full release acceptance remain open.
## Previous checkpoint — 2026-10-27 11:00 UTC

The combined `--iopl-controls` regression now passes 480 scenarios across
both READY modes. In addition to the previous IOPL/IF/HLT cases, 120 cases
check nonzero-CPL LGDT/LIDT/LMSW/CLTS #GP(0) before operand access and 40
ring-0 controls exercise those forms. The full default Verilator bootstrap
and release preflight pass. The source and evidence are recorded in the
[system-instruction privilege report](../report/2026-10-27-system-instruction-privilege.md).
An additional two-case regression checks nested protected #GP escalation when
the initial #GP handler lookup faults on the IDT limit. The event packet
selects vector 8 with a null error code and preserves the original saved
context, then the interrupt/trap-only gate validator rejects the all-zero
vector-8 descriptor. The 24-case
LLDT/LTR matrix, 480-case privilege matrix, full default bootstrap and release
preflight pass. Current RTL SHA-256 is
`2777eaea08bd5de2247a994d1468ab707f5d596d4e367915bb097c031af75d90`; current
bootstrap testbench SHA-256 is
`42a1726bd7dd589426934650f947788944b732c23c763f2540a222362eb8d137`.
Formal properties now include a #DF transition assertion and cover; preflight
passes with 299 assertions, one assumption and 50 covers, SHA-256
`d650dd7231a11b85b7737a9295afe0161a2cf87c235ae90fff6915f2688b28cb`.
The runner fingerprint is
`50306e079cfaa8a48e8dd565ca9e092620e7aef3dbb5015f7d42333dc9f599d8`.
No connected-core formal result covers this RTL/property pair. Older `_21` cover/PDR jobs
remain active on prior snapshots (cover waiting at step 35 at 10:42:24 UTC;
PDR at frame 25 at 10:39:46 UTC); do not count them as current-source evidence
or start overlapping formal jobs. Full formal closure, IDT task gates, task
switching, the remaining nested-fault matrix and shutdown, independent
historical software and release acceptance remain open. See the
[double-fault checkpoint](../report/2026-10-27-double-fault-escalation.md).
The corresponding [issue #80 checkpoint](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6440006292)
records the same source hashes and remaining completion gates.

### Previous connected-core checkpoint

The `--call-gate-retf-faults` suite now includes an outer-RETF stack-span
`#SS(0)` with exact restart state, no partial access above SS limit, handler
repair, and IRET retry. The case passes in both READY modes and exposed a
missing RET-owner cleanup in the generic memory exception path; that path now
clears the abandoned return state. Release preflight and the full Verilator
bootstrap pass; the captured log is
`design/intel_80286/work/sim_codex_20261027/full_bootstrap.log`. Current RTL SHA-256
is `ffa9248d1866ecea38b2357f265028821a79768349e2ba86b7f0ac036ba6642b`.
Run `_27` passed its base case but failed induction on an overbroad owner/opcode
assertion; it admitted arbitrary simultaneous RET and IRET owners. The
assertion now checks the denied-memory-check cleanup transition directly.
Run `_28` passed its base case but failed induction at line 578 on an arbitrary
BUS return continuation with opcode `83`; the denied-memory-check cleanup
assertion passed. The RET code-load property now checks PE and owner at that
state, retaining the RETF opcode check at `FAR_RETURN_DONE`. Preflight passes
with 298 assertions, one assumption and 49 covers; property SHA-256 is
`b46fea44605d534db9578a494663fdd3d76b0f1ad07e263ba8d9ca041d96e9c5`.
Connected-core prove `_29` passed the depth-12 base case but returned UNKNOWN
at induction line 329 on an arbitrary BUS continuation carrying
`EVENT_GATE_TAIL` without an active event owner or valid packet. The reverse
event-state assertion now requires that an owner was active in the previous
cycle. The next proof snapshot has not started while older `_21` cover and PDR
jobs remain active. BMC, current-property prove, cover, PDR and the aggregate
exact-source audit remain open. Full-chip completion is not claimed.
See the [live status](../../../plans/286/STATUS.md) and
[latest issue checkpoint](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6438637209).

| Area | Completion evidence | Current state |
|---|---|---|
| Reset and real-mode compatibility | Documented reset/cache behavior, exact instruction traces, historical software, and checked boundary/reset cases | Partial; the exact-source `run_development.sh` passes 36 real-mode #UD cases and 71 reset cuts. A source-backed 82C284 digital RES synchronizer is integrated with the native CPU, bus and 82288; 1/2-CLK delay, 16-CLK hold and reset-vector pin regressions pass. Analog startup, board clock/phase, broad real-software and release acceptance remain open |
| Instruction set and system instructions | Every documented instruction and mode restriction accounted for; exact PC, flags, register, memory, and I/O effects; explicit handling for undefined encodings | Incomplete; the 480-case privilege regression checks direct IN/OUT, REP INS/OUTS, CLI/STI, POPF/IRET IF/IOPL rules, protected HLT, and nonzero-CPL LGDT/LIDT/LMSW/CLTS with ring-0 controls. A separate 24-case selector matrix checks LLDT/LTR register/memory #GP(0) behavior at CPL1–3. ARPL now has a 384-case reachable CPL1–3 matrix for every source/destination RPL pair, register and SS-memory forms, incoming ZF state and READY policy. Other privileged encodings, task instructions, remaining ISA coverage and independent software remain open |
| Protected segmentation | Descriptor-table lookup and validation; GDT/LDT and code/data/stack cache commit; privilege and access checks; precise faults | Incomplete; ring-0 GDT event recovery, loaded-LDT data loads, valid outer IRET, same-level GDT gate, LDT-resident gate to GDT code, null/out-of-limit gate and target #GP, invalid-LDTR/out-of-limit/present-data/non-present-code LDT target faults, all 15 non-call system gate types plus a data descriptor, gate-access #GP/#NP, target-type/privilege/presence #GP/#NP, ring-3-to-ring-0/1/2 TSS stack selection, one DPL-1 conforming target without privilege change, nine TSS/SS0/stack-span #TS/#SS cases, and 13 outer-RETF descriptor #GP/#NP/#SS cases with SS-before-IP priority and one handler-repair/IRET retry, plus a separate stack-span #SS(0) repair/retry; all pass directed checks. Outer IRET additionally covers null/inward/#NP/#GP return-CS rejection, one over-limit saved-IP #GP(0), five invalid outer-SS #SS cases, current-stack starting-SP/frame-span #SS(0) faults with handler repair/retry, and twelve Table 7-4 pairwise priority executions: both current-stack bounds before null CS, null/non-present return CS before null outer SS, and null/non-present outer SS before over-limit saved IP. The limit check is deferred until outer SS validation; descriptor accessed-bit writes and no-partial-context commit are checked. All cases run in both READY modes. Broader protected combinations remain open |
| Events and task state | Protected IDT delivery, interrupt/exception frame rules, IRET, privilege transitions, task register/TSS and task switching, plus defined escalation behavior | Incomplete; CPL3-to-ring0 interrupt/trap gates, exact frames and IRET, software-INT DPL, restartable outer-IRET descriptor/selector faults, #DF task entry/IRET and incoming-task validation pass directed cases. IDT-limit escalation covers first-fault #DE/#GP plus #NP/#SS; incoming-task first-fault escalation covers #TS from invalid LDTR, null CS, wrong-type CS, CS DPL/RPL mismatch and CS GDT-limit, #NP from non-present CS/DS/ES, #SS from null SS, SS GDT-limit, non-present SS, SS DPL mismatch and selector-RPL mismatch (both with #DF escalation), and #GP from read-only/code-type SS, execute-only DS/ES, DS/ES system descriptors, and incoming-DS/ES privilege mismatches. Matching malformed handler gates select null-error #DF; shutdown and valid #DF task-gate delivery check exact saved TSS state and handler successor in both READY modes for the closed variants. Shutdown NMI ignores INTR and exits only after successful protected delivery. 234 reset cuts cover nested #DF task-gate entry and 180 cover task IRET, with exact reset-vector replay in both READY modes. The direct far task-gate and direct-TSS matrices each cover 192 CPL/RPL/DPL/CALL/JMP executions in both READY policies: 104 permitted and 88 denied, with exact successors, frames and task preflight checks. Incoming non-null-LDT task entry adds 460 valid CPL0-2 DPL/RPL privilege executions and eight CS/SS/DS/ES limit-fault cases with Table 8-1 exceptions. The incoming-selector fault matrix adds 52 invalid CS/SS/DS/ES executions, including all four GDT-limit cases. Ordinary protected code JMP retains its descriptor transaction. Direct task-transfer fault priorities, full #DF classification, current-source formal, and other event/task failure phases remain open |
| Bus and restart behavior | Stable requests through waits, exclusive ownership, reset cancellation, whole-span access checks, precise instruction restart, and externally visible I/O ordering | Partial; `NATIVE_BEATS=1` reports one/two-byte completion with 16-bit lane data. `intel_80286_native_cpu` connects the core, CPU-pin controller and non-MULTIBUS `intel_80286_82288` model. Its wrapper accepts processor-rate `clk_i` and external 2x `clk_2x_i`; the connected test now drives their documented 2:1 frequency relation with a deterministic digital phase. The pin test checks even/odd words, explicit LOCK MOV load/store, memory ROL, locked and implicit XCHG, two REP LOCK MOVSB/INSB/OUTSB iterations, memory/I/O READY waits, lock coverage across operand gaps, HOLD exclusion/release, no LOCK during fetch, INTA, IVT/frame data, exact IRET/HLT return and all exercised controller strobes. The full `run_sim.sh` pass exercises that clock schedule. The 82288 component test checks status decode, CENL/CEN/CMDLY, waits, direct back-to-back cycles, halt, active-low strobes and MCE/ALE timing. Board clock generation and physical phase/reset timing, MULTIBUS mode, automatic descriptor/coprocessor locks, 80287 pins, SCAS fault behavior and broader restart behavior remain open. See `spec/native_bus_interface.md`, `report/2026-10-28-native-clock-phase.md`, `report/2026-10-28-native-lock-integration.md` and `report/2026-10-28-82288-local-controller.md`; full native protocol remains incomplete |
| Independent evidence | External-oracle instruction cases, real historical software, reviewed assumptions, formal assertions/proofs/covers, strict lint, mutation checks, and synthesis | Incomplete; the latest exact-source `run_sim.sh` exits 0 with 196 `PASS:` lines, including 79 protected replay cases in both READY modes; the protected replay manifest binds those cases to the current RTL and replay sources. The 13-target Yosys 0.69 matrix was rerun on the updated RTL and completed with zero structural problems in all 13 targets. Earlier separately scoped evidence includes 99,650 Unicorn cases / 1,715,162 states, 68,510 physical captures and 52 protection captures in both READY modes, 29 detected mutations, and IBM AT software with 196,846 exact states; the current-source run now passes the bounded BIOS checksum checkpoint plus helper, IRQ8 and system-register traces; see report/2026-10-29-historical-software-current-source.md. The latest aggregate audit is 36/40 for its older snapshot: component tasks pass, core BMC/prove property copies are stale, and core cover was not run. A separate current-source component refresh passes 36/36 tasks with 59 cover witnesses, but does not prove the connected core. The older whole-core PDR remains active on its distinct 21-file source snapshot: 19/21 copied inputs match, while `intel_80286.sv` and `intel_80286_code_load.sv` differ. At 03:07:38 UTC it remains active at frame 166 with 344/411 outputs proved and 67 timeout retries, without terminal PASS; this stale-source run is not current-source evidence. See `report/2026-10-29-pdr-source-epoch-audit.md`. SDK 1.00 CPGREP remains emulator-only in PCjs/OS/2, with no CPGREP trace or RTL execution |
| Release gate | One reproducible full `run_all.sh` run against a source-identified snapshot, with all required stages and no stale or missing outputs | Not achieved; `run_all.sh` has not passed against a current, exact-source snapshot. The current-source full simulation passes independently, and prior vectors, hardware replay, mutation, software and synthesis stages have separate evidence. The latest aggregate audit is an incomplete 36/40 snapshot; no current-source connected-core proof is available. |

## Current-source checkpoint — 2026-10-29 02:50 UTC

The bounded IBM AT BIOS software regression now passes on exact current source through the original ROM-checksum success checkpoint. The separate original-BIOS helper, IRQ8 handler and system-register tests also pass against Unicorn 2.1.4 traces. This does not claim full POST or boot; the OS/2 SDK 1.00 CPGREP workload still lacks an RTL trace. See eport/2026-10-29-historical-software-current-source.md.

The preserved whole-core PDR is still active on its separate stale 21-file source snapshot at frame 166 with 344/411 outputs proved and 67 timeout retries. Do not treat it as current-source evidence or start a competing connected-core run until it terminates.

## Completion rules

- Keep source-backed decisions and explicit `ASSUMPTION:` entries in the spec
  and RTL. Validate assumptions against an independent 286 artifact or real
  software before sign-off.
- Use an independent external artifact for the instruction oracle; do not
  derive the expected model by re-reading this RTL.
- Assert exact post-instruction PC and next-executed instruction. Do not add
  padding that tolerates an unknown control-flow landing.
- Run cover tasks and check non-vacuity. Bind every PASS to exact source hashes,
  tool identity, command, and retained log/result paths.
- Include actual historical software in the design's release regression. The
  selected first workload is Microsoft OS/2 SDK 1.00 `CPGREP.EXE`; its install
  and run harness must be completed and its behavior checked against an
  independent 286 trace.

See the [continuation plan](../../../plans/286/README.md) and
[current status](../../../plans/286/STATUS.md) for task order and live evidence.
