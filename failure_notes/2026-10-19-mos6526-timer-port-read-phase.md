# MOS 6526 timer-selected port read phase

## External observation

The unchanged public-domain Lorenz 2.15 `cia1pb6.prg`, as maintained in VICE
SVN revision 45243, reported `TIMING ERROR INDEX 0C` and wrote FF to its
failure mailbox at D7FF after 19,708 native CPU clocks. Its last table checks
PB6 eight clocks after starting Timer A, including small and zero reloads.
The original PB7 test contains the equivalent Timer B table.

Sources:
[original PB6 source](https://svn.code.sf.net/p/vice-emu/code/!svn/bc/45243/testprogs/general/Lorenz-2.15/src/cia1pb6.s),
[original PB7 source](https://svn.code.sf.net/p/vice-emu/code/!svn/bc/45243/testprogs/general/Lorenz-2.15/src/cia1pb7.s),
[independent VICE PRB read path](https://github.com/VICE-Team/svn-mirror/blob/d928b850b7ef4c1b1826a6efd175d8eaa80344d8/vice/src/core/ciacore.c).

## Cause and verification escape

The integrated CIA sent every PRB bit through the rising-edge resolved-pin
sample. That is the GPIO contract, but timer-selected bits require the
current-cycle timer result at the internal PRB mux. VICE independently
updates the selected timer before replacing its PRB bit. The old fixture's
loopback read therefore observed a previous-cycle timer pulse.

The isolated timer agreed with its unchanged external oracle on more than
3.6 million cycles; the defect was outside that block. Directed integrated
tests checked GPIO resolved-pin reads and timer pulses separately. Formal
asserted that every PRB bit equaled the GPIO sample, encoding the same
incorrect extension of the GPIO rule. Neither checked the original software
timing table. The published milestone retained software/physical gates, but
its sampled integration still contained this escaped defect.

## Correction and re-verification

Timer-selected PB6/PB7 reads now bypass the GPIO sample and use the current
timer underflow or toggle result. Other PRB bits still read sampled pins.
No timer-oracle source or original program/table was edited. The spec and
RTL explicitly record the internal mux phase as an assumption supported by
the independent code and unchanged software; physical pin-versus-read
captures remain required because the preliminary sheet does not describe
this phase exception.

Both unchanged programs pass in the native CPU/CIA fixture: PB6 takes
20,566 clocks and PB7 takes 20,409; each performs 466 CIA reads and 1,377
CIA writes. Startup fetch PCs/opcodes, the success store's post-PC and its
exact next instruction are checked. The fixture executes actual RTS
instructions for its documented KERNAL stubs; it does not teleport CPU state.
The original timing tables also have a direct two-simulator regression.
Whole-device lint, formal, simulation and synthesis are rerun after this fix;
the [CIA integration report](../design/mos_6526/report/integration_report.md)
records final results.

## Prevention

`design/mos_6526/scripts/run_all.sh` now runs `run_software.sh`, with hash-pinned
unchanged binaries and provenance files. The directed port suite exercises
both timer-selected read bits against the original tables, including pins
held different from the timer read result. The formal GPIO property applies
only to bits whose timer override is disabled. Broader historical timer/IRQ
and revision/capture qualification remains open; passing these two programs
does not establish complete C64 compatibility.
