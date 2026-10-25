# Altair 8800 implementation plan

Follows `system/README.md` and the established virtual-platform pattern
(`micral_n`, `ibm_pc`): one persistent Verilator process behind a local HTTP
server, a web front panel, waveform capture and scripted regressions.

## Phase 1 — Board RTL (`src/altair_8800.sv`)

Instantiate `design/intel_8080/src/intel_8080.sv` with `bus_ready_i` tied
high. Around it:

- RAM array sized by `RAM_KIB` (default 16), writes gated by the protect
  latch; reads above RAM top return FFh. Combinational read, synchronous
  write on completed transfers only (`bus_req_o && !hlda_o`).
- I/O decode: port 0 SIO status, port 1 SIO data, port FF sense switches
  (address switches A15..A8), everything else FFh on reads.
- 88-SIO model: received-byte FIFO (host-fed), transmitted-byte pulse to
  the host, transmitter-busy down-counter, control writes ignored.
- Panel FSM: RUN/STOP via HOLD/HLDA, SINGLE STEP via hold-until-retire,
  EXAMINE/EXAMINE NEXT/DEPOSIT/DEPOSIT NEXT acting on RAM and the display
  latches, RESET (core reset + display address 0), CLR (SIO reset), and the
  protect latch.
- Lamp latching on every completed transfer; panel operations update the
  display latches when stopped.
- Host observation ports: memory window reads (async, read-only), CPU
  architectural outputs, counters, SIO queue levels.

## Phase 2 — Host simulator (`host/simulator.cpp`)

Verilator harness with the line protocol used by `micral_n`/`ibm_pc`:
STATE, RUN n, RUNSW, STEP, EXAMINE, EXNEXT, DEPOSIT, DEPNEXT, RESET, CLR,
PROTECT, UNPROTECT, SWITCHES a d, KEY b, TAPE path, TXDELAY n, CAPTURE n
(FST trace), QUIT. The RUN loop feeds tape bytes into the SIO FIFO with
backpressure, collects transmitted bytes into a per-poll log and advances
cycle/instruction counters. All state comes from RTL; no architectural
injection. FST capture via `verilated_fst_c.h` with a bounded tick count.

## Phase 3 — Web front panel (`host/server.py`, `host/web/`)

- `server.py` mirrors `ibm_pc/host/server.py`: /api/state poll (runs a
  burst when the machine is running), /api/control with strict validation,
  /waveform.fst with version header, Surfer assets from /opt/surfer/webapp
  under /surfer/, console text assembled from transmitted bytes.
- `host/web/`: Altair-style panel with address/data LED rows, the eight
  status lamps plus INTE/HLDA/PROT/WAIT, 16+8 toggle switches (A15..A8
  labelled SENSE), the ten panel buttons, a teletype console, CPU
  register/flag display, a memory window and the waveform viewer panel.

## Phase 4 — Scripts

- `scripts/fetch_firmware.py`: download the 4K BASIC 3.2 tape to `work/`,
  verify SHA-256 fd01fd8b...d90f, fail loudly on mismatch.
- `scripts/build.sh`: verilator --cc --exe --build with --trace-fst.
- `scripts/run_all.sh`: lint, board testbench, fetch firmware, real-software
  regression, backend test, synthesis check.
- `scripts/run_system.sh`: build + launch the panel server.
- `scripts/run_synth.sh`: yosys synthesis of board + CPU.

## Phase 5 — Verification

- `tb/tb_top.sv`: deposit and run the Operator's Manual add program
  (12+34=46 at 0202 octal) through the real panel path; SIO loopback
  status/data checks; PROTECT blocks DEPOSIT; SINGLE STEP retires exactly
  one instruction; HOLD/HLDA sequencing.
- `scripts/test_software.py`: the real-software gate. Boot 4K BASIC 3.2 via
  panel + tape, drive the startup prompts (CR, CR, N, N, N), require the
  exact `BYTES FREE`/version/OK banner, run `PRINT 2+2`, a GOTO loop and a
  floating-point expression, and match expected console output exactly.
- `scripts/test_backend.py`: HTTP API validation and waveform endpoint.
- Lint, synthesis; update `design/README.md` only if chip behavior changes
  (not expected), update `system/README.md` index and write
  `report/final_report.md`.

## Risks

- The 8080 core is opcode-complete but BASIC is the heaviest software the
  repository has run on it; semantic gaps will surface here. Fixes go into
  the chip design with its own suite re-run.
- Tape pacing: the loader and BASIC poll with no timeout, so FIFO
  backpressure is safe; tests feed everything and let the FIFO bound it.
- Panel STEP semantics across mid-instruction stops; covered by the
  testbench single-step assertions.
