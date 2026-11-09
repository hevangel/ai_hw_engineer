# Zilog Z80: eight-bit microprocessor

**First introduced: July 1976.** The launch date is stated by the
[Z80 historical summary](https://en.wikipedia.org/wiki/Zilog_Z80) (infobox
"Launched July 1976", narrative "the Z80 was officially launched in July
1976"), which also records the first working samples returning from Mostek on
9 March 1976. Only the month is claimed: no primary Zilog announcement of a
specific day was located, so day-level precision is not asserted.

The Z80 was designed by Federico Faggin and Masatoshi Shima after they left
Intel, and it is the reason the 8080's software base outlived the 8080. It
executes the 8080 instruction set as a binary-compatible subset while adding a
complete alternate register file, IX/IY index registers, bit operations, block
copy/search/IO instructions, three interrupt modes with a vector table, and
built-in DRAM refresh in a single 5 V, single-clock 40-pin package. That
combination — cheaper boards, faster interrupt response, 8080 compatibility —
put it in the TRS-80 Model I, the Osborne 1, the ZX Spectrum, CP/M machines
generally and a long tail of embedded designs
([Z80 historical summary](https://en.wikipedia.org/wiki/Zilog_Z80)). It stayed
in production until June 2024.

This design reconstructs the NMOS part (Z8400 family: 2.5/4/6/8 MHz grades),
including the undocumented behavior that compatibility suites actually check:
SLL, IXH/IXL/IYH/IYL, the DD-CB register-copy forms, `ED 70`/`ED 71`, ED
duplicate encodings, prefix-ignore rules and the F3/F5 flag sources fed by the
Q latch and WZ/MEMPTR. Two engines are planned in the repository's usual
staging: a functional transaction-bus core verified by an independent oracle
and the ZEXALL/ZEXDOC exercisers, and a native M-cycle engine whose cycle
shapes and T-state counts are checked against the manufacturer timing tables.
The native engine is what the dependent TRS-80 Model I system will use.

**Status: instruction set complete; interrupts, exercisers and native timing outstanding.**
`src/zilog_z80_pkg` types live in `src/zilog_z80_defs.svh`, the ALU in
`src/zilog_z80_alu.sv` and the core in `src/zilog_z80.sv`. Verified against the
pinned superzazu/z80 emulator: the byte ALU over 648,328 cases with 0
mismatches (negative control rejects every perturbed case), and the instruction
core over 1,996 executions with full-state and 64 KiB memory-image comparison,
0 mismatches. Formal bmc/cover/prove pass for the implemented subset, and Yosys
synthesizes it to 16,179 generic cells. Encodings outside the subset (I/O, ED,
DD/FD, BIT (HL)) raise `fault_o` rather than executing wrongly. ZEXDOC/ZEXALL,
real software and the native timing engine remain open.

- [Specification and assumption ledger](spec/spec.md)
- [Implementation plan](plans/implementation_plan.md)
- [Test plan](plans/testplan.md)
- [Formal plan](plans/formal_plan.md)
- [Sources, oracle and software provenance](references/README.md)
- [Verification report](report/final_report.md)

Run in the project's hardware-tool environment once RTL and testbenches land:

```sh
sh design/zilog_z80/scripts/run_all.sh
```

Historical dating and technical boundaries follow the
[design index](../README.md) conventions; the index records the July 1976
launch and the provenance note for this entry.
