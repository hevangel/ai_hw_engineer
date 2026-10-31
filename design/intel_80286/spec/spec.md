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

For protected string memory-fault register state, target the corrected
post-C2 behavior in Intel's 15 October 1984 restartability memo, including
the handler-repair rules in its LOADALL memo. INS, MOVS, STOS, OUTS and CMPS
have integrated directed cases. Intel order 210498-005 defines CMPS flags from
the source element at DS:SI minus the destination element at ES:DI. See the
source links and exact rules in the
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

The integrated protected-mode slice includes ring-0 GDT execution, selected
ring-3 selector and CALL/event/IRET transitions, bounded GDT/LDT CALL gates,
and the documented IOPL/IF rules for port instructions and flag restoration.
These features have focused evidence, not full architectural coverage. Task
switching, nested-fault escalation, broader privilege/fault combinations, and
the complete 80286 instruction set remain open. The
[integration contract](protected_mode_integration.md),
[IOPL contract](iopl_control.md) and
[completion ledger](../plans/completion_requirements.md) define the current
scope and remaining work. No item is complete solely because an unsupported
path stops visibly.

Protected `IN`/`OUT`/`INS`/`OUTS` IOPL checks and POPF/IRET IOPL/IF
restoration are specified in the [IOPL contract](iopl_control.md); directed
evidence is recorded in the
[IOPL report](../report/2026-10-27-iopl-controls.md).
Protected HLT's CPL-0 restriction is specified in the
[HLT privilege contract](hlt_privilege.md), with the directed result in the
[HLT privilege report](../report/2026-10-27-hlt-privilege.md).
Protected LGDT, LIDT, LMSW and CLTS are also checked as CPL-0-only operations;
the [system-register contract](system_register_execution.md#protected-system-instruction-privilege-checks)
records the bounded #GP(0) behavior and its evidence.

The source-backed CPU-pin contract for the 80286 local bus is in
[native_bus_interface.md](native_bus_interface.md). It defines the architectural
pin boundary and required protocol evidence; the current byte-transaction core
does not yet implement that native interface.

Unspecified details require an `ASSUMPTION:` entry in this spec and in the
affected RTL, plus independent evidence before sign-off. Record any such
assumption next to the relevant clause; do not silently infer 386 behavior.

ASSUMPTION A26: the standalone processor-extension channel samples PEREQ low
between requests before accepting another. The datasheet specifies withdrawal,
but this particular sampling rule needs validation against a real 80287 or an
independent pin trace. See [the channel contract](processor_extension_channel.md).
