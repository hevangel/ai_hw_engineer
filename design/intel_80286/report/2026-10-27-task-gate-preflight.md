# IDT task-gate TSS preflight checkpoint

**Date:** 2026-10-27 11:10 UTC  
**Issue:** [hevangel/ai_hw_engineer#80 checkpoint](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6440466589)  
**Branch/worktree:** `design/intel-80286` in `B:\ai_hw_engineer\worktree\intel-80286`

The project item was read back after the checkpoint comment: Status `Building`,
Agent `Codex`, Path `ai_hw_engineer/design/intel_80286`, and first Start date
`2026-10-23` remain set.

## Change

Intel's [80286 Programmer's Reference Manual, order 210498-005, §§8.2–8.5 and 9.4](https://bitsavers.org/components/intel/80286/210498-005_80286_and_80287_Programmers_Reference_Manual_1987.pdf)
defines IDT task gates and the 286 TSS. The event gate decoder now recognizes
type 5 and begins a bounded preflight: it checks the zero gate offset and
reserved byte, checks that the target selector is non-null, GDT-based and
within the GDT limit, then reads the target descriptor and checks that it is
a present, available 286 TSS with limit at least `002Bh` and zero reserved
bytes.

This checkpoint stops immediately after successful descriptor preflight. It
does not claim architectural task entry. No busy bit is written; the outgoing
TSS is not saved; the incoming TSS is not loaded; TR, TS, NT, backlink and
segment caches are not updated; the #DF error code is not pushed; task IRET
and shutdown are not implemented. Invalid task-gate/TSS cases still stop
diagnostically rather than delivering their specified exceptions.

## Directed evidence

The `--iopl-controls` regression creates a nested #GP that selects vector 8,
then supplies a task gate targeting selector `0050` and a present available
TSS descriptor with limit `002Bh`. In immediate and stalled READY modes it
checks all eight IDT gate bytes followed by all eight GDT descriptor bytes,
checks that no writes occur, and checks that the current CS, SP, FLAGS and
retirement count remain unchanged at the diagnostic stop.

The fresh Verilator build, focused log and full bootstrap log are retained in
`design/intel_80286/work/task_gate_preflight_build/`. The exact build command
was:

```sh
verilator --cc --exe --build -j 2 -Wall --top-module intel_80286 \
  --Mdir work/task_gate_preflight_build src/*.sv tb/bootstrap.cpp
```

The repository runner's pre-existing `work/sim` cache refers to source paths
under an old `/work/design/...` mount. Its attempted reuse failed with “No rule
to make target”; the cache was preserved and verification used a new ignored
build directory.

Strict Verilator `--lint-only -Wall`, `scripts/preflight.py`, the focused
`--iopl-controls` regression, and the full default bootstrap all pass. The
focused run also retains the 480 protected privilege scenarios. `git diff
--check` reports only the repository's LF-to-CRLF working-copy warnings on
plan files.

| Artifact | Identity |
|---|---|
| RTL `src/intel_80286.sv` | SHA-256 `73fe049105c7794e8bf9d61d22fc28d83a4f471b1c3f260a119782f1980596bc` |
| Testbench `tb/bootstrap.cpp` | SHA-256 `61f59532c26dad4eac6ef49aa7477ab49adfed4ab7b88e3149c846e43422c1cd` |
| Verilator | `5.052 2026-09-05 rev v5.052` |
| Fresh runner | SHA-256 `a3921483cd9d36252fa45189235c5b7367f9ee336513a6f6a2544055d75bda0b` |
| Focused log | `work/task_gate_preflight_build/iopl_controls.log` |
| Full bootstrap log | `work/task_gate_preflight_build/full_bootstrap.log` |

## Formal status and next work

No connected-core formal result covers this RTL snapshot. The older `_21`
cover job remains waiting at step 35, last logged at 11:12 UTC. The older PDR
job last advanced to frame 30 at 11:06 UTC with 366 outputs proved and 28
timeout retries. Both use older source snapshots and remain active, so no
overlapping core formal run was started.

Next implement the actual nested task switch: incoming busy-bit write,
outgoing dynamic TSS save, backlink, register/IP/FLAGS load, TR and TS update,
LDTR/SS/CS/DS/ES validation, NT behavior and #DF error-code push. Add task
IRET through the backlink and verify return to the interrupted task before
expanding the double-fault matrix and shutdown behavior.
