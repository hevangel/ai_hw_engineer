# WDC W65C816S

The W65C816 is Western Design Center's 16-bit extension of the 6502: 16-bit
accumulator and index registers selectable at run time, a relocatable direct
page, a 16-bit stack pointer, 24-bit addressing through program and data bank
registers, block-move instructions, and a 6502 emulation mode it starts in
after reset. Nintendo used it as the core of the Ricoh 5A22 in the Super
Famicom / SNES; Apple used it in the Apple IIGS.

**First introduced: 1984.** WDC announced the design in 1983 and sampled the
part in 1984 ([W65C816S history](https://en.wikipedia.org/wiki/WDC_65C816)).
Behaviour follows the [W65C816S datasheet](https://www.westerndesigncenter.com/wdc/documentation/w65c816s.pdf);
cycle-level details are checked against the
[SingleStepTests 65816](https://github.com/SingleStepTests/65816) records.

This original SystemVerilog model performs one bus cycle per enabled clock:
the address, VDA/VPA/VPB/ML qualifiers and write data of every cycle,
including the dummy and internal cycles, match the reference records, in
native and emulation mode, with decimal mode, interrupts, WAI and STP.

Read the [specification and assumptions](spec/spec.md),
[implementation plan](plans/implementation_plan.md) and
[verification report](report/final_report.md). `scripts/run_all.sh` runs
lint, the SingleStepTests gate and synthesis. Real software runs in the
[SNES system](../../system/snes/) through the [Ricoh 5A22](../ricoh_5a22/).
