# AMD Am2914 vectored priority interrupt controller

Am2914 combines eight interrupt inputs, pulse capture, masks, an interrupt
threshold, vector generation and sixteen microinstructions. Cascaded groups
support larger interrupt systems; separate threshold and held-vector state
allow nested service and delayed clearing of the request that was accepted.
It was designed for Am2900 bit-slice machines and could also support Am9080A.

**First-introduced year is not established; documented by 1978.** The original
datasheet appears on PDF114–121 of the [1978 family book](https://bitsavers.trailing-edge.com/components/amd/bitslice/1978_The_Am2900_Family_Data_Book.pdf).
Implementation follows the expanded [1979 book](https://bitsavers.trailing-edge.com/components/amd/bitslice/1979_AMD_2900family.pdf),
PDF166–190, and the [January 1987 AMD datasheet](https://bitsavers.trailing-edge.com/components/amd/bitslice/_dataSheets/1987_2914.pdf)
for explicit overflow persistence. The documentary bound does not establish
an exact commercial launch date.

The digital design passes clean Verilator lint, formal BMC/PDR/21 covers,
1,441,792 native cases, 4,608 original interrupt procedures and 4,103 original
64-level cascade cases using eight actual controllers and two Am2913
expanders. Synthesis/check passes with 278 cells. Eight LOW-phase capture bits
adapt digital edge ordering; source interpretation and electrical limits are
explicitly documented and validated against the original applications.

- [Specification and assumption ledger](spec/spec.md)
- [Implementation and verification plan](plans/implementation_plan.md)
- [Manufacturer artifacts](references/README.md)
- [Final report and reproduction](report/final_report.md)
- [RTL](src/amd_am2914.sv), [formal](formal/amd_am2914.sby),
  [original cascade fixture](tb/tb_top.sv)
