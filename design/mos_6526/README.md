# MOS Technology 6526 CIA

The Complex Interface Adapter combines ports, two linked timers, serial
I/O, interrupts and a time-of-day/alarm clock. Two CIAs provide the Commodore
64's keyboard/joystick, serial-bus and timing interfaces. Its pipeline and
revision-specific interrupt behavior matter to software compatibility.

**First introduced: by 1981; exact launch unconfirmed.** MOS's
[November 1981 preliminary datasheet](http://www.6502.org/documents/datasheets/mos/mos_6526_cia_preliminary_nov_1981.pdf)
establishes that documented bound. The
[pinned VICE timer reference](https://github.com/VICE-Team/svn-mirror/blob/d928b850b7ef4c1b1826a6efd175d8eaa80344d8/vice/src/core/ciatimer.h)
and [physical measurement discussion](https://www.forum64.de/index.php?thread/109935-mos6526-cia-detailed-test-vectors-and-models/)
provide independent pipeline evidence beyond the preliminary datasheet.

The assembled sampled CIA connects ports, two timers, TOD, serial and
interrupt control. The timer uses an unchanged external oracle. Physical
revision and external-software qualification are still in progress.
Read the [specification/source and fidelity ledger](spec/spec.md) and
[implementation plan](plans/implementation_plan.md) and
[measured timer report](report/timer_report.md). The timer now passes an
unchanged external oracle, four-state replay, formal and synthesis;
`scripts/run_timer_all.sh` runs those foundation gates. Read the
[TOD/serial measured report](report/tod_serial_report.md) for their exhaustive,
formal and four-state checks; `run_tod_all.sh` and `run_serial_all.sh` run
those flows. The [integration report](report/integration_report.md) records
the complete register-interface regression and interrupt checks.
The [status and known issues](report/final_report.md) collect remaining gates.
`scripts/run_all.sh` runs the sampled digital gates. Full-device external
timing/software, old-CIA interrupt races and system integration remain required.
`scripts/run_software.sh` also runs eleven unchanged, hash-pinned public-domain
Lorenz CIA programs with original 901227-03 KERNAL firmware, plus the two
isolated PB6/PB7 baselines. The [software report](report/software_report.md)
records 41,195,603 KERNAL-backed clocks and exact CPU checkpoints. They found
and now regress the [timer port read defect](../../failure_notes/2026-10-19-mos6526-timer-port-read-phase.md)
and [counter/ICR/IRQ cycle-view defects](../../failure_notes/2026-10-20-mos6526-current-cycle-reads.md).
`scripts/run_transactor.sh` runs the original loss detector with original
BASIC/KERNAL routines, two selectable affected/unaffected profiles, an
unchanged independent CIA and recovered transistor CPU oracle. The
[Transactor report](report/transactor_report.md) records its witnessed
read/underflow race and explicit RDY phase-coverage input.
The [phase-coverage failure analysis](../../failure_notes/2026-10-20-mos6526-loss-detector-phase-coverage.md)
explains why the initial zero-output probe was inconclusive.

`scripts/run_serial_software.sh` executes the original hardware-table
serial-delay program, matching all 21 timing samples in 64,250 clocks.
The [serial software report](report/serial_software_report.md) describes
the exact CPU checkpoints, declared raster fixture and remaining revision
limits. It found and now regresses the
[serial completion defect](../../failure_notes/2026-10-20-mos6526-serial-completion-timing.md).
`scripts/run_tod_software.sh` also passes original latch and stop/restart
programs: 66 checked time samples over 19,629,050 clocks. The
[TOD software report](report/tod_software_report.md) records their unchanged
tables, exact CPU checkpoints and declared frame-synchronous clock stimulus.
