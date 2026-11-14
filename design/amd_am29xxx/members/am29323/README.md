# AMD Am29323 32 × 32 parallel multiplier

**First documented: 1985 (advanced information); the CMOS Am29C323
datasheet is preliminary in the 1988 data book.** The Am29323 is the
multiplier of the three-bus Am29300 family: a 32 × 32 array producing a
64-bit product into a 67-bit accumulator (PASS / ACCUMULATE / SHIFT AND
ACCUMULATE for sum-of-products and 64 × 64 multiprecision multiplies in
the datasheet's seven cycles), dual input registers per bus for
multiprecision operand staging, a temporary output register and
instruction register for pipelining, format-adjust (full or
left-shifted fractional product), rounding of the most-significant
word, byte even-parity checking/generation, and master/slave checking
through HARDERR.

The reconstruction implements the documented register set with
per-register enables and feedthrough, the exact mixed-mode product
(two's complement, unsigned, or mixed per TCX/TCY), the FA word-slice
geometry from the data-format figures, RND, the output multiplexer with
DISABLE, parity, and HARDERR comparison.

- [Specification and assumptions](spec/spec.md)
- [Manufacturer provenance](references/README.md)
- [Verification results](report/final_report.md)

Run from the repository toolchain:

```sh
sh design/amd_am29xxx/members/am29323/scripts/run_all.sh
```

The suite runs lint, formal BMC/PDR/cover, an 8,069-drive lockstep
oracle (directed accumulator-command × slice-selection sweeps, mixed
modes, accumulate and shift-and-accumulate flows, the multiprecision
64 × 64 sequence, and random full-space drives with readback windows),
then synthesis. Electrical timing and the speed grades are outside the
contract.

The [Am29C323](../am29c323/spec/spec.md) CMOS member (preliminary
datasheet) documents the same function and shares this RTL.

## Roadmap ownership

Chip member: [ai_hw_engineer#230](https://github.com/hevangel/ai_hw_engineer/issues/230);
series card [#126](https://github.com/hevangel/ai_hw_engineer/issues/126).
Multiple models of the same chip share this one member issue.
