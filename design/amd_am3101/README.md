# AMD Am3101: 64-bit bipolar RAM

**First introduced: 1971*** (earliest located dated availability evidence). AMD's own
[April 26, 1971 Electronics advertisement, page 9](https://www.worldradiohistory.com/Archive-Electronics/70s/71/Electronics-1971-04-26.pdf)
identifies the commercial Am3101 and military Am31013 as its Schottky
64-bit RAM products. This establishes availability by that date; the exact
first shipment is not inferred from an advertisement.

The Am3101 was an early AMD memory product, offering fast scratchpad/buffer
storage as a discrete 16x4 building block. Its inverted open-collector outputs
made it straightforward to build larger memory banks with shared data lines.
It helped establish AMD's memory business alongside its logic and arithmetic
devices before integrated microprocessors became central to the company.

This recreation follows the original Am3101 in AMD's
[1974 Data Book, pages 6-11 to 6-16](https://bitsavers.trailing-edge.com/components/amd/_dataBooks/1974_AMD_Data_Book.pdf).
It preserves asynchronous write windows, read inversion, unknown power-up
state, and the original unspecified deselected-write output mode. Output
levels represent open collectors with external pull-ups; no active HIGH
drive or fabricated clock is introduced. The later Am3101A has a separate
datasheet and is not silently substituted for the original part.

- [Specification and output-valid contract](spec/spec.md)
- [Implementation plan](plans/implementation_plan.md)
- [Test plan](plans/testplan.md)
- [Formal plan](plans/formal_plan.md)
- [Verification report](report/final_report.md)
- [Series progress](../../plans/amd_historical_series.md)

Run in the project's `ai-hw-engineer:latest` Docker image:

```sh
sh design/amd_am3101/scripts/run_all.sh
```
