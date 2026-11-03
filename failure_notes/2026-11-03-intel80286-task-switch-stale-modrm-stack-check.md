# 2026-11-03 - 80286 task-switch DS/ES load inherited a stale ModRM stack check

## What broke

The shared protected segment-load engine takes a `stack_i` input that selects
the SS rules (writable data, DPL = RPL = CPL, #SS for not present). The core
drove it with `... || modrm[4:3]==2` regardless of state or opcode. ModRM is
not cleared between instructions. After any instruction whose ModRM reg field
was 2 or 6 (for example `MOV SS,AX`, `8E D0`), a later task switch through an
IDT task gate loaded the incoming DS and ES with stack checks. A read-only data
segment or readable code segment in the incoming TSS's DS/ES slot then failed,
although Intel 210498-005 Table 8-2 allows any data or readable code segment.

The defect was found by reading the RTL while adding protected POP ES/SS/DS
and LES/LDS (2026-11-03), not by the regression suite.

## Why verification missed it

- Every task-switch test used writable DPL-0 data descriptors for the incoming
  DS/ES, which pass the stack checks too. No test used a read-only incoming
  data segment.
- The instruction executed before each task gate was `LTR` or `IRET`, whose
  ModRM reg field is not 2, so the stale term was never true in a task switch.
- Formal properties check the engine's own decisions given `stack_i`, not
  which caller may request stack semantics.

## Fix

`stack_i` now selects SS rules only for the task's incoming SS, the CALL-gate,
interrupt and outer-return stacks, `MOV SS` started from `EXECUTE`, and
`POP SS` started from `POP_DONE`. The directed test
`protected_task_switch_stale_modrm` executes `MOV SS,AX` and then `INT 0Dh`
through a task gate whose incoming DS/ES are a read-only data segment, and
checks task entry with both caches loaded. With the old term restored, the
test fails with #GP(0070h); with the fix it passes in both READY modes.

## Prevention

- A shared engine input that changes architectural checks must be driven by
  the state that starts the transaction, never by an opcode or ModRM field
  alone. Review every such mux when adding a caller.
- Task-switch tests must include descriptor variants that are legal for one
  segment register and illegal for another (read-only data, readable code in
  DS/ES), so a mis-selected rule set fails a test.
