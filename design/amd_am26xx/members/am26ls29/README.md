# AMD Am26LS29: quad three-state single-ended RS-423 line driver

The Am26LS29 is AMD's quad RS-423 driver: four buffered non-inverting
3-state outputs behind one active-low enable, per-driver slew-rate
control (an external capacitor per output shapes rise/fall time to
suppress near-end crosstalk), output short-circuit protection, and a
hi-impedance state that does not clamp the line across the RS-423
voltage range — with power off or three-stated, the driver lets the
line float. A full-duplex RS-423 system runs one driver against up to
twelve receivers on the shared line.

First introduced: **1978*** — documented in the
[1978 AMD Schottky and Low-Power Schottky Data Book](https://www.bitsavers.org/components/amd/_dataBooks/1978_AMD_Schottky_and_Low-Power_Schottky_Data_Book_including_Digital_Signal_Processing_Handbook_Second_Edition_197807.pdf)
(PDF pages 307-309) and reprinted in the
[1979 Linear and Interface Data Book](../../../../references/1979_AMD_Linear_and_Interface_Data_Book.pdf)
(pages 4-26 to 4-29). No month-level claim is made.

Why it matters here: it is the single-ended member of AMD's documented
EIA RS-422/423 chip set, its slew-rate-control pins are a documented
analog-only interface the digital abstraction must state explicitly
(exposed as unused inputs preserving the pin map), and its one-enable/
four-driver gating differs from the OR-ed enable pairs of the
[Am26LS31](../am26ls31/README.md) and the mode-switched
[Am26LS30](../am26ls30/README.md).

This reconstruction implements the documented digital contract as a
zero-delay combinational block, per the [specification](spec/spec.md).

**Verified.** Verilator lint, formal bmc/prove/cover, exhaustive
simulation in Verilator and xezim, and Yosys synthesis all pass — see
the [validation report](report/final_report.md).

- [Specification and assumption ledger](spec/spec.md)
- [Implementation plan](plans/implementation_plan.md)
- [Test plan](plans/testplan.md)
- [Formal plan](plans/formal_plan.md)

Run from the repository root in `ai-hw-engineer:latest`:

```sh
sh design/amd_am26xx/members/am26ls29/scripts/run_all.sh
```

## Roadmap ownership

Chip member: [ai_hw_engineer#195](https://github.com/hevangel/ai_hw_engineer/issues/195);
canonical family parent [#127](https://github.com/hevangel/ai_hw_engineer/issues/127).
Multiple models of the same chip use this one member issue.
