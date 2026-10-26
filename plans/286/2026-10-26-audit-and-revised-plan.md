# Intel 80286 progress audit and revised plan

Audited 2026-10-26 in the `design/intel-80286` worktree. This is now the active
continuation plan. It supersedes the 2026-10-25 plan's task order while keeping
that audit as a dated historical record. The overall 80286 objective remains
open; no completion percentage is claimed.

## Assessment

The latest work closes a useful, externally sourced protected-string fault
slice: CMPS now has register repair, a clean source-matched 79-case strict
replay, and 15 detected mutations. The earlier protected ring-0 #GP/IRET and
INS/MOVS/STOS/OUTS slices remain in that replay. This is focused functional
evidence, not evidence that the 80286 is complete.

The largest remaining risks are architectural coverage and independent
execution evidence. The 286 still lacks documented instructions and protected
mechanisms; OS/2 SDK CPGREP has not run; the full formal cover run timed out;
and the native pin-level bus contract is not implemented or verified. The old
plan's next edit said to finish CMPS, which is now stale. The next work should
first make this passing change a durable review checkpoint, then secure an
independent software/trace baseline before expanding the core further.

## Audit basis and current checkpoint

- Worktree: `B:\ai_hw_engineer\worktree\intel-80286`, branch
  `design/intel-80286`, HEAD `fce97a47bf901321abc6e773dc8fd9cf89a3cc2c`.
  The branch is 37 commits behind and 4 commits ahead of the local `main`
  reference. Refresh and reconcile it with the current upstream before PR
  review; no fetch or rebase was done in this audit.
- The implementation checkout has nine modified tracked files: core RTL,
  CPU properties, replay fixture and test sources, two mutation drivers, the
  manifest recorder, and two specifications. These are the pre-existing CMPS
  implementation changes; they are not committed yet. The current diff passes
  `git diff --check` (Git warns that one older CRLF document will be normalized
  to LF on its next update).
- The live GitHub item is issue
  [hevangel/ai_hw_engineer#80](https://github.com/hevangel/ai_hw_engineer/issues/80),
  still open and Building. Its project fields currently show Agent Codex,
  Start date 2026-10-23, and Path `ai_hw_engineer/design/intel_80286`.
- Evidence below was inspected in place and its source hashes were checked;
  verification suites were not rerun during this documentation audit.

## What works

| Slice | Current evidence | What it establishes |
| --- | --- | --- |
| Protected ring-0 fault path | Five directed replay cases cover #GP frame delivery, handler DS repair, IRET retry, exact PC/successor, reset cuts and READY stalls | The bounded same-level GDT/IDT vector-13 path works for this fixture |
| Protected INS repair | Five INS scenarios in the current replay cover byte/word, REP final/nonfinal, wrap and wait modes | The tested protected INS fault-time DI/CX repair and retry work in the fixture |
| MOVS, STOS and OUTS repair | Forty cases in the 55-case checkpoint, retained in the current 79-case replay | The tested source/destination fault phases, direction, count and wrap cases work |
| CMPS repair and compare | `work/protected_cmps_native_20261025_03/` has 79 PASS lines; its strict Verilator 5.052 manifest matches all 19 current replay inputs | The final directed replay checks both CMPS fault phases, REPE/REPNE behavior, compare flags, handler repair, exact PC and bus phases. Core SHA-256 is `08ab26c1fc4fabb1320453036e09f3d62920795821bac60914483e0c594b7dca`; binary SHA-256 is `6713a06c6b36c1f2585565748912081e222a143e0e899a297bc02163160a89fd` |
| Regression sensitivity | `work/protected_cmps_mutations_20261025_03/mutations.json` records 15/15 detected mutations with expected semantic diagnostics | The focused replay rejects the listed INS/string fault and compare regressions |
| Synthesis checks | `work/cmps_checks_20261026_01/synthesis.log` completes with Yosys 0.69 and reports zero problems in its checks | The current synthesizable hierarchy passes these structural checks; this says nothing about full instruction correctness |
| Bounded formal smoke | `bmc12_02/status` is `PASS 0 185`; all 21 RTL/property inputs in its snapshot match the current checkout | Assertions held for the configured 12-cycle bounded run only |

The formal cover snapshot also matches all 21 current RTL/property inputs, but
`cover64_01/status` is `TIMEOUT 8 90`. The solver stopped at its 180-second
limit after saving 11 complete witnesses; 53 cover statements remained
unreached. This is incomplete coverage, not a passing cover result.

The CMPS sources are consistent with Intel's statement that the comparison
flags are formed from `[SI] - [DI]` in the [80286/80287 Programmer's Reference
Manual](https://bitsavers.trailing-edge.com/components/intel/80286/210498-005_80286_and_80287_Programmers_Reference_Manual_1987.pdf).
The repair tests cite the original [Intel LOADALL memo, page
14](https://docs.pcjs.org/manuals/intel/80286/80286_LOADALL.pdf). Functional
read ordering is modeled ES:DI first; native per-beat ordering remains an
explicit assumption without an independent pin trace.

## What does not work or remains unverified

| Priority | Finding | Required response |
| --- | --- | --- |
| P0 | The 286 is not a complete CPU. Decode currently rejects documented protected-mode operations such as ARPL (`63`) and `0F 00/02/03` without a mode-specific inventory. Far transfers, LDT/TR state, privilege changes, task switching and exception escalation are incomplete. | Build an instruction/mode inventory from Intel sources, distinguish legal-but-unimplemented operations from invalid encodings, and implement by dependency group with exact expected behavior. |
| P0 | The selected OS/2 SDK 1.00 `CPGREP.EXE` has not executed. The recorded PCjs run reaches a prerelease OS/2 banner, then BIOS error 1782; F1 does not yield a shell and injected CPGREP produces no output. | Do not repeat that same boot attempt as if it were a new test. Identify a viable local 286 environment or independent hardware/recovered trace; keep the external emulator result separate from an RTL run. |
| P0 | There is no recovered, source-complete broad CPU regression/release runner. Several former harnesses and specifications are absent from this worktree. | Recover the exact sources where available; otherwise reconstruct named tests and enumerate the lost coverage. An aggregate runner must fail when required suites are unavailable instead of silently skipping them. |
| P1 | The whole-core proof is not closed. Depth-12 BMC is shallow; the current cover times out; prior induction/PDR runs lack final proof closure. | Partition obligations, fix reachability/invariant issues without weakening architectural requirements, and prove final source with reachable targeted covers. |
| P1 | SCAS fault-time index text in the old LOADALL memo names SI, conflicting with ordinary scan semantics. A20/port-consumption timing is assumed; INS decrementing-direction integration and I/O privilege checks remain open. | Resolve with independent 286 evidence or keep each behavior explicitly blocking sign-off; add focused tests after the oracle is settled. |
| P2 | The current interface is a functional byte scheduler, not the native 80286 pin interface. BHE/status, READY timing, arbitration, LOCK, interrupt acknowledge and 80287 connections are not closed. | Specify native pins and timing independently, then add pin-level monitors, scoreboards and platform tests. |

These limits are also reflected in the [completion requirements](../../design/intel_80286/plans/completion_requirements.md),
[processor specification](../../design/intel_80286/spec/spec.md),
[protected-mode contract](../../design/intel_80286/spec/protected_mode_integration.md)
and [Task 5 media report](../../design/intel_80286/report/2026-10-25-task5-media.md).
The 2026-10-25 string report remains a historical 55-case checkpoint; the
79-case manifest above is the newer CMPS evidence.

## Revised execution plan

### Gate 0 — Make the CMPS slice reviewable

1. Review the nine-file CMPS diff as one change. Reconfirm that compare flags
   retain source-minus-destination order and that phase-specific native repair
   matches the cited Intel memo. Do not alter passing sources without producing
   a new manifest and replay.
2. Add a dated design report containing the replay and mutation commands,
   source/binary identities, synthesis and BMC results, cover timeout, failed
   trial history, citations and remaining assumptions. Keep the ignored work
   directories as evidence; the report itself must be tracked.
3. Update the design status and issue comment with this checkpoint. Keep issue
   #80 Building, Agent Codex, its original Start date and Path.
4. Commit the implementation, focused report and status on the feature branch.
   Before opening a PR, fetch the current base and reconcile the observed
   divergence without dropping the worktree changes. Do not push to `main`.

**Exit:** one reviewable source commit has matching replay/mutation evidence,
with all formal limits and assumptions recorded. The focused CMPS behavior can
then be treated as closed; the full 286 remains open.

### Gate 1 — Restore the regression and specification baseline

1. Inventory the tracked design tree against the historical manifests. Recover
   missing component/real-mode test sources and detailed specs where exact
   versions exist; otherwise create explicitly named replacements and record
   what old coverage was lost.
2. Restore reproducible component, CPU simulation, formal, lint and synthesis
   entry points. Each stage must capture source/tool/command identity and exit
   status. Required missing inputs must fail the aggregate runner.
3. Preserve external vectors and real-software inputs with hashes and
   provenance. Keep generated binaries and restricted firmware in ignored
   `work/` directories.

**Exit:** a clean worktree can run the source-backed focused suites and reports
missing broad coverage explicitly; no stale binary can stand in for a rebuilt
source result.

### Gate 2 — Establish an independent software and trace baseline

1. Use the already documented PCjs BIOS-1782/no-shell result as the outcome of
   that configuration. Inspect viable local 286 emulators or available hardware
   traces and select one that can execute protected-mode software. Record its
   exact version, machine configuration and known limitations before relying
   on it.
2. Run unchanged CPGREP against a fixed input in the independent environment.
   Record stdout, output, exit behavior, input/media hashes and a usable
   instruction/exception trace. A kernel banner or a scheduled command is not
   execution evidence.
3. Specify the path to run the same authentic workload on the RTL: OS/2 boot,
   NE loading, required APIs/tasking and platform devices. A smaller authentic
   protected workload may diagnose the core earlier but does not close the
   CPGREP requirement.
4. Compare observed emulator behavior with Intel references; identify
   disagreements rather than treating any emulator as the normative ISA.

**Exit:** an unchanged historical program executes reproducibly in an
independent 286 environment, and the same bytes have a concrete RTL execution
path. Only a successful RTL run closes the software acceptance item.

### Gate 3 — Build the mode-specific ISA and behavior ledger

1. Enumerate documented opcodes, prefixes, operand forms, flags, privilege
   checks, exception ordering, and commit/side-effect boundaries for real and
   protected mode. Link every row to an Intel source, RTL location, positive
   test, negative test and independent expected result.
2. Resolve all current legal-opcode/#UD classifications, starting with ARPL
   and the `0F 00/02/03` system/selector family. Track unsupported documented
   behavior separately from architecturally invalid encodings.
3. Add an assumption ledger with the cited source, implementation site,
   validation evidence and whether the assumption blocks release.

**Exit:** no documented mode/encoding is missing from the inventory or
silently substituted with #UD, stop, or real-mode behavior.

### Gate 4 — Implement protected architecture in dependency groups

1. Complete descriptor and selector state: LDTR/TR, GDT/LDT selection, null,
   expand-down and conforming descriptors, validation, accessed/busy bits and
   atomic cache commit.
2. Complete ordinary protected control flow and stack transactions: far
   calls/returns, segment POP, LDS/LES, privilege checks, I/O permission and
   precise faults.
3. Complete privilege-changing interrupt/trap/call gates and returns, TSS
   stack selection, task gates/switching and backlink/NT/busy behavior.
4. Complete nested exceptions, #DF/shutdown, interrupt/NMI/TF/SS-shadow
   interactions, remaining string/IOPL edge behavior and the unresolved SCAS
   rule. Then close the documented 80287 ESC/WAIT/MSW and real-mode boundary
   behavior.
5. For each group, write the external expected transaction before RTL. Verify
   exact faulting PC and successor, denied side effects, bus waits, reset cuts,
   handler repair and targeted mutations.

**Exit:** each documented mechanism has independent expected behavior and
executable evidence. Unsupported instructions do not pass by halting, silently
falling back, or being misclassified as #UD.

### Gate 5 — Specify and verify the native interface

Define 16-bit data and byte lanes, BHE/status, T-state and READY timing, bus
ownership/arbitration, LOCK, interrupt acknowledge and coprocessor signals.
Separate native timing from the functional byte scheduler. Add protocol
monitors, scoreboards, coverage and representative platform/firmware tests.

**Exit:** native interface behavior is source-backed and covered in pin-level
simulation. Simulation and synthesis remain distinct from physical
qualification.

### Gate 6 — Prove, integrate and release

Freeze a final source/tool/input snapshot. Run strict lint, all required
component and CPU regressions, independent vectors/traces, formal proof and
reachable covers, mutation suites, authentic software and synthesis. Every
stage must have reproducible commands, hashes, logs and a bounded failure
status. Close each completion-ledger row, publish limitations, and submit a
feature-branch PR for human review. No single green replay, shallow BMC,
successful synthesis or external emulator run closes the chip.

**Exit:** all agreed completion requirements are supported by evidence on the
same final source snapshot and reviewed through the repository PR workflow.

## Handoff for the next implementation turn

Start with Gate 0, then Gate 1 and Gate 2. The CMPS replay and 15 mutation
results already have matching source identities; inspect those artifacts
instead of rerunning unchanged suites. Preserve the earlier failed trials and
the cover timeout. Do not begin a broad ISA RTL expansion until the missing
regression sources and an independent executable/trace path have been
accounted for. Continue to update issue #80's evidence and blockers while it
remains Building.
