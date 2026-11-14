# AMD Am26S12A: quad open-collector bus transceiver (revised hysteresis)

The Am26S12A is the revised-hysteresis grade of the
[Am26S12](../am26s12/README.md): "functionally identical to the
Am26S12 but has a different hysteresis characteristic so that the
output switches when the input is typically at 1.2 volts or 2.25
volts" — against the S12's 1.4/2.0 V pair — moving the receiver
switching points for noisier bus environments while the threshold
margin stays guaranteed above 0.4 V. One published truth table serves
both grades.

First introduced: **1974*** — the
[1974 Data Book](../../../../references/1974_AMD_Data_Book.pdf) lists
Am26S12/26S12A grade order numbers side by side on the shared
Am26S10/S11/S12 sheet; the dedicated electrical sheet is in the
[1979 Linear and Interface Data Book](../../../../references/1979_AMD_Linear_and_Interface_Data_Book.pdf)
(pages 4-62 to 4-66, with the per-grade receiver input-characteristic
curves). The bound is retained rather than guessed.

Why it matters here: per the parent issue's revision rule, documented
base and A revisions of one part share a single SystemVerilog source
with an explicit revision selection and verify each contract
separately — the S12/S12A pair is this family's instance of that rule.
The grade difference is analog (receiver thresholds), recorded as
documented constants with an elaboration-time margin check, while the
digital contract is verified independently at each grade.

This reconstruction implements the shared digital contract at
REVISION 1 per the [specification](spec/spec.md).

**Verified.** Verilator lint, formal bmc/prove/cover, exhaustive
simulation plus directed party-line checks in Verilator and xezim, and
Yosys synthesis all pass at REVISION 1 — see the [validation
report](report/final_report.md).

- [Specification and assumption ledger](spec/spec.md)
- [Implementation plan](plans/implementation_plan.md)
- [Test plan](plans/testplan.md)
- [Formal plan](plans/formal_plan.md)

Run from the repository root in `ai-hw-engineer:latest`:

```sh
sh design/amd_am26xx/members/am26s12a/scripts/run_all.sh
```

## Roadmap ownership

Chip member: [ai_hw_engineer#204](https://github.com/hevangel/ai_hw_engineer/issues/204);
canonical family parent [#127](https://github.com/hevangel/ai_hw_engineer/issues/127).
Multiple models of the same chip use this one member issue.
