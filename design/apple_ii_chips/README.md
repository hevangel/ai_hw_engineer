# Apple II support-package models

This library reconstructs the small-scale logic that made the Apple II's
shared video/CPU memory and peripheral interface possible. The board first
shipped in **1977**; individual 74-series parts predate it. Exact commercial
introduction years for every speed/family variant have not been established,
so 1977 is a board-use date, not a claim that these chips were invented then.

Historical source: [Apple II Reference Manual](https://apple2history.org/dl/Apple_II_Redbook.pdf).
Technical sources, assumptions, and limits: [specification](spec/spec.md).
See the [implementation plan](plans/implementation_plan.md) and
[verification report](report/final_report.md).

Each source file is a physical-pin model of one package type. There are 29
digital support models and three analog support models. The CPU reference
package lives in the [system reference adapter](../../system/apple_ii/board/DEPENDENCIES.md).
These are simulation components; electrical timing qualification is pending.

The chip families are 74LS00/02/04/08/11/20/32/51/74/86, 138/139/151/153,
161/166/174/175/194/195/251/257/259/283, 8T28/8T97, 4116, system mask ROM,
2513, NE555, NE558, and 741. First-introduced years for individual family
variants have not been established. The manual establishes their use on the
1977 board; that is the supported historical date recorded by this group.

Run `sh scripts/run_all.sh` for package tests and
`sh scripts/run_synth.sh` for the 16 combinational models suitable for this
check. Digital tests use Xezim; analog tests use Icarus. See
[the analog package contracts](spec/analog.md) and
[Icarus setup](../../docs/iverilog/README.md).

The directed digital test generator is [generate_package_tests.py](scripts/generate_package_tests.py).
It uses manufacturer truth tables as its oracle and board metadata for pin
identities only; run it from any directory with Python 3.
