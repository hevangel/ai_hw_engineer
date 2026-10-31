# Original Apple II system specification

Target: the original 1977 Apple II, not later II+ or IIe extensions. The [Apple II Reference Manual](https://apple2history.org/dl/Apple_II_Redbook.pdf) anchors the memory and I/O map.

Initial intended map: `$0000-$BFFF` RAM (configured to 48 KiB), `$C000-$C0FF` motherboard I/O including keyboard and display soft switches, `$C100-$CFFF` expansion slots, `$D000-$FFFF` firmware ROM. Text page 1 occupies `$0400-$07FF`; its physical row mapping must follow the manual. The keyboard latch at `$C000` and strobe clear at `$C010` need cycle-accurate read side effects.

ASSUMPTION: a 48 KiB RAM configuration is used as the first integration target. Original machines shipped with multiple RAM configurations; this choice is for the first platform build and does not define all Apple II variants.

No Apple ROM binary is included. Firmware provenance and redistribution rights must be established before adding one; the system test can accept a user-supplied ROM path in the meantime.

## Physical-package reference platform

The main reconstruction target is revision 0 with three 16 KiB rows of 4116s.
`apple_ii_rev0_digital.sv` is generated from the normalized pin manifest,
instantiating 79 digital packages. `apple_ii_rev0_reference.sv` connects H7's
physical NMOS CPU pins and the B3/H13/K13 support packages for a total of 83.
The initial behavioral memory/keyboard wrapper remains an early CPU regression.

Connectivity provenance, missing-power and RDY corrections, and identical
48 KiB memory-selection straps are in [board/README.md](../board/README.md).
The original Monitor image is hash-pinned and downloaded to ignored build
output. Its six socket images populate the ROM space for the reference test;
this configuration does not assert that every original shipped board had six
populated ROMs. [Dependency notes](../board/DEPENDENCIES.md) identify ownership
and the reference solver/netlist's different licenses.

## Additional assumption ledger

- ASSUMPTION: the checked-in board keeps the original uniform 5 ns package
  delay and 20 ns DRAM output delay for event ordering. `board/timing.json`
  records per-part typical and maximum datasheet propagation delays, selected
  with `generate_rev0.py --timing typ|max`; they stay opt-in until every
  directed testbench is retimed.
- ASSUMPTION: memory packages (4116, system ROM, 2513) are marked
  `idealized` and keep that placeholder in every timing mode, because the 4116
  model has no row-access, column-access or refresh timing.
- ASSUMPTION: two characterized delays are bounds, not board-load numbers. The
  8T97 value is its datasheet maximum at CL = 50 pF, and the 8T28 value is the
  AMD second-source maximum because no Signetics delay was readable.
- ASSUMPTION: testbenches give the delayed netlist a static settle window
  before the oscillator starts. Delayed continuous assignments otherwise
  propagate X from the all-unknown time-zero state, which silicon does not have.
- ASSUMPTION: digital supply pins use power-good tokens, including negative
  supplies; analog packages use real ideal voltage rails.
- ASSUMPTION: selected startup values initialize unresettable timing counters,
  keyboard strobe, and NE558 latches. No artificial motherboard reset is added.
- ASSUMPTION: open TTL keyboard input and released NE558 collectors read high
  through explicit boundary bias models. General chip models retain X/Z.
- ASSUMPTION: the transistor solver's two-state boundary samples unknown read
  bits high and counts them; the Monitor test rejects unknown opcodes.
- ASSUMPTION: EPROM font bits 5..1 represent the original five glyph columns.
  Address/pin mapping is tested; original-dump content comparison is pending.

Analog reductions and integration steps are documented in
[analog.md](analog.md). Exact electrical fidelity, full schematic audit,
composite-video voltage/color and complete cassette command validation remain
acceptance requirements. The authored 6502 documented-instruction firmware
gate passes using `apple_ii_rev0_authored` with the same package nets. The full
suite runs historical software and returns nonzero while those requirements
remain outstanding.

## Digital video acceptance contract

A socket bus master initializes display bytes through the same DRAM write
path as the CPU and selects modes through the real C050-C057 soft switches.
The test observes numbered scan-counter pins and the B10 pin-5 video output;
no behavioral video renderer is substituted for the motherboard.

The independent oracle uses the original manual's text row address layout
and Figure S-11 serial glyph/polarity wiring, plus the pinned AppleWin
[scanner timing reference](https://github.com/AppleWin/AppleWin/blob/736a12b0a2d59d122ec3d7257497d4ff1fc5c029/source/Video.cpp)
and [pixel expansion reference](https://github.com/AppleWin/AppleWin/blob/736a12b0a2d59d122ec3d7257497d4ff1fc5c029/source/NTSC.cpp),
with revision-0 differences taken from the original schematic and source below.
It expects 65 character clocks per line, 262 lines per NTSC frame, and
40 by 24 text cells (seven monochrome pixels per cell). The original board's
five glyph columns have two spacer columns; the source glyph content still
requires comparison against an original 2513 dump.

ASSUMPTION: a diagnostic image initializes known screen bytes before capture;
unused/uninitialized memory is not required to produce known video. Output
is sampled after package propagation delay. Digital video validation does
not validate Q3's voltage, color filtering, or the external 75-ohm load.

The high-resolution oracle deliberately ignores DL7 on revision 0. The
later-board half-dot delay is absent: see Winston Gayler, *The Apple II
Circuit Description*, Appendix B, printed p.153
([source](https://mirrors.apple2.org.za/Apple%20II%20Documentation%20Project/Books/W.%20Gayler%20-%20The%20Apple%20II%20Circuit%20Description.pdf)).
The revision-0 scan has 912 master-clock samples per line: 64 ordinary
14-clock characters plus the extended 16-clock repeated H=0 state. Sync
comparison follows Figure S-11's physical gate inputs; it does not substitute
later-board or ideal NTSC pulse widths. B10 output trails visible scan addresses
by one character, so the last visible cell spills into the initial H=0 state.

Historical display regression: type ESC then @ ($40, physical Shift-P on the
original keyboard) through the keyboard pins to
invoke the Monitor's original screen-clear routine, then deposit/examine.
Track actual CPU text-page writes in the test oracle, capture a stable full
frame during the next keyboard wait, and compare every displayed pixel to
those bytes and the externally sourced glyphs. Reject unknown visible bytes,
unknown pixels, screen changes during capture, and malformed scan timing.

The keyboard boundary accepts the actual seven data bits, not modern key labels.
Original Shift-P's code is $40, not $50. The original Monitor listing at FC2C
(`EOR #$C0`, then `BEQ HOME`) establishes the high-bit-strobed value $C0.
The display checker must assert the untouched rows are $A0 spaces after HOME;
scrolling uninitialized RAM can otherwise turn unknown bytes into known $FF
question marks at the reference boundary and falsely appear initialized.

## Cassette acceptance

The [cassette byte-routine contract](cassette.md) defines historical WRITE
body/RDBYTE execution, independent analog stimuli, exact cycle timing,
physical DRAM readback and both polarities. R18/R19 output attenuation is
modeled with explicit voltage/load assumptions in [analog.md](analog.md).
Full leader/sync acquisition, READ checksum/error handling and measured
analog waveform agreement remain requirements for sign-off.

## Additional reconstruction acceptance

All physical IC pad memberships must agree with the independently traced
Willegal Osmond source, not merely the upstream KiCad export used to generate
RTL. The checker compares all 83 packages / 1,368 pads, accounting for eight
open pads omitted by source symbols. Keep its fixture extraction reproducible
and source SHA-pinned. Published original-schematic corrections, slot pinouts
and output-network values have a separate bounded check.

Undriven I/O reads must preserve the preceding video byte, with actively driven
I/O bits replacing only their respective retained bits. ASSUMPTION: ideal
zero-delay bus charging and negligible half-cycle leakage; a weak resolved
functional model represents passive capacitance, with no calibrated decay.
Strong contention remains X. Warm CPU RES does not discharge board charge.
The disabled-retention negative control must fail the same read assertion.

ASSUMPTION: ideal rail voltage dominates device drive where real copper grounds
unused H14.6. Device short-circuit current is outside the functional model.
Do not connect the separate A2.8/A2.11 soft-5 branches merely because both are
logically high. See the [copper ledger](../board/README.md) and
[analog contract](analog.md) for external sources and remaining limits.
