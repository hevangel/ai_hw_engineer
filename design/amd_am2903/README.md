# AMD Am2903 Superslice

**First-introduced year: by 1978*; exact year unestablished.** AMD's
[1978 Am2900 Family Data Book](https://bitsavers.trailing-edge.com/components/amd/bitslice/1978_The_Am2900_Family_Data_Book.pdf)
contains the complete marketed Am2903 datasheet on PDF38–59. The year is a
sourced availability upper bound, not an exact launch claim. Its arithmetic
slice extended Am2901 with externally expandable RAM, bidirectional buses,
parity/sign extension, normalization and multiply/divide instructions.

The reconstruction preserves native CP read/write phases, independent WE,
Q/sign-compare edge sampling, real slice-position control pins, three-state
buffers and open-collector Z. All 505 documented nine-bit instructions are
checked against original manufacturer table transcriptions. Four actual
slices and an actual Am2910 execute AMD's original Figures17/19 multiply
programs with exact microaddresses and mathematical product checks.

[AMD's 1979 Designer's Guide](https://bitsavers.trailing-edge.com/components/amd/_dataBooks/1979_AMD_The_Designers_Guide.pdf)
PDF69 corrects a 1978 divide-correction carry-generation cell; the corrected
manufacturer value is used in RTL and the external golden table.

- [Specification and assumptions](spec/spec.md)
- [Implementation plan](plans/implementation_plan.md)
- [Test plan](plans/testplan.md)
- [Formal plan](plans/formal_plan.md)
- [Original tables and software provenance](references/README.md)
- [Verification report](report/final_report.md)

```sh
sh design/amd_am2903/scripts/run_all.sh
```

Seven reserved special codes have no defined data contract. The native model
uses five explicit input-capture bits to preserve pre-edge sampling in
zero-delay tools; they are a timing adapter, not claimed physical storage.
Localized latch/cascade lint annotations are documented in the report.
