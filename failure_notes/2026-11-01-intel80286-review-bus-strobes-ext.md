# 2026-11-01 - 80286 review: 82288 MRDC# on I/O reads, missing EXT, reset-time NMI

## What broke and how it was observed

A read-only code review of `main` at `f8b528d`, posted on
[issue #80](https://github.com/hevangel/ai_hw_engineer/issues/80), found
defects that the design's own suite had passed:

1. `intel_80286_82288.sv` asserted MRDC# during every I/O read, together
   with IORC#. On a board this lets memory and an I/O device drive the data
   bus at the same time.
2. No protected-mode error code ever carried bit 0 (EXT). Intel 210498-005
   Appendix B, printed page B-8, says bit 0 is 1 when the exception was
   detected during an interrupt caused by an event external to the program.
   The 16 task-gate cases where INTR vector 13 reaches a faulting incoming
   task expected EXT=0.
3. `intel_80286_event_control.sv` reset its NMI edge detector to 0, so a NMI
   line already high when reset ended became a pending NMI. Intel 210760-002
   says NMI is edge-triggered and must be low for four CLKs before the rising
   edge (printed page 3-12), and that NMI is not recognized during reset
   (page 3-67).
4. `intel_80286_82c284_reset.sv` had no power-up value (RESET was X until
   two CLK falls) and accepted out-of-range delay parameters.
5. `intel_80286_native_bus.sv` reported a malformed beat only combinationally
   and then ignored the request, which turns a core scheduling bug into a hang.

## Root cause, and why verification missed it

- The 82288 bench checked that each read asserted its own command but never
  that the other commands stayed inactive. A positive-only check cannot see an
  extra strobe.
- The EXT rule was never written into the spec or the error-code oracle. The
  task-gate tests derived their expected codes from the selector alone, the
  same reading the RTL used, so the oracle and the RTL shared the omission.
- The event-control bench asserted the faulty behaviour explicitly ("high NMI
  after reset not sampled" required a pending NMI); its expectation came from
  the RTL rather than from the hardware manual's edge rule.
- The reset and bus-error cases were in paths no test drove (power-up before
  the first CLK fall, and a stuck scheduler).

## Fix and re-verification

- MRDC# now requires a memory cycle. The 82288 bench checks that memory and
  I/O reads assert exactly one command.
- `enter_event` records whether the event is external (INTR, NMI, single step,
  vectors 7, 9 and 16) and ORs EXT into any error code raised while that event
  is still being delivered, including incoming-task faults of a task gate. The
  segment/code check units stay EXT-free by contract. The 16 bootstrap
  expectations now carry EXT=1, citing B-8 and Table 9-5.
- The NMI edge detector tracks the line level through reset. The bench and the
  formal monitor now require that a level held through reset is not an edge,
  and that an NMI recorded before shutdown still wakes shutdown.
- The reset synchronizer powers up in the "RES asserted" state (assumption
  A27) and rejects delays other than 1 or 2 at elaboration.
- The bus protocol error latches until RESET and stops simulation with
  `$fatal` unless a bench clears `FATAL_ON_PROTOCOL_ERROR`.

The commands and results are recorded in
[the review report](../design/intel_80286/report/2026-11-01-code-review-fixes.md).

## Prevention

- Bus-controller and decoder benches must check every output of the group for
  each cycle type, not only the one expected to assert.
- Error-code oracles must come from Intel 210498-005 Appendix B and Table 9-5,
  including EXT and the IDT bit; a selector-only expected value is incomplete.
- A reset expectation must cite the device's reset or power-up text. A bench
  must not assert a behaviour that only restates the RTL.
