# Sony SPC700

The SPC700 is the 8-bit processor inside the Sony S-SMP, the sound CPU of
the Super Famicom / SNES. Its instruction set resembles the 6502 with
additions: a 16-bit YA register pair with MOVW/ADDW/SUBW/CMPW/INCW/DECW,
MUL and DIV, bit operations on direct-page and absolute memory bits,
decimal adjust, a TCALL table and a relocatable direct page (P flag).

**First introduced: 1990.** It shipped in the Super Famicom, released in
Japan on 21 November 1990 ([Super Famicom history](https://en.wikipedia.org/wiki/Super_Nintendo_Entertainment_System#History)).
Behaviour follows [fullsnes](https://problemkaputt.de/fullsnes.htm#snesapucpuoverview)
and the [SingleStepTests spc700](https://github.com/SingleStepTests/spc700)
records.

This original SystemVerilog core performs one bus cycle per enabled clock:
reads (including dummy reads), writes and internal cycles match the
reference records cycle for cycle for all 256 opcodes, as do SLEEP and
STOP.

Read the [specification and assumptions](spec/spec.md),
[implementation plan](plans/implementation_plan.md) and
[verification report](report/final_report.md). `scripts/run_all.sh` runs
lint, the SingleStepTests gate and synthesis. The core sits inside the
[Sony S-SMP](../sony_s_smp/) and runs real software in the
[SNES system](../../system/snes/).
