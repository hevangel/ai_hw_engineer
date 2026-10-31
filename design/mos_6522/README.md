# MOS Technology 6522 VIA

The Versatile Interface Adapter combines two eight-bit ports, input latches,
programmable handshake/control pins, two timers and a serial shift register.
It became a standard building block in the VIC-20, Commodore disk drives
and other 6502 systems, illustrating how programmable peripheral control
could replace numerous separate logic parts.

The index records **by 1977**, based on MOS's
[November 1977 preliminary datasheet](https://www.6502.org/documents/datasheets/mos/mos_6522_preliminary_nov_1977.pdf).
That document establishes a dated specification, not an exact first-shipment
date. The introduction month is not asserted.

This original SystemVerilog reconstruction implements all sixteen registers,
timer operating modes, seven interrupt sources, input latches, all PCR modes
and all eight serial modes. Split buses and output enables support board
integration. Its sampled digital contract passes lint, formal proof,
simulation and synthesis. **NMOS pin-timing equivalence is still open**:
IER bit7, one-shot counter reload, half-cycle IRQ timing and serial mode
change/errata details require stronger independent evidence.

- [Specification, sources and discrepancy ledger](spec/spec.md)
- [Implementation plan](plans/implementation_plan.md)
- [Test plan](plans/testplan.md)
- [Formal plan](plans/formal_plan.md)
- [Validation report](report/final_report.md)
- [MOS series and four-system roadmap](../../plans/mos_historical_series.md)

Run `sh design/mos_6522/scripts/run_all.sh` in `ai-hw-engineer:latest`.
The complete Verilator sweep checks every 16-bit load on both timers and
1,792 byte streams. xezim uses reduced sweeps of the same tests.
Technical cross-checks also use the [production MOS datasheet](https://datasheet4u.com/pdf/1115291/6522.pdf)
and independent [MAME VIA implementation](https://github.com/mamedev/mame/blob/master/src/devices/machine/6522via.cpp).
No emulator code is incorporated into the RTL or bench.
