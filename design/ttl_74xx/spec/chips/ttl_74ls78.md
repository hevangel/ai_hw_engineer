# 74LS78: dual negative-edge-triggered J-K flip-flop, preset, shared clock and clear

**First introduced:** Exact first-introduced year not established; see linked manufacturer source..

**Manufacturer source:** [SN74LS78A](https://archive.org/details/bitsavers_tidataBookVol2_45945352/page/n369).

This building block is part of the classic logic family used to assemble
board-level computers, control logic, storage and datapaths. Its function
is useful independently of the electrical logic family.

**RTL:** [module](../../src/ttl_74ls78.sv). **Test:** [testbench](../../tb/tb_ttl_74ls78.sv).

See the [library specification](../spec.md), [implementation plan](../../plans/library_plan.md), [verification report](../../report/library_report.md), and [license/provenance](../../references/README.md).

## Functional baseline and interface notes

# ttl_74ls78 — Dual negative-edge-triggered JK FF

Same logical function as `ttl_74h78` but negative-edge clocked per the
74LS datasheet. Sharing clock and clear is intentional (matches pinout).
