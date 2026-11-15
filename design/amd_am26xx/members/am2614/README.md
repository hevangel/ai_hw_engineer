# AMD Am2614: quad single-ended line driver

The Am2614 is AMD's quad inverting line driver for multi-channel
common-ground operation: four independent 3-input inverting drivers
("two separate inputs and one common-strobe input for each pair"),
active pull-up outputs with short-circuit protection, DTL/TTL-compatible
inputs on a single 5 V supply, capable of driving 50 Ω terminated
transmission lines. In systems terms it is a high-speed, high-fan-out
 NAND gate with line-driver output stages — usable for memory decode,
buffering and clock driving as well as line transmission.

First introduced: **1974*** — documented in the
[1974 Data Book](../../../../references/1974_AMD_Data_Book.pdf)
(catalog pages 4-45 to 4-50) and reprinted identically in the
[1979 Linear and Interface Data Book](../../../../references/1979_AMD_Linear_and_Interface_Data_Book.pdf)
(pages 4-67 to 4-71). No earlier dated AMD documentation is located; the
bound is retained rather than guessed.

Why it matters here: it is the single-ended transmitter half of AMD's
first line-communication family (the receiver half is the
[Am2615](../am2615/README.md)), and its fully specified combinational
contract — four NANDs with pair strobes and a documented 16-pin map —
is the anchor for the 1979 LS-series drivers that follow it in this
family.

This reconstruction implements the documented digital contract as a
zero-delay combinational block, per the [specification](spec/spec.md);
the electrical envelope (50 Ω drive, active pull-up, short-circuit
protection, delays) is documented, not modeled.

**Verified.** Verilator lint, formal bmc/prove/cover, exhaustive 1024-
combination simulation in Verilator and xezim, and Yosys synthesis all
pass — see the [validation report](report/final_report.md).

- [Specification](spec/spec.md)
- [Implementation plan](plans/implementation_plan.md)
- [Test plan](plans/testplan.md)
- [Formal plan](plans/formal_plan.md)

Run from the repository root in `ai-hw-engineer:latest`:

```sh
sh design/amd_am26xx/members/am2614/scripts/run_all.sh
```

## Roadmap ownership

Chip member: [ai_hw_engineer#188](https://github.com/hevangel/ai_hw_engineer/issues/188);
canonical family parent [#127](https://github.com/hevangel/ai_hw_engineer/issues/127).
Multiple models of the same chip use this one member issue.
