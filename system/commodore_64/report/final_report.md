# Commodore 64 verification report

Date 2026-10-27. Build container: Verilator 5.020, VICE x64sc 3.7.1,
Yosys 0.33 plus the YoWASP Yosys 0.70 build (`YOSYS=yowasp-yosys`, needed
here because 0.33 cannot parse the VIC-II's packed arrays; the repository
image pins a newer Yosys), Python 3.13, Playwright Chromium.

## Results

| Gate | Command | Result |
|---|---|---|
| Firmware | `scripts/fetch_firmware.py` | BASIC 901226-01, KERNAL 901227-03, chargen 901225-01 hashes match |
| Lint | `scripts/run_lint.sh` | clean, PAL and NTSC |
| PAL oracle | `scripts/test_oracle.py` | **cycle-exact.** IRQ entries at cycles 2,060,443 / 2,076,843 / 2,093,268 / 2,109,692 / 2,126,123 / 2,142,533 and the first READY-loop fetch at 2,142,755 match VICE with identical registers; the 64 KiB RAM image there is identical; two 8,192-instruction cycle-stamped traces are identical |
| NTSC oracle | `scripts/test_oracle.py --ntsc` | functional match: READY registers and RAM image identical (stack bytes below S excepted); checkpoint cycle offsets RTL minus VICE = 0, 3, 3, 1, 1, -1, -1 |
| Software, PAL | `scripts/test_software.py` | all stages pass |
| Software, NTSC | `scripts/test_software.py --ntsc` | all stages pass |
| Backend | `scripts/test_backend.py` | pass |
| Synthesis | `scripts/run_synth.sh` | 193,614 cells (VIC-II 144,490; SID 31,368), `check -assert` 0 problems, storage blackboxed |
| PLA | `design/commodore_906114/scripts/run_all.sh` | all gates pass ([report](../../../design/commodore_906114/report/final_report.md)) |

Software regression detail (PAL): banner and 38,911 bytes free; KERNAL
keyboard loop reached; the 320x200 text window is pixel-exact against an
independent renderer at raster row 51, column 124 (NTSC row 23); border
color 14; `PRINT 2+2` prints 4; a stored program prints squares; SID voice 1
triangle at $224B measures 515.5 Hz against 515.5 Hz expected (NTSC
535.2 Hz); joystick 2 fire reads 239 at $DC00; TOD seconds advance; RUN/STOP
+ RESTORE clears the screen to `READY.`.

## How the oracle was matched

The CPU/VIC power-on phase is the only free parameter. Sweeping the VIC
start delay against VICE showed a single value giving zero drift at every
checkpoint on PAL (11 system clocks); on NTSC 10 gives the smallest offsets.
VICE's random RAM initialization was disabled (`-raminitstartvalue 0` and
the related options) and the RTL was filled with zero for the comparison.

## Open discrepancy: NTSC badline stall

No start delay makes NTSC cycle-exact. The first divergence is the
`STA ($F3),Y` at $E4DD near cycle 2,062,001: BA falls during the
instruction's dummy read and the RTL holds the CPU one cycle longer than
VICE. The VIC-II design matches unchanged MAME `mos6566` per fetch and BA
cycle for the 6567R8, so this is most likely a MAME-versus-VICE difference in
6567R8 badline BA timing, not a board fault. It is not resolved: neither
emulator is a physical measurement, and the report does not claim NTSC
cycle accuracy.

## Limits

- No physical-board comparison; the oracle is an emulator.
- SID analog filter, DAC and combined-waveform tables are not modeled;
  audio is a digital mix.
- No cartridges, IEC devices, datasette, paddles or light pen.
- Power-on phase and DRAM contents are chosen (spec ledger 1-2).
- The embedded Surfer viewer could not be shown in the screenshot (not
  installable in the build container); FST capture is verified by the
  backend test.
