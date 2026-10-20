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

Implementation is in progress, with isolated timer, TOD and serial blocks.
The timer uses an unchanged external oracle. This directory does not yet provide a complete
CIA. Read the [specification/source and fidelity ledger](spec/spec.md) and
[implementation plan](plans/implementation_plan.md) and
[measured timer report](report/timer_report.md). The timer now passes an
unchanged external oracle, four-state replay, formal and synthesis;
`scripts/run_timer_all.sh` runs those foundation gates. Read the
[TOD/serial measured report](report/tod_serial_report.md) for their exhaustive,
formal and four-state checks; `run_tod_all.sh` and `run_serial_all.sh` run
those flows. Ports, interrupt pipelines, full-device timing/software and
system integration remain required.
