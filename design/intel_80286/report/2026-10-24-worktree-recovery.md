# 80286 worktree recovery — 2026-10-24

Updated 2026-10-25 with the retry3 PDR follow-up.

## Recovery summary

The original working checkout was reset to clean `main` while the 80286 sources
and plan were untracked. The unignored design files therefore disappeared
from that checkout. The large ignored `design/intel_80286/work/` results and
the Task 5 reference materials remained available. The user directed recovery
of the 286 work and asked to put it in a worktree.

A local worktree was created at `B:\ai_hw_engineer\worktree\intel-80286` on
branch `design/intel-80286`, based on main commit
`4612e2ce6313e386b683d13deacf249028749ff6`. The core RTL and formal property
sources were restored from the source snapshot embedded in the active Task 4
retry3 BMC. The protected-mode fixture and plan were recovered from the saved
Codex task transcript. The chip README, top-level spec overview, implementation
entry point, completion ledger, status, and this report were recreated to make
the restored state reviewable.

## Preserved evidence and remaining recovery

The Task 4 retry3 depth-24 BMC passed after 30m26s with no counterexample.
After the launcher exited, the complete ignored `design/intel_80286/work/`
directory was moved into this worktree. The retry3 status is `PASS 0 1847`.
All 21 SBY source files match the recovered worktree byte-for-byte. The
standard depth-12 induction passed its base case but failed at property line
43 from a non-reset event-gate state with PE clear. ABC PDR proved that
assertion (output 252) in frame 7; the full PDR assertion set remains active.
Cover and the exact-source audit remain.

The Task 5 scratchpad references have been moved into this worktree's ignored
`scratchpad/` directory. The original component testbench, build scripts,
recovery reports, and several detailed specs were not present in the clean main
checkout or in the active BMC source snapshot. Recover those files from saved
task artifacts where possible before treating prior simulation or mutation
results as reproducible from this worktree.

The restored core SHA-256 is
`c77cfbcedb8e0868a9826ad3df033e5b1f586338082018d3be905241fd54a702`, and the
restored CPU property SHA-256 is
`4d184fc59ad991c3ac02b81530b1e69e8965e7d11816886f6a9b4e2368fe3f57`. See
[current status](../../../plans/286/STATUS.md) for proof outcomes and the
remaining 80286 completion gates.

## Follow-up verification — 2026-10-25

The recovered work was moved into the dedicated worktree after the retry3 BMC
exited. Strict Verilator 5.052 lint (`--lint-only -Wall`) passes on the 14
recovered RTL files. The preserved Verilator runner was replayed from
`design/intel_80286/work/sim/` and exited successfully; its output reports the
protected #GP recovery and reset-cut suite passing in both wait modes, as
well as the prior component and real-mode suites. Its manifest records runner
SHA-256
`a80516521b0bcfc8c076c2dfe9531618a781c72467fb9b0197cc8943f6eeadce` and
matches all 14 recovered RTL source hashes. The replay output is retained at
`design/intel_80286/work/sim/recovered_runner_replay.log`.

The manifest also records 13 C++ testbench inputs; 12 are absent from the
recovered source tree and the remaining protected-mode fixture differs from
the manifest hash. Treat this as execution of a preserved binary with
verified RTL identity, not as a source-audited rebuild. The current
depth-64 cover and complete ABC PDR runs are active under
`design/intel_80286/work/task4_protected_event_retry3/`. Neither has a full
PASS yet. No claim of complete 80286 support is made.

The current formal run source audit passed: each of the 21 RTL/property files
in the retry3 BMC, standard prove, PDR and cover snapshots matches the
worktree source byte-for-byte. Fresh strict Verilator lint passes, and fresh
generic Yosys 0.69 synthesis of all 14 RTL files succeeds with 28,595 cells
including submodules; its log is
`design/intel_80286/work/synth_current/yosys.log`. The older 22,359-cell count
in the October 21 recovery logs predates the integrated bus-owner, code-load
and segment-load modules and is retained as historical evidence only.

To restore reproducibility without claiming the missing old C++ suite, a new
focused regression was added at `design/intel_80286/tb/protected_mode_replay.cpp`
with `scripts/run_protected_mode_replay.sh`. A clean forced rebuild passed in
both unstalled and READY-stalled modes. It checks the exact retirement and
successor trace, descriptor/gate reads and accessed writes, protected fault
packet and frame, handler commit, denied read, IRET retry and final HLT state.
Its run log and exact source/tool/binary manifest are retained under the
ignored `design/intel_80286/work/protected_mode_replay_results/`. The focused
test also injects resets after the handler descriptor read, first protected
frame byte and IRET CS accessed-byte write, then reruns the complete path; the
accepted external frame byte is checked for persistence. The broader old
reset-cut matrix and four strict mutation checks remain outside this source
regression.
