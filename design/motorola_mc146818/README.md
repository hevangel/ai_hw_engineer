# Motorola MC146818 real-time clock plus RAM

The MC146818 is a CMOS real-time clock with 64 bytes of battery-backed
RAM. It keeps seconds, minutes, hours, day of week, date, month and a
two-digit year in BCD or binary, in 12- or 24-hour form. It has a
once-per-day-to-once-per-second alarm, a programmable periodic interrupt
and square-wave output (30.5 us to 500 ms), and an update-ended interrupt.
It also holds 50 bytes of general-purpose RAM. It connects to a
multiplexed address/data bus (AS, DS, R/W, CE, AD0-AD7), and its MOTEL
circuit adapts it to Motorola- and Intel-style bus timing.

## Why it matters

IBM made the MC146818 the "RT/CMOS RAM" of the PC AT (5170). Its 64 bytes
hold the AT's configuration record: disk and display types, memory size
and the checksum the BIOS checks at every power-on. Byte 0Fh is the
"shutdown byte" that tells the BIOS where to resume after the 80286 is
reset to leave protected mode. The AT BIOS touches the chip within its
first few dozen instructions. Port 70h/71h, with the NMI mask in port 70h
bit 7, became a fixed part of the PC architecture, and "CMOS setup" and
the IRQ 8 periodic interrupt come from this chip.

## First introduced

**Not confirmed; available by 1981.** The earliest dated source found is the
full advance-information sheet in Motorola's *Microprocessors Data Manual*
(1981), p. 4-1046. It prints no document number. The later revision,
ADI-856-R1, appears in the *8-Bit Microprocessor and Peripheral Data* book
(1983). No Motorola announcement or first-shipment date has been found, so
the year in the index is a no-later-than date.

Sources: Motorola data books on bitsavers (see the [specification](spec/spec.md)
for URLs and SHA-256), the IBM PC AT Technical Reference 6280070
(March 1984), and [MAME mc146818.cpp](https://github.com/mamedev/mame/blob/master/src/devices/machine/mc146818.cpp)
(behavior cross-check only).

## Status

The pin-level synthesizable core (`src/motorola_mc146818.sv`) implements:
- all 64 locations and all register bits;
- the 22-stage divider, with the three time bases and divider reset;
- periodic interrupts and SQW for all RS codes;
- the update cycle with UIP, tBUC and tUC;
- BCD and binary data modes, 12- and 24-hour modes, leap years and
  daylight saving;
- the alarm with don't-care codes, interrupts and register C clear-on-read;
- the RESET and PS pins;
- a `$readmemh` power-on image (`NVRAM_FILE`).

It matches an independent reference model written from the data sheet:
- 46 directed tests with hand-derived expected values;
- 32 random seeds covering about 3,900 simulated seconds;
- the IBM PC AT BIOS port 70h/71h access sequences, including the first
  access at F000:01AF and the POST checkpoint 02 shutdown-byte test.

Formal prove/cover, strict lint, a mutation check and Yosys synthesis
also pass. Only the Motorola bus mode is modeled. See the
[report](report/final_report.md).

```sh
sh design/motorola_mc146818/scripts/run_all.sh
```

- [Specification, interface and assumption ledger](spec/spec.md)
- [Implementation plan](plans/implementation_plan.md)
- [Test plan](plans/testplan.md)
- [Formal plan](plans/formal_plan.md)
- [Verification report](report/final_report.md)

Issue: https://github.com/hevangel/ai_hw_engineer/issues/262
