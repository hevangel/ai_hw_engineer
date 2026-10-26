# Intel 80286 continuation status

## Current checkpoint — CMPS and full-chip audit (2026-10-26)

The active continuation sequence is
[the 2026-10-26 audit and revised plan](2026-10-26-audit-and-revised-plan.md).
The prior 2026-10-25 plan is historical; its “CMPS unfinished” statements are
superseded by this checkpoint.

The protected-string change now includes CMPS source/destination fault repair
and compare semantics. The final strict Verilator 5.052 replay at
`design/intel_80286/work/protected_cmps_native_20261025_03/` has 79 passing
cases. Its manifest matches all 19 current replay inputs; the core SHA-256 is
`08ab26c1fc4fabb1320453036e09f3d62920795821bac60914483e0c594b7dca` and the
binary SHA-256 is
`6713a06c6b36c1f2585565748912081e222a143e0e899a297bc02163160a89fd`. The
focused mutation run at
`design/intel_80286/work/protected_cmps_mutations_20261025_03/` detected all
15 mutants with expected diagnostics.
The source-backed checkpoint description is in the
[CMPS report](../../design/intel_80286/report/2026-10-26-protected-cmps.md).

Yosys 0.69 synthesis/check completed with zero reported problems at
`design/intel_80286/work/cmps_checks_20261026_01/synthesis.log`. The depth-12
BMC at `bmc12_02/` is `PASS 0 185`; its 21 RTL/property files match current
source. Cover mode at `cover64_01/` timed out after 180 seconds with 11 complete
witnesses and 53 cover statements unreached. This is not a formal cover pass.
The current core and property SHA-256 values are
`08ab26c1fc4fabb1320453036e09f3d62920795821bac60914483e0c594b7dca` and
`430fc631524a30ea1637cab2e8d021c9204aee3bd6aea80b605eb7a6aaac83d2`.

The CMPS slice is present as nine modified tracked files on branch
`design/intel-80286`; it has not yet been committed. The branch is 37 commits
behind and 4 ahead of the local `main` reference. GitHub issue #80 remains
Building with Agent Codex, Start date 2026-10-23, and Path
`ai_hw_engineer/design/intel_80286`.

No 286 formal container was running when Docker was inspected on 2026-10-26.
The only recently started container was identified as an unrelated Busicom
firmware run. The 2026-10-25 PDR/cover containers were stopped earlier; their
saved logs remain historical evidence only.

The full CPU remains incomplete. CPGREP has not run; the recorded PCjs setup
stops at BIOS 1782 without a shell. The ISA/mode inventory, valid protected
opcodes, LDT/TR, privilege/task/event mechanisms, native bus, broad runner and
complete formal proof/cover remain open. See the active plan for sequenced
gates. No verification suite was rerun during this documentation audit.

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

## Task 5 media recovery

The SDK 1.00 media was already present in ignored `scratchpad/`; it was not
missing. All nine raw 1.2 MB images and the extracted `CPGREP` sample have been
hash-verified. `extracted/samples/APPS/README` identifies CPGREP as
“Protect” (protected mode) and describes it as a multi-threaded fast string
search program. The C and EXE hashes are recorded in
`design/intel_80286/report/2026-10-25-task5-media.md`; the earlier recovery
summary had these two filenames’ hashes reversed. The source set is an OS/2
prerelease build, not final OS/2 1.0.

A local PCjs headless run now loads the SDK program disk and a local hard-disk
image via `--diskette` and `--disk`, then prints the OS/2 Version 10.0,
Revision 3.42.1.1 banner. The AT BIOS reports `1782-Disk Controller Failure`.
After F1, the banner prints again but no command-shell prompt appears. A
scheduled CPGREP command produced no program output; this is not a successful
CPGREP run. No instruction trace or independent exception oracle has been
captured. PCjs remains a comparison harness candidate, not a normative 286
specification.

## Remaining scope

Task 4 only implements a bounded same-level protected vector-13 path. Task 5
selects the Microsoft OS/2 SDK 1.00 `CPGREP.EXE` sample for real-software
validation. PCjs reaches the prerelease kernel banner but does not expose a
command shell, so CPGREP has not run; independent 286 trace evidence is also
open. Independent INS port timing, remaining string-fault semantics, full protected-fault delivery,
nested-fault escalation, broader ISA completion, real-software regression,
and full-suite closure remain open. The overall 80286 objective is incomplete.
