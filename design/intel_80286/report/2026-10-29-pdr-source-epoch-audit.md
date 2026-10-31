# Preserved whole-core PDR source-epoch audit — 2026-10-29

## Later state after Docker interruption

The container described below (`dcd30140a9c0`) is no longer present in the
Docker inventory after an engine interruption. Its saved directory has no
terminal SBY status; its last recorded 344/411 outputs are not a completed
proof. A fresh current-source PDR ran in retained container
`codex-intel80286-pdr-20261029-01`; all 21 copied RTL/property files matched
at dispatch. It later failed at step 9; see the
[WAIT/event counterexample report](2026-10-29-wait-event-formal.md).

## Historical job state

The older whole-core ABC PDR remains active in the container. Its work
directory is
`design/intel_80286/work/release_lock_checkpoint_20261028_0720/formal_runs/current_pdr_20261028_0926/intel_80286_pdr_prove/`.
At 01:02 UTC, ABC PID 4917 had reached frame 79 with 342 of 411 outputs
proved and 40 timeout retries. Its latest observed solver log, timestamped
01:09:23 UTC, advanced to frame 96 with 343 of 411 outputs proved and 48
timeout retries. A later check at 2026-10-29 02:27:59 UTC found PID 4917 still
active after 16:58:05 elapsed, at frame 118 with 343 of 411 outputs proved and
50 timeout retries (`20744.33` solver seconds). No terminal PASS or failure
is recorded.

## Source comparison

The saved SBY job contains 21 copied SystemVerilog inputs: 14 RTL modules and
seven property files. All 21 have a matching current source file. Nineteen
files are byte-identical; these two RTL files differ:

| File | Saved PDR snapshot SHA-256 | Current source SHA-256 |
|---|---|---|
| `src/intel_80286.sv` | `71ebadce9b7ae4ebeff104274254b938424fa9fca8aa2f171dca34a18109c7c5` | `3e68c9080a7279822983642f0b9729b70269479f5f89db8021e77873104bec3e` |
| `src/intel_80286_code_load.sv` | `172076a66a541f029cf5bf90fc22c9bf40b3bfc1d153674f93a810e123aa833a` | `9adcb050b8b8911ac4e10a272d56696d73e554264ca36842ff5d363ebf8c3e57` |

The saved configuration is an ABC PDR prove run. The two differing RTL
inputs mean its eventual result cannot be reported as proof of the current
source, even if the run reaches PASS. At the time of the initial audit, the
current-source 183-PASS simulation and 79-case protected replay were separate
evidence and did not close this formal gap.

## Latest recheck — 2026-10-29 04:03 UTC

The preserved container job is still active after more than 19 hours. At this
recheck, the latest solver log line remains the 03:07:38 UTC frame-166 record
with 344/411 outputs proved and 67 timeout retries; no terminal result is
recorded. The job still uses the saved snapshot, where `intel_80286.sv` and
`intel_80286_code_load.sv` differ from current source. Preserve it and do not
count it as current-source proof.

## Previous recheck — 2026-10-29 02:27:59 UTC

The active ABC process remains on the same saved snapshot and has not
terminated. Its frame 118 log line records 343/411 outputs proved and 50
timeouts; it remains a stale-source run because the two RTL files above still
differ from current source. The current exact-source simulation now has 194
PASS lines and protected replay passes 79 cases in each READY mode, but neither
result substitutes for a current-source connected-core proof. Preserve this
job until terminal status; do not start a competing whole-core run while it
owns the existing formal slot.

## Next steps

The formal plan directs us to preserve this active run and not start a
competing connected-core job until it reaches a terminal result and its
source epoch is reconciled. Accordingly, no current-source core formal was
started during this audit. When the saved job terminates, preserve its final
logs and status, mark the result against the two-file snapshot, then run
current-source connected-core BMC, induction, cover, PDR and the aggregate
exact-source audit.
