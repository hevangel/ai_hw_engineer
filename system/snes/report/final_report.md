# SNES verification report

## Contract and evidence

`src/snes.sv` is the console board around the repository's
[5A22](../../../design/ricoh_5a22/) (with the
[65C816](../../../design/wdc_65c816/)),
[5C77](../../../design/ricoh_5c77/), [5C78](../../../design/ricoh_5c78/),
[S-SMP](../../../design/sony_s_smp/) (with the
[SPC700](../../../design/sony_spc700/)) and
[S-DSP](../../../design/sony_s_dsp/) RTL: one master clock with clock
enables, a phase accumulator for the 1.024 MHz APU clock, 128 KiB work RAM
with its B-bus port, 64 KiB VRAM, 64 KiB audio RAM, LoROM and HiROM
cartridge maps with SRAM, two controllers, and separate power-on and reset
inputs. The [specification](../spec/spec.md) records sources and
assumptions A1–A4.

Software is Peter Lemon's public-domain test-ROM collection
(`PeterLemon/SNES` at revision `350b394e86ec5d62f600b5cbf64cdce3721bb6ef`).
`scripts/fetch_roms.py` downloads each ROM and its reference screenshot and
verifies them by git blob SHA-1; bytes stay in ignored `work/`. The
expected result of every test comes only from those files: the author's
screenshot, the word FAIL in a test's text layer, or, for sound demos with
no screenshot, the presence of sound.

## Results (2026-10-27)

Cloud container: Verilator 5.020, Yosys 0.33, Python 3 with numpy and
Pillow, Node Playwright for the screenshot. The project Docker image run of
`scripts/run_all.sh` is still owed.

| Stage | Measured result |
|---|---|
| Lint | `verilator --lint-only -Wall` passes for NTSC and PAL |
| CPU cores | 65C816: `cases=5080400 opcode_modes=512 bus_cycles=26144846` PASS. SPC700: `cases=256000 opcodes=256 bus_cycles=1182940` PASS (SingleStepTests, every bus cycle compared) |
| Test ROMs | 88 ROMs: **81 PASS, 5 REF, 2 KNOWN**, 0 FAIL (below) |
| Backend API | `scripts/test_backend.py` PASS: request validation, ROM list and LOAD, 512×480 screen and audio payloads, reset, FST waveform capture and download |
| Synthesis | Yosys generic synthesis of the board with all seven chips (memories blackboxed by `synth/snes_memory_stub.v`) and `check -assert` pass: 1,763,033 cells (`-noshare`, as for the S-DSP; the PPU line buffers, OAM and CGRAM are flip-flops in the generic flow) |

The 81 passing ROMs:

- CPU: all 23 `CPUTest/CPU` instruction groups, including `CPUMSC`, which
  executes STP and continues after the harness presses reset.
- Memory map: the 5 `BANK` tests (LoROM and HiROM, SlowROM and FastROM,
  work RAM).
- APU: the 7 `CPUTest/SPC700` instruction groups, each 1,005–2,039 frames
  (they upload code through the IPL and time cases with the S-SMP timers),
  and 9 sound demos that must produce non-silent S-DSP output.
- Picture, matched exactly with the screenshot in some frame:
  - HelloWorld and the Mode 7 plot demos.
  - BG maps in 2, 4 and 8 bpp, and tile flips.
  - The HiColor blend pictures, and the 64 and 128 colours per tile row
    pictures, whose palettes are rewritten by DMA during display.
  - Mode7HDMA, RedSpace9BitHDMA, WaveHDMA and WindowHDMA.
  - Interlace with HDMA and OBJ interlace.
  - Mode 7 Perspective and StarWars.
  - Mosaic in modes 3 and 5, Rings and GreenSpace.

Every emulated frame is compared with the screenshot at the full 512×480
output. That handles animated demos, and those that show the expected
picture only briefly. MosaicMode3/5 hold R, which steps the mosaic size,
and PlayTwoSong presses A to start; the inputs are listed in
`scripts/test_software.py`.

## Known differences

- **REF** (the screenshot cannot be matched pixel for pixel; the ROM runs
  without error):
  - `InterlaceFont`: the screenshot is vertically resampled; rows 30/31
    and 61/62 repeat one source row.
  - `InterlaceMoogle`: the screenshot is smoothed horizontally, with
    colours between the 5-bit levels at every edge.
  - `InterlaceScroll`, `RotZoom` and `WindowMultiHDMA`: the screenshot
    shows a scroll position, angle or zoom that the author chose with the
    joypad.
- **KNOWN** (open model difference, bounded at 0.001 of the picture):
  - `HiColor64PerTileRowPseudoHiRes` and `mandrill64PerTileRowHiRes`
    differ only in column 0 on some lines (0.0005). This is the first
    sub-screen half in pseudo-high resolution while the palette is
    rewritten every line; see the
    [5C78 report](../../../design/ricoh_5c78/report/final_report.md).
- The S-DSP is not yet compared sample by sample with an independent
  model. The lock-step gate against blargg's `SPC_DSP` is written but
  waits for approval to compile third-party code, so sound accuracy beyond
  "plays recognisably" is unverified.

## Limitations

The Verilator model runs at about 2.7 frames per second, so the panel is
practical for demos and tests but not for playing games. The PPUs render a
line at a time, so register writes in the middle of a visible line take
effect on the next line. Coprocessor cartridges, the expansion port, the
multitap and light guns, and the analog video and audio paths are not
modelled. The Surfer viewer embedded in the panel exists only in the
project Docker image.
