# Revision-0 board reconstruction

`rev0_connectivity.json` records all 196 components and their physical pin
connections from the [pinned KiCad transcription](https://github.com/reifsnyderb/Apple-II-R0/tree/db72624ab23c02f782235bb4420d91695dc17d4e).
This is a factual connectivity extraction, not a copy of the schematic artwork.
The export has not yet been certified against every original schematic sheet.

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
The ideal oscillator and digital speaker/video taps remain fidelity boundaries.
