# AMD Am26L02: low-power dual retriggerable resettable monostable

The Am26L02 is the low-power grade of AMD's dual retriggerable one-shot:
"one-fourth the power of the equivalent Am2602/9602", with the identical
16-pin organization, trigger polarity (Ī0 active low, I1 active high),
direct-clear behavior and outputs. The pulse range is 100 ns to ∞ per
the 1979 selection guide, timed by T = 0.33·Rx·Cx·(1 + 3.2/Rx) with Rx
from 20 kΩ to 200 kΩ.

First introduced: **1974*** — documented in the
[1974 Data Book](../../../../references/1974_AMD_Data_Book.pdf)
(catalog pages 4-27 to 4-32, truth table page 4-30); the
[1979 Linear and Interface Data Book](../../../../references/1979_AMD_Linear_and_Interface_Data_Book.pdf)
selection guide (page 1-13) still lists it as "Low-Power version 2602,
tpw = 100 ns to ∞". No earlier dated AMD documentation is located; the
bound is retained rather than guessed.

Why it matters here: it demonstrates AMD's L-grade cost/power optimization
of a documented interface part while preserving the pin and truth-table
contract, and its digital contract is verified here independently of the
[Am2602](../am2602/README.md) member it derives from.

This reconstruction implements the documented digital contract with a
parameterized pulse width standing in for the RC network, per the
[specification](spec/spec.md) and its assumption ledger; the distinct
low-power electrical envelope is documented, not modeled.

**Verified.** Verilator lint, formal bmc/prove/cover with per-channel
independent reference models and reachable covers, directed simulation in
Verilator and xezim, and Yosys synthesis all pass — see the [validation
report](report/final_report.md).

- [Specification and assumption ledger](spec/spec.md)
- [Implementation plan](plans/implementation_plan.md)
- [Test plan](plans/testplan.md)
- [Formal plan](plans/formal_plan.md)

Run from the repository root in `ai-hw-engineer:latest`:

```sh
sh design/amd_am26xx/members/am26l02/scripts/run_all.sh
```

## Roadmap ownership

Chip member: [ai_hw_engineer#193](https://github.com/hevangel/ai_hw_engineer/issues/193);
canonical family parent [#127](https://github.com/hevangel/ai_hw_engineer/issues/127).
Multiple models of the same chip use this one member issue.
