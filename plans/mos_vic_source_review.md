# MOS 6560/6561 VIC source review

This prepares the next chip in the [MOS series](mos_historical_series.md).
It is a source/verification inventory, not an implemented VIC or a completed
chip milestone. Finish the specification and variant history before RTL.

## Primary evidence

- [MOS/Commodore 6560/6561 datasheet](https://6502.org/documents/datasheets/mos/mos_6560_6561_vic.pdf):
  sixteen control registers, bidirectional fourteen-bit address bus,
  twelve-bit display data bus, phase-separated CPU/display accesses,
  character/color addressing, graphics modes, sound, potentiometers,
  light-pen and mask-option pin descriptions.
- [MAME implementation](https://github.com/mamedev/mame/blob/41a494b6ef80adc924ccb2bdba1ee69580276e0c/src/devices/sound/mos6560.cpp)
  and [matching header](https://github.com/mamedev/mame/blob/41a494b6ef80adc924ccb2bdba1ee69580276e0c/src/devices/sound/mos6560.h):
  independently maintained NTSC/PAL implementations, clock/raster constants,
  readback behavior, palette and audio model. This is in `devices/sound`,
  despite including video. Its framebuffer abstraction alone is insufficient
  to qualify every physical memory-fetch phase.
- [floooh/chips m6561.h](https://github.com/floooh/chips/blob/9e88298ce56319953ac7a43213a1120359f7a3a6/chips/m6561.h):
  independent PAL tick/fetch callback/framebuffer/audio implementation with
  its original zlib license. It contains explicit documentation, open-bus
  and noise-feedback qualifications. It is not an NTSC oracle.

## Requirements to carry into the specification

The manufacturer describes display fetches during system phase 1 and CPU
register accesses during phase 2. Export actual address/data output enables
and fetch transactions; do not replace those with a direct framebuffer RAM
lookup. The upper four display data bits carry color/mode information,
independent of the eight CPU data bits. Decode the actual fourteen-bit VIC
address space before applying the VIC-20 board's memory mapping.

The register set includes screen origin, rows/columns, eight/sixteen-line
characters, video/character bases, raster readback, light-pen and POT reads,
three tone channels, noise, amplitude, auxiliary/background/border colors
and inversion/multicolor controls. Register changes during display must
be tested at their actual sampling boundary, including out-of-range values.

The matching MAME header specifies distinct variants:

| Variant | System clocks per line | Lines per frame | Dots per system clock | Reference clock |
|---|---:|---:|---:|---|
| 6560 NTSC | 65 | 261 | 4 | 14.318181 MHz / 14 |
| 6561 PAL | 71 | 312 | 4 | 4.433619 MHz / 4 |

These are independent implementation constants, not yet verified RTL
results. Do not reuse the CIA fixture's C64-like 63-clock raster for VIC.
The original manufacturer's scan, visually checked on PDF page 10, prints
the PAL oscillator as 4.436187 MHz; this disagrees with the independent
header and is a printed discrepancy rather than an OCR substitution.
The checked eighteen-page PDF has SHA-256
`84aaf8fe390932eb7087675eefa65bca00ec21524a8462256ce336a935d5aad8`.
Obtain independent board/crystal documentation before fixing a master
clock specification. Absolute oscillator/analog tolerances are separate
from integer system-clock raster timing.

Pin 37 is described with alternative mask options: memory clock, reset,
bus-available or light-pen input. Do not silently expose all as simultaneous
physical pins. Establish actual package/mask variants and their defaults.
Analog sound, composite color/luminance and RC potentiometer conversion
need explicit sampled contracts and separately qualified analog limits.

The datasheet also names the MOS 6512 as a processor driven by the generated
system clocks. Add that discovered family member to the catalog inventory;
do not assume the existing 6502 package establishes its phase/pin behavior.
An independently sourced first-introduced-year bound for each VIC variant
remains required before its design README/index entry is created.

## Verification sequence

1. Specify CPU half-cycle reads/writes, address/data enables, reset/mask
   options and all register masks. Exercise genuine board address decoding.
2. Verify both raster/sync generators and every display fetch address,
   including border, matrix and character phases, with independent traces.
3. Compare PAL output against the unchanged pinned callback model and NTSC
   against independent NTSC evidence. Keep address/fetch comparisons in
   addition to pixel comparisons; matching pictures can hide bus defects.
4. Verify tones/noise/volume, POT and light-pen paths against independent
   artifacts; preserve disagreements instead of deriving a golden model
   from the RTL. Record assumptions with actual-software validation.
5. Run original VIC-20 firmware on the native CPU/VIA/VIC combination,
   checking exact CPU checkpoints and independent video/audio results.
   This is chip qualification and does not replace any of the four
   requested system builds. Publish measured lint, formal/cover, simulation
   and synthesis results before counting a VIC milestone.
