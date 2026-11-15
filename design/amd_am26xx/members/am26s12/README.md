# AMD Am26S12: quad open-collector bus transceiver (dual enable)

The Am26S12 is AMD's Schottky quad bus transceiver: four open-collector
inverting drivers (100 mA sink at 0.7 V typical) controlled by an
active-LOW two-input AND gate — both enable pins must be low — and four
always-active bus receivers with input hysteresis chosen so the
receiver is "very insensitive to noise on the bus" (output HIGH when
the input moves to 1.4 V, LOW when it moves to 2.0 V, typical; margin
guaranteed over 0.4 V). The dual-enable structure lets active-low
decoders such as the Am54S/74S139 gate the drivers directly.

First introduced: **1974*** — the
[1974 Data Book](../../../../references/1974_AMD_Data_Book.pdf)
documents the part on the shared Am26S10/S11/S12 sheet (pages 4-39 to
4-44); the dedicated sheet with the electrical characteristics and the
receiver input-characteristic curves is in the
[1979 Linear and Interface Data Book](../../../../references/1979_AMD_Linear_and_Interface_Data_Book.pdf)
(pages 4-62 to 4-66). The bound is retained rather than guessed.

Why it matters here: the S12/S12A pair is this family's documented
base-and-revision part — one truth table, two released receiver-
hysteresis grades — and per the parent issue's rule the two member
issues share the single [source file](../am26s12/src/am26s12.sv) with
an explicit revision selection, each grade verified separately (see
[Am26S12A](../am26s12a/README.md)). Its dual-enable AND also
distinguishes it from the single-enable [Am26S10](../am26s10/README.md)
and [Am26S11](../am26s11/README.md).

This reconstruction implements the documented digital contract per the
[specification](spec/spec.md) and its assumption ledger.

**Verified.** Verilator lint, formal bmc/prove/cover, exhaustive
simulation plus directed party-line checks in Verilator and xezim, and
Yosys synthesis all pass at REVISION 0 — see the [validation
report](report/final_report.md).

- [Specification and assumption ledger](spec/spec.md)
- [Implementation plan](plans/implementation_plan.md)
- [Test plan](plans/testplan.md)
- [Formal plan](plans/formal_plan.md)

Run from the repository root in `ai-hw-engineer:latest`:

```sh
sh design/amd_am26xx/members/am26s12/scripts/run_all.sh
```

## Roadmap ownership

Chip member: [ai_hw_engineer#203](https://github.com/hevangel/ai_hw_engineer/issues/203);
canonical family parent [#127](https://github.com/hevangel/ai_hw_engineer/issues/127).
Multiple models of the same chip use this one member issue.
