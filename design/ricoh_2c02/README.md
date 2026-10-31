# Ricoh RP2C02 / RP2C07

The RP2C02 is the picture processing unit of the Nintendo Family Computer
and NES. It draws a 256×240 scrolling tile background and up to 64 sprites
(eight per line) from pattern tables on the cartridge and name tables in
console RAM, and raises the vertical-blank NMI the CPU uses to pace every
game. The RP2C07 is the PAL version with 312 lines and no odd-frame skip.

**First introduced: 1983.** It shipped with the Famicom, released in Japan
on 15 July 1983 ([Family Computer history](https://en.wikipedia.org/wiki/Nintendo_Entertainment_System#History)).
Behaviour here follows the [NESdev PPU documentation](https://www.nesdev.org/wiki/PPU),
which is compiled from the [Visual 2C02](https://www.nesdev.org/wiki/Visual_2C02)
die simulation and hardware tests.

This original SystemVerilog model is dot-accurate: the background
fetch/shift pipeline, cycle-sequenced sprite evaluation (including the
hardware's overflow-flag bug), sprite-zero hit, the shared `t`/`v` scroll
registers, the `$2007` read buffer, vblank/NMI race behaviour and the
decaying I/O latch. It outputs a 6-bit palette index plus emphasis bits per
dot; composite encoding is left to the host.

Read the [specification and assumptions](spec/spec.md),
[implementation plan](plans/implementation_plan.md),
[formal properties](formal/ricoh_2c02_props.sv) and
[verification report](report/final_report.md). `scripts/run_all.sh` runs
lint, the testbench (a full rendered frame compared pixel for pixel against
an independent reference renderer, in both regions), formal and synthesis.
blargg's PPU test ROMs run in the [NES system](../../system/nes/).
