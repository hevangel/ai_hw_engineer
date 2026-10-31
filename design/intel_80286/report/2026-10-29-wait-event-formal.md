# WAIT/event formal counterexample — 2026-10-29

## WAIT extension-error/NMI priority race and correction

The replacement BMC `codex-286-wait-state-bmc-20261029-01` and earlier PDR
`codex-286-wait-race-pdr-20261029-01` both ended **FAIL** at step 9 on the
event-valid assertion. In the BMC witness, WAIT reaches `WAIT_BUSY`, BUSY
falls, ERROR# is active and NMI rises on the same edge. The sequencer starts
the extension-error exception while the event controller simultaneously
claims NMI and holds it valid outside a poll state. Intel 210498-005 tables
5-1 and 9-4 give instruction exceptions higher priority than NMI. The new
directed test reproduced premature NMI selection before the fix in
`codex-286-wait-mf-nmi-before-20261029-02`. The core now withholds new event
selection when WAIT can report the extension error, and holds WAIT while a
previously claimed INTR awaits acknowledgement under assumption A8. The
corrected bootstrap simulation passed with 111 PASS lines in retained
container `codex-286-wait-mf-nmi-after-20261029-01`. The new tests check both
READY modes, exact exception and interrupt frames, no intervening handler
fetch, IRET and exact successor execution. The already-claimed INTR test also
holds INTA stalled across BUSY/ERROR# changes, checks one acknowledgement,
and verifies the following WAIT reports the still-active extension error.

Full `run_sim.sh` passed with 203 PASS lines and no failure markers in
`codex-286-wait-mf-nmi-fullsim-20261029-01`, including 79 protected replay
PASS lines across stalled and unstalled READY cases. Its script was later extended with the separate
refresh arbiter and combined-path tests; those tests passed separately, not as
part of this completed run. The historical-software regression also exited 0
in `codex-286-wait-mf-nmi-software-20261029-01`, with 13 PASS lines. The
unchanged IBM AT BIOS reaches `F000:038A` in both virtual-clock/READY modes;
Unicorn matches 247,196 and 1,295,769 CPU instruction states and data
transactions respectively, using recorded I/O inputs. This is not an
independent peripheral or physical timing proof.
The completed regressions are recorded in [issue comment 6510351122](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6510351122).

Yosys synthesis, BMC and PDR are running in retained containers
`codex-286-wait-mf-nmi-synth-20261029-01`,
`codex-286-wait-mf-nmi-bmc-20261029-01`, and
`codex-286-wait-mf-nmi-pdr-20261029-01`. Each formal run's 21 copied inputs
matched the worktree at dispatch; no synthesis or whole-core
formal pass is claimed before its terminal result. The original BMC witness is in
`work/wait_state_formal_20261029_01/bmc/engine_0/trace.vcd`. Neither failed
run is a whole-core proof.
The checkpoint is recorded in [issue comment 6510250610](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6510250610).

The full-core ABC PDR run in retained container
`codex-intel80286-pdr-20261029-01` ended **FAIL** at step 9. Its 21 copied
RTL/property inputs matched the worktree at dispatch. The SBY log, source
snapshot and VCD witness are in
`work/current_pdr_20261029_01/formal_runs/pdr/intel_80286_pdr_prove/`.
The failed property file snapshot has SHA-256
`a86878199d5b1ce79cd92f2c2987723f13e430a12fa9312f1616e8e503006ba2`.

The trace fetches WAIT (`9B`) at reset CS:IP `F000:FFF0`; NMI becomes pending,
and BUSY falls as the processor is in `WAIT_BUSY`. On the same edge the CPU
retires WAIT and the event controller selects NMI. The CPU is then in
`BOUNDARY` for one cycle while the selected event is held valid, before
`EVENT_POLL` accepts it. The formal retirement-state list omitted `WAIT_BUSY`,
and the event-valid assertion required the core to poll immediately. These
assertions therefore failed on a reachable, intended handshake. An INTR
acknowledge can also remain outstanding on the same transition.

The property now admits WAIT retirement and the bounded WAIT-to-BOUNDARY
handoff while still requiring no CPU bus request during acknowledgement. The
event controller holds valid until accepted. The CPU regression exercises both
the NMI handoff and a delayed INTR acknowledgement, checks the exact interrupt
frame and handler, and checks the exact successor after IRET. This does not
independently settle the already documented saved-IP assumption A25 for an
interrupt while WAIT remains busy; it checks the case where WAIT retires.

The Verilator CPU bootstrap simulation passed in retained container
`codex-286-wait-race-sim-20261029-01`, including the new two-case race and
111 PASS lines overall. Reproduce in the repository image with
`INTEL_80286_WORK_DIR=/work/design/intel_80286/work/wait_race_sim_20261029_01 sh design/intel_80286/scripts/build_runner.sh`
followed by that work directory's `sim/Vintel_80286`. The fresh whole-core
bounded run in `codex-286-wait-race-bmc-20261029-01` later failed as described
below; a PDR run of the same snapshot subsequently failed in
`codex-286-wait-race-pdr-20261029-01` (ID
`5743d0a00de4`). Their evidence is under
`work/wait_race_formal_20261029_01/bmc/` and `pdr/`, respectively. All 21
copied RTL/property files in each run matched the worktree on dispatch. The
PDR failure
is not a successful proof; rerun BMC, induction, cover and PDR on the corrected
snapshot and retain terminal results and exact-source evidence before sign-off.
The checkpoint is recorded in [issue comment 6491814344](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6491814344).

## Bounded run: outdated state bound

The corrected-snapshot ABC BMC terminated **FAIL** at step 8. Its witness
fetches opcode `9B` and reaches `WAIT_BUSY` (state 106); the assertion
`state <= SHUTDOWN` used the older maximum of 105. The source now allocates
five later states, ending at `CALL_DESC_FINAL` (110). The state-range
assertion now uses that actual last state instead. This is a property change,
not a CPU RTL change. The earlier passing WAIT simulation exercises this state.
Preserved evidence is under `work/wait_race_formal_20261029_01/bmc/`.

A replacement bounded run was started in retained container
`codex-286-wait-state-bmc-20261029-01`, with evidence under
`work/wait_state_formal_20261029_01/bmc/`. The still-running PDR has the
pre-correction property snapshot; both it and the replacement BMC later failed
on the priority race described above. No bounded or unbounded current-snapshot
pass is claimed.
The follow-up is recorded in [issue comment 6492014603](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6492014603).

## Task-image read warning investigation

During preparation of the corrected BMC job, Yosys reported 16 undriven bits
on the read-mux branch corresponding to `task_state_image[15]`; the array has
only entries 0–14. The affected source expression selects its index as
`target==2 ? 12 : target==3 ? 13 : 10`, where `target` is two bits. Thus the
branch is not selected for any target. A separate combinational miter in
`work/wait_race_formal_20261029_01/task_index_miter.sv` checks the selected
index and its equivalence to a direct three-way data mux for arbitrary inputs.
Yosys `sat -verify -prove-asserts -set-def-inputs` passed in retained container
`codex-286-task-index-miter-20261029-03`, after `chformal -lower`.
This small miter is evidence for the index expression only, not a proof of
the full source or all other formal warnings. Preserve the source snapshots
and inspect terminal core results before drawing broader conclusions.

## Refresh investigation

The [IBM 5170 type 1 schematic](https://www.minuszerodegrees.net/misc/schematic_5170_motherboard_type_1.pdf),
sheet 21 (PDF page 11), shows the 8254 OUT1 signal entering the refresh
request logic and U118's inverted output fed back to its D input. U118 is
clocked by `+REFRESH` and its Q is `REF DET`, sent to sheet 17. This supports
a flip-flop driven by refresh cycles, rather than treating a free-running port
bit as evidence of refresh. The preset is tied to the board pull-up. The
grant/acknowledgement wiring still needs to be traced; no BIOS refresh
test is claimed as passing.
