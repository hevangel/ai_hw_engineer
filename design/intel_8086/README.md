# Intel 8086

**First introduced: 1978. Status: complete documented instruction set and native digital chip interface.**

Intel dates the 8086's introduction to June 8, 1978 in its [manufacturer history](https://timeline.intel.com/1978/the-beginning-of-a-legend%3A-the-8086). Its 16-bit architecture and segmented 20-bit address space established x86. The later 8088 brought that architecture to the IBM PC; this design targets the original 8086.

`intel_8086_chip` combines the execution unit with a six-byte prefetch queue, minimum/maximum-mode bus phases, READY waits, interrupts, LOCK and HOLD/RQ/GT arbitration. `intel_8086` is also available as a functional transaction interface. This folder contains the chip and its verification environment. Native pins use explicit output enables; electrical delays and original EU clock-for-clock timing are outside the RTL contract.

- [Specification, interfaces and assumptions](spec/spec.md)
- [Implementation plan](plans/implementation_plan.md)
- [Verification plan](plans/verification_plan.md)
- [Results, corrections and limits](report/final_report.md)
- [Complete encoding/evidence ledger](report/encoding_coverage.md)
- [Physical-chip reference provenance](references/README.md)
- [Original historical software regressions](tb/software/README.md)

Technical authority: Intel's [8086 Family User's Manual, October 1979](https://www.inf.pucrs.br/~calazans/undergrad/orgcomp_EC/mat_microproc/intel-8086_family_Users_Manual.pdf), also [archived by Bitsavers](https://bitsavers.org/components/intel/8086/9800722-03_The_8086_Family_Users_Manual_Oct79.pdf), and the [Intel 8086 datasheet](https://www.inf.pucrs.br/calazans/undergrad/orgcomp_EC/mat_microproc/intel-8086_datasheet.pdf). Independent instruction expectations come from [SingleStepTests/8086](https://github.com/SingleStepTests/8086), captured on a physical Intel P80C86A-2. Original Microsoft DEBUG.COM supplies an unchanged application regression with trap-based single stepping.

Run from the repository root inside the tool image:

```sh
sh design/intel_8086/scripts/run_all.sh
```

The first run downloads pinned, integrity-checked references to ignored `work/`. The report distinguishes documented behavior, supported extensions, finite verification evidence and timing/electrical limits; it does not claim exhaustive silicon equivalence.

## XT coprocessor integration

The execution core also exports the captured ESC ModR/M byte, ESC instruction
physical address and WAIT state for the [XT/8087 platform](../../system/ibm_pc_xt_5160/README.md).
These observation outputs do not change native CPU instruction or bus behavior.
