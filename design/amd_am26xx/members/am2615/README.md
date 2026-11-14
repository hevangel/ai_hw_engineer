# AMD Am2615: dual differential line receiver

The Am2615 is the receiver half of AMD's first line-communication pair
(with the [Am2614](../am2614/README.md) driver): two differential
comparators with ±15 V common-mode range, per-receiver strobe gating,
an internal 130 Ω terminating resistor, response-time control via an
external capacitor, and uncommitted-collector outputs with an optional
active pull-up. Its distinguishing contract is fail-safe protection —
"the output going to a LOW state when the inputs are open or
disconnected" — so a broken line reads as an asserted (spacing) state
rather than floating.

First introduced: **1974*** — documented in the
[1974 Data Book](../../../../references/1974_AMD_Data_Book.pdf)
(catalog pages 4-51 to 4-56; the Am9615 threshold variant shares the
sheet) and reprinted identically in the
[1979 Linear and Interface Data Book](../../../../references/1979_AMD_Linear_and_Interface_Data_Book.pdf)
(pages 4-72 to 4-77). No earlier dated AMD documentation is located;
the bound is retained rather than guessed.

Why it matters here: the sheet contains a genuine print defect — the
1974 loading-rules table swaps the STROBE and RESPONSE CONTROL pin
labels while three figures in the same books agree on the opposite
assignment. The reconstruction documents and resolves that conflict
from the 1979 logic diagram (LIC-399), the switching-test circuit and
the frequency-response figure, an example of source conflict
resolution the family's assumption ledgers exist for.

This reconstruction implements the documented digital contract —
OUT = !(COMP && STROBE) per receiver with the fail-safe tie
resolution — as a zero-delay combinational block, per the
[specification](spec/spec.md).

**Verified.** Verilator lint, formal bmc/prove/cover, exhaustive 64-
combination simulation in Verilator and xezim, and Yosys synthesis all
pass — see the [validation report](report/final_report.md).

- [Specification and assumption ledger](spec/spec.md)
- [Implementation plan](plans/implementation_plan.md)
- [Test plan](plans/testplan.md)
- [Formal plan](plans/formal_plan.md)

Run from the repository root in `ai-hw-engineer:latest`:

```sh
sh design/amd_am26xx/members/am2615/scripts/run_all.sh
```

## Roadmap ownership

Chip member: [ai_hw_engineer#189](https://github.com/hevangel/ai_hw_engineer/issues/189);
canonical family parent [#127](https://github.com/hevangel/ai_hw_engineer/issues/127).
Multiple models of the same chip use this one member issue.
