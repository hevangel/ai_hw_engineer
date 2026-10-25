# Space Invaders implementation plan

Follows the established virtual-platform pattern (micral_n, ibm_pc,
altair_8800): persistent Verilator process behind a local HTTP server, web
cabinet screen + controls, waveform capture, scripted regressions, pinned
original firmware fetched at verification time.

## Phase 1 — RTL (`src/`)

- `si_memory.sv`: storage model — 8 KiB ROM (`$readmemh` plusarg image),
  1 KiB work RAM at 2000h, 7 KiB VRAM at 2400h, mirror at 4000h–7FFFh,
  async CPU read, registered write (one-edge landing, as learned on the
  Altair board). Blackboxed for synthesis via `synth/si_memory_stub.v`.
- `space_invaders.sv`: instantiates `intel_8080` with `bus_ready_i` tied
  high; memory/IO read mux with INTA override (pending vector byte CF/D7);
  frame counter modulo 33 280 with interrupt events at 12 480/29 120 held
  until INTA; 16-bit shift register with 3-bit offset; input port
  registers from host with constant bits forced; sound-port event latches
  (we + byte for ports 3 and 5); watchdog frame counter (8 frames) that
  resets the CPU; run/step/hold machinery identical to the Altair board;
  host VRAM window; cycle/instruction/frame/interrupt counters; CPU
  observables for the panel and waves.

## Phase 2 — Host (`host/simulator.cpp`)

Line protocol: STATE (full JSON incl. 7 KiB VRAM hex + sound events +
input port bytes + counters), RUN n, RUNSW x, STEP, RESET, IN0/IN1/IN2
bytes, CAPTURE n (FST trace), QUIT. The RUN loop paces frames naturally by
cycle count; sound events accumulate like the Altair teletype log.

## Phase 3 — Web (`host/server.py`, `host/web/`)

ibm_pc-style panel: canvas screen 224×256 rendered rotated 90° CCW with
the CC0 gel bands (red 32–62, green 184–240 + partial 240–260), keyboard
mapping (5=coin, 1=1P start, arrows+space or A/D+F for P1, T=tilt), run/
pause/step/reset, sound toggle (WebAudio blips on sound-port edges),
CPU/memory state, FST capture + Surfer viewer (known to crash in the
automation browser; download link as fallback).

## Phase 4 — Scripts

- `fetch_roms.py`: pinned PCjs git revision + per-file git-blob SHA-1
  verification, CRC-32 cross-check against canonical MAME values, outputs
  to `work/`.
- `prepare_rom.py`: concatenate H|G|F|E to a single 8 KiB `$readmemh`
  image in `work/`.
- `oracle_board.c`: superzazu-i8080-driven functional board twin (memory
  map, ports, shift register, interrupts at the same cycle counts); dumps
  CPU state + VRAM hashes at checkpoints. Independent of the RTL.
- `build.sh`, `run_all.sh`, `run_system.sh`, `run_synth.sh`,
  `test_software.py`, `test_backend.py` — following the altair_8800
  templates.

## Phase 5 — Verification gates

1. Lint `-Wall`.
2. `tb/tb_top.sv`: reset → RAM/ROM check → attract loop; both ISR vectors
   executed; shift-register sequence; coin credit appears in work RAM.
3. `test_software.py`: boot to attract; verify VRAM contains the attract
   screen (e.g. score row "SCORE<1> HI-SCORE SCORE<2>" text bytes);
   coin+start; run gameplay; verify score text in VRAM increases; compare
   CPU/VRAM state against `oracle_board.c` at three checkpoints.
4. `test_backend.py`: API validation, screen endpoint data, waveform.
5. Synthesis with storage blackbox.

## Risks

- The 8080 core's injected-RST path is exercised hard for the first time
  (two vectors, continuous 120 Hz). Any divergence shows up immediately as
  a dead boot; oracle comparison localizes it.
- Interrupt phase choice (RST8 first) only matters at the first frame.
- Watchdog could mask emulation bugs as resets; the testbench counts
  watchdog resets and fails if any occur during the regression.
