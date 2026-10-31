# MOS 6560/6561 VIC display-fetch source review

This review selects the independent reference for the VIC display fetch,
pixel, light-pen and sound stages of the [VIC design](../design/mos_6560/README.md)
and preserves every disagreement between the two pinned implementations.
It was written on 2026-10-23 from the unchanged sources listed below; it
is a reading of external code, not a hardware measurement.

| Reference | Revision | Scope |
|---|---|---|
| MAME `src/devices/sound/mos6560.cpp`/`.h` (BSD-3-Clause, Curt Coder) | `41a494b6ef80adc924ccb2bdba1ee69580276e0c` | NTSC 6560 and PAL 6561: per-cycle `cycle()` state machine, `fetch()`, `output_pixels()`, light pen, registers, sound |
| floooh/chips `m6561.h` (zlib) | `9e88298ce56319953ac7a43213a1120359f7a3a6` | PAL only: per-tick fetch callback, framebuffer decode, float audio |

Hashes are pinned by `design/mos_6560/scripts/fetch_ntsc_reference.py` and
`fetch_raster_reference.py`.

## Selection

MAME is the primary oracle for both profiles. Its `cycle()` exposes, per
system clock, an explicit fetch state (`FETCH_START` with a four-cycle
delay, then alternating `FETCH_MATRIX`/`FETCH_CHARGEN`), a two-stage load
pipeline into the pixel shifter, mid-group color-register effects, NTSC
and PAL constants from the same code, light-pen capture and a sound model.
Its vertical origin uses two-line units, as the manufacturer datasheet's
control-register example states (visually checked, PDF page 6: CR1 = 19
"moves Video Matrix down HEX 19 (x2) dot heights"; CR0 counts "(3x4) dot
widths", i.e. one system clock of four pixels). The datasheet's multicolor
codes on PDF page 5 (00 background, 01 border, 10 foreground, 11 auxiliary)
also match MAME's decode. The design adapter compiles nineteen
byte-preserved MAME functions (`work/ntsc-reference/mame_display_functions.inc`)
and checks the RTL's fetch strobe, fetch kind, 14-bit address, four pixel
colors, register reads and sound samples on every clock.

floooh/chips remains the unchanged PAL raster oracle already used for scan
counters and register 3/4 readback. Its display model disagrees with MAME
in the ways below, so it is **not** used as a display oracle and agreement
with it is not claimed.

## Preserved disagreements

| Topic | MAME (implemented) | floooh/chips (not implemented) |
|---|---|---|
| Fetch schedule | Fetches only inside the display window: open at `cyc == R0 & 0x7f`, four-cycle start, then one matrix and one character fetch per column | Fetches every tick; parity of the video counter selects matrix or graphics access, including in the border with a stalled counter |
| Vertical origin | `R1 == line >> 1` (two-line units), sampled before the cycle advance | `v_count == R1` in single lines, after the advance; `R1 = 0` never opens |
| Columns | `min(R2 & 0x7f, 31 NTSC / 32 PAL)`, sampled at cycle 1 | `R2 & 0x7f` columns, recomputed at the register write |
| Rows | `(R3 & 0x7e) >> 1` sampled at line 0, cycle 2 | Bottom border recomputed at the register write |
| Character rows | Row counter compared with height or twice the height; address uses `ycounter & 7` or `& 15` | 8-bit row counter compared with the height only |
| Matrix counter | 12-bit counter with the carry quirk (`+0x10`, `+0x100`) after an incremented line | 11-bit counter, reloaded from the even base |
| Pixel pipeline | Character data reaches the shifter two cycles after its fetch; 4 pixels per clock | Shifter loaded during the fetch tick, decoded on the next tick; decode skipped outside the visible window and in the border |
| Color registers | Writes to 14/15 take effect inside the next four-pixel group (pixel 1, reverse at pixel 3) | Immediate at the write |
| Light pen | Captured once per frame with a final-line extra-bit rule | Not implemented |
| POT X/Y | External callback values | Not implemented |
| Sound | 7-bit counters with 1/2/4/8 prescale, 8-bit shift-register voices, 16-bit noise LFSR (taps 3, 12, 14, 15); DAC table indexed by `(bits*7+1)*volume` | Period-based square waves, 23-bit noise LFSR (taps 22, 13), float averaging and DC filter |
| Address width | Masked to 14 bits; color RAM uses the low 10 bits | 16-bit callback addresses; board maps them |
| Open bus | Last fetched byte and color nibble kept (`fetch_open_bus_r`) | Not implemented (`FIXME`) |

## Requirements that remain open

- Neither reference defines the VIC address bus during non-display PHI1
  cycles. The physical chip fetches on every PHI1; the RTL asserts
  `fetch_o` only for matrix/character fetches and keeps the idle-cycle bus
  behavior as an open assumption.
- MAME's analog DAC curve, palette RGB values, composite sync/colour
  burst and RC POT conversion are analog behavior. The RTL exposes the
  digital DAC index and accepts external POT bytes; electrical behavior
  remains open.
- MAME's sound stream runs at half the system clock; the RTL fixes the
  sample phase from platform initialization. The real phase relationship
  between register writes and the sound divider is unmeasured.
- The Attack UFO arcade variant in the same MAME file is not a 6560/6561
  and is excluded.
- Agreement with one emulator can hide a shared misreading of the real
  chip. Original VIC-20 software running on the native CPU, VIA and VIC,
  with independently checked screen output, is required before sign-off.
