# Intel 8087 numeric data processor

First introduced: **1980**. Intel's July 1980 *8086 Family User's Manual,
Numerics Supplement* and its authors' 1980 National Computer Conference paper
document the device that established x87. No exact announcement month is
asserted. Its eight 80-bit registers, directed rounding, extended intermediate
precision and mathematical functions brought practical floating-point
computation to the 8086 and 8088.

This is a synthesizable **architectural ESC coprocessor core** with original
instruction bytes, calculated physical addresses and a stalled byte-wide
memory interface. Native prefetch snooping, multiplexed pins and RQ/GT bus
arbitration are outside the interface. Transcendentals use numerical
approximations rather than recovered Intel microcode.

- [Specification, interface and assumptions](spec/spec.md)
- [Implementation plan](plans/implementation_plan.md)
- [Verification and formal boundaries](plans/testplan.md)
- [Results and compatibility limits](report/final_report.md)
- [Manufacturer sources and independent oracle](references/README.md)
- [Original Intel software regression](tb/software.md)

Primary sources: Intel's [July 1980 numerics supplement](https://mark-ogden.uk/files/intel/publications/121586-001%20The%208086%20Family%20Users%20Manual%20Numerics%20Supplement-Jul80.pdf),
its authors' [1980 conference paper](https://kib.kiev.ua/x86docs/Intel/486/8087.pdf),
and [8087 datasheet 205835-007](https://datasheets.chipdb.org/Intel/x86/808x/datashts/8087/205835-007.pdf).

Run in the existing hardware toolchain container:

```sh
sh design/intel_8087/scripts/run_all.sh
```

The regression requires an x86 host with actual 80-bit x87 `long double`;
compilation deliberately fails if it is a 64-bit alias. Regression execution
requires no external downloads. See the report before integration or sign-off.
