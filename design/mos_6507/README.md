# MOS Technology 6507

The 6507 made the NMOS 6502 architecture available in a cheaper 28-pin
package and became the Atari 2600 CPU. Its thirteen physical address pins
reach 8 KiB, while the internal PC and addressing remain sixteen bits.
This distinction matters for cartridge aliases, reset/BRK vectors and bus
side effects. IRQ/NMI are disabled by internal metal connections, as the
[Visual6502 die comparison](http://blog.visual6502.org/2010/09/6502-vs-6507.html)
shows.

**First introduced: 1975, historically reported.** The
[historical summary](https://en.wikipedia.org/wiki/MOS_Technology_6507)
reports that year; a manufacturer launch notice and exact month have not
been verified. The primary [November 1985 MOS family datasheet](http://www.6502.org/documents/datasheets/mos/mos_6500_mpu_nov_1985.pdf)
establishes the package features used here, rather than an exact launch date.

This original SystemVerilog package adapter reuses the
[native NMOS 6502 engine](../mos_6502_family/mos_6502/README.md), exposing only thirteen
physical address bits and tying unavailable inputs inactive. Debug signals
are explicitly separate from package pins. This is a sampled digital model;
clock oscillator/electrical behavior and Atari board compatibility retain
their own verification gates.

Read the [specification and assumptions](spec/spec.md),
[implementation plan](plans/implementation_plan.md),
[formal properties](formal/mos_6507_props.sv), and
[verification report](report/final_report.md). `scripts/run_all.sh` runs
the entire shared native CPU flow, then package lint/formal/simulation and
synthesis. Historical tests include Klaus and the original KIM monitor;
the latter runs through this adapter's actual reduced address bus. Atari
software/raster/audio validation follows with TIA and the complete system.
