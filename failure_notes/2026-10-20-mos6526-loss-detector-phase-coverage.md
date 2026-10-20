# Timer B loss and detector phase coverage

## Independent evidence

The archived original Transactor detector describes Timer B flag loss on
affected physical CIAs, with unaffected Timer A and unaffected chip samples.
The previous CIA milestone explicitly listed this behavior as unimplemented.
The first native probe returned zero error stars for both timers over five
million clocks each. That was a known fidelity gap, not proof of a good die.

Sources are the unchanged
[original detector](https://svn.code.sf.net/p/vice-emu/code/!svn/bc/45243/testprogs/CIA/transactor/ciatest64.bas),
[physical-observation attribution](https://svn.code.sf.net/p/vice-emu/code/!svn/bc/45243/testprogs/CIA/transactor/readme.txt),
[VICE marker/read logic](https://github.com/VICE-Team/svn-mirror/blob/d928b850b7ef4c1b1826a6efd175d8eaa80344d8/vice/src/core/ciacore.c)
and [independent CIA implementation](https://github.com/floooh/chips/blob/9e88298ce56319953ac7a43213a1120359f7a3a6/chips/m6526.h).

## Missing behavior and test escape

No Timer B/read marker existed. The source-backed implementation remembers
an underflow one cycle after an ICR read and removes its B flag when ICR is
next read, unless a clean new B event replaces the marker. Both affected and
unaffected legacy-latency profiles are necessary: the article did not find
the defect in every physical chip.

Adding that marker initially still produced no error stars. Instrumentation
showed zero adjacent read/underflow witnesses. A three-cycle replacement
idle loop did not represent BASIC's waiting context and locked the phase;
even original BASIC WAIT code alone did not reach the needed overlap in
the simplified fixed-raster/no-DMA fixture. The unchanged independent CIA
also printed no stars in that environment. Treating zero output as an
unaffected result would have made the regression vacuous.

## Correction and verification

The permanent test executes the original 104 DATA bytes, original NMI
handler, original KERNAL setup/exit and original BASIC WAIT loop. A declared
legal RDY input sweeps CPU read phase while CIA clocks continue: one hold
every 127 observation clocks, only in the WAIT routine. No detector byte,
source expectation or read-loss window is widened to force a result.

Affected RTL and the unchanged independent CIA each print one original
Timer B error star in a million-clock run, with a witnessed adjacent read
and masked B flag. Timer A prints none. The unaffected RTL reaches the
race but prints none. Both profiles pass their direct formal and two-tool
source/read-offset/recovery checks; all eleven Lorenz programs remain green.

The recovered transistor CPU compares every address, RW and write byte
through 999,948 phase-swept bus cycles, including the loss event. A test-only
adapter supplies the same settled I/O read data and RDY/IRQ/NMI pins. Exact
bootstrap, payload return, WAIT entry, NMI entry and NMI exit instructions
are asserted. See the [measured report](../design/mos_6526/report/transactor_report.md).

## Prevention and limits

`run_all.sh` now runs `run_transactor.sh`. The test requires a real race
witness as well as the original detector result; no-output alone cannot
pass an unaffected-profile test. The unchanged independent model runs the
same inputs, and source/ROM hashes preserve every external artifact.

This verifies a sampled profile in a declared phase-coverage fixture. It
does not prove VIC-II DMA, every die's behavior, analog timing or a complete
C64. Physical subcycle/CNT/cascade read-loss evidence remains required.
