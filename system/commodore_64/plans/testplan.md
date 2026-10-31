# Commodore 64 test plan

| Check | Command | Oracle | Pass criterion |
|---|---|---|---|
| Firmware | `scripts/fetch_firmware.py` | pinned SHA-256 and MAME SHA-1 | all three ROMs match |
| Lint | `scripts/run_lint.sh` | Verilator `-Wall` | clean for PAL and NTSC |
| Boot timing | `scripts/test_oracle.py` | VICE x64sc, unchanged, same ROMs, zero RAM | PAL: cycle and registers at six IRQ entries and READY, RAM image, two 8,192-instruction traces identical |
| NTSC boot | `scripts/test_oracle.py --ntsc` | same | READY registers and RAM image (stack below S excepted) identical; cycle offsets reported |
| Software | `scripts/test_software.py [--ntsc]` | the ROMs themselves, an independent text renderer (character ROM + screen/color RAM), the SID frequency formula, CIA register semantics | every stage `ok` |
| Panel | `scripts/test_backend.py` | expected API behavior | typing, warm start, validation, FST capture |
| Synthesis | `scripts/run_synth.sh` | Yosys `check -assert` | 0 problems |

Software stages: banner, bytes free, READY and the KERNAL keyboard loop;
pixel-exact 320x200 text window and light-blue border; `PRINT 2+2` and a
stored program printing squares; SID voice 1 triangle at register $224B,
measured from the audio stream against `f = reg * phi2 / 2^24`; joystick
port 2 fire clearing CIA1 PA4; TOD seconds advancing; RUN/STOP + RESTORE
warm start clearing the screen to `READY.`.

`scripts/run_all.sh` runs every row.
