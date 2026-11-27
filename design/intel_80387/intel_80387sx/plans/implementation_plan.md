# Implementation plan: 387SX profile

1. Source the 387SX data sheet 240225-002 and record its bus-cycle definitions and pinout.
2. Build the 16-bit coprocessor-bus unit on top of the shared controller (`VARIANT = 2`), as for the 387DX in M3/M4 of [the 387 plan](../../intel_80387dx/plans/implementation_plan.md).
3. Integrate it with the 386SX bus unit and the PS/2 Model 35 SX system.
