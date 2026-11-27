# Test plan: Intel 80386 core

| Check | Command | Oracle / reference | M1 status |
| --- | --- | --- | --- |
| Lint | `scripts/run_lint.sh` | `verilator --lint-only -Wall` | pass |
| Physical-capture replay | `scripts/run_vectors.sh` | SingleStepTests/80386 `459d49fb` `v1_ex_real_mode`, captured on an 80386EX | 1,758,671 / 1,758,691 pass; 20 listed open |
| Formal | `scripts/run_formal.sh` | Division identity; ALU flags against integer definitions | pass |
| Synthesis | `scripts/run_synth.sh` | Yosys generic synthesis | see report |
| Original software | (to add) | Unchanged historical program against an independent emulator | open |

## Replay method

For each record, the bench:

1. loads the 20-register initial state through the load port, seeds memory, and runs to HLT;
2. compares all registers. EFLAGS is compared through the capture's per-opcode `f_umask` (undefined flags are masked);
3. compares every captured final memory byte, and rejects any other write that changed memory. Pushed FLAGS images in exception frames are masked the same way as EFLAGS.

One upstream-revoked record is skipped. Eight records are waived with a reason pinned by hash (`scripts/sst386_waivers.json`).

## Coverage gaps in the oracle

- No captures exist for D8–DF, 0F00, 0F01, 0F02/03, 0F07 or 0F20–23. These paths are exercised only by construction and are listed as unvalidated in the report.
- The captures never exercise TF/IF-driven events, LOCK on register forms, or reset.
- The 386EX is not a 386DX. Its bus cycles, SMM-lengthened timings and internal I/O registers are not DX evidence.
