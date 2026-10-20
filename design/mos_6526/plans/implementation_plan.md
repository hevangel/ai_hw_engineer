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
Eleven unchanged Lorenz programs now run with original 901227-03 KERNAL
firmware, dual actual CIAs and exact CPU checkpoints. Original vector/I/O
and interrupt code executes in the fixture; counter, ICR and NMI-sensitive
failures found by those programs are fixed and documented in
[failure notes](../../../failure_notes/2026-10-20-mos6526-current-cycle-reads.md).
The [software report](../report/software_report.md) records every result
and the fixed raster/ROM mapping/console assumptions.

Next obtain independent revision-specific ICR-loss and serial/TOD software
or captured traces. Old timer-B/read-ICR loss remains unimplemented; physical
CNT/SP synchronizer, IRQ transition, TOD reset and complete-device subcycle
evidence remain required. Keep the original Lorenz programs and KERNAL
artifact unchanged while extending these gates. All four requested systems
and the later chip queue remain incomplete.
