# AMD Am2617: quad RS-232C line receiver

The Am2617 is AMD's quad RS-232C receiver: four single-ended inverting
receivers with guaranteed thresholds over the full military temperature
range, built-in hysteresis (output switches LOW at +2.25 V rising and
HIGH at +0.75 V falling, typ) for AC-noise immunity, a response-control
input per receiver for high-frequency-noise filtering, and TTL/DTL-
compatible outputs with 2 kΩ internal pull-ups. Input range ±30 volts.
The companion driver is the [Am2616](../am2616/README.md); the
differential counterpart is the [Am2615](../am2615/README.md).

First introduced: **1979*** — documented in the
[1979 Linear and Interface Data Book](../../../../references/1979_AMD_Linear_and_Interface_Data_Book.pdf)
(pages 4-82 to 4-85). The bound is retained rather than guessed.

Why it matters here: with the Am2616 it completes AMD's documented
RS-232C subsystem in this family, and its hysteresis thresholds are the
documented, per-receiver analog envelope the digital abstraction has to
state precisely in its assumption ledger.

This reconstruction implements the documented digital contract —
OUT = !IN per receiver in the boolean line model — as a zero-delay
combinational block, per the [specification](spec/spec.md).

**Verified.** Verilator lint, formal bmc/prove/cover, exhaustive 16-
combination simulation in Verilator and xezim, and Yosys synthesis all
pass — see the [validation report](report/final_report.md).

- [Specification and assumption ledger](spec/spec.md)
- [Implementation plan](plans/implementation_plan.md)
- [Test plan](plans/testplan.md)
- [Formal plan](plans/formal_plan.md)

Run from the repository root in `ai-hw-engineer:latest`:

```sh
sh design/amd_am26xx/members/am2617/scripts/run_all.sh
```

## Roadmap ownership

Chip member: [ai_hw_engineer#191](https://github.com/hevangel/ai_hw_engineer/issues/191);
canonical family parent [#127](https://github.com/hevangel/ai_hw_engineer/issues/127).
Multiple models of the same chip use this one member issue.
