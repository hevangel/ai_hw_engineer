# Ricoh 5C78 (S-PPU2)

The 5C78 is the second picture-processing chip of the Super Famicom / SNES.
It generates the video timing (341 dots by 262 lines for NTSC, 312 for PAL,
with interlace), owns the 512-byte colour palette (CGRAM), the two window
units, layer priority, colour addition and subtraction against the sub
screen or a fixed colour, master brightness, and the H/V counter latches
read by software and light guns. It takes the layer pixels that the
[5C77 (S-PPU1)](../ricoh_5c77/) produced and outputs 15-bit RGB.

**First introduced: 1990**, in the Super Famicom released in Japan on
21 November 1990 ([Super Famicom history](https://en.wikipedia.org/wiki/Super_Nintendo_Entertainment_System#History)).
Behaviour follows [fullsnes](https://problemkaputt.de/fullsnes.htm) and the
[SNESdev wiki](https://snes.nesdev.org/wiki/PPU_registers).

The model runs on the master clock with a PAL parameter for the 50 Hz board.

Read the [specification and assumptions](spec/spec.md),
[implementation plan](plans/implementation_plan.md) and
[verification report](report/final_report.md). `scripts/run_all.sh` runs
lint and synthesis. The picture is verified in the [SNES system](../../system/snes/).
