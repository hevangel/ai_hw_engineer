# AMD Am2910 microprogram controller

**First-introduced year: by 1978*; exact year not established.** AMD's original
[1978 Am2900 Family Data Book](https://bitsavers.trailing-edge.com/components/amd/bitslice/1978_The_Am2900_Family_Data_Book.pdf)
contains the complete marketed Am2910 datasheet (PDF96–108). This is a sourced
upper bound, not a claim that the chip first appeared in 1978. The
[Smithsonian artifact record](https://americanhistory.si.edu/collections/object/nmah_1383931)
groups production dates 1977–1979 but does not establish first shipment.

Am2910 integrates a twelve-bit microprogram sequencer, five-level return
stack, loop counter and sixteen control instructions. It replaced cascaded
small sequencer slices with one controller capable of addressing 4096
microinstructions and implementing conditional subroutines and counted loops.

The reconstruction implements actual native digital pins, saturation at
stack boundaries, counter load priority and output/branch-source enables.
All sixteen opcodes are verified against AMD's table. Original Figure4
firmware exercises subroutines, single/multiple-word loops and memory search.

- [Specification and assumptions](spec/spec.md)
- [Implementation plan](plans/implementation_plan.md)
- [Test plan](plans/testplan.md)
- [Formal plan](plans/formal_plan.md)
- [Manufacturer oracle and firmware provenance](references/README.md)
- [Verification results](report/final_report.md)

Run from the repository toolchain:

```sh
sh design/amd_am2910/scripts/run_all.sh
```

The suite generates independent table expectations, runs lint, formal
BMC/PDR/cover, historical firmware/simulation, then synthesis/check. Electrical
propagation and undefined empty-stack addresses remain outside the contract.
