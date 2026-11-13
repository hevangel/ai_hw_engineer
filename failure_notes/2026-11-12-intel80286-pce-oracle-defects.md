# 80286 defects found by the PCE-286 oracle — 2026-11-12

## What broke and how it was found

Comparing the RTL with the PCE-286 emulator on 2,936 generated
protected-mode scenarios (`design/intel_80286/plans/pce_oracle_loop.md`)
found five defects that the design's own suite passed:

1. A fault taken in an incoming task entered its handler with the outgoing
   task's SP minus the frame size.
2. CALL/JMP through a task gate to a non-TSS target raised #TS, not #GP.
3. Protected PUSHA wrote part of its frame before a limit fault.
4. LAR accepted interrupt and trap gates.
5. WAIT raised exception 7 with TS=1 and MP=0.

## Root cause and why verification missed it

- **Handler SP.** `enter_event` computes the post-frame SP from the live
  SP register. `task_entry_fault_context` loads the incoming SP in the same
  clock edge, so the computation used the old value. The frame itself was
  written at the right address, and the directed incoming-task tests checked
  the frame and the exception packet but never the handler's SP.
- **Task-gate target.** The CALL/JMP path and the IDT path implemented the
  same check twice with different fault classes; only the IDT one was tested
  against a code-segment target.
- **PUSHA.** Every protected stack fixture used SP=0080h, far from either
  end of the segment. The real-mode edge cases were covered by physical
  captures; protected mode had none.
- **LAR and WAIT.** The directed tests asserted the RTL's behavior, and both
  were derived from the same reading. Neither had an Intel citation.

All five share one cause already named in the 2026-11-09 note: expected
values, RTL and formal properties came from one reader, with no independent
executable reference for protected mode.

## Fix and re-verification

RTL changes are in `src/intel_80286.sv`; directed tests were updated or
added for the task-gate target, LAR and WAIT. Details and results are in
`design/intel_80286/report/2026-11-12-pce-oracle-loop.md`.

## Prevention

- `scripts/run_pce_oracle.sh` is the standing independent check for
  protected mode. A new protected-mode rule gets a scenario family before
  it is called verified.
- A directed test of a fault checks the handler's entry state (CS:IP, SP,
  SS), not only the pushed frame and the packet.
- When two paths implement one architectural check, a scenario must drive
  both with the same inputs.
- An emulator is not ground truth: every disagreement kept in the RTL is a
  waiver with a cited source, and rules backed only by emulators are
  recorded as assumptions (A45, A46).
