# Revision-0 reconstruction verification

Status of `system/apple-ii-review-followup` (based on `f8b528d`),
1 November 2026. Every gate is a script under `scripts/`; `run_all.sh`
runs them in order and returns nonzero while analog and font sign-off
remain incomplete. The datasheet timing gate is separate.

## Gate status

| Gate | Script | Last run | Result |
|---|---|---|---|
| Copper IC audit | `check_copper_ic_wiring.py` | 1 November 2026 | pass, <1 s |
| Package library regression | `../../design/apple_ii_chips/scripts/run_all.sh` | 1 November 2026 | pass, 5 s |
| Package synthesis | `../../design/apple_ii_chips/scripts/run_synth.sh` | 1 November 2026 | pass, 2 s |
| Verilator lint | `run_lint.sh` | 1 November 2026 | pass, 1 s |
| Socket wiring (Icarus) | `run_board_sim.sh` | 1 November 2026 | pass, 1 s |
| Floating-bus retention | `run_floating_bus_sim.sh` | 1 November 2026 | pass, 5 s |
| Paddle and peripheral | `run_peripheral_sim.sh` | 1 November 2026 | pass, <1 s |
| Video and speaker networks | `run_output_sim.sh` | 1 November 2026 | pass, 29 s |
| Nine diagnostic frames | `run_video_sim.sh` | 1 November 2026 | pass, 129 s |
| Transistor CPU smoke | `run_reference_smoke.sh` | 1 November 2026 | pass, <1 s |
| Transistor CPU Monitor boot | `run_reference_boot.sh` | 1 November 2026 | pass, 77 s |
| Cassette byte routines | `run_cassette_sim.sh` | 1 November 2026 | pass, 258 s |
| Front-panel transport | `run_host_test.sh` | 1 November 2026 | pass, <1 s |
| Integer BASIC | `run_basic_sim.sh` | 1 November 2026 | pass, 278 s |
| Authored CPU Monitor boot | `run_authored_boot.sh` | 1 November 2026 | pass, 65 s |
| Authored CPU cassette | `run_authored_cassette.sh` | 1 November 2026 | pass, 215 s |
| Cassette command harness | `run_cassette_command_firmware.sh` | 1 November 2026 | pass, 13 s |
| Datasheet timing gate | `run_timing_sim.sh` (datasheet delays) | 1 November 2026 | pass, 144 s |
| Full cassette WRITE | `run_full_write_board.sh` | 1 November 2026 | see note |
| Full cassette READ | `run_full_read_board.sh` | 1 November 2026 | see note |

`full write board` passed on 1 November 2026 with 16,499 transitions and
16,498 exact intervals. `full read board` runs four polarity/checksum variants:
the `polarity=+1` pair (good and bad checksum) passed with 6 payload bytes and
6 readbacks each; the `polarity=-1` pair was still running when this table was
written. Both gates are hour-scale runs.

## Limits that prevent sign-off

1. This is a functional physical-package simulation, not an exact electrical
   replica. The crystal oscillator is an ideal clock input. Q3/Q4 output networks
   and configurable loads now have reduced numerical models; supply ramp,
   decoupling, device tolerances, leakage and parasitics remain unsolved.
2. Analog package models use ideal comparator thresholds, reduced RC networks,
   typical amplifier parameters, and explicit initial conditions. No vintage
   waveform comparison has been performed. Full cassette commands pass at both firmware and physical-board layers.
   Measured audio and composite-video voltage/color agreement remain outstanding.
   Digital Monitor output and diagnostic modes are validated in
   [history.md](history.md).
3. All 83 ICs and 1,368 pads now agree with an independently traced copper
   source. Non-IC components still require a complete schematic/copper audit.
   Corrections and source hashes are recorded in the board ledger.
4. The character font is a conversion from a pinned AppleWin EPROM
   representation. Its physical package pin/address mapping is tested, but
   the converted glyph contents have not been compared to an original 2513 dump.
5. Passive system-bus charge preserves the preceding video byte. Cold DRAM now
   powers up as a documented zero pattern, which cut the Monitor gate's unknown
   reads from 4,516 to 2; both are undriven soft-switch reads at $C054/$C056.
   Success still does not certify those electrical read values.
6. Xezim package tests pass; the complete resolved-bus board test loses driven
   CPU data, so Icarus is the board simulator and Xezim is not a board option.
   `scripts/run_xezim_board_probe.sh` reproduces the defect and is expected to
   fail; it is not yet reduced to an isolated minimal case.

No SBY proofs are claimed for these mixed-signal/event package models.
Analog, DRAM event models, and the external transistor CPU are simulation-only;
their synthesis is not claimed. The full system `run_all.sh` intentionally
returns nonzero after successful regressions while the requirements above remain.

