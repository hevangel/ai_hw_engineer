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

### Located Timer B loss evidence

VICE's [archived Transactor readme](https://svn.code.sf.net/p/vice-emu/code/!svn/bc/45243/testprogs/CIA/transactor/readme.txt)
attributes a physical-chip flag-loss test to George Hug, Transactor,
February 1989, page 62. Its
[unchanged BASIC listing](https://svn.code.sf.net/p/vice-emu/code/!svn/bc/45243/testprogs/CIA/transactor/ciatest64.bas)
contains a 104-byte machine-code payload at 3200, with its own sum 11949.
The article reports affected and unaffected chips; do not assume that every
6526 die must exhibit the defect.

An exploratory native CPU/dual-CIA/original-KERNAL probe executes that
payload unchanged, with a bootstrap representing BASIC's SYS and waiting
loop. Over 5,000,000 clocks for each target it reaches 5,860 original NMI
handler entries per timer and prints zero flag-error stars for both A and
B. This is evidence of the current model's missing defective-chip behavior,
not a passing revision test. Temporary probe and source artifacts are under
ignored `work/transactor/`. The BASIC source SHA-256 is
`4b3bf50de8f35ac2f231641ae3e3e28e1cc0c6685fd64b5c8f1b0d86b07fd93f`.

Next promote that probe into a reproducible independent regression with
exact entry/return/NMI checks and separate affected/unaffected profiles,
then implement the source-backed Timer B/read-ICR loss. Preserve the original
payload, all eleven Lorenz programs and their expected tables. Reconcile
both observed error-star behavior and the independent VICE ICR-loss path;
do not add a flag mask solely to make one detector print an error.
