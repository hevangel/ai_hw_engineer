# 80286 implementation plan

The detailed, dated work plan lives in the repository-level
[286 continuation plan](../../../plans/286/README.md). This file keeps the
design folder's implementation entry point local and names the required
completion evidence in [completion requirements](completion_requirements.md).

## Milestones

1. **Recover and audit the baseline.** Restore source and docs into the
   dedicated worktree, move preserved results after active jobs exit, and
   check each claimed result against exact source and tool identities.
2. **Close architectural contracts.** Use Intel order 210498-005 and
   independent 286 evidence to specify state commits, descriptor accesses,
   fault restart, event frames, bus ownership, and unsupported boundaries.
3. **Complete protected execution.** Build on the recovered ring-0 path to
   implement all documented protected-mode segment, privilege, event, return,
   and task-state behavior. Preserve existing real-mode behavior.
4. **Close whole-ISA and bus behavior.** Resolve documented instruction
   semantics, boundary cases, wait-state stability, reset cuts, and I/O side
   effects against external artifacts.
5. **Run real software and release verification.** Complete the OS/2 SDK 1.00
   `CPGREP.EXE` harness and independent trace, then run the full formal-first
   release gate on one identified source snapshot.

The first protected-mode implementation task and its exact byte-level trace
are defined by [the ring-0 integration contract](../spec/protected_mode_integration.md).
The design remains incomplete until every row in the completion ledger has
passing, reproducible evidence.
