# AMD Am2904 status and shift control unit

The Am2904 supplies the status and serial wiring around a bit-slice processor:
two four-bit micro/machine status registers, conditional comparisons, carry
selection and32 single/double-length shift or rotate linkages. Its separate
status contexts let a microprogram preserve machine flags across intermediate
operations; its Y bus supports interrupt state save and restoration.

**First-introduced year: not established; advance information existed by1978.**
The [1978 AMD family book](https://bitsavers.trailing-edge.com/components/amd/bitslice/1978_The_Am2900_Family_Data_Book.pdf)
lists the part on PDF60–63 as advance information. The complete specification
and orderable packages appear in the [1979 family book](https://bitsavers.trailing-edge.com/components/amd/bitslice/1979_AMD_2900family.pdf),
PDF92–106 (printed2-84–2-98). These publications do not pin the exact commercial
launch year or month; the index uses a qualified documentary bound.

This implementation preserves native positive-edge clocks, undefined startup,
individual active-low enables, current-state outputs and the documented shift
carry override. Digital bidirectional buses expose value and output-enable
ports. It passed unsuppressed Verilator lint, BMC/PDR/36 formal covers,
2,686,976 native vectors and manufacturer interrupt/borrow/overflow sequences.
Yosys synthesis has267 cells and eight flip-flop bits, with no latches.

- [Specification and assumptions](spec/spec.md)
- [Implementation and verification plan](plans/implementation_plan.md)
- [Manufacturer oracle provenance](references/README.md)
- [Final report and reproduction](report/final_report.md)
- [RTL](src/amd_am2904.sv), [formal](formal/amd_am2904.sby),
  [native test driver](tb/status_driver.cpp)
