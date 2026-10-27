# Commodore 64 reference provenance

No copyrighted material is stored here.

| Item | Source | Check |
|---|---|---|
| BASIC 901226-01, KERNAL 901227-03, character ROM 901225-01 | zimmers.net CBM firmware archive, falling back to the [VICE svn-mirror at d928b850](https://github.com/VICE-Team/svn-mirror/tree/d928b850b7ef4c1b1826a6efd175d8eaa80344d8/vice/data/C64) | SHA-256 and MAME SHA-1 pinned in `scripts/fetch_firmware.py` |
| Oracle emulator | VICE x64sc, unchanged (3.7.1 in the build container) | run by `scripts/test_oracle.py` |
| System year | [MAME c64.cpp at 41a494b6](https://github.com/mamedev/mame/blob/41a494b6ef80adc924ccb2bdba1ee69580276e0c/src/mame/commodore/c64.cpp) | `COMP( 1982, c64 ...)` |
| Keyboard matrix | Commodore 64 Programmer's Reference Guide keyboard-matrix table and the KERNAL decode table at $EB81 | `host/c64_keys.py` |
| Display palette | Philip "Pepto" Timmermann's colodore values | `scripts/frame_png.py`, `host/web/app.js` |

PLA references (VICE memory tables, MAME pin order) are recorded with the
[906114 design](../../../../design/commodore_906114/spec/spec.md).
