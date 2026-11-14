# AMD Am29334 four-port dual-access register file

**First documented: 1985 (advanced information in the Am29300 Family
Handbook); final datasheet in the 1988 Am29C300/29300 Data Book
(Amendment 10).** The Am29334 is the register file of the three-bus
Am29300 family: 64 words × 18 bits with two read ports, two write ports,
four addresses, per-byte (9-bit) write enables, transparent output
latches and an on-chip read/write address multiplexer that makes one RAM
array serve a read window and a write window in every microcycle. The
18-bit width stores byte parity for the Am29332 ALU. No clock pin: the
write window is timed by the WEAC/WEBC level and the system's single-phase
clock gates the enables externally (datasheet Figure 2).

The reconstruction implements the actual asynchronous behavior: ordered
per-byte writes with the documented read-during-write transparency, the
address multiplexer, output latches and three-state outputs, with the
both-sides-same-address collision resolved deterministically (spec
ledger).

- [Specification and assumptions](spec/spec.md)
- [Implementation plan](plans/implementation_plan.md)
- [Test plan](plans/testplan.md)
- [Manufacturer provenance](references/README.md)
- [Verification results](report/final_report.md)

Run from the repository toolchain:

```sh
sh design/amd_am29xxx/members/am29334/scripts/run_all.sh
```

The suite runs lint, formal BMC/PDR/cover (anyconst watched cells with
write-shadow invariants over a formal-only clock), 27,210 lockstep drive
cases including readback windows, then synthesis. Uninitialized and
partially written cells read as undefined data; electrical timing remains
outside the contract.

The [Am29434](../am29434/spec/spec.md) ECL member (preliminary datasheet)
documents the identical function and shares this RTL and suite.

## Roadmap ownership

Chip member: [ai_hw_engineer#172](https://github.com/hevangel/ai_hw_engineer/issues/172);
series card [#126](https://github.com/hevangel/ai_hw_engineer/issues/126).
Multiple models of the same chip share this one member issue.
