# Ricoh 5C77 (S-PPU1)

The 5C77 is the first of the two picture-processing chips of the Super
Famicom / SNES. It owns the 64 KB video RAM port, the 544-byte sprite
attribute memory (OAM), the background scroll, tile-map and character
registers, the Mode 7 matrix (whose 16×8 product the CPU can also read as a
fast multiplier) and the pixel generation for four background layers and up
to 128 sprites. Its partner, the [5C78 (S-PPU2)](../ricoh_5c78/), mixes the
layers into the final picture.

**First introduced: 1990**, in the Super Famicom released in Japan on
21 November 1990 ([Super Famicom history](https://en.wikipedia.org/wiki/Super_Nintendo_Entertainment_System#History)).
Behaviour follows [fullsnes](https://problemkaputt.de/fullsnes.htm) and the
[SNESdev wiki](https://snes.nesdev.org/wiki/PPU_registers).

This original SystemVerilog model renders each line into a line buffer while
that line is scanned, and S-PPU2 composes it during the following line. All
logic runs on the master clock.

Read the [specification and assumptions](spec/spec.md),
[implementation plan](plans/implementation_plan.md) and
[verification report](report/final_report.md). `scripts/run_all.sh` runs
lint and synthesis. The picture is verified against reference screenshots
from real-software test ROMs in the [SNES system](../../system/snes/).
