# AMD Am2902: look-ahead carry generator

**First introduced: 1975*** (public announcement evidence). [Electronics,
July 10, 1975, page 132](https://www.worldradiohistory.com/Archive-Electronics/70s/75/Electronics-1975-07-10.pdf)
names Am2902 as the carry generator to follow Am2901 shortly. The original
AMD family advertisement in [Electronic Design, December 20, 1975](https://bitsavers.org/magazines/Electronic_Design/Electronic_Design_V23_N26_19751220.pdf)
also labels Am2902 in its processor datapath. An exact first-shipment date is
not established; this date denotes documented public introduction. The
implemented digital contract is the Am2902A sheet in the 1978 family book.

The carry generator let four Am2901 slices calculate carries in parallel;
aggregate propagate/generate outputs allowed a second look-ahead level for
larger word widths. This supported fast, configurable microprogrammed
machines without changing the slices' arithmetic interface.

All physical inputs/outputs and their polarities are implemented. The chip
has three carry outputs plus aggregate P/G. Exhaustive pin tests, actual
Am2901 arithmetic, a two-level 64-bit network, formal proof/cover, clean
lint and combinational synthesis pass.

- [Specification](spec/spec.md)
- [Implementation plan](plans/implementation_plan.md)
- [Test plan](plans/testplan.md)
- [Formal plan](plans/formal_plan.md)
- [Verification report](report/final_report.md)
- [Series progress](../../plans/amd_historical_series.md)

```sh
sh design/amd_am2902/scripts/run_all.sh
```

Primary behavior source: [AMD 1978 Am2900 Family Data Book](https://bitsavers.trailing-edge.com/components/amd/bitslice/1978_The_Am2900_Family_Data_Book.pdf),
printed 2-26/2-27, PDF 34/35. Pin-symbol overbars are significant.
