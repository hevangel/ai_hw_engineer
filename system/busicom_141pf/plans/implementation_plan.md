# Implementation Plan — BUSICOM 141-PF virtual platform

Dependencies: this plan assumes the spec (`../spec/spec.md`). Steps are
ordered so each one is independently verifiable.

1. **Firmware extraction** — `scripts/extract_rom.py` splits the reference
   1280-byte dump into `src/rom/rom_4001_N.hex` (done; verified 5×256).
2. **ROM contents** — `src/rom/rom_4001_N.hex` feed the five 4001s
   directly: the board instantiates the design-folder `intel_4001` with
   `ROM_FILE`/`CHIP_NO`/`IO_DIR` per chip (the earlier generated-wrapper
   step was removed when the 4001 switched from a mask parameter to
   `$readmemh`).
3. **Board RTL** — `src/busicom_141pf.sv`: shared 4-bit bus, 4004, five
   4001s, two 4002s on separate CM-RAM lines, three 4003s wired to the
   ROM0 port lines per spec §3.1; front-panel edge detectors (hammer /
   paper / red / lamps) and drum pacing per spec §3.3/§4.2.
4. **Headless bring-up** — `tb/tb_top.sv` + `scripts/run_sim.sh`: reset
   (incl. CL pulse to clear the 4001 I/O latches), free-run the firmware,
   assert scan activity; DPI stubbed off via `` `ifndef SYSTEM_DPI ``.
5. **Panel bridge** — `host/dpi/panel_bridge.c`: DPI-C library with an
   embedded HTTP server (pthread): keys, switches, lamps, paper, drum.
6. **Web app** — `host/web/`: front-panel replica (paper, drum window,
   keypad, switches, lamps, Move Up), HTTP/JSON to the bridge.
7. **System run** — `scripts/run_system.sh`: build bridge, launch xezim
   with `--dpi-lib`, expose port (default 8080).
8. **End-to-end tests** — `scripts/run_system_test.sh`: HTTP-driven key
   sequences, assert printed results.
9. **Docs/report** — `report/final_report.md`, `system/README.md` index,
   AGENTS.md structure update.
