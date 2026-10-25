# MOS 8520 CIA

The 8520 Complex Interface Adapter is the Amiga's peripheral controller:
two 8-bit ports, two 16-bit timers, a serial shift register and a 24-bit
event counter in place of the 6526's BCD time-of-day clock. The Amiga uses
its two 8520s for the keyboard, floppy control, parallel/serial lines and
the vertical/horizontal-sync event counters that much Amiga software times
itself against. It is the queued MOS part for the Amiga chip set.

This design reuses the qualified [6526](../mos_6526/README.md) timer,
serial and interrupt blocks and adds the 8520 differences of the pinned
MAME model: binary 24-bit TOD event counter with a nibble-ripple alarm
quirk, one-shot start on timer-high writes with the 8520 reload latency,
interrupt sources latched a cycle later, and no TOD-frequency bit.

First-introduced year: **by 1986 (bibliographic evidence), exact year
unconfirmed.** The Addison-Wesley *Amiga Hardware Reference Manual*,
ISBN 0-201-11077-6, is catalogued as published in 1986
([archive.org record](https://archive.org/details/isbn_0201110776); the
scan is a restricted lending item and its text was not inspected here).
A later printing with copyright 1985-1989
([archive.org](https://archive.org/details/Amiga_Hardware_Reference_Manual_1985_Commodore))
names the "8520 Complex Interface Adaptor (CIA) Chips" in its contents.
Neither establishes a first-shipment date.

- [Specification and assumptions](spec/spec.md)
- [Implementation plan and 6526/MAME classification](plans/implementation_plan.md)
- [Measured report and remaining work](report/final_report.md)
- [Full chip/system queue](../../plans/mos_historical_series.md)

Run `sh design/mos_8520/scripts/run_all.sh` in the documented tool container.
