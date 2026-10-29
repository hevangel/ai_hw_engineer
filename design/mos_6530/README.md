# MOS Technology 6530 RRIOT

The 6530 combines 1 KB of mask ROM, 64 bytes of SRAM, two ports and a timer.
Its integration made small 6502 computers practical with very few large
chips. The KIM-1 used two variants: 6530-002 for the monitor and 6530-003
for its cassette routines. Each carries different ROM contents and address
decode masks; they cannot be represented faithfully by simply adding ROM
to a 6532 RIOT.

**First-introduced year: not established precisely.** The conservative index
date is **by 1976**, supported by MOS's [August 1976 KIM-1 User Manual](https://bitsavers.org/components/mosTechnology/kim-1/6500-15B_KIM-1_Users_Manual_197608.pdf).
Its firmware listing is dated October 18, 1975; that is a source revision
date rather than proof of a chip shipment date. No exact launch month is
asserted.

This original SystemVerilog implements the native mask comparison inputs,
ROM/SRAM, ports, select-pin ownership, four timer rates and shared PB7
GPIO/IRQ. A separate unexpanded KIM decoder adapter instantiates either
original mask with its authentic firmware. The manufacturer manual's
post-expiry timer-read behavior takes precedence over a conflicting emulator
interpretation. The existing functional CPU runs the original monitor in
the regression; this is not a released KIM-1 system or native-cycle CPU.

- [Specification and assumption ledger](spec/spec.md)
- [Implementation plan](plans/implementation_plan.md)
- [Test plan](plans/testplan.md)
- [Formal plan](plans/formal_plan.md)
- [Original ROM provenance and hashes](references/README.md)
- [Validation report](report/final_report.md)
- [Full MOS/four-system roadmap](../../plans/mos_historical_series.md)

Run `sh design/mos_6530/scripts/run_all.sh` in the project's hardware image.
The implementation remains subject to the specification's physical mask-pin,
reset/readback and timing validation requirements. Technical sources also
include the [MOS 6530 datasheet](https://www.6502.org/documents/datasheets/mos/mos_6530_rriot.pdf)
and the independent [MAME 6530 model](https://github.com/mamedev/mame/blob/master/src/devices/machine/mos6530.cpp).
