# 74LS68: dual 4-bit decade counters

**First introduced:** Exact first-introduced year not established; see linked manufacturer source..

**Manufacturer source:** [SN74LS68](https://archive.org/details/bitsavers_tidataBookVol2_45945352/page/n311).

This building block is part of the classic logic family used to assemble
board-level computers, control logic, storage and datapaths. Its function
is useful independently of the electrical logic family.

**RTL:** [module](../../src/ttl_74ls68.sv). **Test:** [testbench](../../tb/tb_ttl_74ls68.sv).

See the [library specification](../spec.md), [implementation plan](../../plans/library_plan.md), [verification report](../../report/library_report.md), and [license/provenance](../../references/README.md).

## Functional baseline and interface notes

# ttl_74ls68 — Dual 4-bit decade (BCD) counters

Two independent BCD counters. Each counts 0..9 and wraps. Each has its
own clock and async clear.
