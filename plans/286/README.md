# Continuation plan: Intel 80286

**Current work (2026-10-30):** Connected-core BMC found a WAIT completion
race against single-step priority; its correction passes directed CPU tests
and lint, with broader verification running. See the
[WAIT report](../../design/intel_80286/report/2026-10-30-wait-tf-priority.md). The native
BIOS refresh path now also checks page selection; see the
[page-map report](../../design/intel_80286/report/2026-10-29-at-refresh-page-map.md).

**Latest work (2026-10-29):** The unchanged IBM AT BIOS reached `F000:03A2`
through its refresh-indication loop on the native fixture, with CPU state and
transaction replay checked against Unicorn in two virtual-clock scenarios.
See the [native BIOS report](../../design/intel_80286/report/2026-10-29-at-bios-native-refresh.md).

**Latest work (2026-10-29):** The native fixture feeds refresh detect to port
`61h`; a directed 286 program observes both bit states. Authentic BIOS
integration and DRAM refresh remain open. See the
[port report](../../design/intel_80286/report/2026-10-29-at-port61-native.md).

**Active plan (2026-10-26):** Follow the
[current progress audit and revised execution plan](2026-10-26-audit-and-revised-plan.md).
**Latest work (2026-10-29):** The AT refresh path now emits LS590 row and
memory-read drive signals; the native CPU/8254 test checks 14 sequential
rows. DRAM and BIOS integration remain open. See the
[row report](../../design/intel_80286/report/2026-10-29-at-refresh-row.md).
**Latest work (2026-10-29):** The native CPU now programs the shared 8254,
whose OUT1 drives the partial refresh signal path in a passing directed test.
DRAM and BIOS refresh remain open; see the
[timer/native report](../../design/intel_80286/report/2026-10-29-at-refresh-timer-native.md).
**Latest work (2026-10-29):** The partial refresh path now uses the 286
native HOLD/HLDA interface and passes READY-stall and LOCK handoff tests.
Real timer, DRAM and BIOS integration remain open. See the
[native report](../../design/intel_80286/report/2026-10-29-at-refresh-native.md).
**Current work (2026-10-29):** U68/U95 refresh request capture and clear
pass standalone checks; integration remains open. Formal counterexamples
also exposed a WAIT extension-error/NMI priority race. The RTL correction
passes bootstrap testing; full verification is underway.
See the [request report](../../design/intel_80286/report/2026-10-29-at-refresh-request.md).
**Latest component (2026-10-29):** The standalone IBM AT U118 refresh-detect
flip-flop passes edge/preset simulation and a Yosys structural check. Bus
arbitration and BIOS refresh remain open; see the
[component report](../../design/intel_80286/report/2026-10-29-at-refresh-detect.md).
**Formal update (2026-10-29):** The current-source PDR failed at step 9 on
WAIT/event assertions. The witness, property changes and ongoing checks are
documented in the [formal report](../../design/intel_80286/report/2026-10-29-wait-event-formal.md).
**Latest activity (2026-10-29):** The IBM AT BIOS now passes the DMA page
register test through `F000:038A` using an explicit page-register fixture.
Both READY scenarios pass the full software entry point and match Unicorn for
247,196 and 1,295,769 CPU states with captured I/O inputs. See the
[page BIOS report](../../design/intel_80286/report/2026-10-29-at-page-bios.md)
and [issue checkpoint](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6491652810).

**Previous activity (2026-10-29):** The IBM AT BIOS now passes both timer and
DMA-controller register tests through `F000:0302` using connected 8254 and
8237 RTL. The full software entry point passes; two CPU traces match Unicorn
for 197,920 and 1,246,493 instruction states with captured I/O inputs. A new
current-source PDR subsequently failed as noted above. See the
[DMA BIOS report](../../design/intel_80286/report/2026-10-29-at-dma-bios.md)
and [issue checkpoint](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6491502332).

**Previous activity (2026-10-29 06:40 UTC):** Added two READY-policy cases
where the #DF task-gate target TSS is unavailable after the #TS handler-entry
fault. Both reach quiescent shutdown without accessing the rejected TSS.
The focused option passes 32 executions and full bootstrap reports 110 PASS lines;
no RTL changed in this follow-up. See the
[handler-entry report](../../design/intel_80286/report/2026-10-29-task-gate-handler-entry.md)
and [issue checkpoint](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6489860781).

**Previous activity (2026-10-29 06:31 UTC):** Added two READY-policy cases for
a not-present #TS task-gate target TSS while delivering a contributory #TS.
The core now escalates to #DF through a valid task gate; the #DF handler repairs
the first faulting TSS, task-IRETs back, and reaches the exact resumed NOP/HLT
successor. The focused task-gate option passes 12 event cases, 16 incoming-task
recovery executions and 2 handler-entry recovery executions; the full bootstrap
passes 110 checks. This includes an RTL fix. See the
[handler-entry report](../../design/intel_80286/report/2026-10-29-task-gate-handler-entry.md)
and [fault-recovery report](../../design/intel_80286/report/2026-10-29-task-gate-fault-recovery.md).
Checkpoint: [issue comment 6489742960](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6489742960).

**Previous activity (2026-10-29 05:41 UTC):** The CPL1/CPL2 task-gate event
matrix grew to 12 cases across external INTR, software `INT 13h`/#GP and NMI.
See the [event-delivery report](../../design/intel_80286/report/2026-10-29-task-gate-event-delivery.md)
and [checkpoint 6489004572](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6489004572).

The previous activity found and fixed an incoming task fault-context defect;
see the [fault-context report](../../design/intel_80286/report/2026-10-29-task-fault-context.md)
and [escaped-defect note](../../failure_notes/2026-10-29-intel80286-task-fault-context.md).
Other task-gate handler-entry faults, current-source connected-core formal,
full POST/boot, OS/2 CPGREP on RTL, native-interface qualification and whole-CPU
acceptance remain open. Tracking issue:
[hevangel/ai_hw_engineer#80](https://github.com/hevangel/ai_hw_engineer/issues/80).

The preceding task-entry ordering audit found that incoming validation must
follow LDT, SS, CS, DS, ES, then IP; see the
[SS-before-CS report](../../design/intel_80286/report/2026-10-29-task-switch-ss-before-cs.md)
and the separate [IP-order report](../../design/intel_80286/report/2026-10-29-task-switch-ip-validation-order.md).

The preserved whole-core PDR uses a stale source snapshot (last recorded at
frame 166, 344/411 outputs proved, 67 timeout retries), so it cannot establish
current-source proof.
Current-source connected-core formal, full POST/boot, OS/2 CPGREP on RTL and
whole-CPU acceptance remain open.

**Previous activity (2026-10-29 03:30 UTC):** Intel 210498-005 section 8.3
step 8 showed incoming IP-limit validation must follow SS, CS, DS and ES
validation. Four READY-mode/fault-priority cases reproduce the old
`#GP`-before-`#SS` behavior and now pass after the RTL check moved to the
correct phase. All 13 Yosys 0.69 synthesis targets completed with zero
structural problems for that source snapshot. The issue checkpoint was posted
and read back in [comment 6487134519](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6487134519).

**Previous activity (2026-10-29 02:50 UTC):** the current-source historical
software regression now passes end to end. The unchanged IBM AT REV1 BIOS
reaches the checksum-success checkpoint after 196,846 exact instruction
states; 16 hex-helper cases / 464 states, eight IRQ8 cases / 236 handler
states, and four system-register patterns / 164 states also pass. The script
now installs pinned Unicorn 2.1.4 into its ignored work directory. This is not
full POST or boot. See the [software report](../../design/intel_80286/report/2026-10-29-historical-software-current-source.md)
and evidence under
`design/intel_80286/work/historical_software_current_20261029_23/`.

Earlier, incoming-LDTR rows 4–5 were extended through both #DF outcomes for
all five invalid-selector categories: TI set, wrong descriptor type
(including RPL bits), not-present LDT, and GDT-limit failure. Ten malformed-
gate cases enter sticky shutdown; ten valid #DF task-gate cases save the
faulting TSS and reach the handler successor across both READY modes. See the
[incoming-LDTR escalation report](../../design/intel_80286/report/2026-10-29-incoming-ldtr-escalation-variants.md)
and [Table 8-1 audit](../../design/intel_80286/report/2026-10-29-table-8-1-task-entry-audit.md).

Preflight, exact-source Verilator 5.052 `-Wall` build, focused
`--iopl-controls` and full `scripts/run_sim.sh` pass. The full log contains
195 `PASS:` lines with no failures/errors, and protected replay passes 79
cases in both READY modes. Evidence and hashes are under
`design/intel_80286/work/incoming_ldtr_escalation_variants_20261029_21/`.
Project readback remains Open/Building, Agent Codex, Path
`ai_hw_engineer/design/intel_80286`, Start date `2026-10-23`, Sprint 1.

Current-source formal and whole-CPU acceptance remain open. The larger OS/2
CPGREP workload still lacks an RTL trace. The preserved PDR remains active on
its stale source snapshot at frame 118 (343/411 outputs, 50 timeout retries);
do not start competing connected-core formal until it terminates. The
checkpoint was posted and read back in
[issue comment 6486536094](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6486536094).

**Previous activity (2026-10-29 02:38 UTC):** extended incoming-LDTR rows 4–5
through both #DF outcomes for all five invalid-selector categories: TI set,
wrong descriptor type (including RPL bits), not-present LDT, and GDT-limit
failure. Ten executions enter sticky shutdown after malformed #TS/#DF gate
delivery; ten enter a valid #DF task gate, all across both READY modes. The
not-present valid-task case uses selector `0078` because the #DF target TSS
occupies `0070`. See the [incoming-LDTR escalation report](../../design/intel_80286/report/2026-10-29-incoming-ldtr-escalation-variants.md)
and [Table 8-1 audit](../../design/intel_80286/report/2026-10-29-table-8-1-task-entry-audit.md).

Preflight, exact-source Verilator 5.052 `-Wall` build and focused
`--iopl-controls` pass. Full `scripts/run_sim.sh` exits 0 with 195 `PASS:`
lines and no `FAIL:` or `ERROR:` lines; protected replay passes 79 cases in
both READY modes. Evidence and hashes are under
`design/intel_80286/work/incoming_ldtr_escalation_variants_20261029_21/`.
Only the testbench changed, so prior synthesis remains applicable. Project
readback confirms Open/Building, Agent Codex, Path
`ai_hw_engineer/design/intel_80286`, first Start date `2026-10-23`, and Sprint
1. Current-source formal, authentic software and whole-CPU acceptance remain
open. The checkpoint was posted and read back in
[issue comment 6486405063](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6486405063).

The preserved whole-core PDR remains active on its separate 21-file source
snapshot. At 02:38 UTC it was still active after more than 17 hours; its latest
solver log remains at frame 118 with 343/411 outputs proved and 50 timeout
retries. Nineteen of 21 inputs match current source, while the top-level core
and code-load module differ. Do not count it as current-source proof or start
a competing connected-core run before it terminates.

**Formal blocker audit (2026-10-29 01:09 UTC):** 19 of the preserved PDR's 21
inputs match current source; the top-level core and code-load module differ.
The still-active run advanced to frame 96 with 343/411 outputs proved and 48
timeouts. Preserve it until terminal status and keep it separate from current
formal evidence. See the
[source-epoch audit](../../design/intel_80286/report/2026-10-29-pdr-source-epoch-audit.md)
and [latest issue checkpoint](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6485126780).

Preflight passes; strict Verilator 5.052 `-Wall` `scripts/run_sim.sh` exits 0
with 181 `PASS:` lines and no `FAIL:` or `ERROR:` lines. Protected replay
passes 79 cases in both READY modes. Evidence and hashes are under
`design/intel_80286/work/incoming_ds_np_double_fault_20261029_06/`. RTL is
unchanged, so prior synthesis remains applicable. Other task-entry fault
phases, current-source formal, authentic software and the full release gate
remain open. The simulation checkpoint was posted and read back in
[comment 6484884414](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6484884414).

**Previous activity (2026-10-29 00:43 UTC):** added four incoming-ES
execute-only first-fault `#GP` escalation executions. Selector `0030` is valid
as CS but unreadable as ES under Table 8-1 row 14. Both shutdown and valid #DF
task-gate delivery pass in both READY modes. See the
[incoming-ES #GP report](../../design/intel_80286/report/2026-10-29-protected-incoming-es-gp-double-fault.md).

**Previous activity (2026-10-29 00:35 UTC):** added four incoming-ES
non-present `#NP` first-fault escalation executions. Intel Table 8-1 row 15
maps ES selector `0020` to `#NP(0020)`. The malformed `#NP` gate escalates to
null-error `#DF`; both shutdown and successful #DF task-gate delivery pass in
both READY modes. See the
[incoming-ES #NP report](../../design/intel_80286/report/2026-10-29-protected-incoming-es-np-double-fault.md).

**Previous activity (2026-10-29 00:27 UTC):** added four incoming-SS first-fault
`#SS` escalation executions. Intel Table 8-1 row 11 maps non-present SS
selector `0010` to `#SS(0010)`. A malformed `#SS` gate escalates to null-error
`#DF`; invalid-vector-8 shutdown and successful #DF task-gate delivery pass in
both READY modes. Tests check exact event context and gate reads, saved
faulting TSS with SS=`0010`, backlink/busy state, null error push and handler
successor. Playwright CLI reviewed the source table. See the
[incoming-SS #DF report](../../design/intel_80286/report/2026-10-29-protected-incoming-ss-double-fault.md).

**Previous activity (2026-10-29 00:21 UTC):** added four incoming-CS
non-present `#NP` first-fault escalation executions. Intel Table 8-1 row 7
maps a non-present incoming code segment to `#NP(0008)`. A malformed `#NP`
gate escalates to null-error `#DF`; invalid-vector-8 shutdown and valid #DF
task-gate delivery pass in both READY modes. The tests check exact event
context, gate reads, saved incoming TSS with CS=`0008`, backlink/busy state,
null error push and exact handler successor. Playwright CLI visually verified
the row; its capture is preserved with the evidence. See the
[incoming-CS #NP report](../../design/intel_80286/report/2026-10-29-protected-cs-np-double-fault-first-fault.md).

Preflight passes; strict Verilator 5.052 `-Wall` `scripts/run_sim.sh` exits 0
with 175 `PASS:` lines and no `FAIL:` or `ERROR:` lines. Protected replay
passes 79 cases in both READY modes. Evidence and hashes are under
`design/intel_80286/work/incoming_cs_np_double_fault_20261029_01/`. RTL is
unchanged, so the prior synthesis remains applicable. Current-source proof,
other task-entry fault phases, authentic software and the full release gate
remain open.

**Previous activity (2026-10-29 00:13 UTC):** added incoming-CS first-fault
`#TS` escalation through both invalid-`#DF`-gate shutdown and valid `#DF`
task-gate delivery. Four executions cover both paths with READY immediate and
stalled. They check the exact null-error `#DF` context, both gate lookups,
sticky shutdown, the faulting incoming TSS image with CS=`0000`, backlink and
busy state, null-error push, and exact handler successor. See the
[incoming-CS #DF report](../../design/intel_80286/report/2026-10-29-protected-cs-double-fault-first-fault.md).

Preflight passes; the strict Verilator 5.052 `-Wall` full run exits 0 with
174 `PASS:` lines and no `FAIL:` or `ERROR:` lines. Protected replay passes 79
cases in both READY modes. Evidence and hashes are in
`design/intel_80286/work/incoming_cs_double_fault_20261029_01/`. The testbench
changed; RTL did not, so the prior 13-target synthesis remains applicable.
Current-source proof, other task-entry fault phases, authentic software and
the full release gate remain open.

Issue #80 remains Open. The last verified project-field snapshot reports
Building, Agent Codex, Path `ai_hw_engineer/design/intel_80286`, and first
Start date 2026-10-23. The latest checkpoint was posted and read back in
[issue comment 6484408436](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6484408436).
GitHub's GraphQL rate limit still blocks project-field readback; no project
fields were changed.

**Previous activity (2026-10-29 00:01 UTC):** added an incoming-task ES
system-descriptor case. Table 8-1 row 13 maps invalid DS/ES selectors to
`#GP`; ES selector `0050` checks exact `#GP(0050)`. The 24-configuration,
48-execution matrix passed. See the
[incoming ES descriptor report](../../design/intel_80286/report/2026-10-29-incoming-es-system-descriptor.md).

**Previous activity (2026-10-28 23:55 UTC):** added an incoming task SS RPL
mismatch case. Intel Table 8-1 row 9 maps an invalid incoming stack selector
to `#SS`; the test checks exact `#SS(0028)` for selector `002B` and RPL 3
against CPL 0. It corrected the earlier `#TS` expectation based on the table
and observed packet. The 23-configuration matrix (46 READY-mode executions)
passed. See the
[incoming SS RPL report](../../design/intel_80286/report/2026-10-28-incoming-ss-rpl-fault.md).

**Previous activity (2026-10-28 23:41 UTC):** expanded incoming non-null-LDT
task-entry coverage to 460 valid privilege executions across CPL0–2. CS/SS
use DPL=RPL=CPL; DS/ES cover every DPL/RPL combination satisfying
`max(CPL,RPL) <= DPL`, in both READY modes. The eight LDT-limit faults still
check Table 8-1 `#TS/#SS/#GP`, exact selector errors, transferred TSS state and
no read or accessed-byte write past the limit. The Intel manual's §7.4.1 and
Table 8-1 were visually checked through `playwright-cli`.

Preflight passes; strict Verilator 5.052 `-Wall` `scripts/run_sim.sh` exits 0
with 173 PASS lines and no failures/errors. Protected replay passes 79 cases
in both READY modes. Evidence and hashes are in the
[incoming-LDT report](../../design/intel_80286/report/2026-10-28-incoming-ldt-privilege-limit-matrix.md)
and `design/intel_80286/work/incoming_ldt_rpl_20261028_02/`. No RTL behavior
changed; the prior 13-target synthesis remains applicable. Current-source
proof, remaining task-switch cases, authentic software and the full release
gate remain open.

Issue #80 remains Open/Building, Agent Codex, Path
`ai_hw_engineer/design/intel_80286`, first Start date 2026-10-23. The checkpoint
was posted and read back in
[issue comment 6483636717](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6483636717).

**Previous activity (2026-10-28 23:30 UTC):** expanded valid incoming
non-null-LDT task-entry coverage to 58 executions across CPL0–2, with CS/SS
DPL=CPL and all allowed DS/ES DPL pairs through 3. The eight LDT-limit fault
executions checked Table 8-1 error classes and no access past limit `0027`.

**Previous activity (2026-10-28 23:16 UTC):** added a 192-execution direct-TSS
CALL/JMP privilege matrix covering CPL0–2, selector RPL0–3, TSS DPL0–3 and
both READY policies. The `max(CPL,RPL) <= TSS_DPL` boundary passes for all
104 allowed transfers and 88 denials, with exact task successors, CALL/IRET
state, JMP busy-bit behavior, #GP frames and preflight side effects checked.
The focused `--iopl-controls` run passes 23 suite groups; strict Verilator
5.052 `-Wall` `scripts/run_sim.sh` exits 0 with 172 PASS lines and no
FAIL/ERROR lines. The protected replay passes 79 cases in both READY modes.
Evidence and hashes are in the
[direct-TSS report](../../design/intel_80286/report/2026-10-28-direct-tss-privilege-matrix.md).
No RTL behavior changed, so the prior 13-target Yosys 0.69 synthesis remains
applicable. Current-source connected-core proof, remaining task-switch fault
phases, authentic historical software and full release acceptance remain
open. The older PDR is still active on its different 21-file snapshot without
a terminal result; it is not current-source evidence.
Issue #80 remains Open/Building with Agent Codex, Path
`ai_hw_engineer/design/intel_80286` and first Start date 2026-10-23. The
checkpoint was read back in
[issue comment 6483230260](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6483230260).

**Previous activity (2026-10-28 22:52 UTC):** added a 384-case reachable
CPL1/CPL2/CPL3 ARPL matrix covering every source/destination RPL pair, register
and SS-memory forms, both prior ZF values and both READY policies. All cases
reach nonzero CPL through outer IRET and check flags, exact fetch/successors,
conditional RMW traffic and unprivileged execution. The focused `--arpl` run
passes. The full strict Verilator 5.052 `-Wall` `scripts/run_sim.sh` exits 0
with 171 PASS lines, no FAIL/ERROR lines and all 79 protected replay cases in
both READY modes. Evidence is under
`design/intel_80286/work/arpl_reachable_privilege_20261028/`; details and
hashes are in the [ARPL report](../../design/intel_80286/report/2026-10-28-arpl-reachable-privilege-matrix.md).
The corrected-source Yosys 0.69 synthesis remains valid because RTL behavior
has not changed. Current-source connected-core proof, alternate-stepping ARPL
captures, authentic historical software and full release acceptance remain
open. The older PDR is still active on its different 21-file snapshot; its
22:21 UTC log remains at frame 27, 342 outputs and 31 timeouts without a
terminal result. Issue #80 remains Open/Building with Agent Codex, Path
`ai_hw_engineer/design/intel_80286`, and first Start date 2026-10-23; the
checkpoint was read back in
[issue comment 6482816712](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6482816712).

**Previous activity (2026-10-28 22:40 UTC):** expanded the direct task-gate
privilege matrix to all 192 CPL0–2 / selector-RPL0–3 / gate-DPL0–3 / CALL/JMP
combinations in both READY modes. All 104 allowed transfers and 88 denials
pass with exact successors, #GP frames and task-state preflight checks. The
fresh strict Verilator 5.052 `-Wall` `scripts/run_sim.sh` exits 0 with 170
`PASS:` lines and no failures/errors; protected replay passes 79 cases in both
READY modes. Evidence is under
`design/intel_80286/work/task_gate_privilege_exhaustive_current_20261028/`.
Corrected-source Yosys 0.69 synthesis remains valid for functional RTL and all
13 targets; no RTL behavior changed since that run. A26 remains unresolved.
The older whole-core PDR still runs on a different 21-file snapshot; at 22:40
UTC it had no new log progress beyond frame 27, 342 outputs proved and 31
timeouts, with no terminal PASS. No competing core proof is being started.
Current-source connected-core formal, authentic historical software and full
release acceptance remain open. See the
[task-gate source audit](../../design/intel_80286/report/2026-10-28-task-gate-source-audit.md),
[direct-transfer report](../../design/intel_80286/report/2026-10-28-protected-direct-task-transfers.md)
and [failure note](../../failure_notes/2026-10-28-intel80286-task-gate-contract.md).
Issue #80 remains Open/Building with Agent Codex, Path
`ai_hw_engineer/design/intel_80286`, and first Start date 2026-10-23; the last
verified issue checkpoint is
[comment 6482597698](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6482597698).

**Previous activity (2026-10-28 21:03 UTC):** the direct far CALL/JMP task-
transfer success matrix and prior 13-target Yosys synthesis passed. That
synthesis predates the manual-driven task-gate source correction and is
retained separately in the direct-transfer evidence directory.

**Previous activity (2026-10-28 20:43 UTC):** implemented and tested protected
far CALL/JMP task transfers through available TSS descriptors and task gates.
Eight cases check nested CALL/backlink/NT return versus non-nested JMP busy
clearing, exact successors and both READY policies. A separate ordinary
code-segment far JMP checks descriptor transaction compatibility. The full
`scripts/run_sim.sh` now passes with 167 `PASS:` lines, zero `FAIL`/`ERROR`
lines, and 79 protected replay cases in both READY modes. Strict Verilator
5.052 `-Wall` is used by the runner. The synthesis matrix result and limits are
recorded in the direct-transfer report.

**Previous activity (2026-10-28 20:07 UTC):** the focused protected privilege
matrix covered first-fault `#TS` from an invalid incoming LDTR. In both READY
modes, a malformed #TS gate escalates to null-error #DF; tests cover sticky
shutdown on an invalid vector-8 gate and successful delivery through a valid
#DF task gate with exact faulting-TSS save and handler successor. Existing
#NP/#SS IDT-limit cases remain passing. Strict Verilator 5.052 `-Wall` and the
full `run_sim.sh` passed with 165 PASS lines; protected replay passed 79 cases
in both READY modes. The then-current 13-target Yosys matrix had zero
structural problems. See the [reset-source report](../../design/intel_80286/report/2026-10-28-reset-source-audit.md)
and [#DF first-fault report](../../design/intel_80286/report/2026-10-28-protected-double-fault-first-faults.md).

**Previous activity (2026-10-28 18:43 UTC):** corrected both outer-IRET fault
ordering mismatches in Intel 210498-005 Table 7-4. The full current-stack
frame check now precedes return-CS validation; the saved-IP limit check follows
outer-SS validation. Twelve paired priority executions and the 36-execution
focused IRET matrix pass in both READY modes. Strict Verilator 5.052 `-Wall`,
preflight, the 71-line full bootstrap and the current-source 12-target Yosys
0.69 synthesis pass (36 zero-problem checks, no errors). Exact hashes and scope
limits are in the
[fault-priority report](../../design/intel_80286/report/2026-10-28-protected-iret-fault-priority.md).
The older whole-core PDR remains on a different 21-file RTL snapshot and is
not current-source proof. Connected-core proof, broader task/event cases,
native timing, successful ESC transfers and the release gate remain open.
Issue #80 remains Building with Agent Codex, Path
`ai_hw_engineer/design/intel_80286` and Start date 2026-10-23. The verified
checkpoint is [issue comment 6477632896](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6477632896).

**Previous activity (2026-10-28 15:54 UTC):** added 16 protected-mode WAIT
event cases covering CPL1/CPL2, NMI/INTR, interrupt/trap gates and both READY
modes. The tests verify TSS stack switching, exact outer frames, IRET and the
exact successor while BUSY remains asserted. Strict Verilator 5.052 `-Wall`,
the focused `--protected-wait` slice and the full default bootstrap pass. No
RTL changed. Evidence and hashes are in the
[protected WAIT report](../../design/intel_80286/report/2026-10-28-protected-wait-interruption.md).
The issue checkpoint is [comment 6473853937](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6473853937).
The saved-IP rule remains assumption A25; native WAIT timing, current-source
connected-core proof, successful ESC transfers and full CPU acceptance remain
open. The whole-core PDR remains on an earlier 21-file snapshot.

**Previous activity (2026-10-28 15:46 UTC):** a Playwright CLI visual review of
Intel's 1986 *Microsystem Components Handbook: Microprocessors, Volume I*,
printed page 4-31, confirms the known 80287 reserved-port, privilege-bypass,
operand-transfer and bus-priority contract. It still does not document the
successful ESC byte/port sequence, so transaction RTL remains source-blocked.
No RTL changed; details are in the
[80287 source report](../../design/intel_80286/report/2026-10-28-80287-processor-extension-slice.md).
The issue checkpoint is [comment 6473621922](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6473621922).
The earlier whole-core PDR remains active at frame 11 with 326/411 outputs
proved as of 15:42 UTC, but it uses a prior 21-file snapshot and is not current-
source evidence.

**Previous activity (2026-10-28 15:32 UTC):** the 286 now accepts eligible
real-mode NMI and IF-enabled INTR while `WAIT` is stalled on BUSY. Strict
Verilator 5.052 `-Wall`, the focused processor-extension slice and the full
default bootstrap pass. Intel's 1983 handbook confirms WAIT is interruptible;
the saved-IP rule remains assumption A25 because that source does not specify
the return address. The same handbook adds that ESC memory operands use a word
I/O transfer at port `00FAh` plus one or two memory cycles, but it still lacks
the ESC command bytes. See the
[WAIT interruptibility report](../../design/intel_80286/report/2026-10-28-wait-interruptibility.md).
The latest default bootstrap log SHA-256 is
`6e8e3eab5bfe50f8a821377cc88a703a01a83f8d659592d2d0672458c469e873`.
The GitHub checkpoint is [issue comment 6473353919](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6473353919).
The separate whole-core PDR remains live against an earlier 21-file snapshot
and does not prove current source; connected-core proof and full release gates
remain open.

**Previous activity (2026-10-28 15:17 UTC):** the strict Verilator `-Wall` build,
the existing ring-3 event regression, four reachable CPL1/CPL2 event matrices
(48 cases total), and the full default bootstrap pass. The matrices check
software-INT gate-DPL allow/deny boundaries, exception DPL bypass via
privileged LIDT, external INTR vector 13 and NMI vector 2 through DPL-0 gates,
#GP(006A)/#GP(0), TSS ring-0 stack selection, exact outer frames, IF/TF
behavior, NMI unblock on IRET, and exact successors in both READY modes. Intel
210498-005 §9.4/Figure 9-4 was reviewed with Playwright CLI. Evidence is in the
[CPL1/CPL2 event report](../../design/intel_80286/report/2026-10-28-protected-event-ring12.md).
The whole-core PDR is still running against an older 21-file snapshot and does
not verify this source; connected-core proof and full release gates remain
open. The GitHub checkpoint is [issue comment 6472602584](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6472602584).

**Previous activity (2026-10-28 14:46 UTC):** all 12 current-source standalone
component configurations pass BMC, proof and cover (36/36 tasks, 59 reached
cover witnesses); the saved task configurations and copied inputs pass the
exact-source audit. The full default bootstrap also passes with the new
768-case reachable CPL1/CPL2 selector matrix. See the
[current component formal report](../../design/intel_80286/report/2026-10-28-formal-components-current.md)
and [selector-query report](../../design/intel_80286/report/2026-10-28-selector-query-ring12.md).
The separate whole-core PDR is still on an earlier 21-file snapshot; at 14:46
it reached frame 89 with 321/411 outputs proven and 70 timeout retries. It
does not verify current source. The formal checkpoint is in
[issue comment 6472164584](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6472164584).

**Previous activity (2026-10-28 14:39 UTC):** the selector regression passes
768 reachable CPL1/CPL2 VERR/VERW/LAR/LSL queries. It covers writable data,
readable nonconforming and conforming code for every DPL/RPL pair, all four
operations and both READY policies, after real outer-IRET privilege entry. The
strict `-Wall` runner build, complete `--selector-exec` slice, and full default
bootstrap all pass. Intel
210498-005 §11.3, printed pages 11-3–11-4, was visually reviewed through
Playwright CLI. The test is testbench-only; full protected-mode/CPU gates remain
open. See the [CPL1/CPL2 report](../../design/intel_80286/report/2026-10-28-selector-query-ring12.md),
[CPL3 report](../../design/intel_80286/report/2026-10-28-selector-query-cpl3.md)
and current [selector specification](../../design/intel_80286/spec/selector_execution.md).
The separate whole-core PDR is still on an earlier 21-file snapshot; at 14:39
it reached frame 83 with 321/411 outputs proven and 68 timeout retries. It
does not prove current source. The evidence is recorded in
[issue comment 6471994393](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6471994393).

**Previous checkpoint (2026-10-28 13:31 UTC):** a Playwright CLI source audit
corrected the SCAS restart citation to page 14 of Intel's LOADALL memo. That
scanned page explicitly tells a fault handler to update SI for SCAS; the
ordinary Programmer's Reference Manual entry names ES:DI and DI advancement.
Page 13 is unrelated implementation notes. The citation error is fixed, but
the architectural disagreement remains unresolved because the local capture
archive has no SCAS fault trace. No RTL behavior was guessed or changed. See
the [SCAS source audit](../../design/intel_80286/report/2026-10-28-scas-restart-source-audit.md)
for evidence. A plan cross-check also found protected IN/OUT/INS/OUTS IOPL
enforcement already implemented; the combined 480-case privilege regression
includes 288 dedicated IOPL/IF cases. The stale plan gap is corrected.
Physical port-side-effect ordering remains open. The inspected Intel manuals
do not provide the complete byte-by-byte reserved-port command sequence for
each successful ESC form; source that protocol before adding transaction RTL.
See the
[IOPL report](../../design/intel_80286/report/2026-10-27-iopl-controls.md)
and [live status](STATUS.md).

**Previous checkpoint (2026-10-28 13:17 UTC):** Intel 210760-002 Chapter 6
confirms that the physical 80287 `BUSY` pin is active high, wired directly to
the CPU. This corrects the prior implementation and its harness, which had
modeled BUSY as active low. The core and native wrapper now use active-high
`busy_i`; `ERROR#` remains active low. WAIT and ESC both stall while BUSY is
high, then prioritize delayed #MF once BUSY falls; ESC checks EM/TS #NM first.
The corrected focused Verilator case passes, including delayed ERROR# on both
instructions. The corrected full `run_sim.sh` passes and its current-source
protected-mode replay manifest records 79/79 cases. Current-source Yosys 0.69
synthesis passed all 12 targets, with 36 zero-problem checks, no `ERROR:`
lines and 12 JSON netlists. Details and source references are in the
[80287 slice report](../../design/intel_80286/report/2026-10-28-80287-processor-extension-slice.md).

Intel 210760-002 also specifies ESC reserved-port operations that bypass I/O
privilege checks and require no wait states, plus the processor-extension
data-channel setup and arbitration contract. PEREQ is active high, PEACK# is
active low, and an operand transfer uses one I/O and one or two memory
operations. The normal ESC transaction, channel timing and operand routing
remain unimplemented.

The whole-core PDR remains active on its earlier 21-file snapshot. At 14:18:30
UTC it reached frame 61, with 321/411 assertion outputs proved and 61 timeout
retries in that anytime pass; no counterexample or terminal result is present.
See [issue comment 6471459873](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6471459873).
That snapshot predates current source and does not cover recent changes. The aggregate
formal audit, depth-12 induction result and release gate remain open. The reset
edge source conflict, analog 82C284 power-up, MB=1 and board-clock timing,
complete 80287 protocol, physical qualification, and CPGREP-on-RTL evidence
also remain open. See the [live status](STATUS.md), [native-bus contract](../../design/intel_80286/spec/native_bus_interface.md),
and [current plan](2026-10-26-audit-and-revised-plan.md). Issue #80 remains
Open/Building with Agent Codex; see the
[latest verification checkpoint](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6470033599).

**Previous checkpoint (2026-10-28 11:52 UTC):** the native-bus contract now
records Intel's 82C284 board-level reset sequence from printed pages 3-41–3-43
and removes an unsupported fixed 38-external-CLK startup claim. Those pages
conflict on single-CPU RESET edge synchronization, so that model remains open
pending an independent 82C284 source. The connected native-CPU regression holds
CPU RESET for 16 complete processor clocks, checks the CPU and 82288 outputs
stay inactive, and verifies the first fetch status address is `FFFFF0h`; it
passes under Verilator 5.052. The full `run_sim.sh` also passes, including all
79 protected-mode replay cases. The 82C284 analog power-up and edge model
remains open. See the [reset source audit](../../design/intel_80286/report/2026-10-28-reset-source-audit.md),
[82288 implementation report](../../design/intel_80286/report/2026-10-28-82288-local-controller.md),
and [live status](STATUS.md). Issue #80 remains Open/Building with Agent Codex.

**Previous checkpoint (2026-10-28 10:48 UTC):** all independent stages after
formal prove have now completed in
`design/intel_80286/work/release_lock_checkpoint_20261028_0720/`. The current
LOCK-connected Verilator suite passed 141 lines and the 79-case protected
replay; independent vectors passed 99,650 Unicorn cases / 1,715,162 states;
hardware replay passed 68,510 physical captures and 52 protection captures in
both READY modes; all 29 mutation cases were detected; IBM AT BIOS/software
regressions passed; and Yosys 0.69 passed all 11 targets with zero problems.
The formal audit of the aggregate snapshot is 36/40: component tasks pass, but
the core proof uses a stale property copy, core cover was not reached, and PDR
did not run. The aggregate has not been rerun after property fixes, so the full
release gate remains open. The standalone current-property depth-12 proof
passes its base case but returned UNKNOWN on induction at line 189 from an
unreachable `TASK_SEGMENT_START` / PE=0 state. The separate current-source
whole-core ABC PDR later proved that assertion as output 147 in frame 14,
according to the exact run's assertion map and log. The whole-core run is still
active from its exact 21-file source snapshot; at 10:37:23 it had reached frame
33 and proved 273/411 assertion outputs, with 133 timeout retries in the
previous pass. The next pass is at frame 6 with 276/411 proved; no terminal
result has been reported. A Playwright CLI rerun reached the
retail OS/2 command prompt and
reproduced `CPGREP -yn fast ..\README`, which printed the expected line 11
containing `FAST`. The attempted instruction capture still contains only the
OS/2 shell wait loop, not CPGREP; this remains emulator-only evidence and does
not show RTL execution. A new hardware-source review found an internal Intel
manual contradiction about 82288 `CENL` polarity. Playwright CLI inspection of
Intel's original HMOS M82288 datasheet confirms active-high selection latched
at the end of `Ts`, resolving the apparent manual text error. The controller
behavior is now source-backed; system-clock integration still needs
definition. See the
[formal induction-gap report](../../design/intel_80286/report/2026-10-28-formal-induction-gap.md),
[82288 source reconciliation](../../design/intel_80286/report/2026-10-28-82288-cenl-source-conflict.md),
[live status](STATUS.md), and
[formal correction 6466581278](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6466581278).

**LOCK integration checkpoint (2026-10-28 07:13 UTC):** the connected core now drives
the native controller's active-low LOCK output for explicit LOCK-prefixed
memory MOV/MOVS/INS/OUTS and rotate-memory forms, plus implicit memory XCHG.
The pin-level Verilator test also checks explicit MOV load/store, memory ROL,
locked and implicit XCHG, and two iterations each of `REP LOCK MOVSB`,
`REP LOCK INSB` and `REP LOCK OUTSB`. It checks READY waits on memory and I/O,
locked gaps, HOLD exclusion, release after each operation, and no LOCK during
instruction fetch. The full
`run_sim.sh` suite passes with 141 PASS lines, including all 79 protected-mode
replay cases. See the [native LOCK integration report](../../design/intel_80286/report/2026-10-28-native-lock-integration.md),
[native CPU bridge report](../../design/intel_80286/report/2026-10-28-native-cpu-bridge.md),
and [core beat report](../../design/intel_80286/report/2026-10-28-core-native-beat-interface.md).
Yosys 0.69 `run_synth.sh` now passes all 11 targets; every log ended normally
with three zero-problem checks and no `ERROR:`. The integrated native CPU
wrapper reports 50,003 generic cells. Logs and JSON netlists are retained in
`design/intel_80286/work/native-lock-candidate-20261028/synth/`. Automatic
descriptor-table and processor-extension locks, external clock division/reset
timing, 82288 command decode, 80287 signaling, current-source connected-core
formal, the `run_all.sh` release gate, CPGREP on RTL and an instruction trace
remain open. The independent OS/2 CPGREP replay and screenshot remain documented in
the [PCjs report](../../design/intel_80286/report/2026-10-27-os2-cpgrep-pcjs-replay.md);
that browser reproduction used `playwright-cli` and is emulator evidence only.
Issue #80 remains Open/Building with Agent Codex.

**Previous checkpoint (2026-10-28 05:09 UTC):** Release evidence is isolated
through `INTEL_80286_WORK_DIR` across `run_all.sh` and its stages. The release
entry point accepts `--work-dir DIR`, defaults to a fresh unique run directory,
and rejects an explicitly selected non-empty directory. Shell/Python syntax
and four focused unit suites pass. A standalone native-bus cycle controller
also passes its directed Verilator test and Yosys synthesis/check, but is not
connected to the CPU; the core still needs a one/two-byte beat interface. The
aggregate release gate has not run while the connected-core cover solver is
active at 45/73 goals with no terminal outcome. The SDK 1.00 `CPGREP.EXE` sample
now runs on a local PCjs 80286 machine booted to Microsoft OS/2 1.0. From the
SDK Samples disk, `CPGREP -yn fast ..\README` returns line 11 containing
`FAST`. The executable and input hashes, PCjs setup, limitations and guest
screenshot are in the
[OS/2 CPGREP replay report](../../design/intel_80286/report/2026-10-27-os2-cpgrep-pcjs-replay.md).
Source review confirms default `-yn` uses OS/2 thread/semaphore and
file/console APIs; `-S` can isolate synchronous I/O but does not remove the
loader/API requirements. The top-level RTL still uses byte transactions and
lacks native bus pins, so the RTL platform path remains to be designed. This
is independent emulator evidence only; an RTL run and instruction trace remain
open. The native bus audit found that the current core accepts and returns one
byte per handshake, so a pin wrapper alone cannot generate even-word cycles.
The core needs a one/two-byte beat boundary before pin RTL; details are in the
source-backed [native 80286 local-bus contract](../../design/intel_80286/spec/native_bus_interface.md)
now separates CPU pins from 82288-generated ALE/command strobes and records
the status, lane, READY, arbitration, LOCK, INTA, reset and coprocessor
requirements. The standalone controller's [component report](../../design/intel_80286/report/2026-10-28-native-bus-controller.md)
records directed simulation and synthesis results; CPU integration and the
full protocol remain open. See the [latest issue checkpoint](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6461200716).
A depth-24
connected-core BMC passed on the prior property snapshot. The first depth-12
prove passed its base case but failed induction at an overbroad HLT property;
the trace confirmed shutdown state (`SHUTDOWN`, `halt_latch=1`). That property
now excludes shutdown, and formal preflight passes. The corrected prove's
depth-12 base case passes, but induction returns UNKNOWN on assertions at
lines 525 and 775. Its trace begins from unconstrained internal state; reset
reachability beyond the checked bound remains unresolved. Coverage audit now
counts 45 of 73 active goals reached: 38/52 top-level CPU-property covers and
7/21 active component covers. The latest witness is
`intel_80286_muldiv_props.sv:38` at step 32, saved as `trace42`; the solver is
checking another goal. The search advanced to step 33 and reached a 1-hour
wait marker; the count remains 45/73 with no new witness or terminal result.
This corrects the earlier `44/52` shorthand,
which mixed component witnesses into a core-only denominator. Yices remains
active with no failure or terminal result. The run is in
`design/intel_80286/work/formal_runs/core_20261027_04/`. Since the
property changed, the prior BMC is stale; rerun BMC and aggregate audit on the
corrected snapshot. A SHA-256 comparison confirms all 21 files copied into the
cover run (14 RTL and 7 property files) match current sources. CPGREP remains
emulator-only, without an independent trace or RTL execution. Issue #80:
[latest checkpoint](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6461098792).

**RTL checkpoint (2026-10-27 14:11 UTC):** HALT and protected shutdown now
have separate `bus_halt_cycle_o` and `bus_shutdown_cycle_o` indications at the
byte-transaction boundary. Both persist with READY low without a byte request;
shutdown still ignores INTR and exits only after a successful NMI commit or
RESET. The `--iopl-controls` suite passes 480 protected privilege scenarios,
234 task-gate entry reset cuts (117 per READY policy) and 180 task-IRET reset
cuts (90 per policy), each followed by exact reset-vector HLT replay. The full
bootstrap also passes. Strict Verilator `-Wall` lint, preflight and Yosys
full-core synthesis pass for the unchanged RTL/property snapshot. CPU
properties contain 309 assertions, one assumption and 52 covers. See the
[bus-cycle and reset-cut report](../../design/intel_80286/report/2026-10-27-shutdown-bus-cycles.md).

The previous pre-bus connected-core BMC was stopped at frame 17 with no
terminal result. A fresh depth-24 BMC for the current RTL is running in
`design/intel_80286/work/formal_runs/shutdown_bus_core_20261027_01/`; its last
recorded progress is frame 12, with no terminal result. Prove, cover, PDR and
aggregate exact-source audit remain open. Raw bus pins, the wider #DF matrix,
CPGREP execution on RTL, broad ISA coverage and release acceptance remain open. Issue #80
checkpoint:
[GitHub comment](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6444263447).

**Previous checkpoint (2026-10-27 13:10 UTC):** invalid handler-gate validation
for restartable protected #DE/#TS/#NP/#SS/#GP now escalates to null-error #DF
with the original saved context. A DIV-by-zero test reads an invalid vector-0
gate, then the vector-8 gate, and verifies shutdown when that gate is also
invalid. The bounded #DF shutdown also covers vector-8 IDT overflow,
not-present target TSS and invalid incoming LDTR. Immediate and stalled READY
tests verify no retirement or pending bus request, task-switch effects,
quiescence and RESET recovery. Valid #DF task entry/IRET,
non-null LDT task entry, null-selector RPL variants and incoming segment
fault/priority matrices still pass. Strict lint, preflight, focused
`--iopl-controls` and the full default bootstrap pass. Details and hashes are
in the [shutdown report](../../design/intel_80286/report/2026-10-27-double-fault-shutdown.md),
[non-null LDT task report](../../design/intel_80286/report/2026-10-27-non-null-ldt-task-entry.md)
and [no-error task-gate report](../../design/intel_80286/report/2026-10-27-task-gate-noerror.md). See the
[incoming-segment report](../../design/intel_80286/report/2026-10-27-incoming-segment-faults.md),
[incoming-LDTR report](../../design/intel_80286/report/2026-10-27-incoming-ldtr-faults.md),
[task-return fault report](../../design/intel_80286/report/2026-10-27-task-return-faults.md),
[task-IRET report](../../design/intel_80286/report/2026-10-27-task-iret.md),
[task-gate switch report](../../design/intel_80286/report/2026-10-27-task-gate-switch.md),
[historical task-gate preflight report](../../design/intel_80286/report/2026-10-27-task-gate-preflight.md),
[double-fault report](../../design/intel_80286/report/2026-10-27-double-fault-escalation.md),
[shutdown report](../../design/intel_80286/report/2026-10-27-double-fault-shutdown.md),
[system-instruction report](../../design/intel_80286/report/2026-10-27-system-instruction-privilege.md),
[LLDT/LTR report](../../design/intel_80286/report/2026-10-27-lldt-ltr-privilege.md),
[live status](STATUS.md), and
[issue checkpoint](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6442740201).
Broader #DF generation/delivery phases, NMI wake, native shutdown bus
signaling, task-switch reset cuts and current-source connected-core proof
remain open. Older
connected-core cover/PDR jobs remain active on prior snapshots.
**Previous checkpoint (2026-10-27):** protected IOPL/IF handling and the
CPL-0-only protected HLT rule are implemented. The focused regression passes
320 scenarios across both READY modes; the full default Verilator bootstrap
and release preflight pass. Exact source identities, evidence and open formal
work are recorded in [current status](STATUS.md) and the
[HLT privilege report](../../design/intel_80286/report/2026-10-27-hlt-privilege.md).
No connected-core proof has evaluated this RTL snapshot; older `_21` cover
and PDR jobs remain active. Full-chip acceptance stays open.
**Verification update (2026-10-27):** the `--call-gate-retf-faults` suite now
checks a real outer-RETF stack-span `#SS(0)`, preserved exception and call
frames, handler repair, and IRET retry in both READY modes. This exposed and
fixed stale protected-return ownership after the generic memory-fault path.
Release preflight, the focused suite and the full Verilator bootstrap pass.
The full run log is `design/intel_80286/work/sim_codex_20261027/full_bootstrap.log`.
Current RTL SHA-256 is
`ffa9248d1866ecea38b2357f265028821a79768349e2ba86b7f0ac036ba6642b`; the
property snapshot remains 298 assertion statements, one assumption and 49
covers (SHA-256
`b46fea44605d534db9578a494663fdd3d76b0f1ad07e263ba8d9ca041d96e9c5`).
Run `_27` passed its base case and failed induction on an owner/opcode
assertion that admitted arbitrary simultaneous RET and IRET owners. That broad
invariant is replaced by an immediate property on the denied-memory-check
cleanup transition. Run `_28` passed its base case but failed induction at
`RET_CODE_START` from an arbitrary BUS continuation; the code-load property
now checks owner and PE there, while `FAR_RETURN_DONE` retains the RETF opcode
check. Run `_29` passed its depth-12 base case but failed induction at the
reverse event-state ownership assertion: its arbitrary BUS continuation had
`EVENT_GATE_TAIL` without an active event owner. I refined that assertion to
check the reverse relation only after an owner was active in the preceding
cycle. Preflight passes; the next proof snapshot has not started because the
older `_21` cover and PDR jobs are still running. No current-property BMC,
complete prove, cover, PDR or aggregate audit has passed. See
[current status](STATUS.md) and
[revised audit plan](2026-10-26-audit-and-revised-plan.md).

**Earlier formal refresh (2026-10-27):** all 36 component BMC, prove and cover tasks
pass on their recorded snapshots. The prior connected-core BMC passed through
24 frames, but its 290-assertion property file is stale. Invariant review
replaced an induction-only failure at line 160 with more specific ownership
assertions; the next run failed at line 180 on the unsupported invalid-TSS
nested-fault path. `_24` and `_25` passed their depth-12 base cases but failed
induction on unreachable protected CALL and RET continuation states. Current
properties add explicit owner invariants: 298 source assertion statements,
one assumption and 49 covers (SHA-256
`edbef28f43c79e09a09035ea7d40a8b76e18d95c58adf2d17a6051e35b96ee36`). Core
prove `_26` later returned UNKNOWN at line 86 on an induction-only owner-state
trace. See the live status above for later retries.
No current-property BMC, complete
prove, cover, PDR or aggregate audit has passed; no
reset-reachable counterexample is established. See [current status](STATUS.md)
and [revised audit plan](2026-10-26-audit-and-revised-plan.md).
The latest implementation adds protected interrupt/trap-gate delivery from
ring 3 through the TSS-selected ring-0 stack, exact inter-level frames and
outer IRET, and software-INT gate-DPL rejection. Eight focused cases pass in
both READY modes; the exact-source strict Verilator build, focused checks and
full bootstrap pass. Yosys 0.69 full-core synthesis and `check -assert` also
pass on the same RTL with zero problems and 40,652 cells. Evidence, hashes and limitations are in
[current status](STATUS.md). The older CALL/RETF, selector and string evidence
below remains applicable to its recorded source snapshots, but its earlier
formal and synthesis results do not qualify the new event implementation.
The 290-assertion connected-core BMC and the `_20`/`_21` induction history are
retained as earlier snapshots. Retries `_22`–`_28` localized induction gaps;
`_29` is pending against the current 298-assertion property snapshot.
Run manifests and traces remain under
`design/intel_80286/work/formal_runs/protected_event_outer_20261027_22/` through
`_29/`. See [current status](STATUS.md) for exact outcomes and next checks.
Task IRET, task-switch fault escalation, broader vectors and privilege rules,
the remaining ISA, independent historical software, native bus timing, and the
aggregate release gate remain open; full-chip acceptance is not claimed.

Older checkpoints below preserve history only.
The remainder of this file is historical context.

**Previous selector execution checkpoint (2026-10-26):** SLDT/STR, LLDT/LTR,
LTR's busy write, null-LDTR invalidation and LDT-backed data loads passed the
focused execution suite. Selector-error delivery and query execution now
extend that checkpoint. See the
[selector scope](../../design/intel_80286/spec/selector_execution.md),
[active audit plan](2026-10-26-audit-and-revised-plan.md) and
[current status](STATUS.md).

**Selector decode checkpoint (2026-10-26):** The earlier 18-case suite
recognized protected-valid 0F 00 /0–/5 and 0F 02/03, consumed the full
encoding, and stopped before operand access or retirement. Its `/0`–`/3`
stop expectation is superseded by the selector execution slice. Real-mode #UD
and invalid 0F 00 /6–/7 remain.

**ARPL follow-up (2026-10-26):** An earlier checkpoint added a protected-mode
ARPL slice with source-backed register/memory and null-source #GP checks. The
focused Verilator build, ARPL regression, real-mode #UD regression, protected
segment/event regression and preflight pass. A current-source connected-core
BMC passed on that earlier ARPL snapshot; prove and cover remain incomplete.
See the
[active audit plan](2026-10-26-audit-and-revised-plan.md) and
[current status](STATUS.md) for hashes and the exact evidence boundary.

**Formal follow-up (2026-10-26):** The pre-ARPL run passed all 36 component
formal tasks and connected-core depth-24 BMC; the exact-source audit was 37/40.
Core induction was UNKNOWN from an event-state invariant-strengthening gap;
core cover and PDR were interrupted without terminal status. A fresh current
ARPL connected-core depth-24 ABC BMC now passes with status `PASS 0 1577`.
Current-source depth-12 prove is `UNKNOWN`: basecase passes, but induction
fails at property line 154 because its antecedent omits the code-load request
target match used by the RTL success path. The depth-64 cover run was
interrupted after 28 witnesses at step 20; the exact-source audit reports
37/40 tasks PASS, with the old PDR snapshot stale. See
[current status](STATUS.md) and the
[formal plan](../../design/intel_80286/plans/formal_plan.md) for exact evidence.

Prepared 2026-10-23. Current owner: Codex. Workspace: `B:\ai_hw_engineer\worktree\intel-80286`. Design: `design/intel_80286`. Issue: [ai_hw_engineer#80](https://github.com/hevangel/ai_hw_engineer/issues/80), Building; start date 2026-10-23.

**String-fault follow-up (2026-10-25):** MOVS source/destination, STOS and OUTS
memory failures now follow the manufacturer handler-repair rules. The expanded
replay passes 55 cases, including backwards and FFFF word references. See the
[report](../../design/intel_80286/report/2026-10-25-protected-strings.md) and
current status for exact evidence. At that checkpoint CMPS/SCAS, IOPL and
full-chip closure remained open; neither that directed matrix nor earlier
proofs finished the 80286.

**CMPS follow-up (2026-10-26):** Both protected CMPS fault phases now have
repair and comparison tests. The source-matched replay passes 79 cases and the
mutation suite detects 15 faults. This closes only the focused CMPS slice;
SCAS, IOPL, independent software execution and full-chip closure remain open.
See the [latest audit and plan](2026-10-26-audit-and-revised-plan.md).

**INS follow-up (2026-10-25):** Intel's restartability memos exposed an escaped
defect in protected INS fault-time DI/CX. The core and regression now implement
the corrected post-C2 handler-repair state. Five scenarios pass in both wait
modes, including 64K wrap and REP final/nonfinal faults. The initial passing
tests of the old project contract are superseded for this behavior. See the
[failure note](../../failure_notes/2026-10-25-intel80286-ins-fault-state.md)
and current status for exact evidence and remaining checks. Earlier formal
results describe the pre-fix RTL/property snapshot and do not prove this change.

**Recovery baseline (2026-10-25):** The 286 source and Task 5 media have been
restored in the dedicated `design/intel-80286` worktree. The core RTL and
formal properties were recovered from the fresh Task 4 retry3 SBY source copy;
their SHA-256 identities are `c77cfbcedb8e0868a9826ad3df033e5b1f586338082018d3be905241fd54a702`
and `4d184fc59ad991c3ac02b81530b1e69e8965e7d11816886f6a9b4e2368fe3f57`.
The property inventory is 207 assertions, 1 assumption and 49 covers.
The prior checkout's `python3 scripts/preflight.py` passed immediately before
the reset; the script is not yet restored in this worktree.

Task 4 implements the bounded same-level protected vector-13 path. The
source-controlled `design/intel_80286/tb/protected_mode_replay.cpp` and
`scripts/run_protected_mode_replay.sh` now rebuild and pass the #GP frame,
handler DS repair, IRET retry, exact PC/successor trace and HLT checkpoint in
both wait modes. It checks descriptor/gate byte reads and accessed writes,
fault packet/frame state, denied operand access and retry data. The historical
runner covered additional reset cuts and four strict mutations on the earlier
checkout; its binary was replayed here, but its C++ inputs remain missing. The
new regression also resets after a handler descriptor read, the first frame
byte and the IRET CS accessed-byte write, then verifies exact restart.
Retry2 depth-24 BMC passed without a
counterexample in 26m13s. Its prove basecase passed, while k-induction exposed
a false address invariant that omitted the accepted-byte offset and checked a
request cancelled by reset. The property now tracks `memory_index` under an
active-request/reset guard. Retry3 depth-24 BMC passed in 30m26s with no
counterexample; its evidence and 21-file source snapshot now reside in this
worktree. The standard depth-12 prove passed its base case, but k-induction
failed at property line 43 from a non-reset event-gate state with PE clear.
The corresponding ABC PDR output 252 passed in frame 7. The last full PDR
log proves 283 outputs through frame 51 but has no final SBY PASS record; the
process is no longer present. The depth-64 cover log saved 43 witnesses and
reached step 39 before the process stopped. Neither run is complete. The
exact-source audit remains.

This is a bounded ring-0 slice. Task 5 selects the protected-mode
`CPGREP.EXE` sample from Microsoft OS/2 SDK 1.00. The nine original 1.2 MB
disk images and extracted sample are present in ignored `scratchpad/`; their
provenance and hashes are recorded in
[`2026-10-25-task5-media.md`](../../design/intel_80286/report/2026-10-25-task5-media.md).
The OS/2 Museum provenance note says the unmodified original floppies were
imaged with KryoFlux in June 2019 without read errors. SDK 1.00 contains an
OS/2 prerelease build, not the final OS/2 1.0 release. PCjs now reaches the
OS/2 prerelease kernel banner using direct local `--diskette`/`--disk` options,
then stops at BIOS error 1782. After F1 it prints the banner again but exposes
no shell; an injected CPGREP command produced no output. A successful
historical-software run and independent 286 trace remain outstanding. The
retry3 BMC output has moved into this worktree.

The complete 80286 goal remains open. Dated starting-state notes below are
historical; use
`STATUS.md` for the latest run identities and results.

## Objective and first deliverable

Continue toward a complete, independently verified 80286. The next architectural deliverable is a working ring-0 protected-mode path: initialize tables, set PE, reload CS, load data/stack descriptors, execute memory operations, deliver a segment-limit #GP through a protected interrupt gate, and return through IRET to retry the exact faulting instruction.

Do not spend another iteration expanding arithmetic test counts while PE still stops the CPU. Preserve the existing real-mode regression and implement the protected path in the dependency order below. The ring-0 milestone is not the complete CPU; later milestones retain the original scope.

## Read first

1. Repository `AGENTS.md` and the design [processor specification](../../design/intel_80286/spec/spec.md).
2. The [completion ledger](../../design/intel_80286/plans/completion_requirements.md), [current status](STATUS.md), and [worktree recovery report](../../design/intel_80286/report/2026-10-24-worktree-recovery.md).
3. The [ring-0 integration contract](../../design/intel_80286/spec/protected_mode_integration.md), then the recovered RTL and [formal harness](../../design/intel_80286/formal/intel_80286.sby).
4. Relevant `docs/verilator/` and `docs/yosys-symbiyosys/` documentation before invoking those tools.

The earlier progress/recovery reports, component testbench, and detailed
segment/code/cache specifications still need recovery. Do not treat their
historical results as reproducible until the missing source and harness files
are restored and the evidence is matched to exact source identities.

Treat reports as dated evidence summaries. Inspect source and saved result identities before relying on any statement that says “current.”

## Starting state observed on October 23

- The CPU formal-property file has been restored; its recovery model contains 110 CPU assertions and 41 covers.
- The saved `work/recovery_formal_audit.log` now ends with **36/36 current tasks passed**. The corresponding JSON records PASS for all tasks. Recovery core BMC and cover status files also report PASS. These jobs finished after the earlier 34/36 documentation checkpoint.
- Core results are under `work/protection_recovery_formal/intel_80286_{bmc,prove,cover}`. The audit combines these with unchanged component evidence under `work/formal`. Do not point the audit at the older canonical core directory and mistake stale core results for the recovery results.
- Recovery logs record passing strict lint, directed simulation, 99,650 independent Unicorn cases / 1,715,162 instruction states, 68,510 ordinary physical captures plus 52 protection captures in both wait modes, original IBM AT software regressions, and all eight synthesis targets. The historical 22,359-cell synthesis is from the earlier real-mode hierarchy and predates the integrated protected-mode bus/code/segment modules. Fresh synthesis of the current 14-file RTL hierarchy reports 28,595 cells in `design/intel_80286/work/synth_current/yosys.log`. These are separate phase results, not a completed end-to-end `run_all.sh` claim.
- The missing `test_protection_hardware_replay.py` now exists and rejects six corruptions. `run_protection_mutations.py` detects four injected RTL faults. Preflight, source/property audits and a short development loop have been added.
- The build wrapper uses content/tool fingerprints, binary hashes and a lock. Later edits added forced rebuilding, post-build input checks and process-group cleanup. Confirm the latest helper tests and real build/cache-hit behavior; do not assume the initial seven-test checkpoint verifies all later changes.
- Protected-mode CPU execution is still absent. The core explicitly stops when LMSW requests PE. Standalone descriptor engines do not constitute integrated protected execution.

This plan was prepared by reading files and existing logs, without running new verification. Revalidate source identities at takeover.

## Task 0 — Close recovery bookkeeping, without restarting completed work

**Files:** `scripts/audit_formal.py`, `scripts/preflight.py`, `scripts/build_runner.py`, their fixture tests, reports, README/index and completion ledger.

1. Inspect working-tree status and active jobs. Preserve unrelated chip/system work. Do not reset the shared checkout, overwrite existing proof directories, or start duplicate jobs.
2. Run preflight and the focused preflight/audit/build-helper fixture suites. If the latest process cleanup lacks coverage, add a bounded test that times out a builder with a child process and verifies no descendant can write after the lock is released. Test concurrent builds, changed inputs during a build, missing/modified binary, stale timestamps and failed builds without accepting an old manifest.
3. Re-run the inexpensive exact-source audit with the recovery core directory. If all 36 results still match, retain them. If something changed, identify the specific changed inputs and affected tasks before starting replacement proofs.
4. Verify the final build helper once on a real build/cache hit and execute `--protection` against the resulting runner. Reuse a valid existing build if its manifest already proves the same state; never force a rebuild merely to collect a second identical PASS.
5. Update the 34/36 text in the recovery report and completion ledger to the verified 36/36 result, naming its snapshot and paths. Update cache-helper evidence from actual results. Preserve the original progress review as a historical review.
6. Record a durable baseline: source identities, tool versions, log paths, open defects and next task. Do not claim the entire 80286 or an end-to-end release run is complete.

**Exit:** source/property integrity, regression wiring and cache tests are sound; saved verification is accurately described; no repair remains hidden behind a misleading status message.

## Task 1 — Resolve the protected-mode contracts before editing PE behavior

**Files:** `spec/protected_mode_integration.md`, `spec/protected_execution.md`, `spec/spec.md`, a new focused protected-mode testbench file.

Use the local Intel 210498-005 material and an independent 286 artifact where necessary. Resolve the open inherited-CS/CPL/cache state and TR/TSS prerequisites explicitly. Record exact source sections and evidence; do not infer behavior by reading the RTL or by assuming a later x86 CPU behaves identically.

Specify:

- Sticky PE behavior and retained caches during entry, including the documented transition instruction sequence.
- The fault request: vector, error-code presence/value, saved first-prefix CS:IP, restart classification, and software versus asynchronous event semantics.
- Which pending register, selector, cache, IP/SP and flag effects commit together; which accepted external writes cannot be rolled back.
- Descriptor, instruction and event bus ownership, stable requests during waits, and reset cancellation.
- Same-level interrupt-gate validation, frame layout, error-code removal and protected IRET validation/commit.
- Explicit unsupported boundaries for the first slice. Unsupported paths must never execute silently as real mode.

Create an externally specified test image and expected descriptor/frame/PC trace before implementing the path. Use an invalid DS limit to trigger a read fault, avoiding unproven write-side restart behavior in the first test. Keep exact successor assertions; no padding to absorb incorrect PC landings.

**Exit:** each architectural decision required for the first executable path has a source-backed contract or a clearly isolated unresolved assumption. Unknowns outside this path do not block unrelated progress.

## Task 2 — Implement fault and bus ownership prerequisites

**Primary file:** `src/intel_80286.sv`; factor a small module only if it clarifies ownership and can be tested independently.

1. Introduce the pending fault/commit state described in Task 1. Preserve existing real-mode event behavior.
2. Distinguish real-mode IVT entry from protected IDT entry. Do not route a protected fault into the existing six-byte real-mode frame.
3. Retain cached-reference vector/error outputs currently named `unused_*`. Select their semantics by operating mode; do not globally replace the real-mode vector-13 rule with protected #SS/#GP rules.
4. Define an exclusive descriptor/event bus handoff. No second requester may interleave with a held request or consume its response.
5. Check complete spans before irreversible memory writes or input-port consumption. Keep completed REP elements while preserving the faulting instruction's restart PC.

**Tests:** denied references issue no operand transaction; unrelated state stays unchanged; waits hold all request fields stable; reset cancels pending work; descriptor failures cannot publish a partially loaded cache. Retain existing real-mode tests.

**Exit:** the core has a usable, tested fault/commit interface and bus handoff. PE is not simply enabled before its execution and fault paths exist.

## Task 3 — Integrate ordinary protected segment loads and PE entry

**Files:** core, `intel_80286_segment_load.sv`, `intel_80286_code_load.sv`, cache/reference logic, core properties and focused testbench.

1. Wire the existing descriptor engines into the core. Reuse their validated interfaces instead of writing a second descriptor parser inside the CPU.
2. Implement the documented LMSW transition and sticky PE semantics. Preserve inherited caches until a valid reload.
3. Connect a direct protected far JMP to the ordinary code-load engine; commit visible CS, hidden cache and target IP only at its successful completion boundary.
4. Connect MOV-to-DS/ES/SS for the ring-0 GDT case. Preserve the old cache on failure and maintain the documented SS interrupt inhibition behavior.
5. Make subsequent fetch/data/stack references use committed cache bases, limits and permissions. Guard real-only formal invariants by mode and add protected invariants rather than deleting useful checks.

**Tests:** nontrivial descriptor bases prove that selector-times-sixteen is no longer used; accessed writes and cache commits occur at the specified times; descriptor validation and reset cases preserve old state; exact PC after every transition. Keep unsupported instructions visible and bounded during development.

**Exit:** the positive ring-0 program enters PE, far-jumps, loads segments and performs in-bounds memory operations. This is an intermediate checkpoint, not protected-mode completion.

## Task 4 — Close the first protected fault/IRET path

Implement the scoped same-level interrupt gate and protected return. Validate the gate, destination code, complete stack frame and IRET return state before the corresponding architectural commits. Preserve the exact fault IP and appropriate flags; push the specified error code. Keep delivery faults/escalation explicitly outside the supported slice until implemented.

The program must:

1. Fault on a word read crossing the DS limit, with no operand read and no destination update.
2. Enter the configured vector-13 handler through the IDT and produce the exact protected frame.
3. Discard its error code, load a wider valid DS descriptor and execute IRET.
4. Retry the same instruction successfully and execute its exact next instruction and final HLT/checkpoint.

Run both wait modes and reset cuts at descriptor reads, accessed writes, gate reads, frame writes and return commits. Add mutations for wrong saved PC, missing error code, early cache commit and ignored permission failure. Independently review expected values against the external semantic source.

**Exit:** one complete protected-mode execution/fault/recovery path passes. A component PASS or a PE bit visible in a register does not satisfy this gate.

## Task 5 — Independent software and release evidence

Choose an actual historical protected-mode workload whose exercised instructions and platform needs can be identified. Pin its provenance and bytes; state any harness setup. Use the new directed program as a diagnostic fixture, not as a substitute for historical software. Do not call a patched synthetic program “unchanged historical software.”

Obtain independent 286-specific expected behavior for the exercised protected path. Existing Unicorn vectors cover shared instruction semantics and the Harris corpus is real mode; neither establishes protected 286 exception semantics by itself. Identify a suitable external artifact before claiming independent protected-mode agreement.

Freeze the milestone source. Run required strict lint, formal BMC/prove/cover, simulation, vectors, physical replay, mutation checks, historical software, synthesis and the final exact-source audit. Preserve prior evidence and record all current result identities. Prepare a scoped feature-branch commit and PR per AGENTS.md after required checks; preserve unrelated work and never push directly to main or merge without review approval.

**Exit:** protected slice evidence and limitations are reproducible and reviewed. Extend the full-chip ledger rather than declaring the CPU finished.

## Subsequent milestones — retain the full scope

Order these by explicit dependencies and independent test availability:

- Complete real-mode encoding/fault inventory, fetch-boundary behavior, tiny-stack/shutdown and exceptional stack/ENTER/LEAVE cases.
- Protected null/expand-down/conforming segments, privilege checks, protected system instructions, LDTR/TR and broader far-control transfers.
- Privilege-changing gates/returns and TSS stack changes; remaining exceptions, nested-fault escalation and shutdown.
- Call/task gates, task switching and remaining 286-specific system behavior.
- 80287 ESC/WAIT, MSW emulation/task controls and BUSY/ERROR behavior.
- Native 16-bit address/data interface, BHE/status, READY/T-state timing, arbitration, LOCK and interrupt acknowledgement, with pin-level tests.
- Required UVM environment, full firmware/platform and protected historical-software closure, assumption-ledger resolution, final review.

Do not classify an implementation gap as an invalid opcode just to make tests terminate. Do not invent later-x86 behavior for undocumented 286 cases.

## Working cadence for Luna

Use one owner for the CPU integration state machine. Delegate bounded source research, independent tests or documentation only when useful; assign distinct files. User-authorized workers should use Luna with maximum effort. Do not have multiple agents edit the core or rebuild the shared simulator concurrently.

For each task: state the acceptance test, make one cohesive change, run focused feedback, inspect the first failure, fix the cause, and record the result. After a completed architectural slice, freeze the source and run the full evidence gate. Do not run the expensive whole-core cover suite after every documentation change, nor reuse evidence for changed RTL/properties/configuration.

`run_development.sh` now includes the focused protected selector-decode matrix
alongside #UD, protection and system-register checks. Keep `run_all.sh` as the
formal-first release gate; it has not passed on the current source.

Start a long job once, record its session/output directory, and inspect meaningful progress at reasonable intervals. Continue independent work while it runs. After interruption, inspect actual files and processes before retrying: a canceled tool call is not a rollback. Never overwrite a prior passing proof directory.

Use a durable handoff file in this directory, `STATUS.md`, after each completed slice or interruption. Record: current task; changed files; source/build identity; completed commands and result paths; active jobs; exact failing test/diagnostic; unresolved semantic decisions; and the next concrete edit. Do not fill it with repeated “still running” entries.

## Commands for takeover

Run these inside the existing `ai-hw-engineer:latest` tool container with repository mounted at `/work`, working directory `/work`. On Windows, the established invocation is `docker run --rm -v B:/ai_hw_engineer:/work -w /work ai-hw-engineer:latest ...`. Read the tool docs first.

```sh
python3 design/intel_80286/scripts/preflight.py
python3 -m unittest discover -s design/intel_80286/scripts -p 'test_preflight.py'
python3 -m unittest discover -s design/intel_80286/scripts -p 'test_audit_formal.py'
python3 -m unittest discover -s design/intel_80286/scripts -p 'test_build_runner.py'
python3 design/intel_80286/scripts/audit_formal.py \
  --core-work-dir design/intel_80286/work/protection_recovery_formal \
  --output design/intel_80286/work/continuation_formal_audit.json
sh design/intel_80286/scripts/run_development.sh
```

The recovery audit can pass only while its recorded inputs match. A stale result means determine the changed task inputs and create a new evidence run, not edit the old artifacts or weaken the audit. Do not rerun the full release gate merely to rewrite the dated recovery report.

## Copyable instruction to Luna

> Continue from plans/286/STATUS.md and the active revised audit plan. The
> current source executes ring-0 selector instructions and VERR/VERW/LAR/LSL,
> reaches CPL1/CPL2/CPL3 through real privilege transitions, and tests CALL
> gates through TSS-selected stacks. Two new matrices (32 executions) cover
> CPL1/CPL2 software INT gate-DPL boundaries and privileged-LIDT #GP(0) delivery
> through gate DPL 0/3, with exact frames and IRET successors. Next broaden
> those event tests to other exceptions and asynchronous vectors, then task-
> gate #TS/#SS delivery, nested-fault recovery, and remaining descriptor/return
> fault cases.
> Continue current-source formal, independent software and remaining
> protected architecture, ISA, independent CPGREP, native-interface and release
> gates in the audit plan. Preserve existing source and evidence, and keep the
> issue fields and first Start date current. Do not claim the 80286 complete
> until every completion requirement has passing evidence.
