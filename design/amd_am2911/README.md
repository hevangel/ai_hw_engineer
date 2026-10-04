# AMD Am2911: shared-bus microprogram sequencer

**First introduced: 1976*** (earliest located contemporary availability
evidence). [Microcomputer Digest, May 1976, page 10](https://deramp.com/downloads/mfe_archive/070-Books%20Newsletters%20and%20Magazines/Microcomputer%20Digest/Microcomputer_Digest_v02n11_May76.pdf)
reports AMD's second sequencer newly available and explicitly contrasts it
with the previously introduced Am2909. The exact first shipment month is
unestablished; this sourced date is not inferred from the whole family's 1975
launch. Behavior comes from AMD's original Am2909/Am2911 shared datasheet.

The twenty-pin Am2911 retains flexible source selection and four-level
return linkage with fewer interface pins: the direct bus also feeds the
held address register, and Am2909's OR inputs are omitted. Cascading slices
still permits arbitrary control-store address width.

This design exposes those actual variant pins and instantiates the proven
common state engine with the manufacturer's prescribed connections. Its
own three-slice regression, shared-bus checks, original microcode traces,
formal covers, clean lint and synthesis pass.

- [Specification](spec/spec.md)
- [Implementation plan](plans/implementation_plan.md)
- [Test plan](plans/testplan.md)
- [Formal plan](plans/formal_plan.md)
- [Independent oracle/software provenance](references/README.md)
- [Verification report](report/final_report.md)
- [Series progress](../../plans/amd_historical_series.md)

```sh
sh design/amd_am2911/scripts/run_all.sh
```

Primary behavior source: [AMD 1978 Am2900 Family Data Book](https://bitsavers.trailing-edge.com/components/amd/bitslice/1978_The_Am2900_Family_Data_Book.pdf),
PDF 82–95, especially the variant note in Figure 2 and comparison on PDF
94/95. Shared-engine source is [amd_am2909](../amd_am2909/src/amd_am2909.sv).
