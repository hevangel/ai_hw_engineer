# AMD Am2909: microprogram sequencer slice

**First introduced: 1975*** (public marketing evidence). [Electronics,
July 10, 1975, page 132](https://www.worldradiohistory.com/Archive-Electronics/70s/75/Electronics-1975-07-10.pdf)
names Am2909 in development with introduction scheduled by November.
AMD's [December 20, 1975 Electronic Design advertisement](https://bitsavers.org/magazines/Electronic_Design/Electronic_Design_V23_N26_19751220.pdf)
labels its counter/stack/sequencer block Am2909. The exact first shipment
month is unestablished. This reconstruction uses the original Am2909 sheet
in the 1978 family book, rather than assigning later Am2910 semantics.

The device supplies flexible microprogram address selection and four-level
return linkage. Cascaded four-bit slices let designers choose the control
store size, while separate branch/register buses and per-bit OR inputs
supported mapping, temporary addresses and multiway conditional branches.

The complete control interface, circular stack, pre-edge-PC pushes,
increment/repeat, ZERO priority and tri-state enable are implemented. A
three-chip 12-bit fixture passes independently sourced transition-table
checks and the manufacturer's exact subroutine/nested-subroutine sequences.

- [Specification](spec/spec.md)
- [Implementation plan](plans/implementation_plan.md)
- [Test plan](plans/testplan.md)
- [Formal plan](plans/formal_plan.md)
- [Oracle/software provenance](references/README.md)
- [Verification report](report/final_report.md)
- [Series progress](../../plans/amd_historical_series.md)

```sh
sh design/amd_am2909/scripts/run_all.sh
```

Primary behavior source: [AMD 1978 family book](https://bitsavers.trailing-edge.com/components/amd/bitslice/1978_The_Am2900_Family_Data_Book.pdf),
PDF 82–95. No reset, power-up initialization or electrical memory-write
waveform is invented.
