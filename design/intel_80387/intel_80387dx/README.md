# Intel 80387DX

**First introduced: 1987. Status: milestones M1 and M2, architectural model. The shared x87 controller built as `VARIANT = 2` implements the full 80387 instruction set. It matches the build host's x87 bit for bit on 4,140,084 differential cases over 46 forms (three seeds). Its transcendentals (FSIN, FCOS, FSINCOS, FPTAN, FPATAN, F2XM1, FYL2X, FYL2XP1) are within 8 ULP on 180,024 cases. The native 386 coprocessor bus is not built yet.**

The 80387 was Intel's first math coprocessor to implement the IEEE 754-1985 standard in full. It distinguished signalling from quiet NaNs, supported only affine infinity and normalized denormal operands, and added the FUCOM unordered compares, FPREM1 and the FSIN/FCOS/FSINCOS instructions. Later IA-32 FPUs kept its arithmetic, which is why a modern x87 can serve as an oracle for it. Its data sheet (order 231920-002) is dated January 1987, and most secondary sources date the part to 1987. No Intel announcement fixing a day was located, so only the year is claimed. Hosts in this program include the IBM PS/2 Model 70 386.

Technical authority: Intel [*80387 Programmer's Reference Manual*, 231917-001 (1987)](https://ftp.mirrorservice.org/sites/www.bitsavers.org/components/intel/80386/231917-001_80387_Programmers_Reference_Manual_1987.pdf), especially Appendix C (differences from the 80287/8087), Appendix D and Figures 2-5 to 2-8.

## Contents

- [Specification, assumption ledger and measured rules](spec/spec.md)
- [Implementation plan](plans/implementation_plan.md) and [test plan](plans/testplan.md)
- [Verification report](report/final_report.md)
- Host-oracle differential bench: [tb/tb_80387.cpp](tb/tb_80387.cpp)
- Shared RTL: [design/intel_8087/src](../../intel_8087/src/)
- SX profile: [../intel_80387sx](../intel_80387sx/README.md)

## Running

```sh
sh design/intel_80387/intel_80387dx/scripts/run_all.sh
sh design/intel_80387/intel_80387dx/scripts/run_sim.sh 20000 0x1987   # cases per form, seed
```

This needs an x86 host. The bench executes each instruction on the host FPU through a generated code stub.
