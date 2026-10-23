# MOS 6560 / 6561 VIC

The VIC combined character graphics, color, three tones, noise and game
inputs, making it a key integrated peripheral in the VIC-20. The 6560 is
the NTSC variant and the 6561 is PAL. This reconstruction implements the
complete digital chip for both variants: CPU register interface, sampled
raster timing/readback with NTSC interlace, display fetch and pixel
sequencing, light-pen capture and the digital sound generator. Original
VIC-20 firmware boots to the BASIC start-up screen on the native 6502, two
6522s and this VIC. Analog outputs (composite video, DAC curve, RC POT
conversion), the idle-cycle bus and physical validation remain open.

First-introduced year: **by 1983, exact launch year unconfirmed** for both
variants. Commodore's [VIC-20 Programmer's Reference Guide, first edition,
sixth printing](https://archive.org/details/VIC-20ProgrammersReferenceGuide1stEdition6thPrinti)
is explicitly printed in 1983 and names both variants in its manufacturer
chip description on printed page 212. Its copyright is 1982; that alone
does not date every page of the sixth printing. This conservative bound
does not assert that either chip first shipped in 1983.

The [manufacturer datasheet](https://6502.org/documents/datasheets/mos/mos_6560_6561_vic.pdf)
defines the register map and physical bus. Independent implementations are
[MAME](https://github.com/mamedev/mame/blob/41a494b6ef80adc924ccb2bdba1ee69580276e0c/src/devices/sound/mos6560.cpp)
and the PAL-only [floooh/chips model](https://github.com/floooh/chips/blob/9e88298ce56319953ac7a43213a1120359f7a3a6/chips/m6561.h).
Both profiles match unchanged MAME display, bus, light-pen and sound
functions clock by clock; disagreements with floooh/chips are preserved in
the [fetch source review](../../plans/mos_vic_fetch_review.md).

- [Specification and assumptions](spec/spec.md)
- [Implementation plan](plans/implementation_plan.md)
- [Measured report and remaining work](report/final_report.md)
- [Independent raster reference provenance](report/raster_reference.md)
- [Display/bus/sound reference and original VIC-20 firmware boot](report/vic20_software.md)
- [Display fetch source review](../../plans/mos_vic_fetch_review.md)
- [Detailed source review](../../plans/mos_vic_source_review.md)
- [Full chip/system queue](../../plans/mos_historical_series.md)

Run `sh design/mos_6560/scripts/run_all.sh` in the documented tool container.
