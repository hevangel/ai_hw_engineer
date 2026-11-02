# Session History: Intel 80286 code-review fixes (issue #80)

**Work date:** 2026-11-01 to 2026-11-02 UTC
**Capture timestamp:** 2026-11-02T02:25:00Z
**Conversation UUID:** Kiro session `sess_7e129328-e355-4d8d-87ae-38c20e09db3b` (from the tool-output path; no separate conversation UUID is exposed).

## Goal

Read [issue #80](https://github.com/hevangel/ai_hw_engineer/issues/80),
address the 2026-10-31 code review of `main` at `f8b528d` first, and offload
mechanical runs to Claude Sonnet 5.5 sub-agents while the main thread kept the
decisions and code changes.

## Completed work

- Fixed review items 1 (82288 MRDC# on I/O reads), 2 (NMI edge through
  reset), 4 (82C284 power-up and parameter check, assumption A27), 5 (latched
  native-bus protocol error with `$fatal`) and 7 (EXT bit in the core's
  `enter_event` for faults during external-event delivery).
- Kept item 3 (pending NMI cleared after a failed shutdown recovery) with
  citations; documented item 6 (no pipelined addressing) as a spec limit;
  deferred item 8 (core restructuring) to a separate issue.
- Updated 16 bootstrap task-gate expectations to EXT=1 against Intel
  210498-005 App. B and Table 9-5; fixed a stimulus error in the new
  event-control test.
- Repaired stale state lists in `formal/intel_80286_props.sv` (state bound,
  `memory_return` continuations, `retire_o`/`event_o` sources, event-delivery
  path, task-switch segment staging) that made the connected-core BMC fail on
  `main`, after a static audit of every list against the RTL.
- Added the spec entries, the report
  `design/intel_80286/report/2026-11-01-code-review-fixes.md`, and the
  post-mortem `failure_notes/2026-11-01-intel80286-review-bus-strobes-ext.md`.
- Commit `3245280` on `design/intel-80286-review-fixes`, pushed;
  [PR #105](https://github.com/hevangel/ai_hw_engineer/pull/105) opened.
  Per-item reply posted on issue #80. Project Agent cleared; Status
  (Building), Path and Start date (2026-10-23) unchanged.

## Validation

All in `ai-hw-engineer:latest` (Verilator 5.052, Yosys 0.69): lint clean;
full `run_sim.sh` 218 PASS lines; protected-mode replay 79 PASS; AT BIOS
native and timer pass; event control 8024 checks and 7/7 mutations;
event-control formal BMC/prove/cover pass; `run_synth.sh` 13 targets with 0
problems; connected-core BMC depth 24 PASS (1:03:41); preflight and
`test_audit_formal.py` (17) pass. Not run: connected-core prove/cover and PDR.

## Model-call evidence

- Main thread: Claude Opus (Kiro does not expose the exact id or call count).
- Sub-agents, all `claude-sonnet-5.5`: source extraction (25.1 credits),
  project bookkeeping (2.53), unit verification (10.4), core regression
  (24.7), re-verification (8.71), BMC re-runs (8.32, 5.40, 5.54) and the
  props audit (15.0) — 9 runs, about 105.7 credits as reported per run.
- Exact token counts are not exposed and were not estimated.

## Duration

About 6 hours of wall-clock time (20:04 to about 02:25 UTC), dominated by
connected-core BMC runs of 63 to 116 minutes. Active model time is not
exposed.
