# Intel 80286 processor specification

**Status:** recovered baseline; implementation incomplete.

## Architectural target

Implement the Intel 80286 as specified by the
[80286 and 80287 Programmer's Reference Manual, order 210498-005](https://bitsavers.trailing-edge.com/components/intel/80286/210498-005_80286_and_80287_Programmers_Reference_Manual_1987.pdf).
The target is the documented 16-bit processor architecture with a 24-bit
physical address space, real-address mode and protected virtual-address mode.
Protected mode includes the descriptor, privilege, event, and task-state
mechanisms defined by that 286 manual. Do not substitute later 80386-or-newer
semantics where the 286 has different behavior.

For protected INS destination-fault register state, target the corrected
post-C2 behavior in Intel's 15 October 1984 restartability memo, including
handler repair of DI and CX. See the source links and exact rules in the
[integration contract](protected_mode_integration.md#native-ins-fault-state-and-handler-repair).
Earlier stepping errata are not implemented as a selectable profile. Native
I/O side-effect timing remains assumption A20 and requires independent closure.

Intel documents the 80286 as introduced in 1982 and identifies the IBM PC/AT
as a major adoption of the processor in its
[history overview](https://timeline.intel.com/1982/the-286-changes-personal-computing).
Historical context does not narrow the architectural completion target.

## Required behavior

- Reset enters the documented real-address state and preserves compatibility
  with documented 8086/8088 software behavior.
- Instruction execution, system instructions, flags, addressing, memory, and
  I/O match the 80286 manual, including defined exceptions and undefined or
  mode-restricted encodings.
- Protected-mode state changes, descriptor access, segment-cache commits,
  privilege checks, exceptions, interrupts, IRET, and task-state operations
  follow 286-specific rules and are committed at documented architectural
  boundaries.
- External bus requests remain stable while held by wait states. Reset,
  faults, and restart preserve precise CPU-visible state and account for
  accepted external side effects.
- Tests assert the exact resulting PC and next instruction, as well as the
  observable register, flag, memory, and I/O effects.

## Current supported slice and open scope

The current protected-mode integration contract defines a bounded ring-0 GDT
path and same-level vector-13 gate/IRET retry. It does not cover full protected
mode, privilege transitions, task switching, nested-fault escalation, or the
complete 80286 instruction set. The [integration contract](protected_mode_integration.md)
and [completion ledger](../plans/completion_requirements.md) define the active
milestone and the remaining work. No item is complete solely because an
unsupported path stops visibly.

Unspecified details require an `ASSUMPTION:` entry in this spec and in the
affected RTL, plus independent evidence before sign-off. Record any such
assumption next to the relevant clause; do not silently infer 386 behavior.
