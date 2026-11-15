# AMD Am29331 16-bit microprogram sequencer

**First documented: 1985 (advanced information); final production datasheet
December 1987.** The 1985 Am29300 Family Handbook introduces the Am29331 as
advanced information and the
[1988 Am29C300/29300 Data Book](https://bitsavers.trailing-edge.com/components/amd/bitslice/1988_AMD_32-Bit_Microprogrammable_Products_Am29C300_29300_Data_Book.pdf)
carries the production datasheet (Issue 05729E/0, December 1987). No
month-level first-shipment date is asserted; the A speed grade (15% faster)
is documented as a later ordering option in the 1988 book.

The Am29331 sequences up to 64K microinstructions with 64 high-level-style
instructions (FOR/END FOR, REPEAT/UNTIL, CASE through four multiway sets,
conditional calls/exits/returns), a 33-deep stack for subroutine, loop and
interrupt nesting, a loop counter, breakpoint comparison with EQUAL,
transparent single-level interrupts with INTA and an automatic
return-address push, trap support through force-continue plus inhibited
incrementer, hold for time-multiplexed microprocesses, and master/slave
operation with an ERROR pin. It was the sequencer of the three-bus
Am29300 32-bit bit-slice family alongside the Am29332 ALU, Am29334
register file, Am29325 floating-point processor and Am29323 multiplier.

The reconstruction implements the actual native pins (bidirectional D/Y,
INTA/A-FULL/EQUAL, ERROR), the documented reset/hold/interrupt/trap cycle
model, the modulo-64 pointer over the 33-word stack including the
documented single-wrap overflow, and all 64 opcodes against AMD's tables.

- [Specification and assumptions](spec/spec.md)
- [Implementation plan](plans/implementation_plan.md)
- [Test plan](plans/testplan.md)
- [Formal plan](plans/formal_plan.md)
- [Manufacturer oracle and microcode provenance](references/README.md)
- [Verification results](report/final_report.md)

Run from the repository toolchain:

```sh
sh design/amd_am29xxx/members/am29331/scripts/run_all.sh
```

The suite regenerates the table oracle from the transcribed CSV, runs
lint, formal BMC/PDR/cover, 81,960 transition vectors plus the original
Figure 3/4-7 microcode flows, then synthesis/check. Electrical
propagation (nanosecond AC tables), the Am29331A speed grade and
undefined deep-overflow slot contents remain outside the contract.


## Roadmap ownership

Chip member: [ai_hw_engineer#170](https://github.com/hevangel/ai_hw_engineer/issues/170);
series card [#126](https://github.com/hevangel/ai_hw_engineer/issues/126).
Multiple models of the same chip share this one member issue.
