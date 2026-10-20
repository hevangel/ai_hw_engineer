# 6526 CIA implementation plan

1. Source manufacturer behavior, physical measurement reports and independent
   timer/CIA implementations. Record revision and reset disagreements.
2. Build an isolated native-cycle timer and unchanged external C oracle.
   Compare every counter/latch/start/underflow result, including write races;
   require lint, formal and synthesis before treating the foundation as ready.
3. Integrate two timers, sources/cascade, PB override and handshake ports.
   Preserve resolved-pin reads and explicit PHI2 sampling.
4. Implement revision-qualified interrupt pipeline/acknowledgment, TOD
   clock/latching/alarm and buffered serial input/output with own tests.
5. Run historical independent CIA software, captured/reference timing,
   complete formal/simulation/synthesis gates, publish measured reports and
   update the chip index. Retain unresolved physical/system gates explicitly.

## Current evidence and next gate

The assembled sampled device passes its measured digital integration flow.
Two unchanged Lorenz programs (PB6 and PB7) now run on the native CPU/CIA
fixture and exposed a timer read-phase defect, documented in
[failure notes](../../../failure_notes/2026-10-19-mos6526-timer-port-read-phase.md).

Next extend the independent software environment for the larger Lorenz
timer/IRQ tests. `cia1ta` calls KERNAL FDA3 after capturing the tested CIA
registers; an unsupported ROM fetch now fails immediately. Source that
environment from the recovered ROM/disassembly, including its I/O setup
and any IRQ/vector dependencies, rather than silently replacing it with an
unverified reset helper. The
[recovered KERNAL IOINIT listing](https://www.pagetable.com/c64ref/c64disasm/#FDA3)
shows that this routine configures both CIAs, the processor port and the
periodic timer. Do not count this program as run until those dependencies
are supported and its original success/failure checks execute unchanged.
