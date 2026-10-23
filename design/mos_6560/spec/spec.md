# VIC 6560/6561 reconstruction specification

## Scope and evidence

The complete target is a phase-separated VIC bus, NTSC/PAL raster and sync,
matrix/character/color fetches, pixels, three tones/noise/volume, POT and
light-pen capture. The digital chip is implemented: register file, sampled
raster timing/readback, display fetch and pixel sequencing, light-pen
capture and the digital sound generator (see "Complete digital VIC"
below). Composite sync/colour, the DAC curve, RC POT conversion and other
analog behavior are not implemented. See the [source review](../../../plans/mos_vic_source_review.md)
for the pinned manufacturer and independent sources and timing discrepancies.

## Register block contract

`mos_6560_regs` samples writes on rising `clk` when `phi2_i` is high.
The integration clock represents the completion of a CPU phase-two access;
it is not a claimed physical VIC master-clock generator. `addr_i` is the
actual fourteen-bit chip address. A13..A8 must equal binary 010000:
addresses 1000..10FF select registers, A7..A4 are mirrors and A3..A0 select
one of sixteen bytes. VIC-20 address 9000 maps to chip address 1000 after
board wiring; this module does not perform that board mapping.

`rw_i=1` reads. `data_oe_o` is asserted only during selected phase-two reads
with `rst_n=1`. A disabled output is represented by separate enable and
zero data, not by driving a shared bus. Writes never drive the CPU bus.
Configuration output `config_o[8*r +: 8]` exposes stored register r to
future peripheral blocks; slots 4,6,7,8,9 and bit 7 of slot 3 are zero.

| Registers | Read | Write |
|---|---|---|
| 0,1,2,5,A..F | Stored byte | Replace stored byte |
| 3 | Raster bit 0 in bit 7; stored bits 6..0 | Store bits 6..0 |
| 4 | Raster bits 8..1 | Ignored |
| 6,7 | External captured light-pen X/Y bytes | Ignored |
| 8,9 | External POT X/Y result bytes | Ignored |

The standalone register test supplies raster, light-pen and POT values.
The raster integration test connects the real timing component; input
capture/conversion blocks remain to be implemented. Read-only writes must never
override these inputs or change other configuration bytes. Both NTSC/PAL
use this register contract; no variant timing equivalence is claimed.

## Assumption ledger

- ASSUMPTION: synchronous `rst_n=0` initializes all stored configuration
  to zero and suppresses CPU drive. This is a deterministic platform
  initialization, matching the independent PAL model's initial registers;
  it is not a claim that a physical CPU reset clears VIC registers. Pin 37
  has mutually exclusive mask options. Actual power-on/reset behavior and
  validation with original VIC-20 software remain open before sign-off.
- ASSUMPTION: a clean digital phase-two completion boundary suffices for
  this isolated register block. Setup/hold, PHI1 display fetch ownership and
  asynchronous pin changes require later integration and software tests.

The manufacturer sheet's PAL oscillator and the independent model's clock
disagree; retain that open issue. NTSC readback also includes an independent
model's raster offset/partial-line behavior. Do not infer raster generation
from this block's nine-bit raster input or substitute C64 timing constants.

## Sampled raster component

`mos_6560_raster` has compile-time parameter `PAL` (default 1). `ce_i`
advances one system clock at each enabled rising `clk`. Disabled clocks
hold timing state; this is a simulation/integration enable, not CPU RDY.
The VIC raster must continue when its host CPU is stalled.

| Profile | Clocks/line | Progressive lines/frame | Readback offset |
|---|---:|---:|---:|
| PAL 6561 | 71 | 312 | 0 |
| NTSC 6560 | 65 | 261 | 37 clocks |

`scan_h_o` and `scan_line_o` give the internal scan counters. `raster_o`
and `raster_pos_o` give the separately phased CPU/light-pen readback view.
These clock-count positions are not analog sync or pixel coordinates.
`line_end_o`/`frame_end_o` identify an enabled imminent scan wrap, before
the active edge, and are suppressed during platform initialization.

The NTSC readback looks ahead by 37 clocks. At a predicted frame crossing
it uses the current frame length as the previous length and predicts the
field toggle. In field 0, readback line 0 positions 0..32 instead report
the preceding frame's line count; positions 33..64 report line 0 positions
0..31. Thus progressive readback includes line 261 for 33 clocks and line
0 for 32 clocks. Reset epoch scan 0/0 reads line 0/position 4, not 0/0.
PAL readback equals its internal scan position without this adjustment.

`interlace_i` is sampled at scan frame boundaries, matching MAME's register
0 bit 7 use. PAL ignores it. NTSC first enables with field 0 and 263 lines,
then alternates field 1/262 lines and field 0/263 lines. Clearing the request
at any boundary returns immediately to field 0/progressive 261 lines.
`frame_lines_o`, `field_o`, and `interlace_o` expose the latched state.
The unchanged extracted MAME timing functions qualify these transitions;
the unchanged complete PAL reference independently qualifies PAL counters
and registers 3/4. No original firmware qualification is claimed yet.

- ASSUMPTION: these integer timing and readback profiles follow the pinned
  independent implementations. The manufacturer's brief sheet does not
  specify their subcycle epoch and interlace transitions. Board/capture and
  real-software validation remain required. This component generates no
  composite sync, analog clock, display fetches or pixels.
- ASSUMPTION: `rst_n` is platform initialization to scan 0/0 and progressive
  base frame length, following reference startup. MAME's physical device
  reset callback does not reset raster timing. Do not connect CPU reset to
  this signal without establishing the actual mask-option/board wiring.

## Complete digital VIC (`mos_6560`)

`mos_6560` (parameter `PAL`, default 1) connects the register block, raster
component, display sequencer (`mos_6560_video`), light-pen capture
(`mos_6560_lightpen`) and sound generator (`mos_6560_audio`). One enabled
`clk` edge is one VIC system clock and, on the VIC-20, one CPU cycle.
Register 0 bit 7 drives the raster interlace request. Behavior follows the
unchanged MAME per-cycle functions selected in the
[fetch source review](../../../plans/mos_vic_fetch_review.md); preserved
floooh/chips disagreements are listed there.

Ordering within one enabled clock, matching MAME's `read`/`lp_w`/`cycle`/
`write` sequence: a selected CPU read returns the state before the edge;
the light-pen level is applied; the cycle advances raster, display, pen and
sound; a selected CPU write then updates registers. A register write is
therefore visible to the following cycle. Holds (`ce_i=0`) freeze all
sequencing; reads, writes and light-pen edges still apply.

### Display fetch and pixels

| Port | Meaning |
|---|---|
| `fetch_o` | A phase-one display fetch occurs this clock |
| `fetch_matrix_o` | The fetch is a video-matrix (character code/color) access; otherwise a character-generator access |
| `fetch_addr_o[13:0]` | Fourteen-bit VIC address; board mapping is external |
| `fetch_data_i[11:0]` | Bits 7..0 data bus, bits 11..8 color nibble, returned in the same clock |
| `pixel_o[15:0]` | Four 4-bit color indices, first pixel in bits 3..0 |

The display opens when register 1 equals the pre-advance line divided by
two and the row count sampled at line 0, cycle 2 is nonzero. Each line
opens fetching when register 0 bits 6..0 equal the post-advance clock;
four clocks later, matrix and character fetches alternate for
`min(R2 & 0x7f, 31 NTSC / 32 PAL)` columns, sampled at cycle 1. The matrix
address is `{R5[7:4], R2[7], 0..0} + vmc[11:1]`; the character address is
`{R5[3:0], 0..0} + code * height + (row & 7 or & 15)`, both truncated to
14 bits. Character data reaches the shifter two clocks after its fetch.
Hi-res and multicolor decode, the row/matrix counters (including the matrix
carry quirk) and the delayed effect of register 14/15 writes inside the
next four-pixel group follow the pinned reference. Pixel indices are
digital color numbers; palette RGB and composite video are not generated.

- ASSUMPTION: `fetch_o` is asserted only for matrix/character fetches. The
  physical VIC owns the bus on every PHI1; its idle-cycle address and the
  open-bus value seen by the CPU remain unspecified by both references.
- ASSUMPTION: display-sequencer initialization equals MAME `device_start`
  values (idle area/fetch, empty shifter at border, zero output colors).

### Light pen

`lightpen_n_i` is active low. An active edge requests capture by the next
executed cycle; capture stores `X = 2 * ((cycle + 1) mod clocks/line) +
extra` and `Y = line / 2` from the next readback position, once per frame.
The lock reopens at readback line 0, position 1, when a held pen captures
again one clock later. An edge exactly two clocks before the end of the
final readback line clears the extra X bit for that capture. Registers 6/7
read the captured bytes.

- ASSUMPTION: synchronous level sampling at each `clk` edge stands for the
  reference's asynchronous `lp_w` event; pin filtering and the pin-37 mask
  option are not modeled.

### Sound

Every second enabled clock produces a sample (`audio_sample_o`). Voices
0..2 advance at 1/8, 1/4 and 1/2 of the sample rate and noise at the
sample rate; each has a 7-bit counter reloaded with `R + 1` and an 8-bit
shift register toggling a square wave when enabled. Noise clocks its shift
register on rising edges of bit 0 of a 16-bit LFSR with taps 3, 12, 14
and 15. `audio_voices_o` gives the four voice bits (noise gated by register
13 bit 7) and `audio_level_o = (voices * 7 + 1) * volume` is the digital
DAC index of the reference.

- ASSUMPTION: the sample phase counts from platform initialization; the
  reference's DAC curve, analog filtering and output stage are not modeled.

### POT inputs

`pot_x_i`/`pot_y_i` are external sampled conversion results, as in the
reference's callbacks. The RC charge/discharge converter is analog and
remains open.
