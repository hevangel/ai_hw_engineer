# Implementation Plan — BUSICOM 141-PF virtual platform

Dependencies: this plan assumes the spec (`../spec/spec.md`). The steps
record the completed build sequence; current verification is in
[`manual_regression.md`](../report/manual_regression.md).

1. **Firmware extraction** — `scripts/extract_rom.py` splits the reference
   1280-byte dump into `src/rom/rom_4001_N.hex` (done; verified 5×256).
2. **ROM contents** — `src/rom/rom_4001_N.hex` feed the five 4001s
   directly: the board instantiates the design-folder `intel_4001` with
   `ROM_FILE`/`CHIP_NO`/`IO_DIR` per chip (the earlier generated-wrapper
   step was removed when the 4001 switched from a mask parameter to
   `$readmemh`).
3. **Board RTL** — `src/busicom_141pf.sv`: shared 4-bit bus, 4004, five
   4001s, two 4002s sharing CM-RAM0 with P0 straps 0/1, three 4003s wired to the
   ROM0 port lines per spec §3.1; front-panel edge detectors (hammer /
   paper / red / lamps) and drum pacing per spec §3.3/§4.2.
4. **Headless bring-up** — `tb/tb_top.sv` + `scripts/run_sim.sh`: reset
   (incl. CL pulse to clear the 4001 I/O latches), free-run the firmware,
   assert scan activity; DPI stubbed off via `` `ifndef SYSTEM_DPI ``.
5. **Panel bridge** — `host/dpi/panel_bridge.c`: DPI-C library with an
   embedded HTTP server (pthread): keys, switches, lamps, paper, drum.
6. **Web app** — `host/web/`: front-panel replica (paper, collapsible drum
   window, keypad, switches, lamps, Move Up), manual replay and Surfer FST
   viewer over HTTP/JSON.
7. **System run** — `scripts/run_system.sh`: build the bridge, launch xezim
   with `--dpi-lib` or Verilator, and expose the panel (default port 8080).
8. **End-to-end tests** — `scripts/run_system_test.sh`: HTTP-driven key
   sequences, assert printed results.
9. **Docs/report** — `report/final_report.md`, `system/README.md` index,
   AGENTS.md structure update.
10. **User-manual alignment** — `spec/reference/Unicom_141P_manual.md`
    extracted from the Unicom 141 operating-instructions PDF; spec
    updated to the manual (selector positions, 14-digit capacity,
    buffer/speed/register facts, known deviations); code updated:
    decimal selector offers only the 8 real positions
    (0,1,2,3,4,5,6,8 — no 7), bridge validates against that set,
    web app retains `00` and has no `000` key, matching the manual.
11. **Manual example regression** — the 42 numbered examples are extracted
    to `spec/reference/Unicom_141P_examples.json` and replayed through
    `scripts/replay_manual.py` or `scripts/run_manual_test.sh`. The
    recovered-ROM profile matches Verilator, xezim and an independent CPU
    reference; see `report/manual_regression.md` for five source differences.
12. **Waveform view** — Verilator writes a per-operation FST at trace depth 3;
    the web app opens it in the bundled Surfer viewer beside the calculator.
