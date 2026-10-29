# MOS Technology 6510

The 6510 combines the NMOS 6502 CPU with a processor port and bus-driver
control. In the Commodore 64 its port selects ROM/RAM/I/O visibility and
controls the cassette interface; AEC lets the video chip take the external
bus. Correct internal-port versus external-RAM behavior is essential for
software that uses 0000/0001 or shares memory with the VIC-II.

**First introduced: by 1982; exact launch unconfirmed.** The manufacturer's
[November 1982 preliminary datasheet](http://www.6502.org/documents/datasheets/mos/mos_6510_mpu.pdf)
provides that documented bound. It describes the register addresses,
programmable port and AEC high-impedance behavior. The ordinary 6510 has
six bonded port pins despite the family document's generic eight-pin text.

This original sampled digital implementation reuses the
[native NMOS CPU](../mos_6502_family/mos_6502/README.md), adds a separate processor-port
block and exposes explicit bus-driver enables for board resolution.
Unbonded-bit charge uses a deterministic configurable approximation.
Reset follows the pinned VICE C64 profile; MAME differs, and that
disagreement remains a physical-validation requirement.

Read the [specification, sources and assumptions](spec/spec.md),
[implementation plan](plans/implementation_plan.md), and
[measured report](report/final_report.md). The independent
[VICE processor-port implementation](https://github.com/VICE-Team/svn-mirror/blob/d928b850b7ef4c1b1826a6efd175d8eaa80344d8/vice/src/c64/c64pla.c)
and [memory/bus model](https://github.com/VICE-Team/svn-mirror/blob/d928b850b7ef4c1b1826a6efd175d8eaa80344d8/vice/src/c64/c64mem.c)
are external semantic references, not code included in RTL.

`scripts/run_all.sh` runs the shared native CPU gates and the port/CPU
formal, simulation and synthesis flows. Its own historical-software gate
executes the original KIM monitor on the actual 6510 wrapper. Full C64
KERNAL/BASIC, peripheral and raster/audio verification remain system gates.
