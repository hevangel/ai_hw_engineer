# Intel 80286 progress audit and revised execution plan

> Historical plan, superseded on 2026-10-26 by
> [the latest audit and revised plan](2026-10-26-audit-and-revised-plan.md).
> The CMPS work described below as pending now has a source-matched 79-case
> replay and 15 detected mutations; use the newer plan for current status.

Audited 2026-10-25 (America/Vancouver). This is the active plan for the next
implementation owner, including Luna at maximum effort. It supersedes the task
order and takeover commands in [the October 23 plan](README.md). That document
and [STATUS.md](STATUS.md) retain historical evidence; neither replaces the
[full completion requirements](../../design/intel_80286/plans/completion_requirements.md).

## Assessment

The project has a working, source-controlled functional CPU slice, including
protected ring-0 entry, a same-level #GP handler and IRET retry. It is still far
from a complete 80286. The immediate constraints are missing broad regression
sources, incomplete architectural mechanisms, an unfinished string-fault
change, and no successful protected historical-software run. Larger arithmetic
case counts or additional shallow whole-core formal runs will not close those
constraints. No defensible whole-chip completion percentage can be assigned.

The prior plan correctly required external semantics, exact PCs, transactional
state changes and full-chip acceptance. Its execution instructions have become
stale: Tasks 1–4 largely describe the already implemented bounded ring-0 path,
while Task 0 and takeover commands name absent recovery helpers. The replacement
sequence below starts from the actual source and leaves every full-chip gate open.

## Baseline and audit method

- Repository: `hevangel/ai_hw_engineer`; issue
  [#80](https://github.com/hevangel/ai_hw_engineer/issues/80), Open, Building.
- Task checkout: `B:\ai_hw_engineer\worktree\intel-80286`, branch
  `design/intel-80286`, local HEAD
  `af9026410fef74c871cbc084aea909d2e11f5e55`. No upstream is configured.
  Local `main` is `461c507415121ee84296514c945e3b0de0d21e27`;
  `git rev-list --left-right --count main...HEAD` reports `35 3`.
  The task branch is unmerged; this audit does not establish upstream availability.
- There are 14 RTL files, seven property files, two core SBY configurations,
  three C++ fixture/replay files and four focused scripts in the recovered design.
  There is no restored broad simulation/UVM environment or full release runner.
- Five files already had uncommitted CMPS work: both replay sources, manifest
  recorder and both mutation scripts. RTL and properties still match HEAD.
  These edits were preserved; this audit changes documentation only.
- Reviewed source, specifications, plans, reports, saved manifests, formal
  status/logs and live Docker jobs. Rehashed the saved replay binary and inputs,
  both current formal source snapshots, and all ten mutation logs.
- Actually rerun: the saved 55-case binary (exit 0, 55 PASS lines), and the
  unfinished CMPS binary (exit 1, native-state mismatch). Neither was rebuilt.
  No new lint, synthesis, proof, cover or mutation compilation was run.

Ignored local audit evidence is in `scratchpad/286_progress_audit_20261025.json`,
`scratchpad/286_audit_mutations_20261025.json`,
`scratchpad/286_audit_baseline_replay_20261025.log` and
`scratchpad/286_audit_cmps_replay_20261025.log`. Preserve these alongside the
original `design/intel_80286/work/` evidence. Local generated files and downloaded
media are evidence inputs, not committed implementation or published results.

## What works, and what that proves

All evidence paths below are relative to `design/intel_80286/`.

| Area | Observed evidence | Limit |
| --- | --- | --- |
| Protected ring-0 path | GDT setup, PE/far jump, segment loads, denied word read, vector-13 frame, handler DS repair, IRET and exact retry/successor pass in the focused replay | Same-level GDT slice; not all selectors, gates, exceptions or privilege levels |
| Fault/commit and reset | Five existing replay cases include three reset cuts at a descriptor read, first frame byte and IRET accessed write; stalled runs check held request fields | Selected cuts only; not the older complete reset matrix |
| Native string repair | `work/protected_strings_20261025_03/` records 55 passing cases: five prior cases, ten INS and forty MOVS/STOS/OUTS cases; saved binary passes again during this audit | Directed manufacturer-derived checks; not physical timing or complete string coverage |
| Regression sensitivity | `work/protected_strings_mutations_20261025_01/mutations.json` records ten compiled, detected mutants; all ten log hashes and expected diagnostics checked again | Compilation was not repeated; CMPS mutations remain unrun |
| Strict build | Passing baseline manifest identifies Verilator 5.052, g++ 15.2.0 and `-Wall` build | Recorded result for that snapshot, not a rebuilt dirty checkout |
| Synthesis | `work/strings_checks_20261025_01/synthesis.log` completes Yosys synthesis/check with 28,734 cells | Synthesizability of a functional model does not prove ISA or native pin compatibility |
| Bounded formal | `work/strings_checks_20261025_01/bmc12/status` is PASS; both BMC/cover snapshots contain 21 matching RTL/property inputs each | Depth 12 is a smoke bound, not a proof of a full protected execution trace |
| Provenance/recovery | Core and properties are committed; SDK images and CPGREP hashes are recorded in the media report | Downloaded media and recovered binaries do not restore missing test sources or establish a software run |

Baseline core SHA-256:
`3e2a84e8a5d417e153b3fe525ecd66e180428e3814b644fbc33c2c2258687f96`.
CPU properties:
`a6ce79a5e9853f915156fbff15ce0b967fbc9b023fad23fccd6fc2f2c0c40cbd`.
Saved replay binary:
`cf69a2a7565ef3428c40db4dfcf8cf0bf4b83f808da47aa40b45751b3737956e`.

Only 16 of the baseline manifest's 19 inputs match the dirty checkout now:
`tb/protected_mode_replay.cpp`, `tb/protected_string_replay.h` and
`scripts/record_protected_mode_manifest.py` changed for CMPS. The two mutation
drivers also changed. The 55-case result remains valid for its recorded baseline;
it must not be described as a passing rebuild of today's unfinished test inputs.

## What fails, is absent, or remains unverified

| Priority | Finding and evidence | Required change |
| --- | --- | --- |
| P0 | The dirty CMPS replay fails with `string-fault packet or native indices/count mismatch`; `work/protected_cmps_red_20261025_02/` has no passing manifest. MEMORY_CHECK has native repair for INS/MOVS/STOS/OUTS, but no CMPS repair branch | Finish the externally specified CMPS transaction, its formal properties and mutations as one reviewed change; do not count the intended 79 cases as passing |
| P0 | No `scripts/run_all.sh`, `run_formal.sh`, `run_sim.sh`, `preflight.py`, `audit_formal.py`, `build_runner.py` or broad test sources in this design's recovered tree. Old case counts refer to preserved binaries/logs | Recover or reconstruct source-controlled regression entry points and external input provenance before claiming broad current real-mode coverage |
| P0 | Decode marks `63` and `0F 00/02/03` as undefined without a mode guard (`src/intel_80286.sv`, `undefined_encoding`); DECODE sends these to #UD. Intel's manual documents ARPL and the protected system/selector instructions | Add a mode-specific documented-encoding inventory and tests, then implement valid protected forms. Distinguish unimplemented behavior from architecturally invalid encodings |
| P1 | LDT inputs are tied to zero/invalid in core code/segment loader instantiations. Components accepting LDT/CPL inputs do not establish integrated LDT or task-state behavior | Implement LDTR/TR and cached system descriptors with validation, accessed/busy semantics and atomic commits |
| P1 | Protected far CALL/RETF, segment POP and LDS/LES explicitly stop in EXECUTE. Delivery and protected-return validation failures also stop. Privilege changes, call/task gates, TSS switches and exception escalation are incomplete | Replace development stops with source-backed instruction/event transactions and correct fault delivery, in dependency order |
| P1 | Current core cover times out: `work/strings_checks_20261025_01/cover64/status` is TIMEOUT, eight complete witnesses recorded. Earlier induction failed; old PDR progress is not a final PASS | Partition proof obligations, address reachability/invariants and prove non-vacuity of actual protected paths; keep timeout/unfinished outcomes visible |
| P1 | OS/2 SDK CPGREP has not run. The independent PCjs attempt reaches a prerelease banner, then BIOS 1782/no shell. No protected physical/independent execution trace is captured | Establish a working external software baseline and a separately specified RTL platform/loader contract; a banner is not program execution |
| P1 | SCAS's old Intel memo names SI where scan semantics use DI; A20 INS port-consumption timing is assumed. INS DF=1 integration and IOPL checks remain open | Resolve against independent 286 evidence, add directional/privilege/side-effect tests, and keep unresolved semantics explicit |
| P2 | Core interface has byte data and functional request/ready scheduling. Native BHE/status/T-state arbitration/LOCK, native interrupt acknowledge and 80287 interfaces are not complete | Add a separately specified native interface and pin-level verification; retain functional tests without calling them native timing tests |
| P2 | Assumption comments cite several missing detailed specs, including `spec/memory_execution.md`; no complete recovered assumption closure matrix exists | Recover references and consolidate every assumption, source, implementation location and independent validation gate |

The Intel 1987 manual and the existing integration contract are the semantic
inputs for these findings. This audit did not change or settle disputed silicon
behavior. See the [processor spec](../../design/intel_80286/spec/spec.md),
[integration contract](../../design/intel_80286/spec/protected_mode_integration.md),
[string report](../../design/intel_80286/report/2026-10-25-protected-strings.md)
and [media report](../../design/intel_80286/report/2026-10-25-task5-media.md).

### Correction: older formal jobs are still active

Docker inspection contradicts the earlier status statement that these processes
were gone. At audit time both containers were running, mounted to this worktree:

| Container | Output under `work/task4_protected_event_retry3/` | Observed state |
| --- | --- | --- |
| `08ff02ed061f` | `intel_80286_pdr/` | No terminal status; latest inspected progress PRV=289, no complete SBY PASS |
| `8f82f426aa15` | `intel_80286_cover/` | No terminal status; 52 `.yw` files, solver checking step 48; witness-file count is not complete cover closure |

Both snapshots use core `c77cfbce...` and properties `4d184fc5...`, predating the
INS and MOVS/STOS/OUTS fixes. Their eventual result cannot verify current RTL.
No job was stopped, restarted or duplicated during this audit. Before allocating
new whole-core solver runs, preserve their identities/logs and make an explicit
resource decision; record cancellation as cancellation, never failure or PASS.

## Revised implementation sequence

Execute these gates in order, with bounded independent research alongside the
current gate. One owner edits the integration state machine. No new workers are
authorized by this plan; use subagents only if the user explicitly asks.

### Gate 0 — Establish a durable, reproducible baseline

1. Preserve the five dirty CMPS files and identify their exact diff from HEAD.
   Keep the red run and original passing inputs; never reset or overwrite them.
2. Inventory missing regression/spec/oracle sources. Recover exact copies where
   available; otherwise reconstruct explicitly named replacements and identify
   the lost coverage. Stop invoking absent takeover helpers.
3. Make tracked formal/simulation/synthesis entry points, including component
   harnesses, usable from a clean checkout. Keep a failing aggregate result when
   required stages are missing; never silently skip them.
4. Improve evidence capture before the next expensive checkpoint: hash/copy
   inputs before compilation, verify them after compilation/execution, bind
   commands/configurations/tool/container identity and logs to results, reject
   source drift and preserve nonzero exits. The current recorder hashes files
   after execution and does not independently detect mid-build source changes.
5. Account for the two live old-snapshot jobs above. Set per-job time/resource
   bounds and cancellation rules before starting replacement work.

**Exit:** a clean-checkout focused rebuild is reproducible, missing broad stages
are explicit, input drift cannot produce a trusted PASS, and every active job
has an owner, source identity, output location and bound.

### Gate 1 — Close the pending string-fault change

1. Review the CMPS oracle independently against Intel's handler-repair rules:
   ES is the first reference; its failure advances DI and decrements repeated CX
   once. A second/source failure advances both indices and decrements CX twice.
   Apply signed byte/word delta, wrap, exact saved prefix PC and preserved flags.
2. Implement the missing repair and correct protected word-wrap dispatch; update
   narrowly scoped register-isolation properties. Preserve earlier string cases.
3. Finish and freshly rebuild the intended 79-case matrix (including equal REPE
   and unequal REPNE), then compile/detect all intended 15 mutations. These counts
   describe the unfinished test design, not current results. Require exact
   frames, bus order, indices, flags and next instruction; retain old-core failure.
4. Add INS DF=1 and I/O privilege tests. Resolve SCAS with a documented independent
   286 artifact; if evidence remains contradictory, isolate that decision and
   continue other work rather than silently guessing or repeatedly scanning PDFs.
5. Run focused lint/simulation/mutations and applicable formal/synthesis checks
   against a frozen snapshot. Keep shallow BMC and incomplete covers qualified.

**Exit:** CMPS has a committed passing implementation/evidence set; all other
string/IOPL/native-port gaps have precise tests or named unresolved evidence.

### Gate 2 — Build an independent executable software baseline

1. Make one bounded diagnostic pass on the PCjs AT/controller/media configuration
   using pinned versions and a recorded launch command. If the same failure
   persists, record it and select another local 286 environment or external trace.
2. Run unchanged CPGREP on fixed input and record stdout/output/exit behavior and
   binary/media hashes. Separate an emulator software result from an RTL result.
3. Specify the RTL execution environment: CPGREP needs OS/2 services and platform
   support; it cannot simply be loaded as a raw directed CPU fixture. Identify
   the NE loader, APIs/tasking and machine dependencies or require a real OS boot.
   An initial smaller authentic protected workload may diagnose the CPU sooner,
   with its provenance and limitations stated, without closing the CPGREP gate.
4. Capture independent 286 instruction/exception traces for exercised behavior.
   Cross-check emulator semantics against Intel and retain disagreements.

**Exit:** a reproducible external reference run plus an explicit path to running
the same authentic bytes on the RTL. Only an actual matching RTL run closes the
historical-software acceptance item.

### Gate 3 — Complete the mode-specific ISA and protected mechanisms

Create a checked inventory of every documented encoding, prefixes, operand forms,
mode/privilege restrictions, flags, exception priority and commit effects. Give
each row its RTL location, external oracle and positive/negative test. Restore
real-mode regressions and fix valid-opcode/#UD classification first.

Then implement coherent dependency groups:

1. System/selector instructions and LDTR/TR state; GDT/LDT selection, null,
   expand-down and conforming descriptors; all segment-load forms and faults.
2. Ordinary protected far calls/returns and precise stack transactions; privilege
   checks for I/O, flags, control and system operations.
3. Privilege-changing interrupt/trap/call gates and returns with TSS stack
   selection, full frame validation and atomic CPU state commit.
4. Task gates/switching, busy/backlink/NT behavior, nested exceptions, #DF and
   shutdown; complete interrupt/NMI/TF/SS-shadow interactions.
5. Remaining real-mode boundaries, exceptional ENTER/LEAVE/stack behavior,
   fetch limits, undefined encodings and 80287 ESC/WAIT/MSW controls.

For every group, define external expected behavior before RTL, include exact PC
and successor, denied-side-effect tests, waits/reset cuts and targeted mutations.
Do not “complete” an instruction by making its unsupported path stop or #UD.

**Exit:** no documented ISA/mode row is missing or silently substituted, every
architectural mechanism has executable evidence, and assumptions are independently
resolved or explicitly prevent sign-off.

### Gate 4 — Close native interface and verification architecture

Specify and implement the native 16-bit bus, byte lanes/status, READY timing,
arbitration, LOCK and interrupt acknowledge, plus required coprocessor signals.
Keep timing expectations independent of the functional byte scheduler. Build
pin-level tests and the required UVM environment, with protocol monitors,
scoreboards, coverage and representative platform/firmware regressions.

Replace repeated shallow whole-core attempts with a proof plan: component
contracts, ownership/commit invariants, reset-reachable induction and targeted
protected-path covers. Preserve useful assertions; fix unreachable-state
induction failures without weakening architectural requirements. Formal depth
must be justified by the obligation, not selected to obtain a green status.

**Exit:** documented native interface coverage, closed assumptions, and passing
proof/cover results for the final source, with physical qualification explicitly
distinguished from simulation and synthesis.

### Gate 5 — Full-chip release and review

Freeze one identified source/configuration snapshot. The restored `run_all.sh`
must run the formal-first release workflow, strict lint, required simulation/UVM,
independent vectors/physical captures, mutations, real historical software and
synthesis. Require exact source/tool/log manifests and no missing or stale stages.
Check every completion-ledger row; publish a report with remaining limitations.
Use a feature-branch PR and human approval; never push directly to `main` or infer
human/physical verification from a tool PASS. Full 80286 completion remains open
until all agreed gates close, not merely the current protected slice.

## Instructions for the next Luna-max continuation

Start with Gate 0, preserve the dirty CMPS work, then finish Gate 1 as one cohesive
change. Do not reimplement the existing ring-0 #GP/IRET path or start the absent
October 23 takeover scripts. Use Gate 2 to obtain independent software evidence
early enough to expose architecture gaps before expanding more self-written tests.
After each slice, record source identity, commands, exact result paths, failing
diagnostic, active job/container IDs, unresolved semantics and the next edit in
`STATUS.md`. Check actual Docker state after interruptions. Keep progress updates
about findings, not solver polling. Reuse valid evidence only for matching inputs.

Follow the live GitHub issue lifecycle: retain the first Start date and actual
Path, claim the working Agent only while active, keep #80 Building while the chip
is partial, record scoped evidence/blockers, and clear Agent on stop/handoff.
Preserve the existing Sprint commitment; do not set one by default. No approval
or finished-chip claim is implied by this audit or plan.
