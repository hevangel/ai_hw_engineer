# AMD Am2913 priority interrupt expander

Am2913 encodes eight active-low requests into a positive three-bit vector,
prioritizing input7 over input0. Its EI/EO cascade supports additional request
groups, while five independent gates allow vector bus sharing. It complements
the Am2914 interrupt controller; the manufacturer's 64-level application
combines eight controllers with one expander.

**First-introduced year is not established; documented by 1978.** Its datasheet
already appears on PDF109–113 of the [1978 AMD family book](https://bitsavers.trailing-edge.com/components/amd/bitslice/1978_The_Am2900_Family_Data_Book.pdf).
The implementation uses the complete
datasheet in the [1979 AMD Am2900 Family Data Book](https://bitsavers.trailing-edge.com/components/amd/bitslice/1979_AMD_2900family.pdf),
PDF161–165 (printed2-153–2-157), with functional/truth tables and an orderable
part list. This is a publication bound, not an exact shipment claim.

The synthesizable digital model preserves positive output polarity, separate
gates and cascade semantics. All16,384 pin combinations, over4.19 million
actual two-chip cascade cases and69,700 nine-chip hierarchy cases pass.
Formal BMC/prove/15 covers, unsuppressed Verilator lint and Yosys synthesis/
check also pass; synthesis has29 combinational cells and no storage.

- [Specification and assumptions](spec/spec.md)
- [Implementation and verification plan](plans/implementation_plan.md)
- [Primary truth table oracle](references/README.md)
- [Final report and reproduction](report/final_report.md)
- [RTL](src/amd_am2913.sv), [formal](formal/amd_am2913.sby),
  [multi-chip fixture](tb/tb_top.sv)
