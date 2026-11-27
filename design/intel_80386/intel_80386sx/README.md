# Intel 80386SX

**First introduced: 1988. Status: planned profile. It shares the 386DX execution core; the 16-bit-bus unit has not been built.**

Intel introduced the 386SX in 1988 as a lower-cost 386. Internally it is the full 32-bit 386, but it has a 16-bit external data bus and a 24-bit address bus (16 MB), so existing AT-class 16-bit board designs could be adapted to it. [WikiChip](https://en.wikichip.org/wiki/i386) dates the first 386SX-16 to June 16, 1988. Ken Shirriff's [die analysis](https://www.righto.com/2023/10/intel-386-die-versions.html) describes it as the low-cost 386 with a 16-bit bus. The exact day comes from a secondary source and has not been checked against an Intel announcement, so only the year is claimed here. The SX matters for the IBM PS/2 Model 25 SX and Model 35 SX targets in this program.

## Implementation

- **Execution core:** shared with the DX: [intel_80386_core](../intel_80386dx/src/intel_80386_core.sv). The core's architectural behaviour is checked against physical-chip captures; see the [DX report](../intel_80386dx/report/final_report.md).
- **Bus unit:** not yet built. It must split each core transaction into 16-bit bus cycles with BHE#/BLE#, drive A23–A1, and handle READY#, LOCK#, HOLD/HLDA, NA# pipelining and the coprocessor interface. See the [SX specification](spec/spec.md) and [plan](plans/implementation_plan.md).

The reference captures were recorded on an 80386EX, which also has a 16-bit data bus. They show 16-bit bus cycles, but the EX's bus and peripherals are not the SX's, so the captures are not a substitute for SX bus-timing evidence.

- [Specification](spec/spec.md)
- [Implementation plan](plans/implementation_plan.md)
- [Report](report/final_report.md)
