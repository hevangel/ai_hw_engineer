# AMD Am29C323 CMOS 32 × 32 parallel multiplier

**First documented: preliminary datasheet in the 1988 Am29C300/29300
Data Book (PDF 266–289).** The low-power CMOS version of the Am29323
with 80 ns and 55 ns speed grades, pairing with the Am29300 family's
CMOS members. The preliminary datasheet documents the same function as
the bipolar Am29323 and explicitly states the SHIFT AND ACCUMULATE
semantics and the 67-bit overflow layout.

Per the series rules this member shares the
[Am29323 RTL and verification suite](../am29323/README.md); no RTL is
duplicated. Its qualification evidence is the same full gate run under
this member's issue. A final CMOS datasheet that changes the functional
contract reopens this member.

- [Specification and assumptions](spec/spec.md)

Run from the repository toolchain:

```sh
sh design/amd_am29xxx/members/am29c323/scripts/run_all.sh
```

## Roadmap ownership

Chip member: [ai_hw_engineer#176](https://github.com/hevangel/ai_hw_engineer/issues/176);
series card [#126](https://github.com/hevangel/ai_hw_engineer/issues/126).
