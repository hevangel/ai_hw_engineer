# AMD Am26S02: Schottky dual retriggerable, resettable monostable

The Am26S02 is AMD's Advanced Schottky grade of the dual retriggerable
one-shot, with PNP inputs that cut the trigger/clear loading to 0.4
Schottky unit loads, a 28 ns-to-∞ pulse range (final data), and a 100 kΩ
maximum timing resistor — the fastest member of the Am26xx monostable
line, targeted at the Am54S/74S logic environment.

First introduced: **1974*** — the
[1974 Data Book](../../../../references/1974_AMD_Data_Book.pdf) prints it
as *preliminary data* (catalog pages 4-33 to 4-38), which locates the
part in that year; the final data appears in the
[1978 AMD Schottky and Low-Power Schottky Data Book](https://www.bitsavers.org/components/amd/_dataBooks/1978_AMD_Schottky_and_Low-Power_Schottky_Data_Book_including_Digital_Signal_Processing_Handbook_Second_Edition_197807.pdf)
(pages 4-50 to 4-53) with the function table and pin map unchanged and
the pulse range narrowed from 40 ns to 28 ns. No month-level claim is
made and the preliminary-to-final delta is recorded.

Why it matters here: the preliminary-to-final qualification is a
worked example of contracting a part from a preliminary sheet — the
digital contract is fixed by the function table, which both printings
agree on — and the S02 completes AMD's documented speed/power grading of
the dual one-shot alongside the [Am2602](../am2602/README.md) and the
[Am26L02](../am26l02/README.md).

This reconstruction implements the documented digital contract with a
parameterized pulse width standing in for the RC network, per the
[specification](spec/spec.md) and its assumption ledger.

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
sh design/amd_am26xx/members/am26s02/scripts/run_all.sh
```

## Roadmap ownership

Chip member: [ai_hw_engineer#200](https://github.com/hevangel/ai_hw_engineer/issues/200);
canonical family parent [#127](https://github.com/hevangel/ai_hw_engineer/issues/127).
Multiple models of the same chip use this one member issue.
