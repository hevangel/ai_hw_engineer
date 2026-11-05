# 2026-11-04 - 80286 NT flag was never loaded or cleared outside task switches

## What broke

An audit of the stop sites in task return, made while reading Intel
210498-005, found three related defects in protected mode:

1. **POPF kept NT.** POPF preserved bit 14 at every privilege level.
   App. B POPF says the entire flag word is popped. Only IOPL (CPL 0) and
   IF (CPL<=IOPL) are privileged.
2. **Interrupt and trap gates kept NT.** The handler inherited NT from the
   interrupted code. Intel says NT is always cleared, after the old flags are
   pushed, when an interrupt uses an interrupt or trap gate. The text is
   around 286intel.txt lines 7988 and 8058.
3. **IRET kept the handler's NT.** A protected IRET without a task switch
   must load the whole flag word from its frame.

Together these break any interrupt taken inside a nested task. The handler
runs with NT=1, so its IRET performs a task return instead of resuming the
interrupted code.

A fourth item was a development stop. An IRET with NT=1 when the current
TSS cache is invalid stopped the core; this includes the case where no LTR
was ever executed. A current TSS descriptor that was no longer a present
busy TSS also stopped it. App. B SWITCH_TASKS requires #TS with the new TSS
(back-link) selector as the error code.

## Why verification missed it

- The formal property for IRET_COMMIT copied the RTL's own NT rule. The
  event-commit property did the same for the gate masks. Both encoded the
  misreading instead of checking it against the text.
- No directed test executed POPF with NT, or an interrupt inside a nested
  task.
- The physical captures are real mode only, and in real mode NT stays clear.

## Fix

- POPF and IRET load NT in protected mode.
- Interrupt and trap gate delivery masks NT (0xbcff / 0xbeff).
- Both task-return stops now raise #TS(back link).
- `protected_nt_flag_contracts` (`--nt`) checks POPF, the gate push and
  clear, the IRET restore, and the invalid-TSS #TS in both READY modes.
- The props now state the Intel rules.

## Prevention

- When a property describes a flag update, derive each bit from the manual
  entry, not from the RTL expression.
- For each FLAGS bit, keep at least one directed test per instruction that
  App. B says loads or clears it.


## Follow-up: Table 8-2 incoming NT

Intel 210498-005 Table 8-2 specifies the incoming task's NT for each
transfer:

| Transfer | Incoming NT |
|---|---|
| JMP | cleared |
| CALL/INT | set |
| IRET | unchanged |

The core had two problems:
- **Task-entry commit:** a JMP kept the TSS image's NT.
- **Task-entry fault context:** a JMP kept NT, and an IRET task return
  cleared the returning task's NT. A nested task that returned to its
  caller lost its own link, so the caller's IRET became an ordinary return.

Both sites now apply the table. The direct-TSS test sets NT in the target
image and checks:
- after a JMP, the resumed task has NT=0;
- after a CALL and the callee's IRET, NT=0 in the abandoned task's TSS image.
