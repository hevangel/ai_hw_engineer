# Physical motherboard front panel

Run the authored CPU and unchanged historical ROM on the Icarus physical board.
The browser supplies seven-bit keyboard data/strobe and the physical RES input.
It observes B10's actual serialized video, aligned with the tested 912-clock
scan line and one-character pipeline delay. No host-side RAM, decoder or font
renderer replaces motherboard circuitry. Unknown pixels stay visibly unknown.

Use a small VPI transport because Icarus supports the required resolved nets.
Its three operations consume keyboard bytes, consume independent Reset events
and publish a packed frame. Reset is sampled at most 64 CPU clocks apart,
even when the firmware does not poll the keyboard.
Keyboard input is acknowledged through the actual B10 strobe-clear latch.
Publish complete frames atomically. The local HTTP server supplies a canvas,
keyboard/text input, Reset, CTRL-B/RETURN, and ESC/@ buttons. Bind to loopback
by default; do not deploy this development server publicly.

The initial front panel is monochrome and runs at simulator speed, not wall-clock
speed. It does not claim analog color decoding or acoustic output. The original
revision-0 board has no power-on reset, so the harness explicitly presses RES
for 20 microseconds and chooses the already documented counter/latch startup
states. A button press pulses only the real CPU RES connection; it must not
reset DRAM, video counters, analog packages or the keyboard latch.

Input files and frames are session data in ignored `work/`. Historical ROMs and
fonts remain external hash-verified artifacts under their existing ownership.
The browser server must reject non-ASCII text and overlong requests. Tests
verify keyboard ordering/EOF recovery and frame bit order/unknown preservation,
then exercise real Monitor commands through the integrated board harness.
