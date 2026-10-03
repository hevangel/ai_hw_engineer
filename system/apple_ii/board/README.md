# Revision-0 board reconstruction

`rev0_connectivity.json` records all 196 components and their physical pin
connections from the [pinned KiCad transcription](https://github.com/reifsnyderb/Apple-II-R0/tree/db72624ab23c02f782235bb4420d91695dc17d4e).
This is a factual connectivity extraction, not a copy of the schematic artwork.
All IC pin net memberships are now compared with the independent copper source
below. Non-IC connectivity has a bounded audit, not full certification.

The `corrections` array records each change to the imported facts. The upstream
[missing-power issue](https://github.com/reifsnyderb/Apple-II-R0/issues/25)
affects B10/B11/B12; their DIP power connections are explicitly restored.
The CPU RDY direction and active-high name are corrected without changing its
net. Component locations and net names are retained for schematic comparison.

For 48 KiB with three rows of 4116s, install identical memory-selection straps
on D1, E1, and F1: **14–10, 13–9, 12–8**. The
[original reference manual](https://apple2history.org/dl/Apple_II_Redbook.pdf)
printed page 135 specifies the identical-block rule; Figure S-6 identifies
the three 16 KiB selections. Optional ROM population must be specified
separately: six socket locations do not imply six original ROM chips installed.

## Fidelity boundary

The digital packages model their physical pins and logic functions. Analog
oscillator, RC networks, cassette amplification, speaker, and composite-video
mixing need explicit mixed-signal models. A supplied digital clock or cassette
logic level is an approximation, not a simulation of those circuits.

The authored `mos_6502` supports all 151 documented NMOS opcodes and boots
this board through a physical-pin adapter. An independent transistor CPU
remains available; [reference dependencies](DEPENDENCIES.md) identify its
external code, data and licenses. Both execute original Monitor commands.
Electrical sign-off remains outstanding.

`apple_ii_rev0_peripherals.sv` models the three analog IC functions with real
voltage inputs and reduced RC networks. See [analog assumptions](../spec/analog.md).
The ideal oscillator remains a fidelity boundary. Q3/Q4 output networks now
have reduced numerical models with observable voltages and validity flags.

## Independent copper IC audit

The factual fixture `rev0_copper_ic_nets.json` is extracted from Mike Willegal's
[revision-0 CAD archive](https://www.willegal.net/appleii/A2rev0.zip), whose layout
was traced from original board images and built as working replicas. It is a
separate source from the KiCad import. The fixture contains package pad labels
and signal memberships; it excludes artwork and track geometry.

| Artifact | SHA-256 |
|---|---|
| A2rev0.zip | `994555e231da779b7f262d2c2fa5ab7475341d0a66a0520eb06968d6f45db3f1` |
| appleiiboardV3a36.osm | `7ba43b7783159ac7899f3883a524229177e8436f9403ed6f47100264934000c9` |

Reproduce the fixture with `python3 scripts/extract_copper_ic_nets.py
/path/to/appleiiboardV3a36.osm --check`. The extractor uses source footprint pin
labels and Signal blocks. It reads only component inventory from the import,
never imported pin-net membership or generated RTL. Its hash rejects an
unreviewed source revision. The normal offline regression uses the tracked
facts: `python3 scripts/check_copper_ic_wiring.py`.

The comparison covers **83 ICs, 1,368 physical pads, 322 nets/open nodes**.
The imported symbols omit eight source-open pads: A5 2/3/9/13/23, B3 5,
and D2 3/11. Every connected source pad must be present. There are 1,360
modeled IC terminals. Source label aliases include A-4 -> A5 character ROM,
6502 -> H7, K-13 -> J13 flip-flop, K-13_1 -> K13 amplifier, C-1 -> C1 mux
(the distinct source C1 is a capacitor), and the whitespace-containing F8
ROM label. These aliases are recorded in the fixture.

Two differences required corrections:

- The imported SOFT5 net joins two physically separate grounded-input A2 NAND
  outputs. The copper has `A2-8 soft 5` and `soft 5(a2-11)` as separate nets.
  The A2.8 branch is now `SOFT5_A2_8`. Equal steady-state logic did not prove
  that the two outputs were physically connected.
- H14.6, the unused complementary game-mux output, is grounded in both the
  source GND Signal block and its drawn ground trace. The import marked it
  unconnected. The correction preserves the copper connection; ideal supply
  strength fixes rail voltage, with short-circuit current explicitly unmodeled.

All source IC memberships agree after these corrections. This is not a
certification of all 196 components, analog parameter values, or manufactured
track geometry. `check_output_wiring.py` separately checks every published
Red Book correction, eight slot address/data/supply pinouts, spare slot buses,
USER1, the original 20/24K addressing connection, keyboard reset separation,
and the Q3/Q4 endpoint/value networks.
