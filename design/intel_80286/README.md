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

This repository contains a developing synthesizable 80286 core, component and
CPU formal properties, and directed regression infrastructure. Protected-mode
execution is still incomplete. The current milestone is a bounded ring-0 GDT
path through a same-level vector-13 interrupt gate and IRET retry; it does not
represent complete protected-mode support or a finished 80286. See the active
[continuation status](../../plans/286/STATUS.md) before relying on historical
verification results.

## Relevant documents

- [Processor specification](spec/spec.md)
- [Ring-0 protected-mode integration contract](spec/protected_mode_integration.md)
- [Implementation plan](plans/implementation_plan.md)
- [Completion requirements](plans/completion_requirements.md)
- [Worktree recovery report](report/2026-10-24-worktree-recovery.md)
- [Protected INS correction and verification](report/2026-10-25-protected-ins.md)
- [MOVS/STOS/OUTS correction and verification](report/2026-10-25-protected-strings.md)
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
A20's native port-side-effect timing, CMPS/SCAS fault rules and the full
release gate remain open.
