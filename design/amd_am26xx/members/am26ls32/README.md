# AMD Am26LS32: quad differential RS-422/RS-423 line receiver

The Am26LS32 is AMD's quad differential line receiver for RS-422 and
RS-423: four non-inverting receivers with 3-state outputs (8 mA sink),
an OR-ed complementary enable pair, ±200 mV input sensitivity over the
±7 V input voltage range, 30 mV input hysteresis, 6 kΩ minimum input
impedance, 17 ns typical propagation delay, and the documented fail-safe
relationship — "output always high when inputs are open" — so a broken
line reads as a spacing state instead of floating.

First introduced: **1977*** — the Am26LS32 appears in the
[1977 AMD Linear and Interface Data Book](https://www.bitsavers.org/components/amd/_dataBooks/1977_AMD_Linear_and_Interface_Data_Book.pdf)
alongside the Am26LS31 driver; the
[1979 Linear and Interface Data Book](../../../../references/1979_AMD_Linear_and_Interface_Data_Book.pdf)
reprints it (pages 4-40 to 4-44) with the quad-family RS-422/423
application note. No month-level claim is made.

Why it matters here: together with the Am26LS29/30/31 members it forms
AMD's documented EIA RS-422/RS-423 chip set, with the application note
in the same book specifying the interconnection contracts; the
receiver's enable pair (pin 4 low OR pin 12 high) is the exact
complement of the Am26LS31 driver's enable structure, and the fail-safe
tie behavior is the distinguishing contract against the later
[Am26LS33](../am26ls33/README.md) (which trades sensitivity range).

This reconstruction implements the documented digital contract —
per-receiver non-inverting decision with 3-state outputs and fail-safe
ties — as a zero-delay combinational block, per the
[specification](spec/spec.md).

**Verified.** Verilator lint, formal bmc/prove/cover, exhaustive 1024-
combination simulation in Verilator and xezim (including the exact
`z` state), and Yosys synthesis all pass — see the [validation
report](report/final_report.md).

- [Specification and assumption ledger](spec/spec.md)
- [Implementation plan](plans/implementation_plan.md)
- [Test plan](plans/testplan.md)
- [Formal plan](plans/formal_plan.md)

Run from the repository root in `ai-hw-engineer:latest`:

```sh
sh design/amd_am26xx/members/am26ls32/scripts/run_all.sh
```

## Roadmap ownership

Chip member: [ai_hw_engineer#198](https://github.com/hevangel/ai_hw_engineer/issues/198);
canonical family parent [#127](https://github.com/hevangel/ai_hw_engineer/issues/127).
Multiple models of the same chip use this one member issue.
