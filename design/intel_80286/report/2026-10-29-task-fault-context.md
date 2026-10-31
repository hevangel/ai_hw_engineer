# Incoming-task fault context and hidden segment caches — 2026-10-29

## Source and finding

Intel 210498-005 §8.3, printed page 8-6 (PDF page 156), says the incoming
task's registers are loaded before its LDT and segment descriptors are fully
checked. A protection fault during those checks is handled in the incoming
task context. Its visible DS/ES selectors can therefore contain nonzero values
whose hidden caches are not usable; the handler may save and inspect the
selectors before repairing them. The source page was reviewed in Chrome using
`playwright-cli`. The capture is
[`manual-page156-table.png`](../work/historical_software_current_20261029_23/manual-page156-table.png)
(SHA-256 `BFF7DF44409CB863233728A4AD311E94667847C16F6B5B1F1BE511B9302F1B91`).

The RTL already transferred visible registers and task state on this fault
path, but `task_entry_fault_context` left the outgoing task's hidden segment
caches in place. A same-level #GP handler then used the incoming SP and SS
selector with the outgoing SS base. The handler could also access data through
the rejected incoming DS selector using the outgoing DS cache. The pre-fix
unstalled directed run reproduced a missing frame on the expected incoming
stack and a write to the outgoing stack.

## Fix and regression

`task_entry_fault_context` now publishes only incoming segment caches whose
descriptors have passed validation. It clears the base, limit, access and
valid state for the other caches, carries the incoming LDTR cache only when
validated, and sets `cs_trusted` only for a validated CS. The first word of
each new `TASK_SWITCH_LOAD` clears staged LDTR and segment caches so a later
task switch cannot inherit earlier descriptor state.

The directed regression gives the incoming task SS=`0028`, CS=`0030`, and an
invalid DS=`0050`; the outgoing and incoming tasks use distinct stack and DS
bases. It delivers the incoming DS #GP to a same-level handler that executes
`MOV AX, DS:[0]`. In both READY modes the test checks error `0050`, saved
CS:IP=`0030:0300`, SP=`0080`, and the exact frame words `0050, 0300, 0030,
4202` on the incoming stack. It also asserts there are no writes to the
outgoing stack and that the handler's subsequent DS access raises another #GP
without reading the outgoing DS base. The testbench's generic hidden-cache
invariant now permits this specific protected incoming-task transition before
the event pulse; the directed stack and bus assertions remain explicit.

## Verification evidence

- Exact-source `scripts/run_sim.sh` exited 0 with 198 `PASS:` lines and no
  `FAIL:`, `ERROR:` or `FATAL` markers. The protected replay manifest is
  `PASS` for 79 cases in both READY modes. Evidence is under
  `work/task_switch_fault_context_20261029_42/`.
- Exact-source `scripts/run_synth.sh` exited 0 under Yosys 0.69 (git
  `9f75ca1f9`). All 13 targets produced JSON netlists and passed three clean
  structural checks each (39 total, zero errors). The core target took
  499.94 seconds. Evidence is under
  `work/task_switch_fault_context_20261029_43/`.
- Exact-source `scripts/run_software.sh` exited 0 in `ai-hw-engineer:latest`.
  The unchanged IBM AT REV1 BIOS passed 196,846 exact instruction states
  through its ROM-checksum success checkpoint. The BIOS hex helper passed 16
  cases / 464 states, IRQ8 passed eight cases / 236 handler states, and the
  system-register test passed four patterns / 164 states. Evidence is under
  `work/task_switch_fault_context_20261029_44/`.
- Verilator 5.052 (`-Wall`), g++ 15.2.0; simulation runner SHA-256
  `DDAC5C314B48FCC9DC7A8AE00A7791D9E8F166A4EC7FE37EF89AF646612145D4`.
- Full simulation log SHA-256:
  `39484F9FD9AA573E4DE216E8E9A347E9F6BE50D8E9616F9A55DC8EB140E8F7BA`.
- Synthesis log SHA-256:
  `D3FFB41EFA7186500B794426400CC9EA666779ECEC5C0B0AF959D1EA0F6DDFDF`.
- Software log SHA-256:
  `BE4CFC05E5C585190683667715F128C4055C80496777388FCDD3339BF28D4FB7`.
- RTL SHA-256:
  `6BD0950AB7C4451A368B342D5C0EC7E7C59DB17649F00985FF5D46F8B62186C5`;
  bootstrap test SHA-256:
  `A6D107B929BE1E880B60876C8B9580B09E6B221021C09F6433844E43B845D134`.

## Limits and follow-up

The BIOS result ends at the ROM-checksum success checkpoint; it is not full
POST or boot. OS/2 SDK 1.00 CPGREP still has no RTL trace. The preserved
whole-core PDR uses a stale source snapshot and does not prove this change;
current-source connected-core formal remains open. Whole-CPU acceptance also
remains open. The protected replay manifest retains the A20 native
port-side-effect timing assumption.

This escaped defect is indexed in
[`failure_notes/2026-10-29-intel80286-task-fault-context.md`](../../../failure_notes/2026-10-29-intel80286-task-fault-context.md).
