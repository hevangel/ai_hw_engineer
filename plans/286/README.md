# Continuation plan: Intel 80286

Prepared 2026-10-23. Current owner: Codex. Workspace: `B:\ai_hw_engineer\worktree\intel-80286`. Design: `design/intel_80286`. Issue: [ai_hw_engineer#80](https://github.com/hevangel/ai_hw_engineer/issues/80), Building; start date 2026-10-23.

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

The existing `run_development.sh` covers #UD/protection real-mode checks. Extend it or add a clearly named focused protected-mode command once the new tests exist; the current script alone does not test new PE behavior. Keep `run_all.sh` as the formal-first release gate.

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

> Follow plans/286/README.md in order. First reconcile the completed recovery evidence with today's source and finish any remaining build-helper safety checks. Then implement the bounded ring-0 protected-mode path through a genuine #GP handler and IRET retry, using externally sourced semantics and exact-PC tests. Keep real-mode behavior passing, preserve unrelated work and previous proof artifacts, and update plans/286/STATUS.md with concrete checkpoints. Do not substitute more arithmetic coverage, standalone component counts or a plan document for integrated protected execution. Do not claim the full 80286 is complete until every full-chip gate is closed.
