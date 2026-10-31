# Incoming task ES readability fault

**Date:** 2026-10-29 00:05 UTC  
**Issue:** [hevangel/ai_hw_engineer#80](https://github.com/hevangel/ai_hw_engineer/issues/80)  
**Branch/worktree:** `design/intel-80286`, `worktree/intel-80286`

## Source and case

Intel 210498-005 §8.4, Table 8-1 row 14 (“DS/ES segments are readable”)
maps an unreadable incoming DS/ES descriptor to `#GP`, with the selector as
the error code. I visually checked the row on printed page 8-6 (PDF page 156)
in Chrome using `playwright-cli` against the
[manufacturer's Programmer's Reference Manual scan](https://bitsavers.org/components/intel/80286/210498-005_80286_and_80287_Programmers_Reference_Manual_1987.pdf#page=156).

The case sets the GDT descriptor at selector `0x0030` to an executable,
execute-only DPL-0 code segment (access byte `0x98`). The incoming task uses
that descriptor as both CS and ES. Loading it as CS is valid; using it as ES
fails the readability check and must raise `#GP(0x0030)`. The test routes the
fault through the task gate and checks the exact packet and transferred task
state in both READY modes.

With this case, the incoming CS/SS/DS/ES selector-fault matrix covers 25
invalid-selector configurations, or 50 executions. The matrix now separately
exercises DS/ES selector validity, DS/ES readability, presence and privilege
checks, alongside CS/SS and table-limit boundaries.

## Verification evidence

- `scripts/preflight.py` passed.
- `scripts/run_sim.sh` completed with exit code 0 under strict Verilator 5.052
  `-Wall`: 173 `PASS:` lines, zero `FAIL:`/`ERROR:` lines, and the 50-execution
  incoming-selector matrix passed. Log:
  `work/incoming_task_es_readability_20261029_01/full_run.log` (SHA-256
  `c1e0fd963d0ca8394facd9d457273805cdb4d0d35de3a37d42e42b8f3a4e11d0`).
- Protected replay manifest result: `PASS`, 79 cases in both unstalled and
  READY-stall modes:
  `work/incoming_task_es_readability_20261029_01/protected_mode_sim_20261029T000457Z/build_manifest.json`
  (SHA-256
  `4ecb5d2c9a351d4d9a5908b0520628fc21fcdced9f4cc33913bc7fc78e87c154`).
- `tb/bootstrap.cpp` SHA-256:
  `04fcb239692c23a49033079e02cdf804be08dd0765fe5196559e00d6ccd9a76d`.
  The unchanged `src/intel_80286.sv` SHA-256 is
  `4616be2d6c9d5bff4245e9964c92b8a26b45a3b67abca9ef4f56ab4b90dd6ee7`.
- Project custom-field readback remains blocked by a GitHub GraphQL API rate
  limit. No project fields were changed; the previous issue checkpoint records
  Open/Building, Agent Codex, Path `ai_hw_engineer/design/intel_80286`, and
  first Start date `2026-10-23`.
- This checkpoint was posted and read back in issue comment
  [6484047009](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6484047009).

The 13-target Yosys synthesis remains applicable because RTL did not change.
Current-source connected-core formal, remaining post-transfer task-switch
fault phases, authentic historical software, native timing qualification and
full CPU acceptance remain open. The older whole-core PDR uses a separate
21-file snapshot and is not current-source evidence.
