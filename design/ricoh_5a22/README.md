# Ricoh 5A22 (S-CPU)

The 5A22 is the CPU of the Super Famicom / SNES: a WDC 65C816 core plus the
console-specific logic around it. It generates the variable-speed memory
cycles (6, 8 or 12 master clocks), refreshes the work-RAM DRAM, runs eight
DMA channels that also do per-scanline HDMA, keeps the H/V counters that
time NMI and IRQ, provides an 8×8 multiplier and 16÷8 divider, reads the
controllers (by hand or automatically at vblank) and drives the separate
8-bit B bus that reaches the PPUs, the APU ports and the work-RAM port.

**First introduced: 1990.** It shipped in the Super Famicom, released in
Japan on 21 November 1990 ([Super Famicom history](https://en.wikipedia.org/wiki/Super_Nintendo_Entertainment_System#History)).
Behaviour follows [fullsnes](https://problemkaputt.de/fullsnes.htm) and the
[SNESdev wiki timing pages](https://snes.nesdev.org/wiki/Timing).

This original SystemVerilog model runs everything on the master clock with
clock enables. It wraps the project's [WDC 65C816](../wdc_65c816/) core.

Read the [specification and assumptions](spec/spec.md), [implementation
plan](plans/implementation_plan.md) and [verification
report](report/final_report.md). `scripts/run_all.sh` runs lint, the CPU,
bank and DMA/HDMA test ROMs on the SNES board, and synthesis. Real software
(Peter Lemon's CPU, bank and DMA/HDMA test ROMs) runs in the [SNES
system](../../system/snes/).
