# AMD Am26LS31: quad high-speed differential line driver

The Am26LS31 is AMD's quad RS-422 differential driver: four drivers with
complementary 3-state output pairs (Y true, Z inverted), an OR-ed
complementary enable pair, 2.0 ns typical output skew and 12 ns typical
delay over 100 Ω terminated lines, from a single +5 V supply. Its
outputs do not load the line when VCC = 0, and the pair is short-
circuit protected. The receiver counterpart is the
[Am26LS32](../am26ls32/README.md); the shared RS-422/423 application
note in the same data book binds the chip set together.

First introduced: **1977*** — documented in the
[1977 AMD Linear and Interface Data Book](https://www.bitsavers.org/components/amd/_dataBooks/1977_AMD_Linear_and_Interface_Data_Book.pdf)
and reprinted in the
[1979 Linear and Interface Data Book](../../../../references/1979_AMD_Linear_and_Interface_Data_Book.pdf)
(pages 4-36 to 4-39). No month-level claim is made.

Why it matters here: its enable structure is the exact complement of
the Am26LS32 receiver's (enabled when pin 4 is low OR pin 12 is high,
disabled only when both are released), and the complementary output
pair with 3-state control is the documented transmitter contract of the
most-deployed RS-422 driver generation.

This reconstruction implements the documented digital contract as a
zero-delay combinational block, per the [specification](spec/spec.md).

**Verified.** Verilator lint, formal bmc/prove/cover, exhaustive 64-
combination simulation in Verilator and xezim (including the exact
`z` state), and Yosys synthesis all pass — see the [validation
report](report/final_report.md).

- [Specification and assumption ledger](spec/spec.md)
- [Implementation plan](plans/implementation_plan.md)
- [Test plan](plans/testplan.md)
- [Formal plan](plans/formal_plan.md)

Run from the repository root in `ai-hw-engineer:latest`:

```sh
sh design/amd_am26xx/members/am26ls31/scripts/run_all.sh
```

## Roadmap ownership

Chip member: [ai_hw_engineer#197](https://github.com/hevangel/ai_hw_engineer/issues/197);
canonical family parent [#127](https://github.com/hevangel/ai_hw_engineer/issues/127).
Multiple models of the same chip use this one member issue.
