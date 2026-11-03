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

ASSUMPTION A27: the 82C284 RES synchronizer in `intel_80286_82c284_reset`
powers up holding "RES asserted", so RESET is high from power-up until RES has
been sampled high for the configured one- or two-CLK delay. The 82284 data
sheet (210453-004, printed page 4-141) and Intel 210760-002 (pages 3-41/3-42)
require RES to be held low until VCC and CLK are stable and RESET to be high
for at least 16 CLK, but give no RESET state before the first CLK edge.
`RES_SYNC_DELAY_CLKS` other than 1 or 2 is rejected at elaboration.

### Error-code EXT bit and NMI reset behavior

Protected-mode error codes set bit 0 (EXT) when the fault is detected while an
event external to the program is being delivered: INTR, NMI, single step,
#NM (7), extension segment overrun (9) and #MF (16). That includes faults in
the IDT gate, the handler CS/SS and, for a task gate, the incoming task.
Software `INT n`, `INTO`, `INT3` and other exceptions leave EXT clear. Sources:
Intel 210498-005 section 9.4 (printed page 9-5), Appendix B (pages B-8 and
B-50) and Table 9-5. `intel_80286_segment_check` and `intel_80286_code_check`
return EXT-free codes; the core ORs EXT in once, when it records the fault in
its event packet, and the handler-invocation faults below add it from the
event being delivered.

### Faults while invoking a protected-mode handler

A protection check that fails while the core invokes the handler for an event
(IDT entry, gate, handler CS, inner stack from the TSS, frame room, or the
task-gate TSS) raises an exception instead of stopping. Intel 210498-005
section 9.6.2 (page 9-10): if the event being delivered is #DE, #TS, #NP, #SS
or #GP the second fault becomes #DF with a null error code; a fault while
delivering #DF enters shutdown; for every other event (vectors 1-7, 9, 16,
INTR, NMI, `INT n`) the new fault is delivered with the error code from
Appendix B pages B-49/B-50, plus EXT when the event was external. A fault on
a software interrupt points at the `INT` instruction; other events keep their
saved return address. Task-gate TSS checks follow Table 8-1 order (not
present #NP, busy #GP, limit below 43 #TS), with any other non-available-TSS
type #GP per page B-50.

ASSUMPTION A28: when an inner-privilege event needs the SS:SP pair for the new
CPL from the current TSS and the TSS limit does not cover it, the core raises
#TS(TR selector). The 286 text gives no rule for this case; validate against
independent 286 evidence before sign-off.

NMI is edge-triggered (210760-002 page 3-12) and not recognized during reset
(page 3-67). The event controller samples the NMI level through reset, so a
level already high at reset release is not an edge. An NMI pending before
shutdown still exits shutdown (210498-005 sections 9.6.2 and 11.6). After a
fault during that NMI's processing, shutdown is exited only by RESET, so the
controller then discards any pending NMI.
