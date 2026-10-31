# Independent raster references

The sampled raster component is compared with external code selected before
RTL implementation. No reference function is edited to agree with RTL.
Both download scripts reject a cached file whose digest differs. Originals,
generated includes, objects and vectors stay in ignored `work/` directories.

## PAL

`scripts/fetch_raster_reference.py` pins floooh/chips revision
`9e88298ce56319953ac7a43213a1120359f7a3a6`:

| Original artifact | SHA-256 |
|---|---|
| [m6561.h](https://github.com/floooh/chips/blob/9e88298ce56319953ac7a43213a1120359f7a3a6/chips/m6561.h) | `901526e4010d7d53bc4c1ccde27b54f6b0f80a384fe884f5ea0ab299a717b288` |
| [chips_common.h](https://github.com/floooh/chips/blob/9e88298ce56319953ac7a43213a1120359f7a3a6/chips/chips_common.h) | `f5992674dc6ddecd88a19b146d2259ba1142e4d2fce9b0620b14c7783965bb7b` |

`tb/pal_raster_oracle.c` compiles the complete unchanged model. Its required
framebuffer and audio services are initialized; its fetch callback returns
zero. Read samples use the genuine model's bus access on a private copy so
sampling does not consume a clock. The copied model has a separate scratch
framebuffer to avoid modifying the live output. Its live bus tick handles
the actual register-3 writes before advancing raster, matching the test
interface. Both internal counters and register 3/4 bytes are compared.
Clock-enable holds omit ticks and still check CPU readback.

## NTSC

`scripts/fetch_ntsc_reference.py` pins MAME revision
`41a494b6ef80adc924ccb2bdba1ee69580276e0c`:

| Original artifact | SHA-256 |
|---|---|
| [mos6560.cpp](https://github.com/mamedev/mame/blob/41a494b6ef80adc924ccb2bdba1ee69580276e0c/src/devices/sound/mos6560.cpp) | `d8b17b6c6bf47d2b52ddbab0ec5b7bb5c0ef1abe32a058964ed613c791aa198f` |
| [mos6560.h](https://github.com/mamedev/mame/blob/41a494b6ef80adc924ccb2bdba1ee69580276e0c/src/devices/sound/mos6560.h) | `36bd790c22f6f6f7f3d163bc5cbbec3d19f18289d322a0e5f67e028b302e89a9` |

The fetcher extracts exact, unchanged bodies of `device_reset`,
`raster_line`, `last_line_cycles`, `end_of_line`, `end_of_frame` and `cycle`.
`tb/ntsc_raster_oracle.cpp` provides their needed class fields and inert
services for unrelated display/fetch/light-pen work. Those services never
change timing state. The original `cycle` controls line/frame transitions;
the adapter increments the cycle count afterward as upstream
`update_cycles` does. Readback calls the original `raster_line`, not an
adapter reconstruction of its equations. The header independently pins
variant constants. Register read packing follows the manufacturer map;
this adapter does not qualify the complete MAME bus/device framework.

## Comparison and limits

The test compares every packed output in each profile before every checked
edge, including raw scan, independently phased readback, frame length,
field/interlace state, imminent wrap flags and actual register-bus bytes.
It sweeps interlace enable/disable at all 65 horizontal phases, leaving
from both fields, and includes pulses that miss the frame boundary,
mid-frame initialization and timing holds with live reads.

Contiguous initial/final runs produce reference vectors for the same SV
replay bench in Verilator and xezim. The unrecorded exhaustive phase sweep
is fully checked by C++ and bracketed by resets; it is not represented by
skipping clocks inside a recorded sequence. The same reference artifacts
generate both simulators' vectors.

Upstream license notices remain in the unchanged cached artifacts and
extracted function include. Neither zero-filled display memory nor stubbed
services establish fetch, image, audio, POT, light-pen or electrical fidelity.
These are digital model comparisons, not independent silicon measurements
or original VIC-20 software qualification. The specification's assumptions
remain open before full-chip sign-off.
