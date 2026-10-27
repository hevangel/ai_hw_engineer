# Sony S-SMP

The S-SMP is the sound CPU chip of the Super Famicom / SNES audio module.
It contains an [SPC700](../sony_spc700/) core plus the glue around it: the
64-byte boot ROM (IPL), the four I/O ports through which the main CPU
uploads programs and data, three timers (two at 8 kHz and one at 64 kHz),
and the register window ($F2/$F3) into the [S-DSP](../sony_s_dsp/). It
shares the 64 KB audio RAM with the S-DSP.

**First introduced: 1990**, in the Super Famicom released in Japan on
21 November 1990 ([Super Famicom history](https://en.wikipedia.org/wiki/Super_Nintendo_Entertainment_System#History)).
Behaviour follows [fullsnes](https://problemkaputt.de/fullsnes.htm)
and the [SNESdev wiki](https://snes.nesdev.org/wiki/S-SMP).

The core runs one SPC700 cycle per 1.024 MHz clock enable taken from the
board's master clock. The IPL ROM is copyrighted and is not stored in the
repository: `scripts/fetch_ipl.py` places a pinned copy in the ignored
`work/` folder and the simulator loads it at start-up.

Read the [specification and assumptions](spec/spec.md), [implementation
plan](plans/implementation_plan.md) and [verification
report](report/final_report.md). `scripts/run_all.sh` runs lint, the SPC700
test ROMs and music demos on the SNES board, and synthesis. Real software
(Peter Lemon's SPC700 instruction tests and music players) runs in the [SNES
system](../../system/snes/).
