# AMD Am29434 ECL four-port dual-access register file

**First documented: September 1986 (preliminary datasheet, Issue 08554A,
in the 1988 Am29C300/29300 Data Book, PDF 216–229).** The ECL member of
the Am29400 family pairs with the Am29432 ECL ALU: the same 64×18
dual-access four-port register file function as the bipolar Am29334 with
ECL I/O and a 20 ns access time.

Per the series rules, this member shares the
[Am29334 RTL and verification suite](../am29334/README.md); no RTL is
duplicated. Its qualification evidence is the same full gate run under
this member's issue, with the ECL electrical layer outside the digital
contract. The datasheet is preliminary; a future final ECL datasheet that
changes the functional contract reopens this member.

- [Specification and assumptions](spec/spec.md)
- [Verification results](report/final_report.md)

Run from the repository toolchain:

```sh
sh design/amd_am29xxx/members/am29434/scripts/run_all.sh
```

## Roadmap ownership

Chip member: [ai_hw_engineer#175](https://github.com/hevangel/ai_hw_engineer/issues/175);
series card [#126](https://github.com/hevangel/ai_hw_engineer/issues/126).
