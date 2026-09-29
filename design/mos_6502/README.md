# MOS Technology 6502

The 6502 was introduced in **1975** and became the CPU of the Apple II. This directory starts an original, synthesizable implementation. The present RTL supports only six opcodes and cannot boot Apple firmware.

Read the [specification](spec/spec.md), [implementation plan](plans/implementation_plan.md), and [current verification report](report/final_report.md).

The year is supported by the [IEEE historical exhibit](https://history.ieee.org/programs/ieee-global-museum/microchips-that-shook-the-world/). The exact commercial introduction date is not asserted. Instruction behavior is grounded in MOS Technology's [January 1976 programming manual](https://www.bitsavers.org/components/mosTechnology/6500-50A_MCS6500pgmManJan76.pdf); cycle timing must be checked against its [hardware manual](https://archive.6502.org/books/mcs6500_family_hardware_manual.pdf).
