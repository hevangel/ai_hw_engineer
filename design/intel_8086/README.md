# Intel 8086

**First introduced: 1978. Status: first functional CPU milestone; incomplete instruction set.**

Intel dates the 8086's introduction to June 8, 1978 in its [manufacturer history](https://timeline.intel.com/1978/the-beginning-of-a-legend%3A-the-8086). Its 16-bit architecture and segmented 20-bit address space established the x86 family. The later 8088 brought that architecture to the IBM PC; this folder targets the 8086 programming model.

This is a chip-only design. It contains synthesizable SystemVerilog, formal properties and chip testbenches. There is no computer, peripheral chipset, operating system or front panel. The initial implementation uses a functional transaction interface and does not reproduce native minimum/maximum-mode pin timing or the six-byte prefetch queue. Unsupported instructions stop with `fault_o`; this is a verification boundary, not a claim that original silicon has an invalid-opcode exception.

- [Specification, supported encodings and assumptions](spec/spec.md)
- [Implementation plan and remaining milestones](plans/implementation_plan.md)
- [Verification plan](plans/verification_plan.md)
- [Results and limitations](report/final_report.md)
- [Independent hardware-vector provenance](references/README.md)
- [Historical Intel startup program](tb/software/README.md)

Technical authority: Intel's *8086 Family User's Manual*, October 1979, [Intel-authored scan](https://www.inf.pucrs.br/~calazans/undergrad/orgcomp_EC/mat_microproc/intel-8086_family_Users_Manual.pdf), also [archived by Bitsavers](https://bitsavers.org/components/intel/8086/9800722-03_The_8086_Family_Users_Manual_Oct79.pdf). Independent instruction expectations come from [SingleStepTests/8086](https://github.com/SingleStepTests/8086), generated on a physical Intel P80C86A-2. CMOS-vector agreement alone does not establish all undocumented behavior of the original NMOS part.

Run in the repository tool image, from the repository root:

```sh
sh design/intel_8086/scripts/run_all.sh
```

The first run downloads the pinned independent vectors to ignored `work/`; later runs use the integrity-checked cache. See the verification plan for dependencies and exact coverage.
