# AMD Am2501: binary synchronous up/down counter

**First introduced: 1970.** A contemporary
[September 27, 1970 Electronic Design product notice](https://bitsavers.computerhistory.org/magazines/Electronic_Design/Electronic_Design_V18_N20_19700927.pdf),
printed page 72, describes the Am2501's synchronous preset, 25-MHz clock,
single-line up/down control and carry look-ahead. A
[December 21, 1970 Electronics notice](https://www.worldradiohistory.com/Archive-Electronics/70s/70/Electronics-1970-12-21.pdf),
printed page 109, also identifies it. These establish public availability
in 1970; the exact first shipment is not asserted.

The Am2501 is historically significant as AMD's early proprietary counter,
following its initial second-source logic products. Its six separate count
enables and combinational terminal count support wide synchronous counters
without a ripple-clock chain. It is the binary hexadecimal counterpart to
the Fairchild-compatible Am9306 BCD counter, not a CPU or a BCD converter.

This recreation follows AMD's [1974 Data Book](https://bitsavers.trailing-edge.com/components/amd/_dataBooks/1974_AMD_Data_Book.pdf),
pages 2-55 to 2-60, and implements both documented two-CE and six-CE packages.
It preserves the actual reset-free device interface and physical pin polarity.

- [Specification and timing restrictions](spec/spec.md)
- [Implementation plan](plans/implementation_plan.md)
- [Test plan](plans/testplan.md)
- [Formal plan](plans/formal_plan.md)
- [Verification report](report/final_report.md)
- [Series progress](../../plans/amd_historical_series.md)

Run from the repository root in `ai-hw-engineer:latest`:

```sh
sh design/amd_am2501/scripts/run_all.sh
```
