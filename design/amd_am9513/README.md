# AMD Am9513 System Timing Controller

Functional reconstruction of the Am9513/Am9513A programmable system timing controller.
Five 16-bit counters with binary/BCD counting, gating, load/hold/alarm registers,
master mode control, FOUT divider and command-driven control.

First introduced: **1979 (planned)** per AMD 1979 Designer's Guide.

- [Specification](spec/spec.md)
- [Implementation plan](plans/implementation_plan.md)

Run: `sh design/amd_am9513/scripts/run_all.sh` in toolchain container.