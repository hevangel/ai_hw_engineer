# Specification: Intel 80387SX profile

Architecture, instruction set, numerics, exceptions and pointer images are those of the 80387, as specified in [../../intel_80387dx/spec/spec.md](../../intel_80387dx/spec/spec.md). The SX differs only in its host interface:

| Item | 387DX | 387SX |
| --- | --- | --- |
| Data bus | D31–D0 | D15–D0 |
| Package | 68-pin PGA | 68-pin PLCC |
| Host | 386DX | 386SX (and the selected IBM 386SLC) |

The 387SX data sheet (240225-002) is the required source for the bus-cycle definitions, which are not yet captured here.
