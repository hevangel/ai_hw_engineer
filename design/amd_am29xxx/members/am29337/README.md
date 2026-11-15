# AMD Am29337 16-bit bounds checker

**First documented: June 1987 (Issue 08548B, in the 1988
Am29C300/29300 Data Book).** The Am29337 compares a 16-bit number
against lower and upper limit registers, flags out-of-bounds values
(OOB), and supports signed/unsigned comparison plus ripple cascading to
32 bits and beyond through COL/COU → CIL/CIU carries (Table 1: the
carry upgrades < to ≤; Table 2: out of bounds unless both carries show
the value inside the window). Intended to trigger counters on
in-range values in DSP front ends.

The reconstruction implements the actual limit registers with
active-low load enables, signed/unsigned comparators and the exact
carry/region semantics.

- [Specification and assumptions](spec/spec.md)
- [Manufacturer provenance](references/README.md)
- [Verification results](report/final_report.md)

Run from the repository toolchain:

```sh
sh design/amd_am29xxx/members/am29337/scripts/run_all.sh
```

The suite runs lint, formal BMC/PDR/cover (region covers for every
Table 2 row, both polarities, boundary equalities), 31,032 lockstep
comparisons with register loads driven through the D bus, then
synthesis. Electrical timing remains outside the contract.

## Roadmap ownership

Chip member: [ai_hw_engineer#173](https://github.com/hevangel/ai_hw_engineer/issues/173);
series card [#126](https://github.com/hevangel/ai_hw_engineer/issues/126).
