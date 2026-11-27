# Intel 80287

**First introduced: by February 1983 (data sheet date). Status: milestone M1, architectural model. It shares the x87 controller with the 8087 (built as `VARIANT = 1`) and passes 246,934 checks. The native processor-extension interface to the 80286 is not built yet.**

The 80287 is the numeric processor extension for the 80286. It is the 8087's numeric execution unit behind an interface where the CPU moves every operand through dedicated I/O ports, so the coprocessor no longer snoops the CPU bus. It adds protected-mode exception pointers (FSETPM), ERROR# reporting in place of an interrupt controller, and FSTSW AX. It was the floating-point option of the IBM PC/AT 5170.

The Intel *80287 data sheet* in this repository's sources is dated February 1983 ([bitsavers](https://bitsavers.org/components/intel/_dataSheets/80287_Data_Sheet_Feb83.pdf)). A 1982 introduction alongside the 80286 is commonly cited, but no Intel announcement fixing the date was located, so only "by February 1983" is claimed. The later CHMOS 80287XL is a separate part with an 80387-class core; it is not this design.

Technical authority: Intel [*80286 and 80287 Programmer's Reference Manual*, 210498-005](https://bitsavers.trailing-edge.com/components/intel/80286/210498-005_80286_and_80287_Programmers_Reference_Manual_1987.pdf), Table 3-1, Figure 2-2 and Appendix B (differences from the 8087).

## Contents

- [Specification and assumption ledger](spec/spec.md)
- [Implementation plan](plans/implementation_plan.md) and [test plan](plans/testplan.md)
- [Verification report](report/final_report.md)
- Shared RTL: [design/intel_8087/src](../intel_8087/src/) (`intel_8087` with `VARIANT = 1`, `AW = 32`)
- 80287-only tests: [tb/tb_80287_extra.hpp](tb/tb_80287_extra.hpp). The shared suite is [../intel_8087/tb/test_8087.cpp](../intel_8087/tb/test_8087.cpp).
- Controller proofs: [formal/intel_80287_control.sby](formal/intel_80287_control.sby)

## Running

```sh
sh design/intel_80287/scripts/run_all.sh
```

This needs an x86 host whose `long double` is the real x87 80-bit format, because the host FPU is the arithmetic oracle.
