# MOS 6567 / 6569 VIC-II

The VIC-II is the Commodore 64's video controller: 40 x 25 text and
320 x 200 bitmap modes with multicolor and extended-color variants, eight
hardware sprites with collision detection, raster interrupts, a light-pen
input, DRAM refresh, and the bus arbitration (BA/AEC) that halts the 6510
during character and sprite fetches. The 6567 is the NTSC part, the 6569
the PAL part; the 8562/8565 are later HMOS revisions. Its raster
interrupts, sprites and cycle-exact bus stealing defined much of the
C64's software technique, so the C64 system build depends on it.

This design implements the 6569, 6567R8, 6567R56A, 8565 and 8562 digital
behavior in one parameterized module (`VARIANT`), dot by dot. VIC-IIe
(8564/8566, C128) extensions are excluded.

First-introduced year: **by 1983 for the 6566/6567, exact launch year
unconfirmed; 6569 and later revisions unconfirmed.** Commodore's
[Commodore 64 Programmer's Reference Guide](https://archive.org/details/c64-programmer-ref),
eighth printing explicitly dated 1983 (copyright 1982), describes the
"6566/6567 (VIC-II) Chip" in its appendix N. The 1982 copyright does not
date every page of that printing, and this review located no dated
primary document naming the 6569; neither year is asserted beyond that.

The independent reference is MAME's
[mos6566.cpp](https://github.com/mamedev/mame/blob/41a494b6ef80adc924ccb2bdba1ee69580276e0c/src/devices/video/mos6566.cpp)
(compiled unchanged); the PAL-only
[floooh/chips m6569.h](https://github.com/floooh/chips/blob/9e88298ce56319953ac7a43213a1120359f7a3a6/chips/m6569.h)
is pinned for the disagreement review.

- [Specification and assumptions](spec/spec.md)
- [Implementation plan](plans/implementation_plan.md)
- [Measured report and remaining work](report/final_report.md)
- [Source review and preserved disagreements](../../plans/mos_vicii_source_review.md)
- [Full chip/system queue](../../plans/mos_historical_series.md)

Run `sh design/mos_6567/scripts/run_all.sh` in the documented tool container.
