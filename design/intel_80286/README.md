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

Work in progress. The core runs real mode and protected mode, including
privilege levels, call and task gates, task switching, LOADALL and the
processor-extension channel, and is checked against three independent
references:

- **Physical 286 captures.** Every real-mode file of the pinned
  SingleStepTests/80286 capture set (`37c73ca`) replays exactly, with and
  without bus stalls: 1,427,994 general, 68,510 port, 50,000 string and 52
  #GP records.
- **PCE-286 emulator.** 3,019 generated protected-mode scenarios: 2,926 match,
  93 differences are waived with cited reasons, none mismatch
  (`scripts/run_pce_oracle.sh`, now part of the release gate).
- **The unchanged IBM AT BIOS** under Unicorn, including its timer, DMA,
  page-register and refresh tests.

The issue #284 review (protected-mode fault rules, CPL, interrupt shadows)
and single-pass release-gate closure are complete: `sh design/intel_80286/scripts/run_all.sh`
runs end-to-end in one pass (`40/40` audited formal tasks passing, `52/52`
connected-core covers reached via blind depth-15 `cover` + Yosys `sim -assert`
primary-input witnesses, `16` mutation suites pattern-checked) and passes all
simulation, oracle, software, and synthesis gates. See the
[release-gate closure report](report/2026-11-24-release-gate-closure.md),
the [final report](report/final_report.md) for the #284 findings and release-gate
summary, and the
[post-mortem](../../failure_notes/2026-11-22-intel80286-review-284-fault-rules.md).
What remains for a complete 80286 is listed in
[the completion requirements](plans/completion_requirements.md); the
[2026-11-24 handoff](../../plans/286/2026-11-24-handoff.md) lists it in
priority order with the latest verified results. The earlier
append-only status log is archived in
[report/2026-11-22-readme-status-log.md](report/2026-11-22-readme-status-log.md).

## Relevant documents

- [Single-pass release-gate closure report (2026-11-24)](report/2026-11-24-release-gate-closure.md)
- [Verification final report](report/final_report.md)

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
