# AMD Am2616: quad MIL-188C and RS-232C line driver

The Am2616 is AMD's quad RS-232C/MIL-188C line driver: four inverting
DTL/TTL-compatible drivers (driver A with two data inputs, B/C/D with
one), per-driver inhibit inputs that force the output to the mark
state, supply-independent output swing from the VCC/VEE pair, internal
slew-rate limiting (lowerable with an external capacitor) and short-
circuit protected outputs. With the [Am2617](../am2617/README.md)
receiver it forms AMD's RS-232C counterpart to the Am2614/Am2615
differential pair.

First introduced: **1979*** — documented in the
[1979 Linear and Interface Data Book](../../../../references/1979_AMD_Linear_and_Interface_Data_Book.pdf)
(pages 4-78 to 4-82); the part does not appear in the 1974 Data Book or
the 1977/1978 line-driver sheets. The bound is retained rather than
guessed.

Why it matters here: its inhibit contract is a documented RS-232C
fault-protection behavior ("A HIGH logic level on the inhibit input
forces the driver output to VOL or to mark state") distinct from the
three-state and open-collector bus conventions of the other members,
and its asymmetric driver structure (one 2-input driver, three 1-input
drivers) is fixed by the logic symbol LIC-411 rather than a uniform
quad-NAND template.

This reconstruction implements the documented digital contract as a
zero-delay combinational block, per the [specification](spec/spec.md);
the RS-232C electrical conventions and protection circuits are
documented, not modeled.

**Verified.** Verilator lint, formal bmc/prove/cover, exhaustive 256-
combination simulation in Verilator and xezim, and Yosys synthesis all
pass — see the [validation report](report/final_report.md).

- [Specification](spec/spec.md)
- [Implementation plan](plans/implementation_plan.md)
- [Test plan](plans/testplan.md)
- [Formal plan](plans/formal_plan.md)

Run from the repository root in `ai-hw-engineer:latest`:

```sh
sh design/amd_am26xx/members/am2616/scripts/run_all.sh
```

## Roadmap ownership

Chip member: [ai_hw_engineer#190](https://github.com/hevangel/ai_hw_engineer/issues/190);
canonical family parent [#127](https://github.com/hevangel/ai_hw_engineer/issues/127).
Multiple models of the same chip use this one member issue.
