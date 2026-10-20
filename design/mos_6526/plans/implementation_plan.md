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
Eleven unchanged Lorenz programs run with original KERNAL, dual CIAs and
exact CPU checkpoints. The original Transactor payload now qualifies both
affected and unaffected Timer B/read-loss profiles using original BASIC
WAIT code and a declared legal RDY phase sweep. An unchanged independent
CIA agrees, and the transistor CPU oracle checks 999,948 bus cycles through
the loss event. See the [software report](../report/software_report.md),
[Transactor report](../report/transactor_report.md) and
[failure analysis](../../../failure_notes/2026-10-20-mos6526-loss-detector-phase-coverage.md).

Next obtain independent serial/TOD software and physical/revision traces.
Remaining requirements include actual subcycle IRQ/read-loss windows,
CNT/cascade loss behavior, serial input synchronization and TOD reset
profiles. The phase sweep is an explicit verification fixture, not a
VIC-II DMA implementation. Preserve all original programs, ROMs and
reference code while extending these gates. All four requested systems
and the later chip queue remain incomplete.
