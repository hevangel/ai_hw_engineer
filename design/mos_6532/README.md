# MOS Technology 6532 RIOT

The RAM–I/O–Timer combines 128 bytes of SRAM, two eight-bit ports, an interval
timer and PA7 edge interrupts. It is especially important as the Atari 2600's
working RAM and controller/switch interface. It illustrates how MOS reduced
the number of chips needed beside a 6502-family processor.

**First-introduced year: not yet established from a dated primary source.**
The index conservatively records **by 1982**, when MOS's
[1982 Data Catalog](https://bitsavers.trailing-edge.com/components/mosTechnology/_dataBooks/1982_MOS_Technology_Data_Catalog.pdf)
documents the part; this is an availability bound, not its launch year.
[RetroFlops](https://retroflops.github.io/sources/mos-6532-riot-datasheet/)
assigns 1976 to the archived datasheet, but that date has not been confirmed
on the scan. No exact month or launch year is inferred from that metadata.

This design implements the manufacturer's register map, native phase-two
falling-edge bus completion, all four timer divisors and separate interrupt
flags. It exposes split buses and output enables for synthesizable board
integration. PA input signals must reflect resolved pin levels, including
output drive; PB output bits read the output latch. Subcycle asynchronous
edge capture and electrical behavior are outside its digital contract.

- [Specification, sources and assumption ledger](spec/spec.md)
- [Implementation plan](plans/implementation_plan.md)
- [Test plan](plans/testplan.md)
- [Formal plan](plans/formal_plan.md)
- [Validation report and remaining limits](report/final_report.md)
- [MOS chip and system series](../../plans/mos_historical_series.md)

Run `sh design/mos_6532/scripts/run_all.sh` inside the repository's
`ai-hw-engineer:latest` container. Verilator runs the complete timer sweep;
xezim runs the same bench with representative timer loads (`+quick`).

Technical sources: [MOS/Commodore 6532 datasheet](https://www.6502.org/documents/datasheets/mos/mos_6532_riot.pdf)
and the independently developed [MAME RIOT implementation](https://github.com/mamedev/mame/blob/master/src/devices/machine/mos6530.cpp).
The original SystemVerilog and tests do not incorporate MAME code.
