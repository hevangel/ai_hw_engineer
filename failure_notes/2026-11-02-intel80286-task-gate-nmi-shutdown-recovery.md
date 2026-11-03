# 2026-11-02 - 80286 NMI shutdown recovery through a task gate

## What broke and how it was observed

The connected-core k-induction proof (`formal/intel_80286.sby`, task `prove`)
failed on a new invariant: shutdown recovery may only be active while its NMI
is being delivered. The counterexample showed the core executing ordinary
instructions with `shutdown_recovery_active` still set after an NMI handler
had been entered through an IDT task gate.

`EVENT_PROTECTED_COMMIT`, the commit point for interrupt and trap gates,
cleared `shutdown_recovery_active`, `shutdown_pending`, `shutdown_nmi_failed`
and `halt_latch`. `TASK_ENTRY_COMMIT`, the commit point for a task-gate
handler, cleared none of them. After such an NMI the CPU ran the NMI task
with shutdown still pending, so the next ordinary fault (for example #GP from
`MOV DS,000C`) matched the "fault during NMI recovery" rule and put the CPU
back into shutdown. Intel 210498-005 section 9.6.2 (page 9-10) says NMI
leaves shutdown if no error occurs while processing it; entering the task-gate
handler is that success.

## Why verification missed it

- The shutdown-NMI directed test used only an interrupt gate for vector 2.
  The task-gate matrix tested NMI through a task gate, but never from
  shutdown.
- Neither shutdown-NMI test ran in the default `run_sim.sh` list; they ran
  only with `--shutdown-nmi`.
- BMC to depth 24 cannot reach shutdown, then an NMI, then a task switch,
  then a later fault. Only the unbounded induction step exposed the state.

## Fix and re-verification

- `TASK_ENTRY_COMMIT` clears the recovery, pending, NMI-failed and halt
  state when the task switch was started by the event, mirroring
  `EVENT_PROTECTED_COMMIT`.
- New invariants: recovery implies the NMI is still being delivered, and a
  task switch during recovery is the event's own task-gate switch.
- New directed test `protected_shutdown_nmi_task_gate_recovery`: #DE
  escalates to #DF shutdown, NMI through a task gate enters the NMI task, and
  a later `MOV DS,000C` is delivered as #GP(000C) at the faulting IP, in both
  READY modes. With the fix reverted in a copy the test fails with
  "re-entered shutdown instead of #GP".
- Both shutdown-NMI tests now run in the default bootstrap list.

## Prevention

- Every event commit point (interrupt/trap gate and task gate) must apply the
  same end-of-delivery bookkeeping; when a state flag is cleared at one commit
  site, check every other commit site for the same flag.
- Recovery and escalation tests must cover each IDT gate type, not only the
  interrupt gate.
- A directed test that is not in the default regression list does not count
  as regression coverage.
