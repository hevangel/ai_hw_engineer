# Intel 8042 (UPI-42)

The 8042 is Intel's Universal Peripheral Interface microcontroller with 2K
of program ROM. It is an MCS-48-derived 8-bit computer with 128 bytes of
RAM, a timer, two ports and a slave interface (data in, data out and a
status register) that lets a host CPU treat it as an I/O device.

## Why it matters

IBM chose an 8042 as the keyboard controller of the PC AT (5170), running
IBM ROM part 1503033. Besides the keyboard, its output port drives the
CPU-reset line and the A20 gate. The AT BIOS uses it to leave protected
mode, and memory above 1 MB depends on it. "8042-compatible keyboard
controller" stayed part of the PC architecture for decades. The AT BIOS
talks to it before it initializes the interrupt controllers, so it is the
first device the [IBM PC AT system](../../../system/ibm_pc_at_5170/) needs
after the timer.

## First introduced

**Not confirmed; available by 1983.** The April 1980 UPI-41A User's Manual
covers only the 1K 8041A/8741A. The 8742 data sheet (290256-001) is dated
November 1991 but is a later revision. MAME labels the IBM 1503033
controller ROM "IBM 1983", and the IBM PC AT that uses it was announced
in August 1984. No Intel source located so far gives the 8042's
introduction date.

Sources: Intel UPI-41A User's Manual 9800504-02B and 8742 data sheet
290256-001 ([Mark Ogden's Intel archive](https://mark-ogden.uk/files/intel/publications/));
[PCjs 1503033 disassembly](https://github.com/jeffpar/pcjs/blob/1a91d38eb12e5fdf91116b21ad9ef1935710a496/machines/pcx86/ibm/keyboard/8042_1503033.TXT)
by A. Tarpai; [MAME at_keybc.cpp](https://github.com/mamedev/mame/blob/master/src/devices/machine/at_keybc.cpp)
for the dump hash; [IBM PC history](https://www.ibm.com/history/personal-computer)
for the AT.

## Status

Core verified against an independent reference model, with IBM's AT
firmware running in lockstep. The IBM ROM itself is only partly available.
1,388 of its 2,048 bytes are known, so its self-test checksum cannot pass
without a verified dump. See the [report](report/final_report.md).

```sh
sh design/intel_mcs48/intel_8042/scripts/run_all.sh
```

- [Specification and assumption ledger](spec/spec.md)
- [Implementation plan](plans/implementation_plan.md)
- [Test plan](plans/testplan.md)
- [Formal plan](plans/formal_plan.md)
- [Verification report](report/final_report.md)

Issue: https://github.com/hevangel/ai_hw_engineer/issues/256
