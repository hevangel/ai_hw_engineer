# AMD Am2918 quad D register

Am2918 is a Schottky register with four positive-edge D flip-flops. Each stored
bit has a continuously driven Q output and a separately gated three-state Y
output. This arrangement supplies uninterrupted local status/data while
allowing the same register to share a bus; AMD illustrated status storage,
bus interfacing and serial-to-parallel conversion.

**First-introduced year is not established; documented by 1978.** The complete
datasheet appears on PDF162–165 of the [1978 family book](https://bitsavers.trailing-edge.com/components/amd/bitslice/1978_The_Am2900_Family_Data_Book.pdf).
The [1979 edition](https://bitsavers.trailing-edge.com/components/amd/bitslice/1979_AMD_2900family.pdf)
provides the specification on PDF209–212 (printed2-201–2-204), including the
truth table and original application circuits. These are documentary bounds,
not an exact launch or shipping date. Am29LS18 is a separate part.

The native digital model has no invented reset or clock enable. It passes
unsuppressed lint, BMC/PDR/four covers, 512 exhaustive native transitions,
262,144 original bidirectional-interface cases and65,536 original serial
word/stream cases. Synthesis/check yields four flip-flops and one inverter.

- [Specification and assumptions](spec/spec.md)
- [Implementation and verification plan](plans/implementation_plan.md)
- [Results and reproduction](report/final_report.md)
- [RTL](src/amd_am2918.sv), [formal](formal/amd_am2918.sby),
  [original circuit fixtures](tb/tb_top.sv)
